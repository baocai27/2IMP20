module gitpm::Main

import gitpm::AST;
import gitpm::Parser;
import gitpm::Check;
import gitpm::Generate;

import IO;
import List;

data CompilationResult
    = generatedFile(loc outputFile)
    | rejectedProgram(list[Diagnostic] diagnostics);


// Parses and statically checks a GitPM program.
list[Diagnostic] validateFile(loc sourceFile) {
    gitpm::AST::Program parsedProgram = parseProgram(sourceFile);
    return checkProgram(parsedProgram);
}


// Runs the complete GitPM compilation pipeline.
CompilationResult compileProgram(
    loc sourceFile,
    loc outputFile
) {
    println("Compiling:");
    println(sourceFile);

    gitpm::AST::Program parsedProgram = parseProgram(sourceFile);
    list[Diagnostic] diagnostics = checkProgram(parsedProgram);

    if (hasErrors(diagnostics)) {
        println("Compilation rejected because static semantic errors were found.");
        printDiagnostics(diagnostics);
        println("");

        return rejectedProgram(diagnostics);
    }

    generateToFile(parsedProgram, outputFile);

    println("Generated Python file:");
    println(outputFile);
    println("");

    return generatedFile(outputFile);
}


// Prints all diagnostics in a readable form.
void printDiagnostics(list[Diagnostic] diagnostics) {
    if (diagnostics == []) {
        println("No static semantic errors found.");
        return;
    }

    for (Diagnostic current <- diagnostics) {
        println(formatDiagnostic(current));
    }
}


// Compiles the bug-assignment example.
CompilationResult compileBugAssignmentExample() {
    return compileProgram(
        |cwd:///examples/valid/bug_assignment.gitpm|,
        |cwd:///generated/bug_assignment_bot.py|
    );
}

// Compiles the variables-and-branching example.
CompilationResult compileConditionalTriageExample() {
    return compileProgram(
        |cwd:///examples/valid/conditional_triage.gitpm|,
        |cwd:///generated/conditional_triage_bot.py|
    );
}


// Compiles the complete example.
CompilationResult compileCompleteExample() {
    return compileProgram(
        |cwd:///examples/valid/complete.gitpm|,
        |cwd:///generated/complete_bot.py|
    );
}


// Compiles the round-robin example.
CompilationResult compileRoundRobinExample() {
    return compileProgram(
        |cwd:///examples/valid/round_robin.gitpm|,
        |cwd:///generated/round_robin_bot.py|
    );
}


// Compiles the security-review example.
CompilationResult compileSecurityReviewExample() {
    return compileProgram(
        |cwd:///examples/valid/security_review.gitpm|,
        |cwd:///generated/security_review_bot.py|
    );
}


// Compiles the stale-issues example.
CompilationResult compileStaleIssuesExample() {
    return compileProgram(
        |cwd:///examples/valid/stale_issues.gitpm|,
        |cwd:///generated/stale_issues_bot.py|
    );
}


// Compiles all valid GitPM examples.
list[CompilationResult] buildAllExamples() {
    println("============================================");
    println(" BUILDING ALL VALID GITPM EXAMPLES");
    println("============================================");
    println("");

    list[CompilationResult] results = [
    compileBugAssignmentExample(),
    compileConditionalTriageExample(),
    compileCompleteExample(),
    compileRoundRobinExample(),
    compileSecurityReviewExample(),
    compileStaleIssuesExample()
    ];

    int generatedCount =
        size([
            outputFile
            | generatedFile(outputFile) <- results
        ]);

    int rejectedCount =
        size([
            diagnostics
            | rejectedProgram(diagnostics) <- results
        ]);

    println("============================================");
    println(" BUILD SUMMARY");
    println("============================================");
    println("Generated programs: <generatedCount>");
    println("Rejected programs: <rejectedCount>");

    if (rejectedCount == 0) {
        println("All valid examples were generated successfully.");
    }
    else {
        println("One or more valid examples were unexpectedly rejected.");
    }

    return results;
}


// Backwards-compatible convenience entry point.
CompilationResult compileExample() {
    return compileCompleteExample();
}