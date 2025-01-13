#!/bin/bash

#ROH_BIN="./roh.fpath.sh"
ROH_BIN="roh.fpath"
#GIT_BIN="./roh.git.sh"
GIT_BIN="roh.git"
HASH="sha256"

ROH_DIR=".roh.git"

usage() {
	echo
    echo "Usage: $(basename "$0") [COMMAND] -d [PATH]"
    echo "Options:"
	echo "  -d, --directory    Operate on a single directory"
    echo "  -h, --help         Display this help and exit"
#	echo 
#	echo "Flags:"
#	echo "  --loop         PATH specifies a \".loop.txt\"; a dir list to loop over"
#   echo "  --force        Force operation even if hash files do not match"
    echo
}

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

cmd="_INVALID_"
# Parse command
case "$1" in
    init) 
        ;;
    verify) 
        ;;
#     write) 
#         write_mode="true"
#         ;;
#     delete) 
#         delete_mode="true"
#         ;;
#     hide) 
#         hide_mode="true"
#         ;;
#     show) 
#         show_mode="true"
#         ;;
#     recover) 
#         recover_mode="true"
#         ;;
    -h)
		usage
        exit 0
        ;;
    --help)
		usage
        exit 0
        ;;
    *)
        echo "ERROR: unknown command: [$1]"
		usage
        exit 1
        ;;
esac
cmd="$1"

shift

directory_mode="false"
while getopts "dh-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
	d)
	  directory_mode="true"
	  ;;
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
		loop)
		  loop_mode="true"
		  ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "ERROR: invalid option: [--${OPTARG}]" >&2
          usage
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "ERROR: invalid option: [-${OPTARG}]" >&2
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

#------------------------------------------------------------------------------------------------------------------------------------------

init_directory() {
	local dir="$1"
	local echo_rename="$2"

	echo "Looping on: [$dir]"
 	$ROH_BIN write "$dir"
 	if [ $? -ne 0 ]; then
        echo "ERROR: [$ROH_BIN write] failed for directory: [$dir]"
 		echo
 		exit 1
 	fi		

	if [ ! -d "$dir/$ROH_DIR/.git" ]; then
 		$GIT_BIN -C "$dir" init

		echo ".DS_Store.$HASH" > "$dir/$ROH_DIR"/.gitignore
		$GIT_BIN -C "$dir" add .gitignore
		$GIT_BIN -C "$dir" commit -m "Initial ignores"
		# $GIT_BIN -C "$dir" status
	fi

	git_status=$($GIT_BIN -C "$dir" status)
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
		$GIT_BIN -C "$dir" add "*"
		$GIT_BIN -C "$dir" commit -m "Initial hashes"
		$GIT_BIN -C "$dir" status
	fi

	if [ ! -f "$dir/_.roh.git.zip" ]; then
		$GIT_BIN -zC "$dir" 
	fi

	dir_ro="${dir}"
	# Check if the directory name ends with '.ro'
	if [[ "$dir" != "." && "$dir" != ".." && ! $dir == *.ro ]]; then
		dir_ro="${dir}.ro"

		# Rename the directory by adding '.ro' if it doesn't already have it
		mv "$dir" "$dir_ro"
		echo "Renamed [$dir] to [${dir_ro}]"
	fi					
	if [ "$echo_rename" = "true" ]; then
		echo "$dir_ro" >> "${file_path%.loop.txt}~.loop.txt"
	fi
}

verify_directory() {
	local dir="$1"

	$ROH_BIN verify "$dir"
	if [ $? -ne 0 ]; then
        echo "ERROR: [$ROH_BIN verify] failed for directory: [$dir]"
		echo
		exit 1
	fi		
	$GIT_BIN -C "$dir" status
	git_status=$($GIT_BIN -C "$dir" status)
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
		echo
        echo "ERROR: local repo [$dir/$ROH_DIR] not clean"
		echo
		exit 1
	fi
}

#------------------------------------------------------------------------------------------------------------------------------------------

# capture all remaining arguments after the options have been processed
shift $((OPTIND-1))
file_path="$1"

if [ "$directory_mode" = "true" ]; then
	init_directory "$file_path" "false"
	echo
	exit 0
# Check if the file ends with .ro.txt
elif [[ ! "$file_path" =~ \.loop\.txt$ ]]; then
    echo "ERROR: No file path argument ending with '.loop.txt' found."
	usage
    exit 1
fi

#------------------------------------------------------------------------------------------------------------------------------------------

if [ "$cmd" = "init" ]; then
	echo "# $(basename "$0") [" > "${file_path%.loop.txt}~.loop.txt"
fi

# Read directories from the file
while IFS= read -r dir; do
	# Skip lines that start with '#'
	if [[ "$dir" =~ ^#.* ]]; then
		continue
	fi

    # Check if the directory exists
    if [ -d "$dir" ]; then

		if [ "$cmd" = "init" ]; then
			init_directory "$dir" "true"

		elif [ "$cmd" = "verify" ]; then
			verify_directory "$dir"
		fi

    else
        echo "ERROR: Directory [$dir] does not exist."
		echo
		exit 1
    fi
	echo 

done < "$file_path"

if [ "$cmd" = "init" ]; then
	echo "# ]" >> "${file_path%.loop.txt}~.loop.txt"

	# Filter out comments at the end of lines and compare
	if diff <(sed 's/#.*$//' "$file_path") <(sed 's/#.*$//' "${file_path%.loop.txt}~.loop.txt"); then
		rm "${file_path%.loop.txt}~.loop.txt"
	fi
fi

