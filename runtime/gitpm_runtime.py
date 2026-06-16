from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


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
        self.members = {
            item["name"]: Member(
                item["name"], item["role"], item["workload_limit"]
            )
            for item in members
        }
        self.labels = set(labels)
        self.milestones = set(milestones)
        self.boards = boards
        self.rules = rules
        self.issues: Dict[int, Issue] = {}
        self.pull_requests: Dict[int, PullRequest] = {}
        self.round_robin_positions: Dict[str, int] = {}

    def add_issue(self, issue: Issue) -> None:
        self.issues[issue.number] = issue

    def add_pull_request(self, pull_request: PullRequest) -> None:
        self.pull_requests[pull_request.number] = pull_request

    def dispatch(
        self,
        event_kind: str,
        item: WorkItem,
        event_value: Any = None,
    ) -> None:
        print(f"\nEvent: {event_kind} on #{item.number}")
        matched = False

        for rule in self.rules:
            if not self._event_matches(rule["event"], event_kind, event_value):
                continue

            if not self._evaluate_expression(rule["condition"], item, {}):
                continue

            matched = True
            print("Matched rule: {}".format(rule["name"]))

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

        if event_kind == "pull_request_merged" and isinstance(item, PullRequest):
            self._complete_reviews(item)

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
            return actual_value is not None and actual_value >= expected["value"]

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
                self._evaluate_expression(expression["left"], item, environment)
            ) and bool(
                self._evaluate_expression(expression["right"], item, environment)
            )
        if kind == "or":
            return bool(
                self._evaluate_expression(expression["left"], item, environment)
            ) or bool(
                self._evaluate_expression(expression["right"], item, environment)
            )
        if kind == "not":
            return not bool(
                self._evaluate_expression(
                    expression["condition"], item, environment
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
                expression["left"], item, environment
            )
            right = self._evaluate_expression(
                expression["right"], item, environment
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
            return isinstance(item, Issue) and item.opened_by == expression["value"]
        if kind == "assigned_to":
            return isinstance(item, Issue) and item.assignee == expression["value"]
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
            return isinstance(item, PullRequest) and len(item.reviewers) > 0
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
            return isinstance(item, PullRequest) and item.state == "merged"

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
                    statement["expression"], item, environment
                )
                environment[statement["name"]] = value
                print(f"  - let {statement['name']} = {value}")
                continue

            if kind == "if":
                condition_value = bool(
                    self._evaluate_expression(
                        statement["condition"], item, environment
                    )
                )
                branch_name = "then" if condition_value else "else"
                print(f"  - if condition is {condition_value}: {branch_name} branch")

                branch_environment = dict(environment)
                branch = statement["then"] if condition_value else statement["else"]
                self._execute_statements(branch, item, branch_environment)
                continue

            raise ValueError(f"Unknown statement kind: {kind}")

    def _execute_action(self, action: Dict[str, Any], item: WorkItem) -> None:
        kind = action["kind"]

        if kind == "add_label":
            if action["value"] not in item.labels:
                item.labels.append(action["value"])
            print("  - added label {}".format(action["value"]))
            return

        if kind == "remove_label":
            if action["value"] in item.labels:
                item.labels.remove(action["value"])
            print("  - removed label {}".format(action["value"]))
            return

        if kind == "move_to_column":
            old_column = item.column
            item.column = action["value"]
            print(f"  - moved from {old_column} to {item.column}")
            return

        if kind == "set_milestone":
            item.milestone = action["value"]
            print(f"  - set milestone {item.milestone}")
            return

        if kind == "clear_milestone":
            item.milestone = None
            print("  - cleared milestone")
            return

        if kind == "set_priority":
            item.priority = action["value"]
            print(f"  - set priority {item.priority}")
            return

        if kind == "add_comment":
            item.comments.append(action["value"])
            print("  - added comment: {}".format(action["value"]))
            return

        if kind == "assign_member":
            self._assign_member(item, action["value"])
            return

        if kind == "assign_using_strategy":
            member_name = self._select_member(
                action["strategy"], action["role"], "assignment"
            )
            if member_name is None:
                print("  - no available member for assignment")
            else:
                self._assign_member(item, member_name)
            return

        if kind == "unassign_member":
            self._unassign_member(item)
            return

        if kind == "close_issue":
            if isinstance(item, Issue):
                self._unassign_member(item)
                item.state = "closed"
                print("  - closed issue")
            return

        if kind == "reopen_issue":
            if isinstance(item, Issue):
                item.state = "open"
                print("  - reopened issue")
            return

        if kind == "request_review_from":
            self._request_review(item, action["value"])
            return

        if kind == "request_review_using_strategy":
            member_name = self._select_member(
                action["strategy"], action["role"], "review"
            )
            if member_name is None:
                print("  - no available member for review")
            else:
                self._request_review(item, member_name)
            return

        if kind == "remove_reviewer":
            self._remove_reviewer(item, action["value"])
            return

        if kind == "close_pull_request":
            if isinstance(item, PullRequest):
                self._release_reviewers(item)
                item.state = "closed"
                print("  - closed pull request")
            return

        if kind == "reopen_pull_request":
            if isinstance(item, PullRequest):
                item.state = "open"
                print("  - reopened pull request")
            return

        raise ValueError(f"Unknown action kind: {kind}")

    def _assign_member(self, item: WorkItem, member_name: str) -> None:
        if not isinstance(item, Issue):
            return

        if item.assignee == member_name:
            return

        member = self.members[member_name]

        if not member.available():
            print(f"  - member {member_name} is at workload limit")
            return

        old_assignee = item.assignee

        if old_assignee is not None:
            self._decrease_workload(old_assignee)

        item.assignee = member_name
        member.workload += 1
        print(f"  - assigned {member_name}")

    def _unassign_member(self, item: WorkItem) -> None:
        if not isinstance(item, Issue) or item.assignee is None:
            return

        old_assignee = item.assignee
        item.assignee = None
        self._decrease_workload(old_assignee)
        print(f"  - unassigned {old_assignee}")

    def _request_review(self, item: WorkItem, member_name: str) -> None:
        if not isinstance(item, PullRequest):
            return

        if member_name in item.reviewers:
            return

        member = self.members[member_name]
        if not member.available():
            print(f"  - reviewer {member_name} is at workload limit")
            return

        item.reviewers.append(member_name)
        member.workload += 1
        print(f"  - requested review from {member_name}")

    def _remove_reviewer(self, item: WorkItem, member_name: str) -> None:
        if not isinstance(item, PullRequest):
            return

        if member_name in item.reviewers:
            item.reviewers.remove(member_name)
            self._decrease_workload(member_name)
            print(f"  - removed reviewer {member_name}")

    def _complete_reviews(self, item: PullRequest) -> None:
        for reviewer in list(item.reviewers):
            if reviewer not in item.reviews:
                item.reviews.append(reviewer)
            self._decrease_workload(reviewer)
        item.reviewers.clear()

    def _release_reviewers(self, item: PullRequest) -> None:
        for reviewer in list(item.reviewers):
            self._decrease_workload(reviewer)
        item.reviewers.clear()

    def _decrease_workload(self, member_name: str) -> None:
        member = self.members.get(member_name)
        if member is not None and member.workload > 0:
            member.workload -= 1

    def _select_member(
        self,
        strategy: str,
        role: str,
        purpose: str,
    ) -> Optional[str]:
        candidates = [
            member
            for member in self.members.values()
            if member.role == role and member.available()
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
            self.round_robin_positions[key] = (position + 1) % len(candidates)
            return selected.name

        raise ValueError(f"Unknown strategy: {strategy}")

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

        if isinstance(item, PullRequest):
            print(f"  reviewers: {item.reviewers}")
            print(f"  reviews: {item.reviews}")

    def print_workloads(self) -> None:
        print("Workloads:")
        for member in sorted(self.members.values(), key=lambda item: item.name):
            print(
                f"  {member.name}: {member.workload}/{member.workload_limit} "
                f"({member.role})"
            )


def run_demo(project: ProjectState) -> None:
    """Run one generic scenario against any generated GitPM project."""
    issues = [
        Issue(
            number=1,
            title="Urgent login failure",
            labels=["bug"],
            column="Backlog",
            opened_by="Reporter",
            days_inactive=14,
        ),
        Issue(
            number=2,
            title="Feature request for export support",
            labels=["feature"],
            column="Backlog",
            opened_by="Reporter",
            days_inactive=2,
        ),
        Issue(
            number=3,
            title="Small bug in the footer",
            labels=["bug"],
            column="Backlog",
            opened_by="Reporter",
            days_inactive=3,
        ),
    ]

    for issue in issues:
        project.add_issue(issue)
        project.dispatch("issue_opened", issue)

    project.dispatch("issue_inactive", issues[0], issues[0].days_inactive)

    pull_requests = [
        PullRequest(
            number=4,
            title="Update security validation",
            author="Alice",
            changed_files=["src/security/validation.py"],
            column="Backlog",
        ),
        PullRequest(
            number=5,
            title="Add export feature",
            author="Alice",
            changed_files=["src/features/export.py"],
            column="Backlog",
        ),
    ]

    for pull_request in pull_requests:
        project.add_pull_request(pull_request)
        project.dispatch("pull_request_opened", pull_request)

    pull_requests[0].state = "merged"
    project.dispatch("pull_request_merged", pull_requests[0])
