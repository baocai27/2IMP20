module gitpm::check::Compatibility

import gitpm::AST;

// Compatibility helpers

bool isIssueEvent(Event trigger) {
    return issueEvent(_) := trigger
        || issueLabelEvent(_, _) := trigger
        || issueInactive(_) := trigger;
}


bool isPullRequestEvent(Event trigger) {
    return !isIssueEvent(trigger);
}


bool containsIssueCondition(Condition condition) {
    if (andCondition(left, right) := condition) {
        return containsIssueCondition(left)
            || containsIssueCondition(right);
    }

    if (orCondition(left, right) := condition) {
        return containsIssueCondition(left)
            || containsIssueCondition(right);
    }

    if (notCondition(inner) := condition) {
        return containsIssueCondition(inner);
    }

    return isAssigned() := condition
        || isUnassigned() := condition
        || openedBy(_) := condition
        || assignedTo(_) := condition
        || assigneeHasRole(_) := condition;
}


bool containsPullRequestCondition(Condition condition) {
    if (andCondition(left, right) := condition) {
        return containsPullRequestCondition(left)
            || containsPullRequestCondition(right);
    }

    if (orCondition(left, right) := condition) {
        return containsPullRequestCondition(left)
            || containsPullRequestCondition(right);
    }

    if (notCondition(inner) := condition) {
        return containsPullRequestCondition(inner);
    }

    return changesPath(_) := condition
        || authoredBy(_) := condition
        || hasReviewer() := condition
        || reviewedBy(_) := condition
        || reviewRequestedFrom(_) := condition
        || isMerged() := condition;
}


bool isIssueAction(Action currentAction) {
    return assignMember(_) := currentAction
        || assignUsingStrategy(_, _) := currentAction
        || unassignMember() := currentAction
        || closeIssue() := currentAction
        || reopenIssue() := currentAction;
}


bool isPullRequestAction(Action currentAction) {
    return requestReviewFrom(_) := currentAction
        || requestReviewUsingStrategy(_, _) := currentAction
        || removeReviewer(_) := currentAction
        || closePullRequest() := currentAction
        || reopenPullRequest() := currentAction;
}


bool isAssignableRole(Role requiredRole) {
    return developer() := requiredRole
        || maintainer() := requiredRole;
}


bool isReviewerRole(Role requiredRole) {
    return reviewer() := requiredRole
        || maintainer() := requiredRole;
}


str roleName(Role requiredRole) {
    if (developer() := requiredRole) {
        return "developer";
    }

    if (reviewer() := requiredRole) {
        return "reviewer";
    }

    if (maintainer() := requiredRole) {
        return "maintainer";
    }

    return "maintainer";
}
