module gitpm::transform::Statements

import gitpm::Syntax;
import gitpm::AST;
import gitpm::transform::Actions;
import gitpm::transform::Expressions;


// Existing actions are wrapped as statements.
gitpm::AST::Statement buildStatement(
    (CstStatement) `<CstAction actionNode>`
) {
    return gitpm::AST::actionStatement(
        buildAction(actionNode)
    );
}


// Local variable declaration.
gitpm::AST::Statement buildStatement(
    (CstStatement)
        `let <Identifier nameNode> = <CstExpression expressionNode>;`
) {
    return gitpm::AST::variableDeclaration(
        "<nameNode>",
        buildExpression(expressionNode)
    );
}


// Conditional branch.
gitpm::AST::Statement buildStatement(
    (CstStatement) `if <CstExpression conditionNode> then { <CstStatement* thenNodes> } else { <CstStatement* elseNodes> }`
) {
    return gitpm::AST::ifStatement(
        buildExpression(conditionNode),
        [
            buildStatement(statementNode)
            | statementNode <- thenNodes
        ],
        [
            buildStatement(statementNode)
            | statementNode <- elseNodes
        ]
    );
}