#!/bin/bash
# GitStat test wrapper - runs Lisp examples and writes results

RESULTS_FILE=".test-results.json"
PASSED=0
FAILED=0
FAILURES=()

# Helper to extract result from REPL output (gets last non-empty result before final prompt)
get_result() {
    grep "^lisp>" | tail -2 | head -1 | sed 's/^lisp> //'
}

# Test: Run factorial example
test_factorial() {
    local output
    output=$(echo "(define (factorial n) (if (<= n 1) 1 (* n (factorial (- n 1))))) (factorial 5)" | kira run src/main.ki 2>&1 | get_result)
    if [[ "$output" == "120" ]]; then
        PASSED=$((PASSED + 1))
        echo "PASS: factorial"
    else
        FAILED=$((FAILED + 1))
        FAILURES+=("factorial: expected 120, got $output")
        echo "FAIL: factorial"
    fi
}

# Test: Basic arithmetic
test_arithmetic() {
    local output
    output=$(echo "(+ 1 2 3 4 5)" | kira run src/main.ki 2>&1 | get_result)
    if [[ "$output" == "15" ]]; then
        PASSED=$((PASSED + 1))
        echo "PASS: arithmetic"
    else
        FAILED=$((FAILED + 1))
        FAILURES+=("arithmetic: expected 15, got $output")
        echo "FAIL: arithmetic"
    fi
}

# Test: List operations
test_lists() {
    local output
    output=$(echo "(car (list 1 2 3))" | kira run src/main.ki 2>&1 | get_result)
    if [[ "$output" == "1" ]]; then
        PASSED=$((PASSED + 1))
        echo "PASS: lists"
    else
        FAILED=$((FAILED + 1))
        FAILURES+=("lists: expected 1, got $output")
        echo "FAIL: lists"
    fi
}

# Test: Lambda and higher-order functions
test_lambda() {
    local output
    output=$(echo "(define (apply-twice f x) (f (f x))) (define (double n) (* n 2)) (apply-twice double 3)" | kira run src/main.ki 2>&1 | get_result)
    if [[ "$output" == "12" ]]; then
        PASSED=$((PASSED + 1))
        echo "PASS: lambda"
    else
        FAILED=$((FAILED + 1))
        FAILURES+=("lambda: expected 12, got $output")
        echo "FAIL: lambda"
    fi
}

# Test: Compile and run
test_compile() {
    local output
    echo "(display (+ 10 20)) (newline)" > /tmp/test_compile.lisp
    kira run src/main.ki compile /tmp/test_compile.lisp > /dev/null 2>&1
    output=$(kira run /tmp/test_compile.ki 2>&1)
    rm -f /tmp/test_compile.lisp /tmp/test_compile.ki
    if [[ "$output" == *"30"* ]]; then
        PASSED=$((PASSED + 1))
        echo "PASS: compile"
    else
        FAILED=$((FAILED + 1))
        FAILURES+=("compile: expected 30, got $output")
        echo "FAIL: compile"
    fi
}

echo "Running tests..."
echo

test_factorial
test_arithmetic
test_lists
test_lambda
test_compile

TOTAL=$((PASSED + FAILED))

echo
echo "Results: $PASSED/$TOTAL passed"

# Build failures JSON array
FAILURES_JSON="["
for i in "${!FAILURES[@]}"; do
    if [ $i -gt 0 ]; then FAILURES_JSON+=","; fi
    escaped=$(echo "${FAILURES[$i]}" | sed 's/"/\\"/g')
    FAILURES_JSON+="\"$escaped\""
done
FAILURES_JSON+="]"

echo "{\"passed\": $PASSED, \"failed\": $FAILED, \"total\": $TOTAL, \"failures\": $FAILURES_JSON}" > "$RESULTS_FILE"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
