from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set


@dataclass
class Member:
    name: str
    role: str
    workload_limit: int
    workload: int = 0

    def available(self) -> bool:
        return self.workload < self.workload_limit


@dataclass
class WorkItem:
    number: int
    title: str
    state: str = "open"
    labels: List[str] = field(default_factory=list)
    priority: Optional[str] = None
    milestone: Optional[str] = None
    column: Optional[str] = None
    comments: List[str] = field(default_factory=list)


@dataclass
class Issue(WorkItem):
    opened_by: Optional[str] = None
    assignee: Optional[str] = None
    days_inactive: int = 0


@dataclass
class PullRequest(WorkItem):
    author: Optional[str] = None
    changed_files: List[str] = field(default_factory=list)
    reviewers: List[str] = field(default_factory=list)
    reviews: List[str] = field(default_factory=list)


class ProjectState:
    """In-memory execution runtime for generated GitPM programs.

    GitPM distinguishes external project events from rule actions. Public methods
    model external GitHub-like operations: they update project state first and
    then dispatch exactly one matching event. Actions executed by a matching rule
    use private state-transition helpers and therefore never recursively trigger
    additional rules.
    """

    _ASSIGNABLE_ROLES: Set[str] = {"developer", "maintainer"}
    _REVIEWER_ROLES: Set[str] = {"reviewer", "maintainer"}
    _PRIORITIES: Set[str] = {"low", "medium", "high", "critical"}

    def __init__(
        self,
        repository: str,
        members: List[Dict[str, Any]],
        labels: List[str],
        milestones: List[str],
        boards: Dict[str, List[str]],
        rules: List[Dict[str, Any]],
    ) -> None:
        self.repository = repository
        self.members: Dict[str, Member] = {
            item["name"]: Member(
                item["name"],
                item["role"],
                item["workload_limit"],
            )
            for item in members
        }
        self.labels: Set[str] = set(labels)
        self.milestones: Set[str] = set(milestones)
        self.boards = boards
        self.columns: Set[str] = {
            column
            for board_columns in boards.values()
            for column in board_columns
        }
        self.rules = rules
        self.issues: Dict[int, Issue] = {}
        self.pull_requests: Dict[int, PullRequest] = {}
        self.round_robin_positions: Dict[str, int] = {}

    # ------------------------------------------------------------------
    # External project operations
    # ------------------------------------------------------------------
    # Each public operation represents one external GitHub-like change.
    # It updates state first and then dispatches one corresponding event.

    def open_issue(self, issue: Issue) -> None:
        self._register_issue(issue)
        self._dispatch_event("issue_opened", issue)

    def update_issue(
        self,
        issue: Issue,
        *,
        title: Optional[str] = None,
        days_inactive: Optional[int] = None,
    ) -> bool:
        self._require_registered_issue(issue)

        if days_inactive is not None and days_inactive < 0:
            raise ValueError("Issue inactivity cannot be negative.")

        changed = False

        if title is not None and issue.title != title:
            issue.title = title
            changed = True

        if days_inactive is not None and issue.days_inactive != days_inactive:
            issue.days_inactive = days_inactive
            changed = True

        if changed:
            self._dispatch_event("issue_updated", issue)

        return changed

    def assign_issue(self, issue: Issue, member_name: str) -> bool:
        self._require_registered_issue(issue)

        if not self._assign_member(issue, member_name):
            return False

        self._dispatch_event("issue_assigned", issue, member_name)
        return True

    def unassign_issue(self, issue: Issue) -> bool:
        self._require_registered_issue(issue)
        previous_assignee = issue.assignee

        if not self._unassign_member(issue):
            return False

        self._dispatch_event("issue_unassigned", issue, previous_assignee)
        return True

    def label_issue(self, issue: Issue, label_name: str) -> bool:
        self._require_registered_issue(issue)

        if not self._add_label(issue, label_name):
            return False

        self._dispatch_event("issue_labeled", issue, label_name)
        return True

    def unlabel_issue(self, issue: Issue, label_name: str) -> bool:
        self._require_registered_issue(issue)

        if not self._remove_label(issue, label_name):
            return False

        self._dispatch_event("issue_unlabeled", issue, label_name)
        return True

    def close_issue(self, issue: Issue) -> bool:
        self._require_registered_issue(issue)

        if not self._close_issue(issue):
            return False

        self._dispatch_event("issue_closed", issue)
        return True

    def reopen_issue(self, issue: Issue) -> bool:
        self._require_registered_issue(issue)

        if not self._reopen_issue(issue):
            return False

        self._dispatch_event("issue_reopened", issue)
        return True

    def report_issue_inactivity(self, issue: Issue, days_inactive: int) -> None:
        """Report a new external inactivity observation for an issue.

        This is an observation event rather than a state-change event. It is
        therefore dispatched for every reported processing cycle, including when
        the observed number of inactive days has not changed.
        """
        self._require_registered_issue(issue)

        if days_inactive < 0:
            raise ValueError("Issue inactivity cannot be negative.")

        issue.days_inactive = days_inactive
        self._dispatch_event("issue_inactive", issue, days_inactive)

    def open_pull_request(self, pull_request: PullRequest) -> None:
        self._register_pull_request(pull_request)
        self._dispatch_event("pull_request_opened", pull_request)

    def update_pull_request(
        self,
        pull_request: PullRequest,
        *,
        title: Optional[str] = None,
        changed_files: Optional[List[str]] = None,
    ) -> bool:
        self._require_registered_pull_request(pull_request)

        changed = False

        if title is not None and pull_request.title != title:
            pull_request.title = title
            changed = True

        if (
            changed_files is not None
            and pull_request.changed_files != changed_files
        ):
            pull_request.changed_files = list(changed_files)
            changed = True

        if changed:
            self._dispatch_event("pull_request_updated", pull_request)

        return changed

    def label_pull_request(
        self,
        pull_request: PullRequest,
        label_name: str,
    ) -> bool:
        self._require_registered_pull_request(pull_request)

        if not self._add_label(pull_request, label_name):
            return False

        self._dispatch_event(
            "pull_request_labeled",
            pull_request,
            label_name,
        )
        return True

    def unlabel_pull_request(
        self,
        pull_request: PullRequest,
        label_name: str,
    ) -> bool:
        self._require_registered_pull_request(pull_request)

        if not self._remove_label(pull_request, label_name):
            return False

        self._dispatch_event(
            "pull_request_unlabeled",
            pull_request,
            label_name,
        )
        return True

    def request_review(
        self,
        pull_request: PullRequest,
        reviewer_name: str,
    ) -> bool:
        self._require_registered_pull_request(pull_request)

        if not self._request_review(pull_request, reviewer_name):
            return False

        self._dispatch_event(
            "pull_request_review_requested",
            pull_request,
            reviewer_name,
        )
        return True

    def remove_review_request(
        self,
        pull_request: PullRequest,
        reviewer_name: str,
    ) -> bool:
        """Remove an external pending review request.

        GitPM has no separate ``review removed`` event. Removing a pending review
        request is therefore represented as a pull-request update.
        """
        self._require_registered_pull_request(pull_request)

        if not self._remove_reviewer(pull_request, reviewer_name):
            return False

        self._dispatch_event("pull_request_updated", pull_request)
        return True

    def submit_review(
        self,
        pull_request: PullRequest,
        reviewer_name: str,
    ) -> bool:
        self._require_registered_pull_request(pull_request)

        if not self._submit_review(pull_request, reviewer_name):
            return False

        self._dispatch_event(
            "pull_request_review_submitted",
            pull_request,
            reviewer_name,
        )
        return True

    def merge_pull_request(self, pull_request: PullRequest) -> bool:
        self._require_registered_pull_request(pull_request)

        if not self._merge_pull_request(pull_request):
            return False

        self._dispatch_event("pull_request_merged", pull_request)
        return True

    def close_pull_request(self, pull_request: PullRequest) -> bool:
        self._require_registered_pull_request(pull_request)

        if not self._close_pull_request(pull_request):
            return False

        self._dispatch_event("pull_request_closed", pull_request)
        return True

    def reopen_pull_request(self, pull_request: PullRequest) -> bool:
        self._require_registered_pull_request(pull_request)

        if not self._reopen_pull_request(pull_request):
            return False

        self._dispatch_event("pull_request_reopened", pull_request)
        return True

    # ------------------------------------------------------------------
    # Event dispatch and rule execution
    # ------------------------------------------------------------------

    def _dispatch_event(
        self,
        event_kind: str,
        item: WorkItem,
        event_value: Any = None,
    ) -> None:
        value_suffix = (
            "" if event_value is None else f" ({event_value})"
        )
        print(
            f"\nExternal event: {event_kind}{value_suffix} "
            f"on #{item.number}"
        )
        matched = False

        for rule in self.rules:
            if not self._event_matches(
                rule["event"],
                event_kind,
                event_value,
            ):
                continue

            if not self._evaluate_expression(rule["condition"], item, {}):
                continue

            matched = True
            print(f"Matched rule: {rule['name']}")

            statements = rule.get("statements")
            if statements is None:
                # Compatibility with older generated configurations.
                statements = [
                    {"kind": "action", "action": action}
                    for action in rule.get("actions", [])
                ]

            self._execute_statements(statements, item, {})

        if not matched:
            print("No rule matched.")
        else:
            print(
                "Rule execution completed; rule actions do not "
                "dispatch follow-up events."
            )

        self.print_item(item)
        self.print_workloads()

    def _event_matches(
        self,
        expected: Dict[str, Any],
        actual_kind: str,
        actual_value: Any,
    ) -> bool:
        if expected["kind"] != actual_kind:
            return False

        if "value" not in expected:
            return True

        if expected["kind"] == "issue_inactive":
            return (
                actual_value is not None
                and actual_value >= expected["value"]
            )

        return expected["value"] == actual_value

    def _evaluate_expression(
        self,
        expression: Dict[str, Any],
        item: WorkItem,
        environment: Dict[str, Any],
    ) -> Any:
        kind = expression["kind"]

        if kind == "boolean":
            return expression["value"]
        if kind == "integer":
            return expression["value"]
        if kind == "string":
            return expression["value"]
        if kind == "variable":
            return environment[expression["value"]]
        if kind == "inactive_days":
            return item.days_inactive if isinstance(item, Issue) else 0
        if kind == "reviewer_count":
            return len(item.reviewers) if isinstance(item, PullRequest) else 0

        if kind == "and":
            return bool(
                self._evaluate_expression(
                    expression["left"],
                    item,
                    environment,
                )
            ) and bool(
                self._evaluate_expression(
                    expression["right"],
                    item,
                    environment,
                )
            )
        if kind == "or":
            return bool(
                self._evaluate_expression(
                    expression["left"],
                    item,
                    environment,
                )
            ) or bool(
                self._evaluate_expression(
                    expression["right"],
                    item,
                    environment,
                )
            )
        if kind == "not":
            return not bool(
                self._evaluate_expression(
                    expression["condition"],
                    item,
                    environment,
                )
            )

        if kind in {
            "equals",
            "not_equals",
            "less_than",
            "less_or_equal",
            "greater_than",
            "greater_or_equal",
        }:
            left = self._evaluate_expression(
                expression["left"],
                item,
                environment,
            )
            right = self._evaluate_expression(
                expression["right"],
                item,
                environment,
            )

            if kind == "equals":
                return left == right
            if kind == "not_equals":
                return left != right
            if kind == "less_than":
                return left < right
            if kind == "less_or_equal":
                return left <= right
            if kind == "greater_than":
                return left > right
            return left >= right

        if kind == "true":
            return True
        if kind == "has_label":
            return expression["value"] in item.labels
        if kind == "priority_equals":
            return item.priority == expression["value"]
        if kind == "milestone_equals":
            return item.milestone == expression["value"]
        if kind == "in_column":
            return item.column == expression["value"]
        if kind == "title_contains":
            return expression["value"].lower() in item.title.lower()
        if kind == "is_open":
            return item.state == "open"
        if kind == "is_closed":
            return item.state == "closed"
        if kind == "is_assigned":
            return isinstance(item, Issue) and item.assignee is not None
        if kind == "is_unassigned":
            return isinstance(item, Issue) and item.assignee is None
        if kind == "opened_by":
            return (
                isinstance(item, Issue)
                and item.opened_by == expression["value"]
            )
        if kind == "assigned_to":
            return (
                isinstance(item, Issue)
                and item.assignee == expression["value"]
            )
        if kind == "assignee_has_role":
            if not isinstance(item, Issue) or item.assignee is None:
                return False
            member = self.members.get(item.assignee)
            return member is not None and member.role == expression["value"]
        if kind == "changes_path":
            return isinstance(item, PullRequest) and any(
                path.startswith(expression["value"])
                for path in item.changed_files
            )
        if kind == "authored_by":
            return (
                isinstance(item, PullRequest)
                and item.author == expression["value"]
            )
        if kind == "has_reviewer":
            return (
                isinstance(item, PullRequest)
                and len(item.reviewers) > 0
            )
        if kind == "reviewed_by":
            return (
                isinstance(item, PullRequest)
                and expression["value"] in item.reviews
            )
        if kind == "review_requested_from":
            return (
                isinstance(item, PullRequest)
                and expression["value"] in item.reviewers
            )
        if kind == "is_merged":
            return (
                isinstance(item, PullRequest)
                and item.state == "merged"
            )

        raise ValueError(f"Unknown expression kind: {kind}")

    def _execute_statements(
        self,
        statements: List[Dict[str, Any]],
        item: WorkItem,
        environment: Dict[str, Any],
    ) -> None:
        for statement in statements:
            kind = statement["kind"]

            if kind == "action":
                self._execute_action(statement["action"], item)
                continue

            if kind == "let":
                value = self._evaluate_expression(
                    statement["expression"],
                    item,
                    environment,
                )
                environment[statement["name"]] = value
                print(f"  - let {statement['name']} = {value}")
                continue

            if kind == "if":
                condition_value = bool(
                    self._evaluate_expression(
                        statement["condition"],
                        item,
                        environment,
                    )
                )
                branch_name = "then" if condition_value else "else"
                print(
                    f"  - if condition is {condition_value}: "
                    f"{branch_name} branch"
                )

                branch_environment = dict(environment)
                branch = (
                    statement["then"]
                    if condition_value
                    else statement["else"]
                )
                self._execute_statements(branch, item, branch_environment)
                continue

            raise ValueError(f"Unknown statement kind: {kind}")

    # ------------------------------------------------------------------
    # Rule action execution
    # ------------------------------------------------------------------
    # Rule actions invoke only private state-transition helpers. They never call
    # public external operations and therefore do not trigger recursive rules.

    def _execute_action(
        self,
        action: Dict[str, Any],
        item: WorkItem,
    ) -> None:
        kind = action["kind"]

        if kind == "add_label":
            if self._add_label(item, action["value"]):
                print(f"  - added label {action['value']}")
            else:
                print(f"  - label {action['value']} was already present")
            return

        if kind == "remove_label":
            if self._remove_label(item, action["value"]):
                print(f"  - removed label {action['value']}")
            else:
                print(f"  - label {action['value']} was not present")
            return

        if kind == "move_to_column":
            old_column = item.column
            if self._move_to_column(item, action["value"]):
                print(f"  - moved from {old_column} to {item.column}")
            else:
                print(f"  - item already is in column {item.column}")
            return

        if kind == "set_milestone":
            if self._set_milestone(item, action["value"]):
                print(f"  - set milestone {item.milestone}")
            else:
                print(f"  - milestone already is {item.milestone}")
            return

        if kind == "clear_milestone":
            if self._clear_milestone(item):
                print("  - cleared milestone")
            else:
                print("  - no milestone was set")
            return

        if kind == "set_priority":
            if self._set_priority(item, action["value"]):
                print(f"  - set priority {item.priority}")
            else:
                print(f"  - priority already is {item.priority}")
            return

        if kind == "add_comment":
            self._add_comment(item, action["value"])
            print(f"  - added comment: {action['value']}")
            return

        if kind == "assign_member":
            if self._assign_member(item, action["value"]):
                print(f"  - assigned {action['value']}")
            else:
                print(f"  - could not assign {action['value']}")
            return

        if kind == "assign_using_strategy":
            member_name = self._select_member(
                action["strategy"],
                action["role"],
                "assignment",
            )
            if member_name is None:
                print("  - no available member for assignment")
            elif self._assign_member(item, member_name):
                print(f"  - assigned {member_name}")
            else:
                print(f"  - could not assign {member_name}")
            return

        if kind == "unassign_member":
            previous_assignee = (
                item.assignee if isinstance(item, Issue) else None
            )
            if self._unassign_member(item):
                print(f"  - unassigned {previous_assignee}")
            else:
                print("  - item had no assignee")
            return

        if kind == "close_issue":
            if self._close_issue(item):
                print("  - closed issue")
            else:
                print("  - issue was not open")
            return

        if kind == "reopen_issue":
            if self._reopen_issue(item):
                print("  - reopened issue")
            else:
                print("  - issue was not closed")
            return

        if kind == "request_review_from":
            if self._request_review(item, action["value"]):
                print(f"  - requested review from {action['value']}")
            else:
                print(f"  - could not request review from {action['value']}")
            return

        if kind == "request_review_using_strategy":
            excluded_names: Set[str] = set()
            if isinstance(item, PullRequest) and item.author is not None:
                excluded_names.add(item.author)

            member_name = self._select_member(
                action["strategy"],
                action["role"],
                "review",
                excluded_names,
            )
            if member_name is None:
                print("  - no available member for review")
            elif self._request_review(item, member_name):
                print(f"  - requested review from {member_name}")
            else:
                print(f"  - could not request review from {member_name}")
            return

        if kind == "remove_reviewer":
            if self._remove_reviewer(item, action["value"]):
                print(f"  - removed reviewer {action['value']}")
            else:
                print(f"  - reviewer {action['value']} was not pending")
            return

        if kind == "close_pull_request":
            if self._close_pull_request(item):
                print("  - closed pull request")
            else:
                print("  - pull request was not open")
            return

        if kind == "reopen_pull_request":
            if self._reopen_pull_request(item):
                print("  - reopened pull request")
            else:
                print("  - pull request was not closed")
            return

        raise ValueError(f"Unknown action kind: {kind}")

    # ------------------------------------------------------------------
    # Private state transitions
    # ------------------------------------------------------------------

    def _register_issue(self, issue: Issue) -> None:
        if not isinstance(issue, Issue):
            raise TypeError("open_issue expects an Issue instance.")

        self._ensure_number_is_unused(issue.number)
        self._validate_initial_work_item(issue)

        if issue.assignee is not None:
            raise ValueError(
                "Open issues must not have a pre-existing assignee. "
                "Use assign_issue after open_issue."
            )

        self.issues[issue.number] = issue

    def _register_pull_request(
        self,
        pull_request: PullRequest,
    ) -> None:
        if not isinstance(pull_request, PullRequest):
            raise TypeError(
                "open_pull_request expects a PullRequest instance."
            )

        self._ensure_number_is_unused(pull_request.number)
        self._validate_initial_work_item(pull_request)

        if pull_request.reviewers:
            raise ValueError(
                "Opened pull requests must not contain pending reviewers. "
                "Use request_review after open_pull_request."
            )

        self.pull_requests[pull_request.number] = pull_request

    def _validate_initial_work_item(self, item: WorkItem) -> None:
        unknown_labels = [
            label for label in item.labels if label not in self.labels
        ]
        if unknown_labels:
            raise ValueError(
                "Work item uses undeclared label(s): "
                + ", ".join(unknown_labels)
            )

        if item.milestone is not None:
            self._require_declared_milestone(item.milestone)

        if item.column is not None:
            self._require_declared_column(item.column)

        if item.priority is not None and item.priority not in self._PRIORITIES:
            raise ValueError(f"Unknown priority: {item.priority}")

    def _ensure_number_is_unused(self, number: int) -> None:
        if number in self.issues or number in self.pull_requests:
            raise ValueError(
                f"Work item number #{number} already exists in the project."
            )

    def _add_label(self, item: WorkItem, label_name: str) -> bool:
        self._require_declared_label(label_name)

        if label_name in item.labels:
            return False

        item.labels.append(label_name)
        return True

    def _remove_label(self, item: WorkItem, label_name: str) -> bool:
        self._require_declared_label(label_name)

        if label_name not in item.labels:
            return False

        item.labels.remove(label_name)
        return True

    def _move_to_column(self, item: WorkItem, column_name: str) -> bool:
        self._require_declared_column(column_name)

        if item.column == column_name:
            return False

        item.column = column_name
        return True

    def _set_milestone(self, item: WorkItem, milestone_name: str) -> bool:
        self._require_declared_milestone(milestone_name)

        if item.milestone == milestone_name:
            return False

        item.milestone = milestone_name
        return True

    def _clear_milestone(self, item: WorkItem) -> bool:
        if item.milestone is None:
            return False

        item.milestone = None
        return True

    def _set_priority(self, item: WorkItem, priority: str) -> bool:
        if priority not in self._PRIORITIES:
            raise ValueError(f"Unknown priority: {priority}")

        if item.priority == priority:
            return False

        item.priority = priority
        return True

    def _add_comment(self, item: WorkItem, text: str) -> None:
        item.comments.append(text)

    def _assign_member(self, item: WorkItem, member_name: str) -> bool:
        if not isinstance(item, Issue):
            return False

        member = self._require_member(member_name)
        if member.role not in self._ASSIGNABLE_ROLES:
            raise ValueError(
                f"Member {member_name} cannot receive issue assignments."
            )

        if item.assignee == member_name:
            return False

        if not member.available():
            return False

        if item.assignee is not None:
            self._decrease_workload(item.assignee)

        item.assignee = member_name
        member.workload += 1
        return True

    def _unassign_member(self, item: WorkItem) -> bool:
        if not isinstance(item, Issue) or item.assignee is None:
            return False

        old_assignee = item.assignee
        item.assignee = None
        self._decrease_workload(old_assignee)
        return True

    def _close_issue(self, item: WorkItem) -> bool:
        if not isinstance(item, Issue) or item.state != "open":
            return False

        self._unassign_member(item)
        item.state = "closed"
        return True

    def _reopen_issue(self, item: WorkItem) -> bool:
        if not isinstance(item, Issue) or item.state != "closed":
            return False

        item.state = "open"
        return True

    def _request_review(
        self,
        item: WorkItem,
        member_name: str,
    ) -> bool:
        if not isinstance(item, PullRequest) or item.state != "open":
            return False

        member = self._require_member(member_name)
        if member.role not in self._REVIEWER_ROLES:
            raise ValueError(
                f"Member {member_name} cannot review pull requests."
            )

        if member_name == item.author:
            return False

        if member_name in item.reviewers or member_name in item.reviews:
            return False

        if not member.available():
            return False

        item.reviewers.append(member_name)
        member.workload += 1
        return True

    def _remove_reviewer(
        self,
        item: WorkItem,
        member_name: str,
    ) -> bool:
        if not isinstance(item, PullRequest):
            return False

        if member_name not in item.reviewers:
            return False

        item.reviewers.remove(member_name)
        self._decrease_workload(member_name)
        return True

    def _submit_review(
        self,
        item: WorkItem,
        member_name: str,
    ) -> bool:
        if not isinstance(item, PullRequest) or item.state != "open":
            return False

        if member_name not in item.reviewers:
            return False

        item.reviewers.remove(member_name)
        self._decrease_workload(member_name)

        if member_name not in item.reviews:
            item.reviews.append(member_name)

        return True

    def _release_pending_reviewers(self, item: PullRequest) -> None:
        for reviewer in list(item.reviewers):
            self._decrease_workload(reviewer)
        item.reviewers.clear()

    def _merge_pull_request(self, item: WorkItem) -> bool:
        if not isinstance(item, PullRequest) or item.state != "open":
            return False

        self._release_pending_reviewers(item)
        item.state = "merged"
        return True

    def _close_pull_request(self, item: WorkItem) -> bool:
        if not isinstance(item, PullRequest) or item.state != "open":
            return False

        self._release_pending_reviewers(item)
        item.state = "closed"
        return True

    def _reopen_pull_request(self, item: WorkItem) -> bool:
        if not isinstance(item, PullRequest) or item.state != "closed":
            return False

        item.state = "open"
        return True

    def _decrease_workload(self, member_name: str) -> None:
        member = self.members.get(member_name)
        if member is not None and member.workload > 0:
            member.workload -= 1

    # ------------------------------------------------------------------
    # Validation and selection helpers
    # ------------------------------------------------------------------

    def _require_registered_issue(self, issue: Issue) -> None:
        if not isinstance(issue, Issue):
            raise TypeError("This operation expects an Issue instance.")

        if self.issues.get(issue.number) is not issue:
            raise ValueError(
                f"Issue #{issue.number} is not registered in this project."
            )

    def _require_registered_pull_request(
        self,
        pull_request: PullRequest,
    ) -> None:
        if not isinstance(pull_request, PullRequest):
            raise TypeError(
                "This operation expects a PullRequest instance."
            )

        if self.pull_requests.get(pull_request.number) is not pull_request:
            raise ValueError(
                "Pull request "
                f"#{pull_request.number} is not registered in this project."
            )

    def _require_member(self, member_name: str) -> Member:
        member = self.members.get(member_name)
        if member is None:
            raise ValueError(f"Unknown member: {member_name}")
        return member

    def _require_declared_label(self, label_name: str) -> None:
        if label_name not in self.labels:
            raise ValueError(f"Unknown label: {label_name}")

    def _require_declared_milestone(self, milestone_name: str) -> None:
        if milestone_name not in self.milestones:
            raise ValueError(f"Unknown milestone: {milestone_name}")

    def _require_declared_column(self, column_name: str) -> None:
        if column_name not in self.columns:
            raise ValueError(f"Unknown board column: {column_name}")

    def _select_member(
        self,
        strategy: str,
        role: str,
        purpose: str,
        excluded_names: Optional[Set[str]] = None,
    ) -> Optional[str]:
        excluded_names = excluded_names or set()

        candidates = [
            member
            for member in self.members.values()
            if (
                member.role == role
                and member.available()
                and member.name not in excluded_names
            )
        ]

        if not candidates:
            return None

        candidates.sort(key=lambda member: member.name)

        if strategy == "least_busy":
            candidates.sort(key=lambda member: (member.workload, member.name))
            return candidates[0].name

        if strategy == "round_robin":
            key = f"{purpose}:{role}"
            position = self.round_robin_positions.get(key, 0)
            selected = candidates[position % len(candidates)]
            self.round_robin_positions[key] = (
                position + 1
            ) % len(candidates)
            return selected.name

        raise ValueError(f"Unknown strategy: {strategy}")

    # ------------------------------------------------------------------
    # Observable state
    # ------------------------------------------------------------------

    def print_item(self, item: WorkItem) -> None:
        print("Updated state:")
        print(f"  type: {type(item).__name__}")
        print(f"  number: {item.number}")
        print(f"  state: {item.state}")
        print(f"  labels: {item.labels}")
        print(f"  priority: {item.priority}")
        print(f"  milestone: {item.milestone}")
        print(f"  column: {item.column}")

        if isinstance(item, Issue):
            print(f"  assignee: {item.assignee}")
            print(f"  days inactive: {item.days_inactive}")

        if isinstance(item, PullRequest):
            print(f"  reviewers: {item.reviewers}")
            print(f"  reviews: {item.reviews}")

    def print_workloads(self) -> None:
        print("Workloads:")
        for member in sorted(
            self.members.values(),
            key=lambda item: item.name,
        ):
            print(
                f"  {member.name}: {member.workload}/"
                f"{member.workload_limit} ({member.role})"
            )


