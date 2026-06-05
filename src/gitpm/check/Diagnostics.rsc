module gitpm::check::Diagnostics

import String;

data Severity
    = errorSeverity()
    | warningSeverity();

data Diagnostic
    = diagnostic(Severity severity, str message);
bool hasErrors(list[Diagnostic] diagnostics) {
    for (Diagnostic current <- diagnostics) {
        if (diagnostic(errorSeverity(), _) := current) {
            return true;
        }
    }

    return false;
}


str formatDiagnostic(Diagnostic current) {
    if (diagnostic(errorSeverity(), message) := current) {
        return "error: <message>";
    }

    if (diagnostic(warningSeverity(), message) := current) {
        return "warning: <message>";
    }

    return "diagnostic";
}
list[Diagnostic] checkName(str kind, str name) {
    if (trim(name) == "") {
        return [
            diagnostic(
                errorSeverity(),
                "<kind> names may not be empty."
            )
        ];
    }

    return [];
}
list[Diagnostic] duplicateDiagnostics(str kind, list[str] names) {
    list[Diagnostic] result = [];
    set[str] reported = {};

    for (str name <- names) {
        if (countOccurrences(name, names) > 1
            && name notin reported) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Duplicate <kind> name <name>."
                )
            ];
            reported = reported + {name};
        }
    }

    return result;
}


int countOccurrences(str target, list[str] names) {
    int count = 0;

    for (str name <- names) {
        if (name == target) {
            count = count + 1;
        }
    }

    return count;
}
