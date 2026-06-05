module gitpm::check::References

import gitpm::AST;
import gitpm::check::Diagnostics;
import gitpm::check::Compatibility;

// Reference checks

list[Diagnostic] checkMemberReference(
    str ruleName,
    str memberName,
    list[Declaration] declarations
) {
    if (!hasMember(memberName, declarations)) {
        return [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> references undefined member <memberName>."
            )
        ];
    }

    return [];
}


list[Diagnostic] checkAssignableMemberReference(
    str ruleName,
    str memberName,
    list[Declaration] declarations
) {
    list[Diagnostic] result =
        checkMemberReference(ruleName, memberName, declarations);

    if (hasMember(memberName, declarations)
        && !isAssignableRole(
            findMemberRole(memberName, declarations)
        )) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> assigns member <memberName>, but that member has an incompatible role."
            )
        ];
    }

    return result;
}


list[Diagnostic] checkReviewerReference(
    str ruleName,
    str memberName,
    list[Declaration] declarations
) {
    list[Diagnostic] result =
        checkMemberReference(ruleName, memberName, declarations);

    if (hasMember(memberName, declarations)
        && !isReviewerRole(
            findMemberRole(memberName, declarations)
        )) {
        result = result + [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> uses member <memberName> as a reviewer, but that member has an incompatible role."
            )
        ];
    }

    return result;
}


list[Diagnostic] checkLabelReference(
    str ruleName,
    str labelName,
    list[Declaration] declarations
) {
    if (!hasLabelDeclaration(labelName, declarations)) {
        return [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> references undefined label <labelName>."
            )
        ];
    }

    return [];
}


list[Diagnostic] checkMilestoneReference(
    str ruleName,
    str milestoneName,
    list[Declaration] declarations
) {
    if (!hasMilestone(milestoneName, declarations)) {
        return [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> references undefined milestone <milestoneName>."
            )
        ];
    }

    return [];
}


list[Diagnostic] checkColumnReference(
    str ruleName,
    str columnName,
    list[Declaration] declarations
) {
    if (!hasColumn(columnName, declarations)) {
        return [
            diagnostic(
                errorSeverity(),
                "Rule <ruleName> references undefined column <columnName>."
            )
        ];
    }

    return [];
}


// Lookup helpers

bool hasMember(str targetName, list[Declaration] declarations) {
    for (Declaration declaration <- declarations) {
        if (memberDeclaration(name, _, _) := declaration
            && name == targetName) {
            return true;
        }
    }

    return false;
}


Role findMemberRole(
    str targetName,
    list[Declaration] declarations
) {
    for (Declaration declaration <- declarations) {
        if (memberDeclaration(name, memberRole, _) := declaration
            && name == targetName) {
            return memberRole;
        }
    }

    return maintainer();
}


bool hasLabelDeclaration(
    str targetName,
    list[Declaration] declarations
) {
    for (Declaration declaration <- declarations) {
        if (labelDeclaration(name) := declaration
            && name == targetName) {
            return true;
        }
    }

    return false;
}


bool hasMilestone(
    str targetName,
    list[Declaration] declarations
) {
    for (Declaration declaration <- declarations) {
        if (milestoneDeclaration(name) := declaration
            && name == targetName) {
            return true;
        }
    }

    return false;
}


bool hasColumn(
    str targetName,
    list[Declaration] declarations
) {
    for (Declaration declaration <- declarations) {
        if (boardDeclaration(_, columns) := declaration) {
            for (BoardColumn column <- columns) {
                if (boardColumn(name) := column
                    && name == targetName) {
                    return true;
                }
            }
        }
    }

    return false;
}


bool hasRoleCandidate(
    Role requiredRole,
    list[Declaration] declarations
) {
    for (Declaration declaration <- declarations) {
        if (memberDeclaration(_, memberRole, _) := declaration
            && memberRole == requiredRole) {
            return true;
        }
    }

    return false;
}


