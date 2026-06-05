module gitpm::transform::Actions

import gitpm::Syntax;
import gitpm::AST;
import gitpm::transform::Values;

import ParseTree;


list[gitpm::Syntax::CstAction] collectActions(Tree tree) {
    if (gitpm::Syntax::CstAction action := tree) {
        return [action];
    }

    list[gitpm::Syntax::CstAction] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectActions(child);
        }
    }

    return result;
}

gitpm::AST::Action buildAction(
    (CstAction)
        `add label <CstName labelNode>;`
) {
    return gitpm::AST::addLabel(buildName(labelNode));
}


gitpm::AST::Action buildAction(
    (CstAction)
        `remove label <CstName labelNode>;`
) {
    return gitpm::AST::removeLabel(buildName(labelNode));
}


gitpm::AST::Action buildAction(
    (CstAction)
        `move to column <CstName columnNode>;`
) {
    return gitpm::AST::moveToColumn(buildName(columnNode));
}


gitpm::AST::Action buildAction(
    (CstAction)
        `set milestone <CstName milestoneNode>;`
) {
    return gitpm::AST::setMilestone(
        buildName(milestoneNode)
    );
}


gitpm::AST::Action buildAction(
    (CstAction) `clear milestone;`
) {
    return gitpm::AST::clearMilestone();
}


gitpm::AST::Action buildAction(
    (CstAction)
        `set priority <CstPriority priorityNode>;`
) {
    return gitpm::AST::setPriority(
        buildPriority(priorityNode)
    );
}


gitpm::AST::Action buildAction(
    (CstAction)
        `add comment <StringLiteral text>;`
) {
    return gitpm::AST::addComment(buildString(text));
}


// Issue actions
gitpm::AST::Action buildAction(
    (CstAction)
        `assign member <CstName memberNode>;`
) {
    return gitpm::AST::assignMember(buildName(memberNode));
}


gitpm::AST::Action buildAction(
    (CstAction)
        `assign using <CstStrategy strategy> <CstRole roleNode>;`
) {
    return gitpm::AST::assignUsingStrategy(
        buildStrategy(strategy),
        buildRole(roleNode)
    );
}


gitpm::AST::Action buildAction(
    (CstAction) `unassign member;`
) {
    return gitpm::AST::unassignMember();
}


gitpm::AST::Action buildAction(
    (CstAction) `close issue;`
) {
    return gitpm::AST::closeIssue();
}


gitpm::AST::Action buildAction(
    (CstAction) `reopen issue;`
) {
    return gitpm::AST::reopenIssue();
}


// Pull request actions
gitpm::AST::Action buildAction(
    (CstAction)
        `request review from <CstName memberNode>;`
) {
    return gitpm::AST::requestReviewFrom(
        buildName(memberNode)
    );
}


gitpm::AST::Action buildAction(
    (CstAction)
        `request review using <CstStrategy strategy> <CstRole roleNode>;`
) {
    return gitpm::AST::requestReviewUsingStrategy(
        buildStrategy(strategy),
        buildRole(roleNode)
    );
}


gitpm::AST::Action buildAction(
    (CstAction)
        `remove reviewer <CstName memberNode>;`
) {
    return gitpm::AST::removeReviewer(buildName(memberNode));
}


gitpm::AST::Action buildAction(
    (CstAction) `close pull request;`
) {
    return gitpm::AST::closePullRequest();
}


gitpm::AST::Action buildAction(
    (CstAction) `reopen pull request;`
) {
    return gitpm::AST::reopenPullRequest();
}
