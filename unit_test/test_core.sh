#! /bin/echo Please-source

echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: core.sh -- exercises test.sh itself"

# Each test here invokes ./test.sh with flags that cause it to exit before
# sourcing this file, so we don't recurse into the suite.

echo
echo "# --help / -h"

run_test "./test.sh -h" "0" "Usage: test\.sh"
run_test "./test.sh --help" "0" "Usage: test\.sh"
run_test "./test.sh -h" "0" "$(escape_expected "[Enter]=run, c=continue without stepping, l=continue to [unit,]line, s=skip, q=quit")"
run_test "./test.sh -h" "0" "$(escape_expected "ERROR:")" "true"

echo
echo "# invalid options"

run_test "./test.sh -z" "1" "illegal option -- z"
run_test "./test.sh --bogus" "1" "Invalid option: --bogus"

echo
echo "# --step validation"

run_test "./test.sh --step" "1" "step: missing value"
run_test "./test.sh --step abc" "1" "step: expected numeric line number, got .abc."
run_test "./test.sh --step -3" "1" "step: expected numeric line number"
run_test "./test.sh --step ,5" "1" "step: expected ID,LINE"
run_test "./test.sh --step foo," "1" "step: expected ID,LINE"
run_test "./test.sh --step foo,abc" "1" "step: expected numeric line number, got .abc."
# Discovered units include test_core.sh and test_99-discovery.sh, so a bare
# LINE is rejected with the multi-unit error.
run_test "./test.sh --step 12" "1" "multiple test units present"
run_test "./test.sh --step nope,1" "1" "step: unknown test unit .nope."

echo
echo "# --list-units / -l (also exercises the number/name alias)"

# Numbered files are addressable by both their number and their name —
# test_99-discovery.sh appears as "99 / discovery". Unnumbered files have a
# single token (e.g. "core").
run_test "./test.sh --list-units" "0" "unit:.99./.discovery."
run_test "./test.sh --list-units" "0" "unit:.core. +unit_test/.test_core\\.sh."
run_test "./test.sh -l" "0" "unit:.99./.discovery."

echo
echo "# --units / -u filtering"

run_test "./test.sh -u nope" "1" "units: unknown test unit .nope."
run_test "./test.sh --units" "1" "units: missing value"
run_test "./test.sh -u 'core,,'" "1" "units: empty entry"
# -l respects the filter; only the selected unit shows up.
run_test "./test.sh -u core -l" "0" "unit:.core."
run_test "./test.sh -u core -l" "0" "unit:.99./.discovery." "true"
# Name-alias resolution applies to --units too.
run_test "./test.sh -u discovery -l" "0" "unit:.99./.discovery."

echo
echo "# escape_expected helper"

# escape_expected must turn regex-meaningful characters into literals so that
# the resulting string can be matched against output as plain text.
run_test "escape_expected 'a[b]c'" "0" 'a\\\[b\\\]c'
run_test "escape_expected '(x|y)?'" "0" '\\\(x\\\|y\\\)\\\?'

echo
echo "# status_matches helper"

# 0 vs 0 matches, non-zero vs non-zero matches (any non-zero), 0 vs non-zero does not.
run_test "status_matches 0 0 && echo same"   "0" "^same$"
run_test "status_matches 1 2 && echo same"   "0" "^same$"
run_test "status_matches 0 1 || echo differ" "0" "^differ$"
run_test "status_matches 5 0 || echo differ" "0" "^differ$"

echo
echo "# run_test verbose-mode labeling (regression: '-v' used to print PASS for failures)"

# In verbose mode, run_test falls through to a shared labeling block whether
# the assertion passed or failed. Before the fix it keyed off verbose_mode
# itself, so any failure under -v was mislabelled "# PASS:". These tests
# drive ./test.sh -v with a tiny custom core file (UNIT_TEST_CORE) so we can
# trigger each outcome without contaminating this main suite.

vt_dir=$(mktemp -d)
trap "rm -rf '$vt_dir'" EXIT

echo 'run_test "echo hello" "0" "^hello$"'   > "$vt_dir/pass.sh"
echo 'run_test "echo hello" "0" "^goodbye$"' > "$vt_dir/fail_regex.sh"
echo 'run_test "echo hello" "1" "^hello$"'   > "$vt_dir/fail_status.sh"

run_test "UNIT_TEST_CORE='$vt_dir/pass.sh' ./test.sh -v" \
    "0" "$(escape_expected '# PASS: [echo hello][0]')"

run_test "UNIT_TEST_CORE='$vt_dir/fail_regex.sh' ./test.sh -v -c" \
    "0" "$(escape_expected '# FAIL: [echo hello][0]')"

run_test "UNIT_TEST_CORE='$vt_dir/fail_status.sh' ./test.sh -v -c" \
    "0" "$(escape_expected '# FAIL: [echo hello][0]')"
