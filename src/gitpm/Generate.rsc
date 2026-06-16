module gitpm::Generate

// GENERATE_SPLIT_RUNTIME_VERSION_2026_06_05

import gitpm::AST;
import IO;
import String;
import List;


// Generates a Python configuration module for the reusable GitPM runtime.
str generateProgram(Program inputProgram) {
    if (program(declarations, rules) := inputProgram) {
        return generateConfiguration(declarations, rules);
    }

    return "";
}


// Writes the generated Python program to a file
void generateToFile(Program inputProgram, loc outputFile) {
    writeFile(outputFile, generateProgram(inputProgram));
}


str generateConfiguration(
    list[Declaration] declarations,
    list[Rule] rules
) {
    str repositoryName = "";
    list[str] memberValues = [];
    list[str] labelValues = [];
    list[str] milestoneValues = [];
    list[str] boardValues = [];

    for (Declaration declaration <- declarations) {
        if (repositoryDeclaration(name) := declaration) {
            repositoryName = name;
        }

        if (memberDeclaration(name, memberRole, workloadLimit) := declaration) {
            memberValues = memberValues + [
                "{\"name\": " + pythonString(name)
                + ", \"role\": " + pythonString(roleName(memberRole))
                + ", \"workload_limit\": " + "<workloadLimit>" + "}"
            ];
        }

        if (labelDeclaration(name) := declaration) {
            labelValues = labelValues + [pythonString(name)];
        }

        if (milestoneDeclaration(name) := declaration) {
            milestoneValues = milestoneValues + [pythonString(name)];
        }

        if (boardDeclaration(name, columns) := declaration) {
            list[str] columnValues = [];

            for (BoardColumn column <- columns) {
                if (boardColumn(columnName) := column) {
                    columnValues = columnValues + [pythonString(columnName)];
                }
            }

            boardValues = boardValues + [
                pythonString(name) + ": [" + joinValues(columnValues) + "]"
            ];
        }

    }

    list[str] ruleValues = [];

    for (Rule currentRule <- rules) {
        ruleValues = ruleValues + [generateRule(currentRule)];
    }

    str result = "";
    result = result
        + "from runtime.gitpm_runtime import ProjectState, run_demo\n\n\n";

    result = result
        + "MEMBERS = [" + joinValues(memberValues) + "]\n\n";

    result = result
        + "LABELS = [" + joinValues(labelValues) + "]\n\n";

    result = result
        + "MILESTONES = [" + joinValues(milestoneValues) + "]\n\n";

    result = result
        + "BOARDS = {" + joinValues(boardValues) + "}\n\n";

    result = result
        + "RULES = [" + joinValues(ruleValues) + "]\n\n\n";

    result = result + "def build_project():\n";
    result = result + "    return ProjectState(\n";
    result = result + "        repository=" + pythonString(repositoryName) + ",\n";
    result = result + "        members=MEMBERS,\n";
    result = result + "        labels=LABELS,\n";
    result = result + "        milestones=MILESTONES,\n";
    result = result + "        boards=BOARDS,\n";
    result = result + "        rules=RULES,\n";
    result = result + "    )\n\n\n";

    result = result + "if __name__ == \"__main__\":\n";
    result = result + "    project = build_project()\n";
    result = result + "    run_demo(project)\n";

    return result;
}


str generateRule(Rule currentRule) {
    if (rule(name, trigger, condition, statements) := currentRule) {
        list[str] statementValues = [];

        for (Statement statement <- statements) {
            statementValues = statementValues
                + [generateStatement(statement)];
        }

        return "{\"name\": " + pythonString(name)
            + ", \"event\": " + generateEvent(trigger)
            + ", \"condition\": " + generateCondition(condition)
            + ", \"statements\": ["
            + joinValues(statementValues)
            + "]}";
    }

    return "{}";
}

