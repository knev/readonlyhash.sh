#!/bin/bash

VERSION="2.2.26"

FPATH_BIN="roh.fpath"
GIT_BIN="roh.git"
HASH="sha256"

# --debug: run against the local source copies (./roh.fpath.sh, ./roh.git.sh)
# instead of the PATH-installed versions. Used by the unit tests so they
# always exercise the working tree without needing to install first.
debug_mode="false"
new_args=()
for a in "$@"; do
    case "$a" in
        --debug) debug_mode="true" ;;
        *)       new_args+=("$a") ;;
    esac
done
set -- "${new_args[@]}"

if [ "$debug_mode" = "true" ]; then
    FPATH_BIN="./roh.fpath.sh"
    GIT_BIN="./roh.git.sh"
fi

usage() {
    echo "Usage:" 
	echo "      $(basename "$0") <C|COMMAND> [OPTIONS|--resume-at STRING] < <FN.roh.txt>"
	echo 
    echo "Commands:"
	echo "      v|verify     Verify files and make sure git repo is clean"
	echo "      i|index      Index (alone, or while verifying)"
	echo "                   verify/index work on an archived ROH_DIR too, by unpacking it to a temp dir"
	echo "      a|archive    Archive ROH_DIR and remove an existing index file"
	echo "      x|extract    Extract _.roh.git.zip as ROH_DIR"
	echo 
    echo "Options:"
	echo "      --resume-at <STRING>    Resume on directory with STRING as suffix"
	echo "      --debug                 Use local ./roh.fpath.sh and ./roh.git.sh instead of installed bins"
    echo "      --version               Display the version and exit"
    echo "  -h, --help                  Display this help and exit"
	echo 
	echo "while;do:"
	echo "      while IFS= read -r line; do echo \"\$line\"; done < FILENAME.roh.txt"
    echo
}

# check_pre_reqs <cmd>...
# Abort with a clear message listing every required external tool that is
# missing. command -v is a shell builtin, so this works even on environments
# where `which` itself isn't installed (e.g. some Git-Bash setups).
check_pre_reqs() {
    local req missing=()
    for req in "$@"; do
        command -v "$req" >/dev/null 2>&1 || missing+=("$req")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: $(basename "$0") requires missing tool(s): ${missing[*]}" >&2
        echo "Abort." >&2
        echo >&2
        exit 1
    fi
}

