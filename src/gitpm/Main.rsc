module gitpm::Main

import gitpm::AST;
import gitpm::Parser;
import gitpm::Check;
import gitpm::Generate;

import IO;


data CompilationResult
    = generatedFile(loc outputFile)
    | rejectedProgram(list[Diagnostic] diagnostics);


// Parses and checks a GitPM program
list[Diagnostic] validateFile(loc sourceFile) {
    gitpm::AST::Program parsedProgram = parseProgram(sourceFile);
    return checkProgram(parsedProgram);
}


// Runs the complete GitPM compilation pipeline
CompilationResult compileProgram(
    loc sourceFile,
    loc outputFile
) {
    gitpm::AST::Program parsedProgram = parseProgram(sourceFile);
    list[Diagnostic] diagnostics = checkProgram(parsedProgram);

    if (hasErrors(diagnostics)) {
        printDiagnostics(diagnostics);
        return rejectedProgram(diagnostics);
    }

    generateToFile(parsedProgram, outputFile);
    println("Generated Python file:");
    println(outputFile);

    return generatedFile(outputFile);
}


// Prints all diagnostics in a readable form
void printDiagnostics(list[Diagnostic] diagnostics) {
    if (diagnostics == []) {
        println("No static semantic errors found.");
        return;
    }

    for (Diagnostic current <- diagnostics) {
        println(formatDiagnostic(current));
    }
}


// Convenience entry point for the complete example
CompilationResult compileExample() {
    return compileProgram(
        |file:///C:/Users/13157/Desktop/2IMP20/examples/complete.gitpm|,
        |file:///C:/Users/13157/Desktop/2IMP20/generated/project_bot.py|
    );
}