str generateStatement(Statement statement) {
    if (actionStatement(currentAction) := statement) {
        return "{\"kind\": \"action\", \"action\": "
            + generateAction(currentAction)
            + "}";
    }

    if (variableDeclaration(name, expression) := statement) {
        return "{\"kind\": \"let\", \"name\": "
            + pythonString(name)
            + ", \"expression\": "
            + generateExpression(expression)
            + "}";
    }

    if (
        ifStatement(
            condition,
            thenStatements,
            elseStatements
        ) := statement
    ) {
        list[str] thenValues = [
            generateStatement(currentStatement)
            | currentStatement <- thenStatements
        ];

        list[str] elseValues = [
            generateStatement(currentStatement)
            | currentStatement <- elseStatements
        ];

        return "{\"kind\": \"if\", \"condition\": "
            + generateExpression(condition)
            + ", \"then\": ["
            + joinValues(thenValues)
            + "], \"else\": ["
            + joinValues(elseValues)
            + "]}";
    }

    return "{}";
}

str generateExpression(Expression expression) {
    if (booleanLiteral(booleanValue) := expression) {
        return dictionaryValue(
            "boolean",
            pythonBoolean(booleanValue)
        );
    }

    if (integerLiteral(integerValue) := expression) {
        return dictionaryValue(
            "integer",
            "<integerValue>"
        );
    }

    if (stringLiteral(stringValue) := expression) {
        return dictionaryValue(
            "string",
            pythonString(stringValue)
        );
    }

    if (variableReference(name) := expression) {
        return dictionaryValue(
            "variable",
            pythonString(name)
        );
    }

    if (conditionExpression(condition) := expression) {
        return generateCondition(condition);
    }

    if (inactiveDaysExpression() := expression) {
        return dictionary("inactive_days");
    }

    if (reviewerCountExpression() := expression) {
        return dictionary("reviewer_count");
    }

    if (andExpression(left, right) := expression) {
        return binaryExpression(
            "and",
            left,
            right
        );
    }

    if (orExpression(left, right) := expression) {
        return binaryExpression(
            "or",
            left,
            right
        );
    }

    if (notExpression(innerExpression) := expression) {
        return "{\"kind\": \"not\", \"condition\": "
            + generateExpression(innerExpression)
            + "}";
    }

    if (equalsExpression(left, right) := expression) {
        return binaryExpression(
            "equals",
            left,
            right
        );
    }

    if (notEqualsExpression(left, right) := expression) {
        return binaryExpression(
            "not_equals",
            left,
            right
        );
    }

    if (lessThanExpression(left, right) := expression) {
        return binaryExpression(
            "less_than",
            left,
            right
        );
    }

    if (lessOrEqualExpression(left, right) := expression) {
        return binaryExpression(
            "less_or_equal",
            left,
            right
        );
    }

    if (greaterThanExpression(left, right) := expression) {
        return binaryExpression(
            "greater_than",
            left,
            right
        );
    }

    if (greaterOrEqualExpression(left, right) := expression) {
        return binaryExpression(
            "greater_or_equal",
            left,
            right
        );
    }

    return dictionary("unknown");
}

str binaryExpression(
    str kind,
    Expression left,
    Expression right
) {
    return "{\"kind\": "
        + pythonString(kind)
        + ", \"left\": "
        + generateExpression(left)
        + ", \"right\": "
        + generateExpression(right)
        + "}";
}


str generateEvent(Event trigger) {
    if (issueEvent(kind) := trigger) {
        return dictionary(
            "issue_" + issueEventName(kind)
        );
    }

    if (issueLabelEvent(kind, labelName) := trigger) {
        return dictionaryValue(
            "issue_" + labelEventName(kind),
            pythonString(labelName)
        );
    }

    if (issueInactive(days) := trigger) {
        return dictionaryValue(
            "issue_inactive",
            "<days>"
        );
    }

    if (pullRequestEvent(kind) := trigger) {
        return dictionary(
            "pull_request_" + pullRequestEventName(kind)
        );
    }

    if (pullRequestLabelEvent(kind, labelName) := trigger) {
        return dictionaryValue(
            "pull_request_" + labelEventName(kind),
            pythonString(labelName)
        );
    }

    if (pullRequestReviewEvent(kind) := trigger) {
        return dictionary(
            "pull_request_review_" + reviewEventName(kind)
        );
    }

    return dictionary("unknown");
}