def run_demo(project: ProjectState) -> None:
    """Run a generic external-event scenario against a generated project.

    The scenario uses only public ProjectState operations. It never directly
    changes work-item fields and never calls the private event dispatcher.
    """

    available_columns = sorted(
        {
            column
            for board_columns in project.boards.values()
            for column in board_columns
        }
    )
    initial_column = (
        "Backlog"
        if "Backlog" in available_columns
        else (available_columns[0] if available_columns else None)
    )

    def declared_labels(*names: str) -> List[str]:
        return [name for name in names if name in project.labels]

    issues = [
        Issue(
            number=1,
            title="Urgent login failure",
            labels=declared_labels("bug"),
            column=initial_column,
            opened_by="Reporter",
            days_inactive=14,
        ),
        Issue(
            number=2,
            title="Feature request for export support",
            labels=declared_labels("feature"),
            column=initial_column,
            opened_by="Reporter",
            days_inactive=2,
        ),
        Issue(
            number=3,
            title="Small bug in the footer",
            labels=declared_labels("bug"),
            column=initial_column,
            opened_by="Reporter",
            days_inactive=3,
        ),
    ]

    for issue in issues:
        project.open_issue(issue)

    project.update_issue(
        issues[2],
        title="Small bug in the footer layout",
    )
    project.report_issue_inactivity(issues[0], 14)

    pr_author = "Alice" if "Alice" in project.members else None
    pull_requests = [
        PullRequest(
            number=4,
            title="Update security validation",
            author=pr_author,
            changed_files=["src/security/validation.py"],
            column=initial_column,
        ),
        PullRequest(
            number=5,
            title="Add export feature",
            author=pr_author,
            changed_files=["src/features/export.py"],
            column=initial_column,
        ),
    ]

    for pull_request in pull_requests:
        project.open_pull_request(pull_request)

    security_pull_request = pull_requests[0]
    if security_pull_request.reviewers:
        project.submit_review(
            security_pull_request,
            security_pull_request.reviewers[0],
        )

    project.merge_pull_request(security_pull_request)
