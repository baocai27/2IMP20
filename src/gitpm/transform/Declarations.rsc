module gitpm::transform::Declarations

import gitpm::Syntax;
import gitpm::AST;
import gitpm::transform::Values;
import gitpm::transform::Events;
import gitpm::transform::Conditions;
import gitpm::transform::Statements;

import ParseTree;


gitpm::AST::Program buildProgram(
    gitpm::Syntax::CstProgram syntaxTree
) {
    list[gitpm::Syntax::CstDeclaration] concreteDeclarations
        = collectDeclarations(syntaxTree);

    list[gitpm::Syntax::CstRule] concreteRules
        = collectRules(syntaxTree);

    list[gitpm::AST::Declaration] declarations
        = [buildDeclaration(declaration)
            | declaration <- concreteDeclarations];

    list[gitpm::AST::Rule] rules
        = [buildRule(ruleTree)
            | ruleTree <- concreteRules];

    return gitpm::AST::program(declarations, rules);
}


// The repetitions in the grammar are represented by internal parse-tree
// nodes, so these helpers collect the required elements.
list[gitpm::Syntax::CstDeclaration] collectDeclarations(Tree tree) {
    if (gitpm::Syntax::CstDeclaration declaration := tree) {
        return [declaration];
    }

    list[gitpm::Syntax::CstDeclaration] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectDeclarations(child);
        }
    }

    return result;
}


list[gitpm::Syntax::CstRule] collectRules(Tree tree) {
    if (gitpm::Syntax::CstRule ruleTree := tree) {
        return [ruleTree];
    }

    list[gitpm::Syntax::CstRule] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectRules(child);
        }
    }

    return result;
}


list[gitpm::Syntax::CstBoardColumn] collectBoardColumns(Tree tree) {
    if (gitpm::Syntax::CstBoardColumn column := tree) {
        return [column];
    }

    list[gitpm::Syntax::CstBoardColumn] result = [];

    if (appl(_, list[Tree] children) := tree) {
        for (child <- children) {
            result += collectBoardColumns(child);
        }
    }

    return result;
}

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

gitpm::AST::Rule buildRule(
    (CstRule)
        `rule <CstName name> { on <CstEvent event>; when <CstCondition condition>; do { <CstStatement* statements> } }`
) {
    return gitpm::AST::rule(
        buildName(name),
        buildEvent(event),
        buildCondition(condition),
        [
            buildStatement(statement)
            | statement <- statements
        ]
    );
}

// Issue events
