from runtime.gitpm_runtime import ProjectState, run_demo


MEMBERS = [{"name": "Alice", "role": "developer", "workload_limit": 3}, {"name": "Bob", "role": "developer", "workload_limit": 3}]

LABELS = ["bug", "urgent", "stale"]

MILESTONES = ["Version 1.0"]

BOARDS = {"MainBoard": ["Backlog", "In Progress", "Done"]}

RULES = [{"name": "ConditionalBugTriage", "event": {"kind": "issue_opened"}, "condition": {"kind": "and", "left": {"kind": "has_label", "value": "bug"}, "right": {"kind": "is_unassigned"}}, "statements": [{"kind": "let", "name": "urgentIssue", "expression": {"kind": "or", "left": {"kind": "title_contains", "value": "urgent"}, "right": {"kind": "priority_equals", "value": "critical"}}}, {"kind": "let", "name": "inactiveFor", "expression": {"kind": "inactive_days"}}, {"kind": "action", "action": {"kind": "assign_using_strategy", "strategy": "least_busy", "role": "developer"}}, {"kind": "if", "condition": {"kind": "variable", "value": "urgentIssue"}, "then": [{"kind": "action", "action": {"kind": "add_label", "value": "urgent"}}, {"kind": "action", "action": {"kind": "set_priority", "value": "critical"}}, {"kind": "action", "action": {"kind": "move_to_column", "value": "In Progress"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "Urgent bug was escalated automatically."}}], "else": [{"kind": "action", "action": {"kind": "set_priority", "value": "medium"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "Normal bug was added to the regular queue."}}]}, {"kind": "if", "condition": {"kind": "greater_or_equal", "left": {"kind": "variable", "value": "inactiveFor"}, "right": {"kind": "integer", "value": 14}}, "then": [{"kind": "action", "action": {"kind": "add_label", "value": "stale"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "This issue was already inactive for at least 14 days."}}], "else": [{"kind": "action", "action": {"kind": "set_milestone", "value": "Version 1.0"}}]}]}]


def build_project():
    return ProjectState(
        repository="ConditionalTriageRepository",
        members=MEMBERS,
        labels=LABELS,
        milestones=MILESTONES,
        boards=BOARDS,
        rules=RULES,
    )


if __name__ == "__main__":
    project = build_project()
    run_demo(project)
