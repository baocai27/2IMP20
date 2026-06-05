module gitpm::check::Declarations

import gitpm::AST;
import gitpm::check::Diagnostics;

import String;
import List;

list[Diagnostic] checkDeclarations(list[Declaration] declarations) {
    list[Diagnostic] result = [];

    list[str] repositoryNames = [];
    list[str] memberNames = [];
    list[str] labelNames = [];
    list[str] milestoneNames = [];
    list[str] boardNames = [];
    list[str] columnNames = [];

    for (Declaration declaration <- declarations) {
        if (repositoryDeclaration(name) := declaration) {
            repositoryNames = repositoryNames + [name];
        }

        if (memberDeclaration(name, _, _) := declaration) {
            memberNames = memberNames + [name];
        }

        if (labelDeclaration(name) := declaration) {
            labelNames = labelNames + [name];
        }

        if (milestoneDeclaration(name) := declaration) {
            milestoneNames = milestoneNames + [name];
        }

        if (boardDeclaration(name, columns) := declaration) {
            boardNames = boardNames + [name];

            for (BoardColumn column <- columns) {
                if (boardColumn(columnName) := column) {
                    columnNames = columnNames + [columnName];
                }
            }
        }
    }

    if (List::size(repositoryNames) == 0) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "The program must declare one repository."
            )
        ];
    }

    if (List::size(repositoryNames) > 1) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "The program may only declare one repository."
            )
        ];
    }

    result = result + duplicateDiagnostics("repository", repositoryNames);
    result = result + duplicateDiagnostics("member", memberNames);
    result = result + duplicateDiagnostics("label", labelNames);
    result = result + duplicateDiagnostics("milestone", milestoneNames);
    result = result + duplicateDiagnostics("board", boardNames);
    result = result + duplicateDiagnostics("column", columnNames);

    for (Declaration declaration <- declarations) {
        result = result + checkDeclaration(declaration);
    }

    return result;
}


list[Diagnostic] checkDeclaration(Declaration declaration) {
    list[Diagnostic] result = [];

    if (repositoryDeclaration(name) := declaration) {
        result = result + checkName("Repository", name);
    }

    if (memberDeclaration(name, _, workloadLimit) := declaration) {
        result = result + checkName("Member", name);

        if (workloadLimit <= 0) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Member <name> must have a workload limit greater than zero."
                )
            ];
        }
    }

    if (labelDeclaration(name) := declaration) {
        result = result + checkName("Label", name);
    }

    if (milestoneDeclaration(name) := declaration) {
        result = result + checkName("Milestone", name);
    }

    if (boardDeclaration(name, columns) := declaration) {
        result = result + checkName("Board", name);

        if (List::size(columns) == 0) {
            result = result + [
                diagnostic(
                    errorSeverity(),
                    "Board <name> must contain at least one column."
                )
            ];
        }

        for (BoardColumn column <- columns) {
            if (boardColumn(columnName) := column) {
                result = result + checkName("Column", columnName);
            }
        }
    }

    return result;
}

