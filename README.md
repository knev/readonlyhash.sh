# unit_test_bash

A small, drop-in Bash unit-testing harness. `test.sh` parses options and defines
the helpers; the actual test cases live in one or more `unit_test/test_*.sh`
files, which `test.sh` discovers and sources automatically.

## Quick start

```
./test.sh                          # run all tests, stop at the first failure
./test.sh -v                       # verbose: show every test's output, pass or fail
./test.sh -c                       # continue past failures instead of stopping
./test.sh -l                       # list discovered test units and exit (--list-units)
./test.sh -u core                  # run only the 'core' unit (--units core)
./test.sh -u 99,core --step 42     # run units 99 then core; step from line 42
./test.sh --step core,42           # interactive step-through, from test_core.sh line 42 onward
./test.sh -h                       # help
```

`-c` and `-v` are mutually exclusive in spirit (the explicit check is currently
commented out in `test.sh`).

## Layout

```
test.sh                       # entry point: option parsing + helpers, discovers and sources units
unit_test/test_core.sh        # one test unit (any file matching test_*.sh is picked up)
unit_test/test_99-extra.sh    # optionally numbered to control run order
```

To grow the suite, drop another file under `unit_test/` whose basename starts
with `test_`. It is sourced automatically — no `source` line to add.

### Run order and unit identifiers

Each discovered file gets a **unit identifier** (and, for numbered files, an
extra **name alias**) taken from the part of its basename after `test_`:

| File                  | Number | Name        | Addressable as       |
|-----------------------|--------|-------------|----------------------|
| `test_core.sh`        | —      | `core`      | `core`               |
| `test_99-discovery.sh`| `99`   | `discovery` | `99` *or* `discovery`|
| `test_01-foo.sh`      | `01`   | `foo`       | `01` *or* `foo`      |

If the part after `test_` starts with digits followed by `-` (or just digits),
the file is **numbered** and the leading number becomes its primary identifier;
the rest after the dash becomes a name alias. Either form may be used wherever
an `ID` is expected (e.g. `--step 99,...` and `--step discovery,...` both
target `test_99-discovery.sh`). Unnumbered files have a single identifier
equal to the full stripped basename.

Run order is: numbered units first, in numeric order; then unnumbered units in
alphabetical order. Duplicate identifiers (across either column) are an error
at startup. Use `./test.sh -l` (or `--list-units`) to print the full table.

### Disabling a unit

Prefix the filename with `_` (e.g. `_test_Entroopy.sh` or
`_test_99-foo.sh`) to mark a unit as **disabled**. Disabled units still appear
in `-l` output marked `(disabled)` so you can see what's been parked, but they
are never sourced and cannot be selected by `--units` or targeted by `--step`.
Rename the file (drop the leading `_`) to re-enable.

### Selecting which units to run

`-u, --units ID[,ID...]` filters the suite to the listed units (resolved by
number or name; duplicates de-duped silently). Order in the run is always the
discovery order, regardless of how you list them on the command line:

```
./test.sh -u core             # only test_core.sh
./test.sh -u 99,core          # both, in discovery order
./test.sh -u discovery -l     # confirm the filter took effect
```

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
# Expected EXIT status [YES|no]: [<expected>]
# Expected to contain [YES|no]: "<regex>"
#----
  <captured combined stdout+stderr>
#----
```

`line no.` is the line in the test unit's source file where `run_test` was
called, which is what `--step` keys off of.

Without `-c`, the harness prints `To be continued ...` and exits `1` on the
first failure.

## Step mode

`--step [ID,]LINENO` pauses before every `run_test` whose caller line is
`>= LINENO` *and* (when `ID` is given) whose unit identifier matches `ID`. The
`ID,` prefix is required when more than one test unit will run after any
`--units` filter; when only one unit will run (either because the suite has
one unit or `--units` narrowed it to one), a bare `LINENO` is accepted.
Examples:

```
./test.sh --step core,12           # pause inside test_core.sh from line 12 onward
./test.sh --step 99,1              # pause inside test_99-discovery.sh from the first run_test
./test.sh -u core --step 12        # bare line OK once -u narrows to one unit
```

At each pause:

```
--- step [<unit>:<file>:<N>] ---
  $ <cmd>
  Expected EXIT status:[<exp>] regex:[<regex>]
[Enter]=run, c=continue without stepping, l=continue to [unit,]line, s=skip, q=quit ?
```

- `Enter` — run this test, then pause at the next one.
- `c` — run this and all remaining tests without pausing.
- `l` — prints the unit table (already-sourced units show `done` in the Status
  column, the active one shows `current`), then prompts for `[unit,]line`.
  Bare `line` keeps stepping in the current unit; `unit,line` jumps stepping
  to a unit that's still ahead in the run order (one-shot version of `c`).
  Empty input cancels and re-displays the main step prompt; targets marked
  `done` are rejected — once a unit has finished sourcing you can't return to it.
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
