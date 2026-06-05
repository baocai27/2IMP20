module gitpm::transform::Events

import gitpm::Syntax;
import gitpm::AST;
import gitpm::transform::Values;


gitpm::AST::Event buildEvent(
    (CstEvent) `issue opened`
) {
    return gitpm::AST::issueEvent(gitpm::AST::issueOpenedKind());
}


gitpm::AST::Event buildEvent(
    (CstEvent) `issue assigned`
) {
    return gitpm::AST::issueEvent(gitpm::AST::issueAssignedKind());
}


gitpm::AST::Event buildEvent(
    (CstEvent) `issue unassigned`
) {
    return gitpm::AST::issueEvent(gitpm::AST::issueUnassignedKind());
}


gitpm::AST::Event buildEvent(
    (CstEvent)
        `issue labeled <CstName labelNode>`
) {
    return gitpm::AST::issueLabelEvent(
        gitpm::AST::labeledKind(),
        buildName(labelNode)
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent)
        `issue unlabeled <CstName labelNode>`
) {
    return gitpm::AST::issueLabelEvent(
        gitpm::AST::unlabeledKind(),
        buildName(labelNode)
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent) `issue closed`
) {
    return gitpm::AST::issueEvent(gitpm::AST::issueClosedKind());
}


gitpm::AST::Event buildEvent(
    (CstEvent) `issue reopened`
) {
    return gitpm::AST::issueEvent(gitpm::AST::issueReopenedKind());
}


gitpm::AST::Event buildEvent(
    (CstEvent) `issue updated`
) {
    return gitpm::AST::issueEvent(gitpm::AST::issueUpdatedKind());
}


gitpm::AST::Event buildEvent(
    (CstEvent)
        `issue inactive <IntegerLiteral daysNode> days`
) {
    return gitpm::AST::issueInactive(buildInteger(daysNode));
}


// Pull request events
gitpm::AST::Event buildEvent(
    (CstEvent) `pull request opened`
) {
    return gitpm::AST::pullRequestEvent(
        gitpm::AST::pullRequestOpenedKind()
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent) `pull request updated`
) {
    return gitpm::AST::pullRequestEvent(
        gitpm::AST::pullRequestUpdatedKind()
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent)
        `pull request labeled <CstName labelNode>`
) {
    return gitpm::AST::pullRequestLabelEvent(
        gitpm::AST::labeledKind(),
        buildName(labelNode)
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent)
        `pull request unlabeled <CstName labelNode>`
) {
    return gitpm::AST::pullRequestLabelEvent(
        gitpm::AST::unlabeledKind(),
        buildName(labelNode)
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent) `pull request merged`
) {
    return gitpm::AST::pullRequestEvent(
        gitpm::AST::pullRequestMergedKind()
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent) `pull request closed`
) {
    return gitpm::AST::pullRequestEvent(
        gitpm::AST::pullRequestClosedKind()
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent) `pull request reopened`
) {
    return gitpm::AST::pullRequestEvent(
        gitpm::AST::pullRequestReopenedKind()
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent) `pull request review requested`
) {
    return gitpm::AST::pullRequestReviewEvent(
        gitpm::AST::reviewRequestedKind()
    );
}


gitpm::AST::Event buildEvent(
    (CstEvent) `pull request review submitted`
) {
    return gitpm::AST::pullRequestReviewEvent(
        gitpm::AST::reviewSubmittedKind()
    );
}


// Conditions
