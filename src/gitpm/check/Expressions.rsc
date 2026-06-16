module gitpm::check::Expressions

import gitpm::AST;
import gitpm::check::Diagnostics;


// The static types supported by GitPM expressions.
data ExpressionType
    = booleanType()
    | integerType()
    | stringType()
    | unknownType();


// One local variable and its inferred type.
data VariableBinding
    = variableBinding(
        str name,
        ExpressionType expressionType
      );


// Result of checking one expression.
data ExpressionCheck
    = expressionCheck(
        list[Diagnostic] diagnostics,
        ExpressionType expressionType
      );


// Checks an expression and infers its type.
ExpressionCheck checkExpressionTypes(
    str ruleName,
    Expression expression,
    list[VariableBinding] environment
) {
    if (booleanLiteral(_) := expression
        || conditionExpression(_) := expression) {
        return expressionCheck(
            [],
            booleanType()
        );
    }

    if (integerLiteral(_) := expression
        || inactiveDaysExpression() := expression
        || reviewerCountExpression() := expression) {
        return expressionCheck(
            [],
            integerType()
        );
    }

    if (stringLiteral(_) := expression) {
        return expressionCheck(
            [],
            stringType()
        );
    }

    if (variableReference(name) := expression) {
        if (!hasVariable(name, environment)) {
            return expressionCheck(
                [
                    diagnostic(
                        errorSeverity(),
                        "Rule <ruleName> references undefined variable <name>."
                    )
                ],
                unknownType()
            );
        }

        return expressionCheck(
            [],
            findVariableType(name, environment)
        );
    }

    if (notExpression(inner) := expression) {
        ExpressionCheck innerCheck = checkExpressionTypes(
            ruleName,
            inner,
            environment
        );

        if (expressionCheck(diagnostics, innerType) := innerCheck) {
            if (!isUnknown(innerType)
                && !isBoolean(innerType)) {
                diagnostics = diagnostics + [
                    diagnostic(
                        errorSeverity(),
                        "Rule <ruleName> applies not to a non-Boolean expression."
                    )
                ];
            }

            return expressionCheck(
                diagnostics,
                booleanType()
            );
        }
    }

    if (andExpression(left, right) := expression) {
        return checkBooleanBinaryExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    if (orExpression(left, right) := expression) {
        return checkBooleanBinaryExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    if (equalsExpression(left, right) := expression) {
        return checkEqualityExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    if (notEqualsExpression(left, right) := expression) {
        return checkEqualityExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    if (lessThanExpression(left, right) := expression) {
        return checkOrderingExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    if (lessOrEqualExpression(left, right) := expression) {
        return checkOrderingExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    if (greaterThanExpression(left, right) := expression) {
        return checkOrderingExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    if (greaterOrEqualExpression(left, right) := expression) {
        return checkOrderingExpression(
            ruleName,
            left,
            right,
            environment
        );
    }

    return expressionCheck(
        [],
        unknownType()
    );
}


// Checks Boolean binary expressions such as and and or.
ExpressionCheck checkBooleanBinaryExpression(
    str ruleName,
    Expression left,
    Expression right,
    list[VariableBinding] environment
) {
    ExpressionCheck leftCheck = checkExpressionTypes(
        ruleName,
        left,
        environment
    );

    ExpressionCheck rightCheck = checkExpressionTypes(
        ruleName,
        right,
        environment
    );

    if (expressionCheck(leftDiagnostics, leftType) := leftCheck
        && expressionCheck(rightDiagnostics, rightType)
            := rightCheck) {
        list[Diagnostic] diagnostics =
            leftDiagnostics + rightDiagnostics;

        if ((!isUnknown(leftType)
                && !isBoolean(leftType))
            || (!isUnknown(rightType)
                && !isBoolean(rightType))) {
            diagnostics = diagnostics + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> uses and/or with a non-Boolean expression."
                )
            ];
        }

        return expressionCheck(
            diagnostics,
            booleanType()
        );
    }

    return expressionCheck(
        [],
        booleanType()
    );
}


// Checks == and != expressions.
ExpressionCheck checkEqualityExpression(
    str ruleName,
    Expression left,
    Expression right,
    list[VariableBinding] environment
) {
    ExpressionCheck leftCheck = checkExpressionTypes(
        ruleName,
        left,
        environment
    );

    ExpressionCheck rightCheck = checkExpressionTypes(
        ruleName,
        right,
        environment
    );

    if (expressionCheck(leftDiagnostics, leftType) := leftCheck
        && expressionCheck(rightDiagnostics, rightType)
            := rightCheck) {
        list[Diagnostic] diagnostics =
            leftDiagnostics + rightDiagnostics;

        if (!isUnknown(leftType)
            && !isUnknown(rightType)
            && leftType != rightType) {
            diagnostics = diagnostics + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> compares expressions with incompatible types <expressionTypeName(leftType)> and <expressionTypeName(rightType)>."
                )
            ];
        }

        return expressionCheck(
            diagnostics,
            booleanType()
        );
    }

    return expressionCheck(
        [],
        booleanType()
    );
}


// Checks <, <=, > and >= expressions.
ExpressionCheck checkOrderingExpression(
    str ruleName,
    Expression left,
    Expression right,
    list[VariableBinding] environment
) {
    ExpressionCheck leftCheck = checkExpressionTypes(
        ruleName,
        left,
        environment
    );

    ExpressionCheck rightCheck = checkExpressionTypes(
        ruleName,
        right,
        environment
    );

    if (expressionCheck(leftDiagnostics, leftType) := leftCheck
        && expressionCheck(rightDiagnostics, rightType)
            := rightCheck) {
        list[Diagnostic] diagnostics =
            leftDiagnostics + rightDiagnostics;

        if ((!isUnknown(leftType)
                && !isInteger(leftType))
            || (!isUnknown(rightType)
                && !isInteger(rightType))) {
            diagnostics = diagnostics + [
                diagnostic(
                    errorSeverity(),
                    "Rule <ruleName> uses an ordering comparison with a non-integer expression."
                )
            ];
        }

        return expressionCheck(
            diagnostics,
            booleanType()
        );
    }

    return expressionCheck(
        [],
        booleanType()
    );
}


// Returns whether a variable is visible in the current environment.
bool hasVariable(
    str targetName,
    list[VariableBinding] environment
) {
    for (VariableBinding binding <- environment) {
        if (variableBinding(name, _) := binding
            && name == targetName) {
            return true;
        }
    }

    return false;
}


// Retrieves the type of a visible variable.
ExpressionType findVariableType(
    str targetName,
    list[VariableBinding] environment
) {
    for (VariableBinding binding <- environment) {
        if (variableBinding(name, expressionType) := binding
            && name == targetName) {
            return expressionType;
        }
    }

    return unknownType();
}


bool isBoolean(ExpressionType expressionType) {
    return booleanType() := expressionType;
}


bool isInteger(ExpressionType expressionType) {
    return integerType() := expressionType;
}


bool isUnknown(ExpressionType expressionType) {
    return unknownType() := expressionType;
}


str expressionTypeName(
    ExpressionType expressionType
) {
    if (booleanType() := expressionType) {
        return "Boolean";
    }

    if (integerType() := expressionType) {
        return "integer";
    }

    if (stringType() := expressionType) {
        return "string";
    }

    return "unknown";
}