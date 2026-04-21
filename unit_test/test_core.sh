#! /bin/echo Please-source

echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: core.sh"

# Parse command line options
echo
echo "# Parse command line options"

run_test "$FPATH_BIN wsweep --qewrere" "1" "$(escape_expected "ERROR: invalid command [wsweep]")"

run_test "ls -alR $TEST" "1" "$TEST.?: No such file or directory"
