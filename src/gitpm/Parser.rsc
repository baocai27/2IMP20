module gitpm::Parser

import gitpm::Syntax;
import gitpm::AST;
import gitpm::CST2AST;

import ParseTree;


// Parses a GitPM file and returns its concrete syntax tree
start[CstProgram] parseConcreteProgram(loc source) {
    return parse(
        #start[CstProgram],
        source
    );
}


// Parses a GitPM file and converts it to the abstract syntax tree
gitpm::AST::Program parseProgram(loc source) {
    start[CstProgram] concreteTree = parseConcreteProgram(source);
    return cstToAst(concreteTree.top);
}