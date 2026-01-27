#!/bin/bash
# GitStat build wrapper - runs kira check and writes results

set -e

RESULTS_FILE=".build-results.json"
ERRORS=0
WARNINGS=0
MESSAGES=()

# Check all Kira source files
for file in src/*.ki; do
    if ! output=$(kira check "$file" 2>&1); then
        ERRORS=$((ERRORS + 1))
        MESSAGES+=("$file: $output")
    fi
done

# Write results
if [ $ERRORS -eq 0 ]; then
    echo "{\"success\": true, \"errors\": 0, \"warnings\": $WARNINGS, \"messages\": []}" > "$RESULTS_FILE"
    echo "Build OK: All files passed type checking"
else
    # Build JSON array of messages
    MSGS_JSON="["
    for i in "${!MESSAGES[@]}"; do
        if [ $i -gt 0 ]; then MSGS_JSON+=","; fi
        # Escape quotes in message
        escaped=$(echo "${MESSAGES[$i]}" | sed 's/"/\\"/g' | tr '\n' ' ')
        MSGS_JSON+="\"$escaped\""
    done
    MSGS_JSON+="]"

    echo "{\"success\": false, \"errors\": $ERRORS, \"warnings\": $WARNINGS, \"messages\": $MSGS_JSON}" > "$RESULTS_FILE"
    echo "Build FAILED: $ERRORS error(s)"
    exit 1
fi
