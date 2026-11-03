#!/bin/bash

# CIS 341 - Person E
# Automated QA Testing Suite

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

passed=0
failed=0

check_test() {
    local actual="$1"
    local expected="$2"
    local description="$3"

    if [ "$actual" -eq "$expected" ]; then
        echo "PASS: $description"
        passed=$((passed + 1))
    else
        echo "FAIL: $description (expected $expected, got $actual)"
        failed=$((failed + 1))
    fi
}

echo "=== CIS 341 - Person E Test Suite ==="

# Test 1: No arguments
bash "$ROOT/sysaudit.sh" >/dev/null 2>&1
check_test "$?" 0 "No arguments"

# Test 2: Help option
bash "$ROOT/sysaudit.sh" --help >/dev/null 2>&1
check_test "$?" 0 "Help option"

# Test 3: Invalid argument
bash "$ROOT/sysaudit.sh" --invalid >/dev/null 2>&1
check_test "$?" 1 "Invalid argument"


echo "--- Configuration Tests ---"

# Test 4: Missing configuration file
bash -c '
    source "$1/sysaudit_logger.sh"
    load_config "/tmp/cis341_nonexistent_config_12345.cfg"
' _ "$ROOT" >/dev/null 2>&1

check_test "$?" 3 "Missing configuration returns exit code 3"

# Test 5: Valid configuration
TEMP_CFG=$(mktemp)
printf 'LOG_LEVEL=INFO\nMAX_DISK_USAGE=100\n' > "$TEMP_CFG"

bash -c '
    source "$1/sysaudit_logger.sh"
    load_config "$2"
' _ "$ROOT" "$TEMP_CFG" >/dev/null 2>&1

check_test "$?" 0 "Valid configuration loads successfully"

# Test 6: Malformed configuration
printf 'THIS LINE IS INVALID\n' > "$TEMP_CFG"

bash -c '
    source "$1/sysaudit_logger.sh"
    load_config "$2"
' _ "$ROOT" "$TEMP_CFG" >/dev/null 2>&1

check_test "$?" 7 "Malformed configuration returns exit code 7"

rm -f "$TEMP_CFG"


echo "--- Workspace Validation Tests ---"

# Test 7: Missing audit workspace
# Use a temporary directory so team files remain untouched.

TEST_DIR=$(mktemp -d)
MISSING_DIR="$TEST_DIR/nonexistent_audit"

bash -c '
    source "$1/sysaudit_logger.sh"
    source "$1/sysaudit_ceiling.sh"

    AUDIT_DIR="$2"
    MAX_DISK_USAGE=100
    LOG_FILE="$3"
    LOG_LEVEL=INFO

    check_disk_ceiling
' _ "$ROOT" "$MISSING_DIR" "$TEST_DIR/test.log" >/dev/null 2>&1

check_test "$?" 4 "Invalid workspace returns exit code 4"

rm -rf -- "$TEST_DIR"


echo "--- Disk Storage Validation Tests ---"

DISK_TEST_DIR=$(mktemp -d)
mkdir -p "$DISK_TEST_DIR/audit"

# Create a 2 MB test file inside the temporary audit folder
head -c 2097152 /dev/zero > "$DISK_TEST_DIR/audit/sample.audit"

# Helper to run the real disk-checking function
run_disk_test() {
    local limit="$1"

    bash -c '
        source "$1/sysaudit_logger.sh"
        source "$1/sysaudit_ceiling.sh"

        AUDIT_DIR="$2"
        MAX_DISK_USAGE="$3"
        LOG_FILE="$4"
        LOG_LEVEL=INFO

        check_disk_ceiling
    ' _ "$ROOT" "$DISK_TEST_DIR/audit" "$limit" \
        "$DISK_TEST_DIR/test.log" >/dev/null 2>&1
}

# Test 8: Disk usage below the configured limit
run_disk_test 100
check_test "$?" 0 "Disk usage below limit"

# Test 9: Disk usage exceeds the configured limit
run_disk_test 1
check_test "$?" 5 "Disk over-allocation returns exit code 5"

# Test 10: Verify warning was actually logged
if grep -q '\[WARNING\].*Disk ceiling reached' \
    "$DISK_TEST_DIR/test.log"; then
    check_test 0 0 "Disk warning recorded in log"
else
    check_test 1 0 "Disk warning recorded in log"
fi

# Test 11: Invalid disk limit
run_disk_test invalid
check_test "$?" 7 "Invalid disk limit returns exit code 7"

rm -rf -- "$DISK_TEST_DIR"


echo "--- Security Permission Tests ---"

# Test 12: Verify unprivileged user is denied access

SECURITY_DIR="/tmp/cis341-security-test"

if [ "$(id -un)" = "root" ]; then
    echo "SKIP: Run security test as an ordinary user"
elif [ ! -d "$SECURITY_DIR" ]; then
    echo "SKIP: Security test directory is missing"
else
    ls "$SECURITY_DIR" >/dev/null 2>&1
    access_code=$?

    if [ "$access_code" -ne 0 ]; then
        check_test 0 0 "Unprivileged user access denied"
    else
        check_test 1 0 "Unprivileged user access denied"
    fi
fi

echo "=============================="
echo "Passed: $passed"
echo "Failed: $failed"

if [ "$failed" -gt 0 ]; then
    exit 1
fi

exit 0
