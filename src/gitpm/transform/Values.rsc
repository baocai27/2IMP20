module gitpm::transform::Values

import gitpm::Syntax;
import gitpm::AST;

import String;


str buildName(
    (CstName) `<Identifier identifier>`
) {
    return "<identifier>";
}


str buildName(
    (CstName) `<StringLiteral literal>`
) {
    return removeQuotes("<literal>");
}


str removeQuotes(str text) {
    if (size(text) < 2) {
        return text;
    }

    return text[1 .. size(text) - 1];
}


int buildInteger(gitpm::Syntax::IntegerLiteral literal) {
    return toInt("<literal>");
}


str buildString(gitpm::Syntax::StringLiteral literal) {
    return removeQuotes("<literal>");
}


// Declarations
gitpm::AST::Declaration buildDeclaration(
    (CstDeclaration)
        `repository <CstName name>;`
) {
    return gitpm::AST::repositoryDeclaration(buildName(name));
}


gitpm::AST::Declaration buildDeclaration(
    (CstDeclaration)
        `member <CstName name> role <CstRole roleNode> workloadLimit <IntegerLiteral limit>;`
) {
    return gitpm::AST::memberDeclaration(
        buildName(name),
        buildRole(roleNode),
        buildInteger(limit)
    );
}


gitpm::AST::Declaration buildDeclaration(
    (CstDeclaration)
        `label <CstName name>;`
) {
    return gitpm::AST::labelDeclaration(buildName(name));
}


gitpm::AST::Declaration buildDeclaration(
    (CstDeclaration)
        `milestone <CstName name>;`
) {
    return gitpm::AST::milestoneDeclaration(buildName(name));
}


gitpm::AST::Declaration buildDeclaration(
    (CstDeclaration)
        `board <CstName name> { <CstBoardColumn* columns> }`
) {
    return gitpm::AST::boardDeclaration(
        buildName(name),
        [buildBoardColumn(column) | column <- columns]
    );
}


gitpm::AST::BoardColumn buildBoardColumn(
    (CstBoardColumn)
        `column <CstName name>;`
) {
    return gitpm::AST::boardColumn(buildName(name));
}


// Roles
gitpm::AST::Role buildRole(
    (CstRole) `developer`
) {
    return gitpm::AST::developer();
}


gitpm::AST::Role buildRole(
    (CstRole) `reviewer`
) {
    return gitpm::AST::reviewer();
}


gitpm::AST::Role buildRole(
    (CstRole) `maintainer`
) {
    return gitpm::AST::maintainer();
}


// Priorities
gitpm::AST::Priority buildPriority(
    (CstPriority) `low`
) {
    return gitpm::AST::low();
}


gitpm::AST::Priority buildPriority(
    (CstPriority) `medium`
) {
    return gitpm::AST::medium();
}


gitpm::AST::Priority buildPriority(
    (CstPriority) `high`
) {
    return gitpm::AST::high();
}


gitpm::AST::Priority buildPriority(
    (CstPriority) `critical`
) {
    return gitpm::AST::critical();
}


// Assignment and review strategies
gitpm::AST::Strategy buildStrategy(
    (CstStrategy) `leastBusy`
) {
    return gitpm::AST::leastBusy();
}


gitpm::AST::Strategy buildStrategy(
    (CstStrategy) `roundRobin`
) {
    return gitpm::AST::roundRobin();
}
