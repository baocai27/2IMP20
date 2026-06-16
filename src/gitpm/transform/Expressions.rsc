module gitpm::transform::Expressions

import gitpm::Syntax;
import gitpm::AST;
import gitpm::transform::Values;
import gitpm::transform::Conditions;

import ParseTree;


// Collect all direct and-expression parts of an or-expression.
list[gitpm::Syntax::CstAndExpression] collectAndExpressions(
    Tree tree
) {
    if (gitpm::Syntax::CstAndExpression andPart := tree) {
        return [andPart];
    }

    list[gitpm::Syntax::CstAndExpression] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectAndExpressions(child);
        }
    }

    return result;
}


// Collect all direct comparison parts of an and-expression.
list[gitpm::Syntax::CstComparisonExpression]
collectComparisonExpressions(
    Tree tree
) {
    if (
        gitpm::Syntax::CstComparisonExpression comparisonPart
            := tree
    ) {
        return [comparisonPart];
    }

    list[gitpm::Syntax::CstComparisonExpression] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectComparisonExpressions(child);
        }
    }

    return result;
}


// Used to obtain the right operand from a comparison tail.
list[gitpm::Syntax::CstUnaryExpression] collectUnaryExpressions(
    Tree tree
) {
    if (gitpm::Syntax::CstUnaryExpression unaryPart := tree) {
        return [unaryPart];
    }

    list[gitpm::Syntax::CstUnaryExpression] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectUnaryExpressions(child);
        }
    }

    return result;
}


// Complete expression
gitpm::AST::Expression buildExpression(
    (CstExpression)
        `<CstOrExpression expressionNode>`
) {
    return buildOrExpression(expressionNode);
}


// Or expressions
gitpm::AST::Expression buildOrExpression(
    gitpm::Syntax::CstOrExpression expressionNode
) {
    list[gitpm::Syntax::CstAndExpression] parts
        = collectAndExpressions(expressionNode);

    gitpm::AST::Expression result
        = buildAndExpression(parts[0]);

    for (index <- [1 .. size(parts)]) {
        result = gitpm::AST::orExpression(
            result,
            buildAndExpression(parts[index])
        );
    }

    return result;
}


// And expressions
gitpm::AST::Expression buildAndExpression(
    gitpm::Syntax::CstAndExpression expressionNode
) {
    list[gitpm::Syntax::CstComparisonExpression] parts
        = collectComparisonExpressions(expressionNode);

    gitpm::AST::Expression result
        = buildComparisonExpression(parts[0]);

    for (index <- [1 .. size(parts)]) {
        result = gitpm::AST::andExpression(
            result,
            buildComparisonExpression(parts[index])
        );
    }

    return result;
}


// Expression without a comparison
gitpm::AST::Expression buildComparisonExpression(
    (CstComparisonExpression)
        `<CstUnaryExpression expressionNode>`
) {
    return buildUnaryExpression(expressionNode);
}


// Expression with one comparison
gitpm::AST::Expression buildComparisonExpression(
    (CstComparisonExpression)
        `<CstUnaryExpression leftNode> <CstComparisonTail comparisonTail>`
) {
    return buildComparisonTail(
        buildUnaryExpression(leftNode),
        comparisonTail
    );
}


// Comparison operators
gitpm::AST::Expression buildComparisonTail(
    gitpm::AST::Expression leftExpression,
    gitpm::Syntax::CstComparisonTail comparisonTail
) {
    list[gitpm::Syntax::CstUnaryExpression] rightOperands
        = collectUnaryExpressions(comparisonTail);

    gitpm::AST::Expression rightExpression
        = buildUnaryExpression(rightOperands[0]);

    if (comparisonTail is equalsComparison) {
        return gitpm::AST::equalsExpression(
            leftExpression,
            rightExpression
        );
    }

    if (comparisonTail is notEqualsComparison) {
        return gitpm::AST::notEqualsExpression(
            leftExpression,
            rightExpression
        );
    }

    if (comparisonTail is lessThanComparison) {
        return gitpm::AST::lessThanExpression(
            leftExpression,
            rightExpression
        );
    }

    if (comparisonTail is lessOrEqualComparison) {
        return gitpm::AST::lessOrEqualExpression(
            leftExpression,
            rightExpression
        );
    }

    if (comparisonTail is greaterThanComparison) {
        return gitpm::AST::greaterThanExpression(
            leftExpression,
            rightExpression
        );
    }

    return gitpm::AST::greaterOrEqualExpression(
        leftExpression,
        rightExpression
    );
}


// Unary not
gitpm::AST::Expression buildUnaryExpression(
    (CstUnaryExpression)
        `not <CstUnaryExpression expressionNode>`
) {
    return gitpm::AST::notExpression(
        buildUnaryExpression(expressionNode)
    );
}


// Parenthesized expression
gitpm::AST::Expression buildUnaryExpression(
    (CstUnaryExpression)
        `(<CstExpression expressionNode>)`
) {
    return buildExpression(expressionNode);
}


// Atomic expression
gitpm::AST::Expression buildUnaryExpression(
    (CstUnaryExpression)
        `<CstAtomicExpression atomicNode>`
) {
    return buildAtomicExpression(atomicNode);
}


// Integer literal
gitpm::AST::Expression buildAtomicExpression(
    (CstAtomicExpression)
        `<IntegerLiteral integerNode>`
) {
    return gitpm::AST::integerLiteral(
        buildInteger(integerNode)
    );
}


// String literal
gitpm::AST::Expression buildAtomicExpression(
    (CstAtomicExpression)
        `<StringLiteral stringNode>`
) {
    return gitpm::AST::stringLiteral(
        buildString(stringNode)
    );
}


// Variable reference
gitpm::AST::Expression buildAtomicExpression(
    (CstAtomicExpression)
        `<Identifier identifierNode>`
) {
    return gitpm::AST::variableReference(
        "<identifierNode>"
    );
}


// Existing domain condition used as a Boolean expression
gitpm::AST::Expression buildAtomicExpression(
    (CstAtomicExpression)
        `<CstAtomicCondition conditionNode>`
) {
    return gitpm::AST::conditionExpression(
        buildAtomicCondition(conditionNode)
    );
}


// Atomic expressions that do not require child extraction
default gitpm::AST::Expression buildAtomicExpression(
    gitpm::Syntax::CstAtomicExpression expressionNode
) {
    if (expressionNode is falseExpression) {
        return gitpm::AST::booleanLiteral(false);
    }

    if (expressionNode is inactiveDaysExpression) {
        return gitpm::AST::inactiveDaysExpression();
    }

    if (expressionNode is reviewerCountExpression) {
        return gitpm::AST::reviewerCountExpression();
    }

    throw "Unsupported atomic expression: <expressionNode>";
}