module gitpm::CST2AST

import gitpm::Syntax;
import gitpm::AST;
import gitpm::transform::Declarations;


gitpm::AST::Program cstToAst(
    gitpm::Syntax::CstProgram syntaxTree
) {
    return buildProgram(syntaxTree);
}
