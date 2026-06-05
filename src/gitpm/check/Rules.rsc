module gitpm::check::Rules

import gitpm::AST;
import gitpm::check::Diagnostics;
import gitpm::check::References;
import gitpm::check::Compatibility;

import String;
import List;

list[Diagnostic] checkRules(
    list[Declaration] declarations,
    list[Rule] rules
) {
    list[Diagnostic] result = [];
    list[str] ruleNames = [];

    for (Rule currentRule <- rules) {
        if (rule(name, _, _, _) := currentRule) {
            ruleNames = ruleNames + [name];
        }
    }

    result = result + duplicateDiagnostics("rule", ruleNames);

    for (Rule currentRule <- rules) {
        result = result + checkRule(currentRule, declarations);
    }

    return result;
}


list[Diagnostic] checkRule(
    Rule currentRule,
    list[Declaration] declarations
) {
    list[Diagnostic] result = [];

    if (rule(name, trigger, condition, actions) := currentRule) {
        result = result + checkName("Rule", name);
        result = result + checkEvent(name, trigger, declarations);
        result = result + checkCondition(name, condition, declarations);

        if (List::size(actions) == 0) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <name> must contain at least one action."
                )
            ];
        }

        if (isIssueEvent(trigger)
            && containsPullRequestCondition(condition)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <name> uses a pull request condition with an issue event."
                )
            ];
        }

        if (isPullRequestEvent(trigger)
            && containsIssueCondition(condition)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <name> uses an issue condition with a pull request event."
                )
            ];
        }

        for (Action currentAction <- actions) {
            result = result + checkAction(name, currentAction, declarations);

            if (isIssueEvent(trigger)
                && isPullRequestAction(currentAction)) {
                result = result + [
                    diagnostic(
                        errorSeverity(),
                        "Rule <name> uses a pull request action with an issue event."
                    )
                ];
            }

            if (isPullRequestEvent(trigger)
                && isIssueAction(currentAction)) {
                result = result + [
                    diagnostic(
                        errorSeverity(),
                        "Rule <name> uses an issue action with a pull request event."
                    )
                ];
            }
        }
    }

    return result;
}


// Event checks

list[Diagnostic] checkEvent(
    str ruleName,
    Event trigger,
    list[Declaration] declarations
) {
    list[Diagnostic] result = [];

    if (issueInactive(days) := trigger && days <= 0) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses an inactive period that is not greater than zero."
            )
        ];
    }

    if (issueLabelEvent(_, labelName) := trigger) {
        result = result + checkLabelReference(
            ruleName,
            labelName,
            declarations
        );
    }

    if (pullRequestLabelEvent(_, labelName) := trigger) {
        result = result + checkLabelReference(
            ruleName,
            labelName,
            declarations
        );
    }

    return result;
}


// Condition checks

list[Diagnostic] checkCondition(
    str ruleName,
    Condition condition,
    list[Declaration] declarations
) {
    list[Diagnostic] result = [];

    if (andCondition(left, right) := condition) {
        result = result + checkCondition(ruleName, left, declarations);
        result = result + checkCondition(ruleName, right, declarations);
        return result;
    }

    if (orCondition(left, right) := condition) {
        result = result + checkCondition(ruleName, left, declarations);
        result = result + checkCondition(ruleName, right, declarations);
        return result;
    }

    if (notCondition(inner) := condition) {
        return checkCondition(ruleName, inner, declarations);
    }

    if (hasLabel(labelName) := condition) {
        result = result + checkLabelReference(
            ruleName,
            labelName,
            declarations
        );
    }

    if (milestoneEquals(milestoneName) := condition) {
        result = result + checkMilestoneReference(
            ruleName,
            milestoneName,
            declarations
        );
    }

    if (inColumn(columnName) := condition) {
        result = result + checkColumnReference(
            ruleName,
            columnName,
            declarations
        );
    }

    if (openedBy(memberName) := condition) {
        result = result + checkMemberReference(
            ruleName,
            memberName,
            declarations
        );
    }

    if (assignedTo(memberName) := condition) {
        result = result + checkAssignableMemberReference(
            ruleName,
            memberName,
            declarations
        );
    }


    if (authoredBy(memberName) := condition) {
        result = result + checkMemberReference(
            ruleName,
            memberName,
            declarations
        );
    }

    if (reviewedBy(memberName) := condition) {
        result = result + checkReviewerReference(
            ruleName,
            memberName,
            declarations
        );
    }

    if (reviewRequestedFrom(memberName) := condition) {
        result = result + checkReviewerReference(
            ruleName,
            memberName,
            declarations
        );
    }

    if (titleContains(text) := condition && trim(text) == "") {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses titleContains with empty text."
            )
        ];
    }

    if (changesPath(path) := condition && trim(path) == "") {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses changesPath with an empty path."
            )
        ];
    }

    if (assigneeHasRole(requiredRole) := condition
        && !isAssignableRole(requiredRole)) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> checks an assignee role that cannot receive issue assignments."
            )
        ];
    }

    return result;
}


// Action checks

list[Diagnostic] checkAction(
    str ruleName,
    Action currentAction,
    list[Declaration] declarations
) {
    list[Diagnostic] result = [];

    if (addLabel(labelName) := currentAction) {
        result = result + checkLabelReference(
            ruleName,
            labelName,
            declarations
        );
    }

    if (removeLabel(labelName) := currentAction) {
        result = result + checkLabelReference(
            ruleName,
            labelName,
            declarations
        );
    }

    if (moveToColumn(columnName) := currentAction) {
        result = result + checkColumnReference(
            ruleName,
            columnName,
            declarations
        );
    }

    if (setMilestone(milestoneName) := currentAction) {
        result = result + checkMilestoneReference(
            ruleName,
            milestoneName,
            declarations
        );
    }


    if (assignMember(memberName) := currentAction) {
        result = result + checkAssignableMemberReference(
            ruleName,
            memberName,
            declarations
        );
    }

    if (requestReviewFrom(memberName) := currentAction) {
        result = result + checkReviewerReference(
            ruleName,
            memberName,
            declarations
        );
    }

    if (removeReviewer(memberName) := currentAction) {
        result = result + checkReviewerReference(
            ruleName,
            memberName,
            declarations
        );
    }

    if (assignUsingStrategy(_, requiredRole) := currentAction) {
        if (!isAssignableRole(requiredRole)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> uses an assignment strategy with an incompatible role."
                )
            ];
        }
        else if (!hasRoleCandidate(requiredRole, declarations)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> uses an assignment strategy for role <roleName(requiredRole)>, but no member has that role."
                )
            ];
        }
    }

    if (requestReviewUsingStrategy(_, requiredRole) := currentAction) {
        if (!isReviewerRole(requiredRole)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> uses a review strategy with an incompatible role."
                )
            ];
        }
        else if (!hasRoleCandidate(requiredRole, declarations)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> uses a review strategy for role <roleName(requiredRole)>, but no member has that role."
                )
            ];
        }
    }

    if (addComment(text) := currentAction && trim(text) == "") {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> adds an empty comment."
            )
        ];
    }

    return result;
}


