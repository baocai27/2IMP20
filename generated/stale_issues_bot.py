from runtime.gitpm_runtime import ProjectState, run_demo


MEMBERS = [{"name": "Alice", "role": "developer", "workload_limit": 2}]

LABELS = ["stale"]

MILESTONES = []

BOARDS = {"MaintenanceBoard": ["Backlog", "Active", "Done"]}

RULES = [{"name": "MarkStale", "event": {"kind": "issue_inactive", "value": 14}, "condition": {"kind": "and", "left": {"kind": "is_open"}, "right": {"kind": "not", "condition": {"kind": "has_label", "value": "stale"}}}, "statements": [{"kind": "action", "action": {"kind": "add_label", "value": "stale"}}, {"kind": "action", "action": {"kind": "add_comment", "value": "This issue has been inactive for 14 days."}}]}]


def build_project():
    return ProjectState(
        repository="MaintenanceRepository",
        members=MEMBERS,
        labels=LABELS,
        milestones=MILESTONES,
        boards=BOARDS,
        rules=RULES,
    )


if __name__ == "__main__":
    project = build_project()
    run_demo(project)
