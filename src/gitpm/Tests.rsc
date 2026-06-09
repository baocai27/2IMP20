module gitpm::Tests

import gitpm::Syntax;
import gitpm::AST;
import gitpm::CST2AST;
import gitpm::Check;
import gitpm::Generate;

import ParseTree;
import String;


// These tests use source strings so they do not depend on local file paths.
Program parseText(str sourceText) {
    start[CstProgram] concreteTree =
        parse(#start[CstProgram], sourceText);

    return cstToAst(concreteTree.top);
}


str baseProgram(str ruleText) {
    return
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "member Bob role developer workloadLimit 3;\n"
        + "member Carol role reviewer workloadLimit 2;\n"
        + "label bug;\n"
        + "label stale;\n"
        + "label securityReview;\n"
        + "milestone \"Version 1.0\";\n"
        + "board MainBoard {\n"
        + "    column Backlog;\n"
        + "    column \"In Progress\";\n"
        + "    column Review;\n"
        + "    column Done;\n"
        + "}\n"
        + ruleText;
}


test bool parsesValidProgram() {
    str sourceText = baseProgram(
        "rule AssignBug {\n"
        + "    on issue opened;\n"
        + "    when hasLabel(bug) and isUnassigned();\n"
        + "    do {\n"
        + "        assign using leastBusy developer;\n"
        + "        move to column \"In Progress\";\n"
        + "    }\n"
        + "}\n"
    );

    Program parsedProgram = parseText(sourceText);
    return program(_, _) := parsedProgram;
}


test bool buildsExpectedConditionTree() {
    str sourceText = baseProgram(
        "rule SecurityReview {\n"
        + "    on pull request opened;\n"
        + "    when changesPath(\"src/security/\") and not hasReviewer();\n"
        + "    do {\n"
        + "        request review using leastBusy reviewer;\n"
        + "    }\n"
        + "}\n"
    );

    Program parsedProgram = parseText(sourceText);

    if (program(_, [rule(
        _,
        _,
        andCondition(
            changesPath("src/security/"),
            notCondition(hasReviewer())
        ),
        _
    )]) := parsedProgram) {
        return true;
    }

    return false;
}


test bool validProgramHasNoDiagnostics() {
    str sourceText = baseProgram(
        "rule AssignBug {\n"
        + "    on issue opened;\n"
        + "    when hasLabel(bug) and isUnassigned();\n"
        + "    do {\n"
        + "        assign using leastBusy developer;\n"
        + "        move to column \"In Progress\";\n"
        + "        set milestone \"Version 1.0\";\n"
        + "    }\n"
        + "}\n"
    );

    return checkProgram(parseText(sourceText)) == [];
}


test bool detectsDuplicateMember() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "member Alice role reviewer workloadLimit 2;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsUndefinedLabel() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule MissingLabel {\n"
        + "    on issue opened;\n"
        + "    when hasLabel(bug);\n"
        + "    do { add comment \"Bug.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsUndefinedMember() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule AssignUnknown {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { assign member Bob; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsUndefinedColumn() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule MoveUnknown {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { move to column Done; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsInvalidWorkloadLimit() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 0;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsMissingDeveloperCandidate() {
    str sourceText =
        "repository Demo;\n"
        + "member Carol role reviewer workloadLimit 2;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule AssignWithoutDeveloper {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { assign using leastBusy developer; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsMissingReviewerCandidate() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule ReviewWithoutReviewer {\n"
        + "    on pull request opened;\n"
        + "    when true;\n"
        + "    do { request review using leastBusy reviewer; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsIssueRuleWithPullRequestCondition() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule InvalidCondition {\n"
        + "    on issue opened;\n"
        + "    when changesPath(\"src/\");\n"
        + "    do { add comment \"Invalid.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsPullRequestRuleWithIssueAction() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule InvalidAction {\n"
        + "    on pull request opened;\n"
        + "    when true;\n"
        + "    do { assign member Alice; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsInvalidInactiveDays() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule InvalidInactivePeriod {\n"
        + "    on issue inactive 0 days;\n"
        + "    when true;\n"
        + "    do { add comment \"Invalid.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsEmptyRule() {
    Program invalidProgram =
        program(
            [
                repositoryDeclaration("Demo"),
                memberDeclaration(
                    "Alice",
                    developer(),
                    3
                ),
                boardDeclaration(
                    "MainBoard",
                    [
                        boardColumn("Backlog")
                    ]
                )
            ],
            [
                rule(
                    "EmptyRule",
                    issueEvent(issueOpenedKind()),
                    trueCondition(),
                    []
                )
            ]
        );

    return hasErrors(checkProgram(invalidProgram));
}


