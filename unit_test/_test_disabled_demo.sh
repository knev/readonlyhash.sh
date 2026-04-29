#! /bin/echo Please-source

# This file's basename starts with `_`, so unitt's discovery loop should
# never source it. If you see this line in the test output, the leading-
# underscore skip rule has regressed.
echo "ERROR: _test_disabled_demo.sh was sourced — discovery should skip leading-underscore files" >&2
