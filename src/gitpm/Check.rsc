module gitpm::Check

import gitpm::AST;
extend gitpm::check::Diagnostics;
import gitpm::check::Declarations;
import gitpm::check::Rules;

// Runs all static semantic checks.
list[Diagnostic] checkProgram(Program inputProgram) {
    list[Diagnostic] result = [];

    if (program(declarations, rules) := inputProgram) {
        result = result + checkDeclarations(declarations);
        result = result + checkRules(declarations, rules);
    }
    else {
        result = result + [
            diagnostic(
                errorSeverity(),
                "The input is not a valid GitPM program."
            )
        ];
    }

    return result;
}
