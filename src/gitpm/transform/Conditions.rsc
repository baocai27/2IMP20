module gitpm::transform::Conditions

import gitpm::Syntax;
import gitpm::AST;
import gitpm::transform::Values;

import ParseTree;


list[gitpm::Syntax::CstAndCondition] collectAndConditions(Tree tree) {
    if (gitpm::Syntax::CstAndCondition condition := tree) {
        return [condition];
    }

    list[gitpm::Syntax::CstAndCondition] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectAndConditions(child);
        }
    }

    return result;
}


list[gitpm::Syntax::CstUnaryCondition] collectUnaryConditions(Tree tree) {
    if (gitpm::Syntax::CstUnaryCondition condition := tree) {
        return [condition];
    }

    list[gitpm::Syntax::CstUnaryCondition] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectUnaryConditions(child);
        }
    }

    return result;
}


// Names can be written either as identifiers or quoted strings.

gitpm::AST::Condition buildCondition(
    (CstCondition)
        `<CstOrCondition condition>`
) {
    return buildOrCondition(condition);
}


gitpm::AST::Condition buildOrCondition(
    gitpm::Syntax::CstOrCondition condition
) {
    list[gitpm::Syntax::CstAndCondition] parts
        = collectAndConditions(condition);

    if (parts == []) {
        return gitpm::AST::trueCondition();
    }

    gitpm::AST::Condition result = buildAndCondition(parts[0]);

    for (index <- [1 .. size(parts)]) {
        result = gitpm::AST::orCondition(
            result,
            buildAndCondition(parts[index])
        );
    }

    return result;
}


gitpm::AST::Condition buildAndCondition(
    gitpm::Syntax::CstAndCondition condition
) {
    list[gitpm::Syntax::CstUnaryCondition] parts
        = collectUnaryConditions(condition);

    if (parts == []) {
        return gitpm::AST::trueCondition();
    }

    gitpm::AST::Condition result = buildUnaryCondition(parts[0]);

    for (index <- [1 .. size(parts)]) {
        result = gitpm::AST::andCondition(
            result,
            buildUnaryCondition(parts[index])
        );
    }

    return result;
}


gitpm::AST::Condition buildUnaryCondition(
    (CstUnaryCondition)
        `not <CstUnaryCondition condition>`
) {
    return gitpm::AST::notCondition(
        buildUnaryCondition(condition)
    );
}


gitpm::AST::Condition buildUnaryCondition(
    (CstUnaryCondition)
        `(<CstCondition condition>)`
) {
    return buildCondition(condition);
}


gitpm::AST::Condition buildUnaryCondition(
    (CstUnaryCondition)
        `<CstAtomicCondition condition>`
) {
    return buildAtomicCondition(condition);
}


// Shared conditions
gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition) `true`
) {
    return gitpm::AST::trueCondition();
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `hasLabel(<CstName labelNode>)`
) {
    return gitpm::AST::hasLabel(buildName(labelNode));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `priorityEquals(<CstPriority priorityNode>)`
) {
    return gitpm::AST::priorityEquals(
        buildPriority(priorityNode)
    );
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `milestoneEquals(<CstName milestoneNode>)`
) {
    return gitpm::AST::milestoneEquals(
        buildName(milestoneNode)
    );
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `inColumn(<CstName columnNode>)`
) {
    return gitpm::AST::inColumn(buildName(columnNode));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `titleContains(<StringLiteral text>)`
) {
    return gitpm::AST::titleContains(buildString(text));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition) `isOpen()`
) {
    return gitpm::AST::isOpen();
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition) `isClosed()`
) {
    return gitpm::AST::isClosed();
}


// Issue conditions
gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition) `isAssigned()`
) {
    return gitpm::AST::isAssigned();
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition) `isUnassigned()`
) {
    return gitpm::AST::isUnassigned();
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `openedBy(<CstName memberNode>)`
) {
    return gitpm::AST::openedBy(buildName(memberNode));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `assignedTo(<CstName memberNode>)`
) {
    return gitpm::AST::assignedTo(buildName(memberNode));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `assigneeHasRole(<CstRole roleNode>)`
) {
    return gitpm::AST::assigneeHasRole(buildRole(roleNode));
}


// Pull request conditions
gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `changesPath(<StringLiteral path>)`
) {
    return gitpm::AST::changesPath(buildString(path));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `authoredBy(<CstName memberNode>)`
) {
    return gitpm::AST::authoredBy(buildName(memberNode));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition) `hasReviewer()`
) {
    return gitpm::AST::hasReviewer();
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `reviewedBy(<CstName memberNode>)`
) {
    return gitpm::AST::reviewedBy(buildName(memberNode));
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition)
        `reviewRequestedFrom(<CstName memberNode>)`
) {
    return gitpm::AST::reviewRequestedFrom(
        buildName(memberNode)
    );
}


gitpm::AST::Condition buildAtomicCondition(
    (CstAtomicCondition) `isMerged()`
) {
    return gitpm::AST::isMerged();
}


// Shared actions