# --install: self-install the readonlyhash suite (this orchestrator + its three
# worker scripts) into the user's bin. This is the single, authoritative source
# of truth for installation (no Makefile). Run it from the source tree, e.g.
# `./readonlyhash.sh --install`; the worker .sh files must sit alongside it.
install_self() {
    local uname_s self dir src_dir bin_dir name src
    uname_s="$(uname -s)"

    # Resolve this script's own absolute directory (following any symlinks).
    self="${BASH_SOURCE[0]}"
    while [ -h "$self" ]; do
        dir="$(cd -P "$(dirname "$self")" && pwd)"
        self="$(readlink "$self")"
        [[ "$self" != /* ]] && self="$dir/$self"
    done
    src_dir="$(cd -P "$(dirname "$self")" && pwd)"

    # Resolve the install root as a POSIX path. On Windows %USERPROFILE% is the
    # stable Windows home in both Git Bash and the MSYS2 shell (unlike $HOME,
    # which differs between them); cygpath converts it to a POSIX path.
    case "$uname_s" in
        MINGW*|MSYS*|CYGWIN* )
            if [ -z "$USERPROFILE" ]; then
                echo "ERROR: %USERPROFILE% is empty; cannot resolve the install dir (run from Git Bash, or the MSYS2 shell)." >&2
                return 1
            fi
            bin_dir="$(cygpath -u "$USERPROFILE")/bin"
            ;;
        * )
            bin_dir="$HOME/bin"
            ;;
    esac

    mkdir -p "$bin_dir" || return 1

    # The suite: orchestrator + workers. Each <name>.sh installs as <name>.
    for name in readonlyhash roh.fpath roh.git roh.copy; do
        src="$src_dir/$name.sh"
        if [ ! -f "$src" ]; then
            echo "ERROR: missing source script [$src] -- run --install-self from the source tree." >&2
            return 1
        fi
        if [ "$src" -ef "$bin_dir/$name" ]; then
            echo "Already in place: $bin_dir/$name (skipping copy)"
        else
            cp -v "$src" "$bin_dir/$name" || return 1
            chmod +x "$bin_dir/$name"
        fi

        # Windows: write a .cmd shim so cmd.exe/PowerShell can run the
        # extensionless bash script. The path is a printf %s *argument* (not the
        # format string) so no backslash is interpreted as an escape.
        case "$uname_s" in
            MINGW*|MSYS*|CYGWIN* )
                printf '%s\r\n' '@echo off' "\"C:\\Program Files\\Git\\bin\\bash.exe\" \"%~dp0$name\" %*" > "$bin_dir/$name.cmd"
                echo "created $bin_dir/$name.cmd"
                ;;
        esac
    done

    echo "Installed suite into: $bin_dir"
    return 0
}

# Handle --install-self before the command parser and the roh.fpath/roh.git
# prereq check below, since at install time those workers may not be on PATH yet.
for a in "$@"; do
    if [ "$a" = "--install-self" ]; then
        install_self
        exit $?
    fi
done

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

# ----

# Compatible with bash 3.2+ (macOS default) and bash 4+

# List of valid full commands
valid_long="verify index archive extract"

# Short to long mapping (using case statement instead of assoc array)
get_long() {
    case "$1" in
        v) echo "verify" ;;
		i) echo "index" ;;
        a) echo "archive" ;;
        x) echo "extract" ;;
        *) echo "" ;;  # empty = invalid
    esac
}

commands=()  # normal array is fine even in 3.2

contains() {
    local needle="$1"
    local item
    for item in "${commands[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

i=1
while [ $i -le $# ]; do
    arg="${!i}"

    # Stop on any switch-like argument
    case "$arg" in
        -*) break ;;
    esac

    # 1. Try full word match (word-boundary lookup without a grep spawn)
    if [[ " $valid_long " == *" $arg "* ]]; then
        commands+=("$arg")
        i=$((i+1))
        continue
    fi

    # 2. Try short letters (consecutive, no separators)
    if [[ "$arg" =~ ^[viax]+$ ]]; then
        invalid=0
        for ((j=0; j<${#arg}; j++)); do
            c="${arg:$j:1}"
            long=$(get_long "$c")
            if [ -n "$long" ]; then
                commands+=("$long")
            else
                echo "ERROR: unknown short operation '$c' in '$arg'" >&2
                invalid=1
                break
            fi
        done
        if [ $invalid -eq 0 ]; then
            i=$((i+1))
            continue
        fi
    fi

	if [ ${#commands[@]} -eq 0 ]; then
		# If we get here → error
		echo "ERROR: invalid command [$arg]" >&2
		# echo "Allowed full: verify write index delete hide show query recover sweep" >&2
		# echo "     short:  v      w     i      d      h    s    q     r      e" >&2
		# echo "Shorts can be concatenated like: vwidhsqre" >&2
		usage
		exit 1
	fi
	break
done
# echo "Parsed commands (${#commands[@]}):"
# for cmd in "${commands[@]}"; do
#     echo "  - $cmd"
# done

# Reset positional parameters to remaining arguments only
shift $((i-1))   # now $1 is the first -something argument

# verify and index may be combined; archive and extract must stand alone.
# Anything else would be silently dropped by the dispatcher, so reject it here.
# (Pure bash: no sort/tr, so it behaves the same on macOS, Linux and Git Bash.)
for c in "${commands[@]}"; do
	case "$c" in
		archive|extract)
			if [ ${#commands[@]} -ne 1 ]; then
				echo "ERROR: [$c] cannot be combined with other commands: [${commands[*]}]" >&2
				usage
				exit 1
			fi
			;;
	esac
done

# This script orchestrates the two worker scripts, so its only direct prereqs
# are that they resolve (on PATH normally, or ./roh.*.sh under --debug). Each
# worker self-checks its own external tools (openssl/sqlite3/xxd for roh.fpath;
# git/zip/unzip/tar/openssl for roh.git), so we don't restate those here.
check_pre_reqs "$FPATH_BIN" "$GIT_BIN"

# -----

skipping_mode="false"
resume_string=""

while getopts "h-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
	    resume-at)
          if [[ $# -lt 2 ]]; then
            echo "Error: --resume-at requires a value" >&2
            exit 1
          fi
		  skipping_mode="true"
          resume_string="$2"
          shift 2
          ;;
	    version)
	      echo "$(basename "$0") version: v$VERSION"
		  echo
	      exit 0
	      ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "ERROR: invalid option [--${OPTARG}]" >&2
          usage
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "ERROR: invalid option [-${OPTARG}]" >&2
      usage
      exit 1
      ;;
    :)
      echo "ERROR: option [-$OPTARG] requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done

# capture all remaining arguments after the options have been processed
shift $((OPTIND-1))

# ----

# Enforce stdin redirection. Fail when:
#   - stdin is a TTY (no redirection at all), or
#   - stdin is neither a pipe nor a regular file (e.g. `< /dev/null`), or
#   - stdin is a regular file but it is empty.
# We cannot reliably detect "open pipe with no data yet" without blocking,
# so that case still slips through and is the caller's responsibility.
if [[ -t 0 ]] \
   || { [[ ! -p /dev/stdin ]] && [[ ! -f /dev/stdin ]]; } \
   || { [[ -f /dev/stdin ]] && [[ ! -s /dev/stdin ]]; }; then
    echo "ERROR: missing input redirection of '.roh.txt' file"
	echo "Abort."
	echo
	exit 1
fi

#------------------------------------------------------------------------------------------------------------------------------------------
# captured output : NO spurious echo/printf outputs!

ROH_DIR_NAME=".roh.git"
ARCHIVE_NAME="_${ROH_DIR_NAME}.zip"

# Temp dir holding a ROH_DIR unpacked from an archive (see unpack_archive_to_tmp).
# Cleaned up on every exit path so a failing verify never leaves it behind.
TMP_ROH_ROOT=""
cleanup_tmp_roh_root() {
	if [ -n "$TMP_ROH_ROOT" ] && [ -d "$TMP_ROH_ROOT" ]; then
		rm -rf "$TMP_ROH_ROOT"
		echo "Removed [$TMP_ROH_ROOT]"
	fi
	TMP_ROH_ROOT=""
}
trap cleanup_tmp_roh_root EXIT INT TERM

# unpack_archive_to_tmp <dir>
#   Unpack <dir>/_.roh.git.zip into a fresh temp dir using roh.git's own
#   extractor (so the archive format lives in exactly one place). Sets
#   TMP_ROH_ROOT; the unpacked ROH_DIR is "$TMP_ROH_ROOT/$ROH_DIR_NAME".
unpack_archive_to_tmp() {
	local dir="$1"

	TMP_ROH_ROOT=$(mktemp -d)
	if [ $? -ne 0 ] || [ -z "$TMP_ROH_ROOT" ]; then
		echo "ERROR: could not create a temp dir for [$dir/$ARCHIVE_NAME]"
		echo
		exit 1
	fi
	echo "OK: staging [$dir/$ARCHIVE_NAME] in [$TMP_ROH_ROOT]"

	if ! cp "$dir/$ARCHIVE_NAME" "$TMP_ROH_ROOT/$ARCHIVE_NAME"; then
		echo "ERROR: could not copy [$dir/$ARCHIVE_NAME] to [$TMP_ROH_ROOT]"
		echo
		exit 1
	fi
	$GIT_BIN -xC "$TMP_ROH_ROOT"
	if [ $? -ne 0 ] || [ ! -d "$TMP_ROH_ROOT/$ROH_DIR_NAME" ]; then
		echo "ERROR: could not stage archived ROH_DIR from [$dir/$ARCHIVE_NAME]"
		echo
		exit 1
	fi
}

# run_fpath_commands <dir> <roh_root> <cmd>...
#   Run roh.fpath <cmd>... on <dir>. If <roh_root> differs from <dir>, hashes
#   are read from <roh_root>/.roh.git via --roh-dir. The index (.roh.sqlite3)
#   is always written next to <dir>.
run_fpath_commands() {
	local dir="$1"
	local roh_root="$2"
	shift 2

	local opts=()
	if [ "$roh_root" != "$dir" ]; then
		opts+=(--roh-dir "$roh_root/$ROH_DIR_NAME")
	fi

	$FPATH_BIN "$@" "${opts[@]}" "$dir"
	if [ $? -ne 0 ]; then
        echo "ERROR: [$FPATH_BIN $* ${opts[*]} $dir] failed"
		echo
		exit 1
	fi
}

# git_assert_clean <roh_root> <label>
#   Fail unless the repo in <roh_root>/.roh.git exists and has a clean tree.
#   <label> names the ROH_DIR (or archive) as the user knows it, so the error
#   is actionable even when <roh_root> is a temp dir.
git_assert_clean() {
	local roh_root="$1"
	local label="$2"
	local git_status

	if [ ! -d "$roh_root/$ROH_DIR_NAME/.git" ]; then
		echo "ERROR: local repo [$label/.git] does not exist"
		echo
		exit 1
	fi

	git_status=$($GIT_BIN -C "$roh_root" status)
	echo "$git_status"
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
		echo
        echo "ERROR: local repo [$label] not clean"
		echo
		exit 1
	fi
}

# verify_index_directory <dir>
#   verify and/or index <dir>. If its ROH_DIR is archived (_.roh.git.zip
#   present), unpack it to a temp dir and work from there so the archive is
#   never extracted in place -- verify/index without extracting.
verify_index_directory() {
	local dir="$1"
	local roh_dir="$dir/$ROH_DIR_NAME"
	local roh_root="$dir"
	local label="$roh_dir"

	if [ -f "$dir/$ARCHIVE_NAME" ]; then
		if [ -d "$roh_dir" ]; then
			echo "ERROR: both [$dir/$ARCHIVE_NAME] and [$roh_dir] exist"
			echo
			exit 1
		fi
		unpack_archive_to_tmp "$dir"
		roh_root="$TMP_ROH_ROOT"
		label="$dir/$ARCHIVE_NAME"
	fi

	local cmds=()
	contains "verify" && cmds+=("verify")
	contains "index"  && cmds+=("index")
	run_fpath_commands "$dir" "$roh_root" "${cmds[@]}"

	if contains "verify"; then
		git_assert_clean "$roh_root" "$label"
	fi

	# roh.fpath keeps its export logs next to ROH_DIR; when that is the temp
	# dir, move them next to <dir> before the temp dir goes away.
	if [ "$roh_root" != "$dir" ] && [ -d "$roh_root/.roh.logs" ]; then
		rm -rf "$dir/.roh.logs"
		mv "$roh_root/.roh.logs" "$dir/.roh.logs"
		echo "OK: moved export logs to [$dir/.roh.logs]"
	fi

	cleanup_tmp_roh_root
}

archive_directory() {
	local dir="$1"

	if [ -f "$dir/$ARCHIVE_NAME" ]; then
		echo "SKIP: directory [$dir] -- [$dir/$ARCHIVE_NAME] exists"
	else
		$GIT_BIN -zC "$dir" 
		[ $? -ne 0 ] && exit 1
	fi

	if [ -f "$dir/.roh.sqlite3" ]; then
		rm -r "$dir/.roh.sqlite3"
		echo "DB_SQL [$dir/.roh.sqlite3] -- removed"
	fi

	if [ -d "$dir/.roh.logs" ]; then
		rm -r "$dir/.roh.logs"
		echo "OK: [$dir/.roh.logs] -- removed"
	fi

	# roh.git -zC may leave .roh.git.zip~ behind on content drift — clean it up.
	if [ -f "$dir/$ROH_DIR_NAME.zip~" ]; then
		rm -f "$dir/$ROH_DIR_NAME.zip~"
		echo "OK: [$dir/$ROH_DIR_NAME.zip~] -- removed"
	fi
}

extract_directory() {
	local dir="$1"

	$GIT_BIN -xC "$dir" 
	[ $? -ne 0 ] && exit 1
}

# - get the absolute path of $TARGET
# - for each (non-comment) dir in fpath_ro 
# 	- 2] get the common parent with $TARGET; get remainder of dir
# 	- 1] cut off the .ro extension
# 	- 3] paste remainder onto the absolute of $TARGET gives result
# 	- 4] do a roh.fpath verify of result, with --roh-dir $ROH_DIR
#
# verify_target() {
# 	local dir="$1"
# 	local rebase_string="$2"
#     IFS=':' read -r rebase_origin rebase_target <<< "$rebase_string"
# 
# 	local dir_rebased=$(rebase_directory "$dir" "$rebase_origin" "$rebase_target")
# 	if [ "$dir_rebased" = "_INVALID_" ]; then
#         echo "ERROR: invalid rebase string [$rebase_string]"
#  		echo
#  		exit 1
# 	fi
# 	# echo "* [$rebase_string] => [$dir_rebased]"
# 
# 	ROH_DIR="$dir/.roh.git"
# 
# 	# echo "Using [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to"
# 	echo "Verifying [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
# 	$FPATH_BIN verify --roh-dir "$ROH_DIR" "$dir_rebased"
# 	if [ $? -ne 0 ]; then
#         echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$dir_rebased]"
# 		echo
# 		exit 1
# 	fi		
# }

#------------------------------------------------------------------------------------------------------------------------------------------

# Read directories from the file
while IFS= read -r dir; do
	# Skip lines that start with '#'
	if [[ "$dir" =~ ^#.* ]]; then
		continue
	fi

	# --resume-at: skip silently until the resume point; output simply starts
	# at the first "Looping on:" of the directory that matched.
	base_dir=${dir%.ro}
	base_resume_string=${resume_string%.ro}
	# echo "* base_dir: [$base_dir]"
	if [ "$skipping_mode" = "true" ] && [[ ! "$base_dir" == *"$base_resume_string" ]]; then
		continue
	fi
	skipping_mode="false"

	#---

	echo "Looping on: [$dir]"

    # Check if the directory exists
    if [ -d "$dir" ]; then

		if contains "verify" || contains "index"; then
#			if [ "$rebase_mode" = "true" ]; then
#				verify_target "$dir" "$rebase_string"
#			else
			verify_index_directory "$dir"

		elif contains "archive"; then
			archive_directory "$dir"

		elif contains "extract"; then
			extract_directory "$dir"

		fi

    else
        echo "ERROR: Directory [$dir] does not exist."
		echo
		exit 1
    fi
	echo "■"

done

