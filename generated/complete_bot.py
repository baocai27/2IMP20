from runtime.gitpm_runtime import ProjectState, run_demo


MEMBERS = [{"name": "Alice", "role": "developer", "workload_limit": 3}, {"name": "Bob", "role": "developer", "workload_limit": 2}, {"name": "Carol", "role": "reviewer", "workload_limit": 2}, {"name": "Dave", "role": "maintainer", "workload_limit": 4}]

LABELS = ["bug", "feature", "stale", "securityReview"]

MILESTONES = ["Version 1.0", "Version 2.0"]

BOARDS = {"MainBoard": ["Backlog", "To Do", "In Progress", "Review", "Done"]}

RULES = [{"name": "AssignNewBug", "event": {"kind": "issue_opened"}, "condition": {"kind": "and", "left": {"kind": "has_label", "value": "bug"}, "right": {"kind": "is_unassigned"}}, "statements": [{"kind": "action", "action": {"kind": "assign_using_strategy", "strategy": "least_busy", "role": "developer"}}, {"kind": "action", "action": {"kind": "set_priority", "value": "high"}}, {"kind": "action", "action": {"kind": "move_to_column", "value": "In Progress"}}, {"kind": "action", "action": {"kind": "set_milestone", "value": "Version 1.0"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "The issue was assigned automatically."}}]}, {"name": "RequestSecurityReview", "event": {"kind": "pull_request_opened"}, "condition": {"kind": "and", "left": {"kind": "changes_path", "value": "src/security/"}, "right": {"kind": "not", "condition": {"kind": "has_reviewer"}}}, "statements": [{"kind": "action", "action": {"kind": "request_review_using_strategy", "strategy": "least_busy", "role": "reviewer"}}, {"kind": "action", "action": {"kind": "add_label", "value": "securityReview"}}, {"kind": "action", "action": {"kind": "move_to_column", "value": "Review"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "A security review is required."}}]}, {"name": "MarkInactiveIssue", "event": {"kind": "issue_inactive", "value": 14}, "condition": {"kind": "and", "left": {"kind": "not", "condition": {"kind": "has_label", "value": "stale"}}, "right": {"kind": "is_open"}}, "statements": [{"kind": "action", "action": {"kind": "add_label", "value": "stale"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "This issue has been inactive for 14 days."}}]}, {"name": "CloseMergedPullRequest", "event": {"kind": "pull_request_merged"}, "condition": {"kind": "is_merged"}, "statements": [{"kind": "action", "action": {"kind": "move_to_column", "value": "Done"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "The pull request was merged."}}]}]


def build_project():
    return ProjectState(
        repository="DemoRepository",
        members=MEMBERS,
        labels=LABELS,
        milestones=MILESTONES,
        boards=BOARDS,
        rules=RULES,
    )


if __name__ == "__main__":
    project = build_project()
    run_demo(project)
