module gitpm::check::Rules

import gitpm::AST;
import gitpm::check::Diagnostics;
import gitpm::check::References;
import gitpm::check::Compatibility;
import gitpm::check::Expressions;

import String;
import List;


data StatementCheck
    = statementCheck(
        list[Diagnostic] diagnostics,
        list[VariableBinding] environment
      );


data StatementBlockCheck
    = statementBlockCheck(
        list[Diagnostic] diagnostics,
        list[VariableBinding] environment
      );


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

    if (rule(name, trigger, condition, statements) := currentRule) {
        result = result + checkName("Rule", name);
        result = result + checkEvent(name, trigger, declarations);
        result = result + checkCondition(name, condition, declarations);

        if (List::size(statements) == 0) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <name> must contain at least one statement."
                )
            ];
        }
        else if (!containsActionStatement(statements)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <name> must contain at least one executable action."
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

        StatementBlockCheck blockCheck = checkStatementBlock(
            name,
            trigger,
            statements,
            declarations,
            []
        );

        if (statementBlockCheck(statementDiagnostics, _) := blockCheck) {
            result = result + statementDiagnostics;
        }
    }

    return result;
}


StatementBlockCheck checkStatementBlock(
    str ruleName,
    Event trigger,
    list[Statement] statements,
    list[Declaration] declarations,
    list[VariableBinding] environment
) {
    list[Diagnostic] result = [];
    list[VariableBinding] currentEnvironment = environment;

    for (Statement statement <- statements) {
        StatementCheck currentCheck = checkStatement(
            ruleName,
            trigger,
            statement,
            declarations,
            currentEnvironment
        );

        if (statementCheck(diagnostics, updatedEnvironment) := currentCheck) {
            result = result + diagnostics;
            currentEnvironment = updatedEnvironment;
        }
    }

    return statementBlockCheck(result, currentEnvironment);
}


StatementCheck checkStatement(
    str ruleName,
    Event trigger,
    Statement statement,
    list[Declaration] declarations,
    list[VariableBinding] environment
) {
    list[Diagnostic] result = [];

    if (actionStatement(currentAction) := statement) {
        result = result + checkAction(
            ruleName,
            currentAction,
            declarations
        );
        result = result + checkActionCompatibility(
            ruleName,
            trigger,
            currentAction
        );

        return statementCheck(result, environment);
    }

    if (variableDeclaration(name, expression) := statement) {
        result = result + checkName("Variable", name);
        result = result + checkExpressionReferences(
            ruleName,
            expression,
            declarations
        );
        result = result + checkExpressionCompatibility(
            ruleName,
            trigger,
            expression
        );

        ExpressionType declaredType = unknownType();
        ExpressionCheck typeCheck = checkExpressionTypes(
            ruleName,
            expression,
            environment
        );

        if (expressionCheck(typeDiagnostics, expressionType) := typeCheck) {
            result = result + typeDiagnostics;
            declaredType = expressionType;
        }

        if (hasVariable(name, environment)) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> declares variable <name>, but that name is already visible in the current scope."
                )
            ];
            return statementCheck(result, environment);
        }

        return statementCheck(
            result,
            environment + [variableBinding(name, declaredType)]
        );
    }

    if (ifStatement(condition, thenStatements, elseStatements) := statement) {
        result = result + checkExpressionReferences(
            ruleName,
            condition,
            declarations
        );
        result = result + checkExpressionCompatibility(
            ruleName,
            trigger,
            condition
        );

        ExpressionCheck typeCheck = checkExpressionTypes(
            ruleName,
            condition,
            environment
        );

        if (expressionCheck(typeDiagnostics, conditionType) := typeCheck) {
            result = result + typeDiagnostics;

            if (!isUnknown(conditionType)
                && !isBoolean(conditionType)) {
                result = result + [
                    diagnostic(
                        errorSeverity(),
                        "Rule <ruleName> uses a non-Boolean expression as an if condition."
                    )
                ];
            }
        }

        if (thenStatements == []) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> contains an empty then branch."
                )
            ];
        }

        if (elseStatements == []) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> contains an empty else branch."
                )
            ];
        }

        StatementBlockCheck thenCheck = checkStatementBlock(
            ruleName,
            trigger,
            thenStatements,
            declarations,
            environment
        );
        StatementBlockCheck elseCheck = checkStatementBlock(
            ruleName,
            trigger,
            elseStatements,
            declarations,
            environment
        );

        if (statementBlockCheck(thenDiagnostics, _) := thenCheck) {
            result = result + thenDiagnostics;
        }

        if (statementBlockCheck(elseDiagnostics, _) := elseCheck) {
            result = result + elseDiagnostics;
        }

        // Variables declared inside a branch do not leave that branch.
        return statementCheck(result, environment);
    }

    return statementCheck(result, environment);
}


bool containsActionStatement(list[Statement] statements) {
    for (Statement statement <- statements) {
        if (actionStatement(_) := statement) {
            return true;
        }

        if (ifStatement(_, thenStatements, elseStatements) := statement
            && (containsActionStatement(thenStatements)
                || containsActionStatement(elseStatements))) {
            return true;
        }
    }

    return false;
}


list[Diagnostic] checkExpressionReferences(
    str ruleName,
    Expression expression,
    list[Declaration] declarations
) {
    if (conditionExpression(condition) := expression) {
        return checkCondition(ruleName, condition, declarations);
    }

    if (andExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (orExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (equalsExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (notEqualsExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (lessThanExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (lessOrEqualExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (greaterThanExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (greaterOrEqualExpression(left, right) := expression) {
        return checkExpressionReferences(ruleName, left, declarations)
            + checkExpressionReferences(ruleName, right, declarations);
    }

    if (notExpression(inner) := expression) {
        return checkExpressionReferences(ruleName, inner, declarations);
    }

    return [];
}


list[Diagnostic] checkExpressionCompatibility(
    str ruleName,
    Event trigger,
    Expression expression
) {
    list[Diagnostic] result = [];

    if (isIssueEvent(trigger)
        && containsPullRequestExpression(expression)) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses a pull request expression with an issue event."
            )
        ];
    }

    if (isPullRequestEvent(trigger)
        && containsIssueExpression(expression)) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses an issue expression with a pull request event."
            )
        ];
    }

    return result;
}


list[Diagnostic] checkActionCompatibility(
    str ruleName,
    Event trigger,
    Action currentAction
) {
    list[Diagnostic] result = [];

    if (isIssueEvent(trigger)
        && isPullRequestAction(currentAction)) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses a pull request action with an issue event."
            )
        ];
    }

    if (isPullRequestEvent(trigger)
        && isIssueAction(currentAction)) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses an issue action with a pull request event."
            )
        ];
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
        return checkCondition(ruleName, left, declarations)
            + checkCondition(ruleName, right, declarations);
    }

    if (orCondition(left, right) := condition) {
        return checkCondition(ruleName, left, declarations)
            + checkCondition(ruleName, right, declarations);
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
