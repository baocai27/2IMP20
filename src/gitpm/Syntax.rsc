module gitpm::Syntax

layout Layout
    = WhitespaceOrComment*;

lexical WhitespaceOrComment
    = [\t\n\r\ ]
    | LineComment;

lexical LineComment
    = "//" ![\n\r]*;

lexical RawIdentifier
    = [A-Za-z][A-Za-z0-9_]*
      !>> [A-Za-z0-9_];

lexical Identifier
    = RawIdentifier \ Keywords;

lexical IntegerLiteral
    = [0-9]+ !>> [0-9];

lexical StringLiteral
    = "\"" ![\"\n\r]* "\"";

keyword Keywords
    = "repository"
    | "member"
    | "role"
    | "workloadLimit"
    | "label"
    | "milestone"
    | "board"
    | "column"
    | "rule"
    | "on"
    | "when"
    | "do"
    | "let"
    | "if"
    | "then"
    | "else"
    | "issue"
    | "pull"
    | "request"
    | "review"
    | "opened"
    | "assigned"
    | "unassigned"
    | "labeled"
    | "unlabeled"
    | "closed"
    | "reopened"
    | "updated"
    | "inactive"
    | "merged"
    | "requested"
    | "submitted"
    | "days"
    | "true"
    | "false"
    | "and"
    | "or"
    | "not"
    | "hasLabel"
    | "priorityEquals"
    | "milestoneEquals"
    | "inColumn"
    | "titleContains"
    | "isOpen"
    | "isClosed"
    | "isAssigned"
    | "isUnassigned"
    | "openedBy"
    | "assignedTo"
    | "assigneeHasRole"
    | "changesPath"
    | "authoredBy"
    | "hasReviewer"
    | "reviewedBy"
    | "reviewRequestedFrom"
    | "isMerged"
    | "inactiveDays"
    | "reviewerCount"
    | "add"
    | "remove"
    | "move"
    | "to"
    | "set"
    | "clear"
    | "priority"
    | "comment"
    | "assign"
    | "using"
    | "unassign"
    | "close"
    | "reopen"
    | "from"
    | "reviewer"
    | "developer"
    | "maintainer"
    | "leastBusy"
    | "roundRobin"
    | "low"
    | "medium"
    | "high"
    | "critical";

syntax CstName
    = identifierName: Identifier
    | stringName: StringLiteral;

start syntax CstProgram
    = program: CstDeclaration* CstRule*;

syntax CstDeclaration
    = repositoryDeclaration:
        "repository" CstName ";"

    | memberDeclaration:
        "member" CstName
        "role" CstRole
        "workloadLimit" IntegerLiteral
        ";"

    | labelDeclaration:
        "label" CstName ";"

    | milestoneDeclaration:
        "milestone" CstName ";"

    | boardDeclaration:
        "board" CstName
        "{"
            CstBoardColumn*
        "}";

syntax CstBoardColumn
    = boardColumn:
        "column" CstName ";";

syntax CstRole
    = developerRole: "developer"
    | reviewerRole: "reviewer"
    | maintainerRole: "maintainer";

syntax CstPriority
    = lowPriority: "low"
    | mediumPriority: "medium"
    | highPriority: "high"
    | criticalPriority: "critical";

syntax CstStrategy
    = leastBusyStrategy: "leastBusy"
    | roundRobinStrategy: "roundRobin";

syntax CstRule
    = automationRule:
        "rule" CstName
        "{"
            "on" CstEvent ";"
            "when" CstCondition ";"
            "do"
            "{"
                CstStatement+
            "}"
        "}"

    | emptyAutomationRule:
        "rule" CstName
        "{"
            "on" CstEvent ";"
            "when" CstCondition ";"
            "do"
            "{"
            "}"
        "}";


syntax CstStatement
    = actionStatement: CstAction

    | variableDeclaration:
        "let" Identifier "=" CstExpression ";"

    | ifStatement:
        "if" CstExpression "then"
        "{"
            CstStatement*
        "}"
        "else"
        "{"
            CstStatement*
        "}";


syntax CstEvent
    = issueOpenedEvent: "issue" "opened"
    | issueAssignedEvent: "issue" "assigned"
    | issueUnassignedEvent: "issue" "unassigned"
    | issueLabeledEvent: "issue" "labeled" CstName
    | issueUnlabeledEvent: "issue" "unlabeled" CstName
    | issueClosedEvent: "issue" "closed"
    | issueReopenedEvent: "issue" "reopened"
    | issueUpdatedEvent: "issue" "updated"
    | issueInactiveEvent: "issue" "inactive" IntegerLiteral "days"
    | pullRequestOpenedEvent: "pull" "request" "opened"
    | pullRequestUpdatedEvent: "pull" "request" "updated"
    | pullRequestLabeledEvent: "pull" "request" "labeled" CstName
    | pullRequestUnlabeledEvent: "pull" "request" "unlabeled" CstName
    | pullRequestMergedEvent: "pull" "request" "merged"
    | pullRequestClosedEvent: "pull" "request" "closed"
    | pullRequestReopenedEvent: "pull" "request" "reopened"
    | pullRequestReviewRequestedEvent: "pull" "request" "review" "requested"
    | pullRequestReviewSubmittedEvent: "pull" "request" "review" "submitted";

syntax CstCondition
    = condition: CstOrCondition;

syntax CstOrCondition
    = orCondition:
        {CstAndCondition "or"}+;

syntax CstAndCondition
    = andCondition:
        {CstUnaryCondition "and"}+;

syntax CstUnaryCondition
    = notCondition: "not" CstUnaryCondition
    | groupedCondition: "(" CstCondition ")"
    | atomicCondition: CstAtomicCondition;

syntax CstAtomicCondition
    = trueCondition: "true"
    | hasLabelCondition: "hasLabel" "(" CstName ")"
    | priorityEqualsCondition: "priorityEquals" "(" CstPriority ")"
    | milestoneEqualsCondition: "milestoneEquals" "(" CstName ")"
    | inColumnCondition: "inColumn" "(" CstName ")"
    | titleContainsCondition: "titleContains" "(" StringLiteral ")"
    | isOpenCondition: "isOpen" "(" ")"
    | isClosedCondition: "isClosed" "(" ")"
    | isAssignedCondition: "isAssigned" "(" ")"
    | isUnassignedCondition: "isUnassigned" "(" ")"
    | openedByCondition: "openedBy" "(" CstName ")"
    | assignedToCondition: "assignedTo" "(" CstName ")"
    | assigneeHasRoleCondition: "assigneeHasRole" "(" CstRole ")"
    | changesPathCondition: "changesPath" "(" StringLiteral ")"
    | authoredByCondition: "authoredBy" "(" CstName ")"
    | hasReviewerCondition: "hasReviewer" "(" ")"
    | reviewedByCondition: "reviewedBy" "(" CstName ")"
    | reviewRequestedFromCondition: "reviewRequestedFrom" "(" CstName ")"
    | isMergedCondition: "isMerged" "(" ")";

syntax CstExpression
    = expression: CstOrExpression;


syntax CstOrExpression
    = orExpression:
        {CstAndExpression "or"}+;

syntax CstAndExpression
    = andExpression:
        {CstComparisonExpression "and"}+;


syntax CstComparisonExpression
    = comparisonExpression:
        CstUnaryExpression

    | comparisonExpression:
        CstUnaryExpression CstComparisonTail;


syntax CstComparisonTail
    = equalsComparison:
        "==" CstUnaryExpression

    | notEqualsComparison:
        "!=" CstUnaryExpression

    | lessThanComparison:
        "\<" CstUnaryExpression

    | lessOrEqualComparison:
        "\<=" CstUnaryExpression

    | greaterThanComparison:
        "\>" CstUnaryExpression

    | greaterOrEqualComparison:
        "\>=" CstUnaryExpression;


syntax CstUnaryExpression
    = notExpression:
        "not" CstUnaryExpression

    | groupedExpression:
        "(" CstExpression ")"

    | atomicExpression:
        CstAtomicExpression;


syntax CstAtomicExpression
    = falseExpression:
        "false"

    | integerExpression:
        IntegerLiteral

    | stringExpression:
        StringLiteral

    | variableExpression:
        Identifier

    | conditionExpression:
        CstAtomicCondition

    | inactiveDaysExpression:
        "inactiveDays" "(" ")"

    | reviewerCountExpression:
        "reviewerCount" "(" ")";


syntax CstAction
    = addLabelAction: "add" "label" CstName ";"
    | removeLabelAction: "remove" "label" CstName ";"
    | moveToColumnAction: "move" "to" "column" CstName ";"
    | setMilestoneAction: "set" "milestone" CstName ";"
    | clearMilestoneAction: "clear" "milestone" ";"
    | setPriorityAction: "set" "priority" CstPriority ";"
    | addCommentAction: "add" "comment" StringLiteral ";"
    | assignMemberAction: "assign" "member" CstName ";"
    | assignUsingStrategyAction: "assign" "using" CstStrategy CstRole ";"
    | unassignMemberAction: "unassign" "member" ";"
    | closeIssueAction: "close" "issue" ";"
    | reopenIssueAction: "reopen" "issue" ";"
    | requestReviewFromAction: "request" "review" "from" CstName ";"
    | requestReviewUsingStrategyAction:
        "request" "review" "using" CstStrategy CstRole ";"
    | removeReviewerAction: "remove" "reviewer" CstName ";"
    | closePullRequestAction: "close" "pull" "request" ";"
    | reopenPullRequestAction: "reopen" "pull" "request" ";";
