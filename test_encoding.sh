#!/usr/bin/env bash
# Test Suite for UTF-8 BOM Detection and CRLF Normalization

echo "============================================================"
echo "UTF-8 BOM DETECTION / CRLF NORMALIZATION TEST SUITE"
echo "============================================================"

PASS=0
FAIL=0

log_result() {
    local name="$1"
    local passed="$2"
    local details="$3"
    
    if [[ "$passed" == "true" ]]; then
        echo "PASS: $name"
        ((PASS++))
    else
        echo "FAIL: $name"
        [[ -n "$details" ]] && echo "       $details"
        ((FAIL++))
    fi
}

# Create temp directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "[SETUP] Test directory: $TEST_DIR"
echo ""

# Test 1: Check encoding.sh exists and has required functions
echo "--- Test 1: Code Existence ---"
if [[ -f /workspace/src/encoding.sh ]]; then
    content=$(cat /workspace/src/encoding.sh)
    
    checks=("detect_bom" "remove_bom" "detect_line_endings" "normalize_line_endings" "UTF8_BOM" "crlf" "normalize_encoding")
    missing=()
    
    for check in "${checks[@]}"; do
        if ! echo "$content" | grep -q "$check"; then
            missing+=("$check")
        fi
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        log_result "Encoding code exists" "true" "All components found"
    else
        log_result "Encoding code exists" "false" "Missing: ${missing[*]}"
    fi
else
    log_result "Encoding code exists" "false" "encoding.sh not found"
fi

# Test 2: BOM Detection
echo ""
echo "--- Test 2: BOM Detection ---"
BOM_FILE="$TEST_DIR/bom_test.txt"
printf '\xef\xbb\xbfHello with BOM' > "$BOM_FILE"

source /workspace/src/encoding.sh
bom_result=$(detect_bom "$BOM_FILE")

if [[ "$bom_result" == "utf-8-bom" ]]; then
    log_result "BOM detection" "true" "Detected utf-8-bom"
else
    log_result "BOM detection" "false" "Got: $bom_result"
fi

# Test 3: BOM Removal from file
echo ""
echo "--- Test 3: BOM Removal ---"
BOM_FILE2="$TEST_DIR/bom_test2.txt"
printf '\xef\xbb\xbfHello with BOM to remove' > "$BOM_FILE2"

remove_bom "$BOM_FILE2" 2>/dev/null
first_bytes=$(head -c 3 "$BOM_FILE2" | od -An -tx1 | tr -d ' \n')

if [[ "$first_bytes" != "efbbbf" ]]; then
    content_after=$(cat "$BOM_FILE2")
    if [[ "$content_after" == "Hello with BOM to remove" ]]; then
        log_result "BOM removal from file" "true" "BOM removed, content intact"
    else
        log_result "BOM removal from file" "false" "Content changed: $content_after"
    fi
else
    log_result "BOM removal from file" "false" "BOM still present"
fi

# Test 4: CRLF Detection
echo ""
echo "--- Test 4: CRLF Detection ---"
CRLF_FILE="$TEST_DIR/crlf_test.txt"
printf 'Line1\r\nLine2\r\nLine3' > "$CRLF_FILE"

line_type=$(detect_line_endings "$CRLF_FILE")

if [[ "$line_type" == "crlf" ]]; then
    log_result "CRLF detection" "true" "Detected crlf"
else
    log_result "CRLF detection" "false" "Got: $line_type"
fi

# Test 5: Line Ending Normalization
echo ""
echo "--- Test 5: Line Ending Normalization ---"
CRLF_FILE2="$TEST_DIR/crlf_test2.txt"
printf 'Line1\r\nLine2\r\nLine3' > "$CRLF_FILE2"

normalize_line_endings "$CRLF_FILE2" 2>/dev/null

# Check if CRLF converted to LF
if grep -q $'\r' "$CRLF_FILE2" 2>/dev/null; then
    log_result "Line ending normalization" "false" "CR characters still present"
else
    # Verify content is correct
    line_count=$(wc -l < "$CRLF_FILE2")
    if [[ "$line_count" -ge 2 ]]; then
        log_result "Line ending normalization" "true" "CRLF converted to LF"
    else
        log_result "Line ending normalization" "false" "Unexpected line count: $line_count"
    fi
fi

# Test 6: String BOM Removal
echo ""
echo "--- Test 6: String BOM Removal ---"
test_str=$'\xef\xbb\xbfHello'
result=$(remove_bom_from_string "$test_str")

if [[ "$result" == "Hello" ]]; then
    log_result "String BOM removal" "true" "BOM removed from string"
else
    log_result "String BOM removal" "false" "Got: $(echo "$result" | od -c | head -1)"
fi

# Test 7: String Line Ending Normalization
echo ""
echo "--- Test 7: String Line Ending Normalization ---"
test_str="Line1"$'\r\n'"Line2"$'\r'"Line3"
result=$(normalize_line_endings_string "$test_str")

# Should have no CR characters
if ! echo "$result" | grep -q $'\r'; then
    log_result "String line ending normalization" "true" "All CR removed"
else
    log_result "String line ending normalization" "false" "CR still present"
fi

# Test 8: Full Encoding Normalization
echo ""
echo "--- Test 8: Full Encoding Normalization ---"
FULL_FILE="$TEST_DIR/full_test.txt"
printf '\xef\xbb\xbfLine1\r\nLine2\r\nLine3' > "$FULL_FILE"

normalize_encoding "$FULL_FILE" 2>/dev/null

# Check both BOM and CRLF are gone
first_bytes=$(head -c 3 "$FULL_FILE" | od -An -tx1 | tr -d ' \n')
has_cr=$(grep -c $'\r' "$FULL_FILE" 2>/dev/null || echo "0")

if [[ "$first_bytes" != "efbbbf" && "$has_cr" -eq 0 ]]; then
    log_result "Full encoding normalization" "true" "BOM and CRLF removed"
else
    details=""
    [[ "$first_bytes" == "efbbbf" ]] && details+="BOM present. "
    [[ "$has_cr" -gt 0 ]] && details+="CR present."
    log_result "Full encoding normalization" "false" "$details"
fi

# Test 9: UTF-8 Validation
echo ""
echo "--- Test 9: UTF-8 Validation ---"
VALID_FILE="$TEST_DIR/valid_utf8.txt"
echo "Valid UTF-8 content" > "$VALID_FILE"

validation_result=$(validate_utf8 "$VALID_FILE")

if [[ "$validation_result" == "valid" ]]; then
    log_result "UTF-8 validation" "true" "Correctly identified valid UTF-8"
else
    log_result "UTF-8 validation" "false" "Got: $validation_result"
fi

# Summary
echo ""
echo "============================================================"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "============================================================"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