str issueEventName(IssueEventKind kind) {
    if (issueOpenedKind() := kind) {
        return "opened";
    }

    if (issueAssignedKind() := kind) {
        return "assigned";
    }

    if (issueUnassignedKind() := kind) {
        return "unassigned";
    }

    if (issueClosedKind() := kind) {
        return "closed";
    }

    if (issueReopenedKind() := kind) {
        return "reopened";
    }

    return "updated";
}


str pullRequestEventName(PullRequestEventKind kind) {
    if (pullRequestOpenedKind() := kind) {
        return "opened";
    }

    if (pullRequestUpdatedKind() := kind) {
        return "updated";
    }

    if (pullRequestMergedKind() := kind) {
        return "merged";
    }

    if (pullRequestClosedKind() := kind) {
        return "closed";
    }

    return "reopened";
}


str labelEventName(LabelEventKind kind) {
    if (labeledKind() := kind) {
        return "labeled";
    }

    return "unlabeled";
}


str reviewEventName(ReviewEventKind kind) {
    if (reviewRequestedKind() := kind) {
        return "requested";
    }

    return "submitted";
}


str generateCondition(Condition condition) {
    if (trueCondition() := condition) {
        return dictionary("true");
    }
    if (andCondition(left, right) := condition) {
        return "{\"kind\": \"and\", \"left\": "
            + generateCondition(left)
            + ", \"right\": " + generateCondition(right) + "}";
    }
    if (orCondition(left, right) := condition) {
        return "{\"kind\": \"or\", \"left\": "
            + generateCondition(left)
            + ", \"right\": " + generateCondition(right) + "}";
    }
    if (notCondition(inner) := condition) {
        return "{\"kind\": \"not\", \"condition\": "
            + generateCondition(inner) + "}";
    }
    if (hasLabel(labelName) := condition) {
        return dictionaryValue("has_label", pythonString(labelName));
    }
    if (priorityEquals(priority) := condition) {
        return dictionaryValue(
            "priority_equals",
            pythonString(priorityName(priority))
        );
    }
    if (milestoneEquals(milestoneName) := condition) {
        return dictionaryValue(
            "milestone_equals",
            pythonString(milestoneName)
        );
    }
    if (inColumn(columnName) := condition) {
        return dictionaryValue("in_column", pythonString(columnName));
    }
    if (titleContains(text) := condition) {
        return dictionaryValue("title_contains", pythonString(text));
    }
    if (isOpen() := condition) {
        return dictionary("is_open");
    }
    if (isClosed() := condition) {
        return dictionary("is_closed");
    }
    if (isAssigned() := condition) {
        return dictionary("is_assigned");
    }
    if (isUnassigned() := condition) {
        return dictionary("is_unassigned");
    }
    if (openedBy(memberName) := condition) {
        return dictionaryValue("opened_by", pythonString(memberName));
    }
    if (assignedTo(memberName) := condition) {
        return dictionaryValue("assigned_to", pythonString(memberName));
    }
    if (assigneeHasRole(requiredRole) := condition) {
        return dictionaryValue(
            "assignee_has_role",
            pythonString(roleName(requiredRole))
        );
    }
    if (changesPath(path) := condition) {
        return dictionaryValue("changes_path", pythonString(path));
    }
    if (authoredBy(memberName) := condition) {
        return dictionaryValue("authored_by", pythonString(memberName));
    }
    if (hasReviewer() := condition) {
        return dictionary("has_reviewer");
    }
    if (reviewedBy(memberName) := condition) {
        return dictionaryValue("reviewed_by", pythonString(memberName));
    }
    if (reviewRequestedFrom(memberName) := condition) {
        return dictionaryValue(
            "review_requested_from",
            pythonString(memberName)
        );
    }
    if (isMerged() := condition) {
        return dictionary("is_merged");
    }

    return dictionary("unknown");
}


