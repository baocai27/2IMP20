from runtime.gitpm_runtime import ProjectState, run_demo


MEMBERS = [{"name": "Alice", "role": "developer", "workload_limit": 3}, {"name": "Bob", "role": "developer", "workload_limit": 3}]

LABELS = ["bug"]

MILESTONES = []

BOARDS = {"BugBoard": ["Backlog", "In Progress", "Done"]}

RULES = [{"name": "AssignBug", "event": {"kind": "issue_opened"}, "condition": {"kind": "and", "left": {"kind": "has_label", "value": "bug"}, "right": {"kind": "is_unassigned"}}, "actions": [{"kind": "assign_using_strategy", "strategy": "least_busy", "role": "developer"}, {"kind": "set_priority", "value": "high"}, {"kind": "move_to_column", "value": "In Progress"}]}]


def build_project():
    return ProjectState(
        repository="BugRepository",
        members=MEMBERS,
        labels=LABELS,
        milestones=MILESTONES,
        boards=BOARDS,
        rules=RULES,
    )


if __name__ == "__main__":
    project = build_project()
    run_demo(project)
