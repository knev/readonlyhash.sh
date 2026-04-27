# unit_test_bash

A small, drop-in Bash unit-testing harness. `test.sh` parses options and defines
the helpers; the actual test cases live in `unit_test/test_core.sh`, which is
sourced at the bottom of `test.sh`.

## Quick start

```
./test.sh                          # run all tests, stop at the first failure
./test.sh -v                       # verbose: show every test's output, pass or fail
./test.sh -c                       # continue past failures instead of stopping
./test.sh --step-test=42           # interactive step-through from line 42 onward
./test.sh -h                       # help
```

`-c` and `-v` are mutually exclusive in spirit (the explicit check is currently
commented out in `test.sh`).

## Layout

```
test.sh                 # entry point: option parsing + helpers, sources the suite
unit_test/test_core.sh  # the actual test cases (add more files and source them)
```

To grow the suite, drop another file under `unit_test/` and `source` it from
`test.sh` next to the existing `source "unit_test/test_core.sh"` line.

## Writing a test

Tests are calls to `run_test`:

```bash
run_test "<command>" "<expected_exit>" "<expected_regex>" [not_flag]
```

| Arg               | Meaning                                                                 |
|-------------------|-------------------------------------------------------------------------|
| `command`         | Shell command to run. Evaluated via `eval`, so quoting matters.         |
| `expected_exit`   | `0` for success, anything else for failure. Matched loosely: 0-vs-0 or non-zero-vs-non-zero is a match (the exact non-zero code is not compared). |
| `expected_regex`  | Bash `[[ =~ ]]` regex matched against combined stdout+stderr.           |
| `not_flag`        | Optional. `true` inverts the regex check (output must **not** match).   |

### Escaping regex metacharacters

Because the third argument is a real Bash regex, characters like `[ ] ( ) ? ! |`
must be escaped. Wrap literal patterns in `escape_expected` so you can write
them naturally:

```bash
run_test "$FPATH_BIN wsweep --qewrere" "1" "$(escape_expected "ERROR: invalid command [wsweep]")"
```

Note: this means you cannot use `[]` or `()` as regex grouping inside a pattern
that you also pass through `escape_expected` — the helper escapes those
literally. Use `.*` and friends for wildcards instead.

### Example

From `unit_test/test_core.sh`:

```bash
run_test "$FPATH_BIN wsweep --qewrere" "1" "$(escape_expected "ERROR: invalid command [wsweep]")"
run_test "ls -alR $TEST" "1" "$TEST.?: No such file or directory"
```

The first asserts a non-zero exit and a literal error string. The second uses a
raw regex (`.?` after `$TEST`) and expects a non-zero exit from `ls`.

## Output

On pass (default mode):

```
PASS: [<cmd>][<exit>] "<regex>", line no. [<N>]
```

On fail (or always, in `-v` mode):

```
# FAIL: [<exit>][<cmd>], line no. [<N>]
# Expected EXIT status: [<expected>]
# Expected to contain [no]: "<regex>"
#----
  <captured combined stdout+stderr>
#----
```

`line no.` is the line in `unit_test/test_core.sh` where `run_test` was called,
which is what `--step-test` keys off of.

Without `-c`, the harness prints `To be continued ...` and exits `1` on the
first failure.

## Step mode

`--step-test=<LINENO>` pauses before every `run_test` whose caller line in
`unit_test/test_core.sh` is `>= LINENO`. At each pause:

```
--- step [test_core.sh:<N>] ---
  $ <cmd>
  Expected EXIT status:[<exp>] regex:[<regex>]
[ENTER]=run, [c]ontinue/to [l]ine, [s]kip, [q]uit ?
```

- `Enter` — run this test, then pause at the next one.
- `c` — run this and all remaining tests without pausing.
- `l` — prompt for a line number `N`, then run this test and resume pausing
  once the caller line is `>= N` (one-shot version of `c`).
- `s` — skip this test (counts as a pass-through, not a failure).
- `q` — quit immediately.

Keystrokes are read from `/dev/tty`, so tests that pipe into stdin still work.

## How `run_test` captures output

The combined stdout+stderr **and** exit status are captured in one shot via a
file-descriptor trick:

```bash
full_output=$( { eval "$cmd" 2>&1; echo $? >&3; } 3>&1 | cat )
exit_status=${full_output##*$'\n'}
output=${full_output%$'\n'*}
```

The exit status is appended after a newline, then split off. This is the only
reliable way in pure Bash to get both at once from a single subshell.