test bool generatorIncludesLeastBusyStrategy() {
    str sourceText = baseProgram(
        "rule AssignBug {\n"
        + "    on issue opened;\n"
        + "    when hasLabel(bug);\n"
        + "    do { assign using leastBusy developer; }\n"
        + "}\n"
    );

    str generatedCode = generateProgram(parseText(sourceText));
    return contains(generatedCode, "\"strategy\": \"least_busy\"");
}


test bool generatorIncludesRoundRobinStrategy() {
    str sourceText = baseProgram(
        "rule AssignFeature {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { assign using roundRobin developer; }\n"
        + "}\n"
    );

    str generatedCode = generateProgram(parseText(sourceText));
    return contains(generatedCode, "\"strategy\": \"round_robin\"");
}

test bool generatorImportsRuntimeModule() {
    str sourceText = baseProgram(
        "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n"
    );

    str generatedCode = generateProgram(parseText(sourceText));

    return contains(
        generatedCode,
        "from runtime.gitpm_runtime import ProjectState, run_demo"
    );
}

test bool generatorIncludesProjectConfiguration() {
    str sourceText = baseProgram(
        "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n"
    );

    str generatedCode = generateProgram(parseText(sourceText));

    return contains(generatedCode, "MEMBERS = [")
        && contains(generatedCode, "LABELS = [")
        && contains(generatedCode, "RULES = [")
        && contains(generatedCode, "def build_project():");
}

test bool generatorIncludesRuleName() {
    str sourceText = baseProgram(
        "rule AssignNewBug {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n"
    );

    return contains(
        generateProgram(parseText(sourceText)),
        "AssignNewBug"
    );
}


test bool detectsMissingRepository() {
    Program invalidProgram =
        program(
            [
                memberDeclaration(
                    "Alice",
                    developer(),
                    3
                ),
                boardDeclaration(
                    "MainBoard",
                    [
                        boardColumn("Backlog")
                    ]
                )
            ],
            [
                rule(
                    "KeepOpen",
                    issueEvent(issueOpenedKind()),
                    trueCondition(),
                    [
                        addComment("Opened.")
                    ]
                )
            ]
        );

    return hasErrors(checkProgram(invalidProgram));
}


test bool detectsMultipleRepositories() {
    Program invalidProgram =
        program(
            [
                repositoryDeclaration("RepositoryOne"),
                repositoryDeclaration("RepositoryTwo"),
                memberDeclaration(
                    "Alice",
                    developer(),
                    3
                ),
                boardDeclaration(
                    "MainBoard",
                    [
                        boardColumn("Backlog")
                    ]
                )
            ],
            [
                rule(
                    "KeepOpen",
                    issueEvent(issueOpenedKind()),
                    trueCondition(),
                    [
                        addComment("Opened.")
                    ]
                )
            ]
        );

    return hasErrors(checkProgram(invalidProgram));
}


test bool detectsDuplicateLabel() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "label bug;\n"
        + "label bug;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsDuplicateMilestone() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "milestone \"Version 1.0\";\n"
        + "milestone \"Version 1.0\";\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsDuplicateBoard() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "board MainBoard { column Done; }\n"
        + "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsDuplicateColumn() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard {\n"
        + "    column Backlog;\n"
        + "    column Backlog;\n"
        + "}\n"
        + "rule KeepOpen {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"Opened.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}


test bool detectsEmptyBoard() {
    Program invalidProgram =
        program(
            [
                repositoryDeclaration("Demo"),
                memberDeclaration(
                    "Alice",
                    developer(),
                    3
                ),
                boardDeclaration(
                    "MainBoard",
                    []
                )
            ],
            [
                rule(
                    "KeepOpen",
                    issueEvent(issueOpenedKind()),
                    trueCondition(),
                    [
                        addComment("Opened.")
                    ]
                )
            ]
        );

    return hasErrors(checkProgram(invalidProgram));
}


test bool detectsDuplicateRule() {
    str sourceText =
        "repository Demo;\n"
        + "member Alice role developer workloadLimit 3;\n"
        + "board MainBoard { column Backlog; }\n"
        + "rule DuplicateRule {\n"
        + "    on issue opened;\n"
        + "    when true;\n"
        + "    do { add comment \"First.\"; }\n"
        + "}\n"
        + "rule DuplicateRule {\n"
        + "    on issue closed;\n"
        + "    when true;\n"
        + "    do { add comment \"Second.\"; }\n"
        + "}\n";

    return hasErrors(checkProgram(parseText(sourceText)));
}
