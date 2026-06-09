from runtime.gitpm_runtime import ProjectState, run_demo


MEMBERS = [{"name": "Alice", "role": "developer", "workload_limit": 3}, {"name": "Carol", "role": "reviewer", "workload_limit": 2}, {"name": "Dave", "role": "maintainer", "workload_limit": 4}]

LABELS = ["securityReview"]

MILESTONES = []

BOARDS = {"SecurityBoard": ["Backlog", "Review", "Done"]}

RULES = [{"name": "RequestSecurityReview", "event": {"kind": "pull_request_opened"}, "condition": {"kind": "and", "left": {"kind": "changes_path", "value": "src/security/"}, "right": {"kind": "not", "condition": {"kind": "has_reviewer"}}}, "actions": [{"kind": "request_review_using_strategy", "strategy": "least_busy", "role": "reviewer"}, {"kind": "add_label", "value": "securityReview"}, {"kind": "move_to_column", "value": "Review"}]}, {"name": "FinishSecurityReview", "event": {"kind": "pull_request_merged"}, "condition": {"kind": "is_merged"}, "actions": [{"kind": "move_to_column", "value": "Done"}]}]


def build_project():
    return ProjectState(
        repository="SecurityRepository",
        members=MEMBERS,
        labels=LABELS,
        milestones=MILESTONES,
        boards=BOARDS,
        rules=RULES,
    )


if __name__ == "__main__":
    project = build_project()
    run_demo(project)
