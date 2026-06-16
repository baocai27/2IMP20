from runtime.gitpm_runtime import ProjectState, run_demo


MEMBERS = [{"name": "Alice", "role": "developer", "workload_limit": 3}, {"name": "Bob", "role": "developer", "workload_limit": 3}, {"name": "Carol", "role": "developer", "workload_limit": 3}, {"name": "ReviewerOne", "role": "reviewer", "workload_limit": 2}, {"name": "ReviewerTwo", "role": "reviewer", "workload_limit": 2}]

LABELS = ["feature"]

MILESTONES = []

BOARDS = {"TeamBoard": ["Backlog", "In Progress", "Review", "Done"]}

RULES = [{"name": "AssignFeature", "event": {"kind": "issue_opened"}, "condition": {"kind": "and", "left": {"kind": "has_label", "value": "feature"}, "right": {"kind": "is_unassigned"}}, "statements": [{"kind": "action", "action": {"kind": "assign_using_strategy", "strategy": "round_robin", "role": "developer"}}, {"kind": "action", "action": {"kind": "move_to_column", "value": "In Progress"}}]}, {"name": "ReviewFeature", "event": {"kind": "pull_request_opened"}, "condition": {"kind": "not", "condition": {"kind": "has_reviewer"}}, "statements": [{"kind": "action", "action": {"kind": "request_review_using_strategy", "strategy": "round_robin", "role": "reviewer"}}, {"kind": "action", "action": {"kind": "move_to_column", "value": "Review"}}]}]


def build_project():
    return ProjectState(
        repository="RoundRobinRepository",
        members=MEMBERS,
        labels=LABELS,
        milestones=MILESTONES,
        boards=BOARDS,
        rules=RULES,
    )


if __name__ == "__main__":
    project = build_project()
    run_demo(project)
