#!/bin/bash
# Compatible with bash 3.2+ (macOS default) and bash 4+

# List of valid full operations
valid_long="verify write index delete hide show query recover sweep"

# Short to long mapping (using case statement instead of assoc array)
get_long() {
    case "$1" in
        v) echo "verify" ;;
        w) echo "write" ;;
        i) echo "index" ;;
        d) echo "delete" ;;
        h) echo "hide" ;;
        s) echo "show" ;;
        q) echo "query" ;;
        r) echo "recover" ;;
        e) echo "sweep" ;;
        *) echo "" ;;  # empty = invalid
    esac
}

operations=()  # normal array is fine even in 3.2

i=1
while [ $i -le $# ]; do
    arg=$(eval echo "\$$i")

    # Stop on any switch-like argument
    case "$arg" in
        -*) break ;;
    esac

    # 1. Try full word match
    if echo "$valid_long" | grep -qw "$arg"; then
        operations+=("$arg")
        i=$((i+1))
        continue
    fi

    # 2. Try short letters (consecutive, no separators)
    if echo "$arg" | grep -qE '^[vwidhsqre]+$'; then
        invalid=0
        for ((j=0; j<${#arg}; j++)); do
            c="${arg:$j:1}"
            long=$(get_long "$c")
            if [ -n "$long" ]; then
                operations+=("$long")
            else
                echo "Error: unknown short operation '$c' in '$arg'" >&2
                invalid=1
                break
            fi
        done
        if [ $invalid -eq 0 ]; then
            i=$((i+1))
            continue
        fi
    fi

    # If we get here → error
    echo "Error: invalid operation '$arg'" >&2
    echo "Allowed full: verify write index delete hide show query recover sweep" >&2
    echo "     short:  v      w     i      d      h    s    q     r      e" >&2
    echo "Shorts can be concatenated like: vwidhsqre" >&2
    exit 1
done

# ── Result ──
echo "Parsed operations (${#operations[@]}):"
for op in "${operations[@]}"; do
    echo "  - $op"
done

# Remaining arguments (if any switch was found)
if [ $i -le $# ]; then
    echo
    echo "Remaining arguments (starting from switch):"
    while [ $i -le $# ]; do
        eval echo "  \$$i"
        i=$((i+1))
    done
fi
