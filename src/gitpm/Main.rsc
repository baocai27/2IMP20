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


list[loc] invalidExampleFiles() {
    return [
        |cwd:///examples/invalid/branch_local_variable.gitpm|,
        |cwd:///examples/invalid/duplicate_label.gitpm|,
        |cwd:///examples/invalid/duplicate_member.gitpm|,
        |cwd:///examples/invalid/duplicate_rule.gitpm|,
        |cwd:///examples/invalid/duplicate_variable.gitpm|,
        |cwd:///examples/invalid/empty_rule.gitpm|,
        |cwd:///examples/invalid/expression_type_mismatch.gitpm|,
        |cwd:///examples/invalid/invalid_inactive_days.gitpm|,
        |cwd:///examples/invalid/invalid_missing_board.gitpm|,
        |cwd:///examples/invalid/invalid_multiple_boards.gitpm|,
        |cwd:///examples/invalid/invalid_workload.gitpm|,
        |cwd:///examples/invalid/issue_with_pr_condition.gitpm|,
        |cwd:///examples/invalid/missing_developer.gitpm|,
        |cwd:///examples/invalid/missing_repository.gitpm|,
        |cwd:///examples/invalid/missing_reviewer.gitpm|,
        |cwd:///examples/invalid/non_boolean_if_condition.gitpm|,
        |cwd:///examples/invalid/pr_with_issue_action.gitpm|,
        |cwd:///examples/invalid/undefined_column.gitpm|,
        |cwd:///examples/invalid/undefined_label.gitpm|,
        |cwd:///examples/invalid/undefined_member.gitpm|,
        |cwd:///examples/invalid/undefined_milestone.gitpm|,
        |cwd:///examples/invalid/undefined_variable.gitpm|
    ];
}


bool validateAllInvalidExamples() {
    println("============================================");
    println(" VALIDATING ALL INVALID GITPM EXAMPLES");
    println("============================================");
    println("");

    int rejectedCount = 0;
    int acceptedCount = 0;

    for (loc sourceFile <- invalidExampleFiles()) {
        list[Diagnostic] diagnostics = validateFile(sourceFile);

        if (hasErrors(diagnostics)) {
            rejectedCount = rejectedCount + 1;
            println("SUCCESS: <sourceFile> was rejected.");
        }
        else {
            acceptedCount = acceptedCount + 1;
            println("FAILURE: <sourceFile> was accepted unexpectedly.");
        }
    }

    int totalCount = size(invalidExampleFiles());

    println("");
    println("============================================");
    println(" INVALID EXAMPLE SUMMARY");
    println("============================================");
    println("Expected invalid programs: <totalCount>");
    println("Rejected programs: <rejectedCount>");
    println("Incorrectly accepted programs: <acceptedCount>");

    if (acceptedCount == 0) {
        println("All invalid examples were rejected successfully.");
    }
    else {
        println("One or more invalid examples were accepted unexpectedly.");
    }

    return acceptedCount == 0;
}


// Backwards-compatible convenience entry point.
CompilationResult compileExample() {
    return compileCompleteExample();
}