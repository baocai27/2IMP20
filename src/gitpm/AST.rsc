module gitpm::AST

// Complete GitPM program
data Program
    = program(
        list[Declaration] declarations,
        list[Rule] rules
      );


// Project declarations
data Declaration
    = repositoryDeclaration(str name)

    | memberDeclaration(
        str name,
        Role role,
        int workloadLimit
      )

    | labelDeclaration(
        str name
      )

    | milestoneDeclaration(
        str name
      )

    | boardDeclaration(
        str name,
        list[BoardColumn] columns
      );


// Column inside a project board
data BoardColumn
    = boardColumn(str name);


// Team roles
data Role
    = developer()
    | reviewer()
    | maintainer();


// Priority levels
data Priority
    = low()
    | medium()
    | high()
    | critical();


// Assignment and review strategies
data Strategy
    = leastBusy()
    | roundRobin();


// Automation rule
data Rule
    = rule(
        str name,
        Event event,
        Condition condition,
        list[Statement] statements
      );

// Statements executed after a rule matches
data Statement
    = actionStatement(Action action)

    | variableDeclaration(
        str name,
        Expression expression
      )

    | ifStatement(
        Expression condition,
        list[Statement] thenStatements,
        list[Statement] elseStatements
      );

// Expressions used by variables and branching statements
data Expression
    = booleanLiteral(bool booleanValue)
    | integerLiteral(int integerValue)
    | stringLiteral(str stringValue)
    | variableReference(str name)
    | conditionExpression(Condition condition)
    | inactiveDaysExpression()
    | reviewerCountExpression()
    | andExpression(Expression left, Expression right)
    | orExpression(Expression left, Expression right)
    | notExpression(Expression expression)
    | equalsExpression(Expression left, Expression right)
    | notEqualsExpression(Expression left, Expression right)
    | lessThanExpression(Expression left, Expression right)
    | lessOrEqualExpression(Expression left, Expression right)
    | greaterThanExpression(Expression left, Expression right)
    | greaterOrEqualExpression(Expression left, Expression right);

// Events that can trigger a rule
data Event
    = issueEvent(IssueEventKind issueKind)
    | issueLabelEvent(LabelEventKind issueLabelKind, str label)
    | issueInactive(int days)
    | pullRequestEvent(PullRequestEventKind pullRequestKind)
    | pullRequestLabelEvent(
        LabelEventKind pullRequestLabelKind,
        str label
      )
    | pullRequestReviewEvent(ReviewEventKind reviewKind);


data IssueEventKind
    = issueOpenedKind()
    | issueAssignedKind()
    | issueUnassignedKind()
    | issueClosedKind()
    | issueReopenedKind()
    | issueUpdatedKind();


data PullRequestEventKind
    = pullRequestOpenedKind()
    | pullRequestUpdatedKind()
    | pullRequestMergedKind()
    | pullRequestClosedKind()
    | pullRequestReopenedKind();


data LabelEventKind
    = labeledKind()
    | unlabeledKind();


data ReviewEventKind
    = reviewRequestedKind()
    | reviewSubmittedKind();


// Conditions used in rules
data Condition
    // Boolean conditions
    = trueCondition()
    | andCondition(
        Condition left,
        Condition right
      )
    | orCondition(
        Condition left,
        Condition right
      )
    | notCondition(
        Condition condition
      )

    // Conditions shared by issues and pull requests
    | hasLabel(str label)
    | priorityEquals(Priority priority)
    | milestoneEquals(str milestone)
    | inColumn(str column)
    | titleContains(str text)
    | isOpen()
    | isClosed()

    // Issue conditions
    | isAssigned()
    | isUnassigned()
    | openedBy(str member)
    | assignedTo(str member)
    | assigneeHasRole(Role role)

    // Pull request conditions
    | changesPath(str path)
    | authoredBy(str member)
    | hasReviewer()
    | reviewedBy(str member)
    | reviewRequestedFrom(str member)
    | isMerged();


// Actions performed when a rule matches
data Action
    // Actions shared by issues and pull requests
    = addLabel(str label)
    | removeLabel(str label)
    | moveToColumn(str column)
    | setMilestone(str milestone)
    | clearMilestone()
    | setPriority(Priority priority)
    | addComment(str text)

    // Issue actions
    | assignMember(str member)
    | assignUsingStrategy(
        Strategy strategy,
        Role role
      )
    | unassignMember()
    | closeIssue()
    | reopenIssue()

    // Pull request actions
    | requestReviewFrom(str member)
    | requestReviewUsingStrategy(
        Strategy strategy,
        Role role
      )
    | removeReviewer(str member)
    | closePullRequest()
    | reopenPullRequest();