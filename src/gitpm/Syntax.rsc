module gitpm::Syntax

layout Layout
    = WhitespaceOrComment*;

lexical WhitespaceOrComment
    = [\t\n\r\ ]
    | LineComment;

lexical LineComment
    = "//" ![\n\r]*;

lexical Identifier
    = [A-Za-z][A-Za-z0-9_]* \ Keywords;

lexical IntegerLiteral
    = [0-9]+;

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
                CstAction*
            "}"
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
        CstAndCondition ("or" CstAndCondition)*;

syntax CstAndCondition
    = andCondition:
        CstUnaryCondition ("and" CstUnaryCondition)*;

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