str generateAction(Action currentAction) {
    if (addLabel(labelName) := currentAction) {
        return dictionaryValue("add_label", pythonString(labelName));
    }
    if (removeLabel(labelName) := currentAction) {
        return dictionaryValue("remove_label", pythonString(labelName));
    }
    if (moveToColumn(columnName) := currentAction) {
        return dictionaryValue(
            "move_to_column",
            pythonString(columnName)
        );
    }
    if (setMilestone(milestoneName) := currentAction) {
        return dictionaryValue(
            "set_milestone",
            pythonString(milestoneName)
        );
    }
    if (clearMilestone() := currentAction) {
        return dictionary("clear_milestone");
    }
    if (setPriority(priority) := currentAction) {
        return dictionaryValue(
            "set_priority",
            pythonString(priorityName(priority))
        );
    }
    if (addComment(text) := currentAction) {
        return dictionaryValue("add_comment", pythonString(text));
    }
    if (assignMember(memberName) := currentAction) {
        return dictionaryValue(
            "assign_member",
            pythonString(memberName)
        );
    }
    if (assignUsingStrategy(strategy, requiredRole) := currentAction) {
        return strategyDictionary(
            "assign_using_strategy",
            strategy,
            requiredRole
        );
    }
    if (unassignMember() := currentAction) {
        return dictionary("unassign_member");
    }
    if (closeIssue() := currentAction) {
        return dictionary("close_issue");
    }
    if (reopenIssue() := currentAction) {
        return dictionary("reopen_issue");
    }
    if (requestReviewFrom(memberName) := currentAction) {
        return dictionaryValue(
            "request_review_from",
            pythonString(memberName)
        );
    }
    if (requestReviewUsingStrategy(strategy, requiredRole) := currentAction) {
        return strategyDictionary(
            "request_review_using_strategy",
            strategy,
            requiredRole
        );
    }
    if (removeReviewer(memberName) := currentAction) {
        return dictionaryValue(
            "remove_reviewer",
            pythonString(memberName)
        );
    }
    if (closePullRequest() := currentAction) {
        return dictionary("close_pull_request");
    }
    if (reopenPullRequest() := currentAction) {
        return dictionary("reopen_pull_request");
    }

    return dictionary("unknown");
}


str strategyDictionary(
    str kind,
    Strategy strategy,
    Role requiredRole
) {
    return "{\"kind\": " + pythonString(kind)
        + ", \"strategy\": " + pythonString(strategyName(strategy))
        + ", \"role\": " + pythonString(roleName(requiredRole)) + "}";
}


str dictionary(str kind) {
    return "{\"kind\": " + pythonString(kind) + "}";
}


str dictionaryValue(str kind, str pythonValue) {
    return "{\"kind\": " + pythonString(kind)
        + ", \"value\": " + pythonValue + "}";
}


str roleName(Role role) {
    if (developer() := role) {
        return "developer";
    }
    if (reviewer() := role) {
        return "reviewer";
    }
    if (maintainer() := role) {
        return "maintainer";
    }
    return "maintainer";
}


str priorityName(Priority priority) {
    if (low() := priority) {
        return "low";
    }
    if (medium() := priority) {
        return "medium";
    }
    if (high() := priority) {
        return "high";
    }
    return "critical";
}


str strategyName(Strategy strategy) {
    if (leastBusy() := strategy) {
        return "least_busy";
    }
    return "round_robin";
}


str pythonString(str sourceText) {
    str escaped = String::replaceAll(sourceText, "\\", "\\\\");
    escaped = String::replaceAll(escaped, "\"", "\\\"");
    escaped = String::replaceAll(escaped, "\n", "\\n");
    escaped = String::replaceAll(escaped, "\r", "\\r");
    escaped = String::replaceAll(escaped, "\t", "\\t");
    return "\"" + escaped + "\"";
}


str joinValues(list[str] items) {
    str result = "";

    for (int index <- [0 .. List::size(items)]) {
        if (index > 0) {
            result = result + ", ";
        }

        result = result + items[index];
    }

    return result;
}
