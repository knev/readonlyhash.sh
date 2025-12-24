#!/bin/bash

#FPATH_BIN="./roh.fpath.sh"
FPATH_BIN="roh.fpath"
#GIT_BIN="./roh.git.sh"
GIT_BIN="roh.git"
HASH="sha256"

usage() {
	echo
    echo "Usage: $(basename "$0") <COMMAND|<verify|copy> --rebase BASEPATH:TARGET_BASEPATH> [OPTIONS] <FPATH> [--resume-at STRING]"
	echo "      init            ..."
	echo "      verify          ..."
	echo "      archive         ..."
	echo "      extract         ..."
	echo "      copy            ..."
    echo "Options:"
	echo "      --resume-at     ..."
	echo "      --directory     Operate on a single directory specified in FPATH, instead of a .loop.txt"
	echo "      --rebase        ..."
    echo "  -v, --version       Display the version and exit"
    echo "  -h, --help          Display this help and exit"
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
    archive) 
        ;;
    extract) 
        ;;
	copy)
	    ;;
#    delete) 
#        ;;
    -v)
		echo "$(basename "$0") version: $VERSION"
        exit 0
        ;;
    -h)
		usage
        exit 0
        ;;
	--version)
	    echo "$(basename "$0") version: $VERSION"
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
rebase_mode="false"
rebase_string="_INVALID_"

while getopts "dh-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
		directory)
		  directory_mode="true"
		  ;;
        rebase)
		  rebase_mode="true"
          rebase_string="${!OPTIND}"
          OPTIND=$((OPTIND + 1))
          if ! [[ "$rebase_string" =~ ^([^:]+):([^:]+)$ ]]; then
			echo "ERROR: invalid rebase string [$rebase_string]"
		  	usage
			exit 1
          fi
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

# capture all remaining arguments after the options have been processed
shift $((OPTIND-1))
file_path="$1"
LOOP_TXT_RO="${file_path%.loop.txt}~ro.loop.txt"

shift
skipping_mode="false"
resume_string=""
if [ $# -ne 0 ]; then
	if [ $# -eq 2 ] && [ "$1" = "--resume-at" ]; then
		resume_string="$2"
		skipping_mode="true"
	else
		echo "ERROR: invalid option [$@]"
		usage
		exit 1
	fi
fi

#------------------------------------------------------------------------------------------------------------------------------------------
# captured output : NO spurious echo/printf outputs!

rename_to_ro() {
    local dir="$1"
    local dir_ro="${dir}"

	# Rename the directory by adding '.ro' if it doesn't already have it
    if [[ "$dir" != "." && "$dir" != ".." && ! $dir == *.ro ]]; then
        dir_ro="${dir}.ro"
    fi
    echo "$dir_ro"	
}

#	validate_rebase_string() {
#	    local string="$1"
#	    [[ "$string" =~ ^[^:]+:[^:]+$ ]]
#	    return $?
#	}
#	validate_rebase_string "path:to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "path::to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "::to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string ":to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "path:" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "path" && echo "Valid" || echo "Invalid"

rebase_directory() {
    local dir="$1"
    local rebase_origin="$2"
    local rebase_target="$3"	
    
#   if ! [[ "$rebase_string" =~ ^([^:]+):([^:]+)$ ]]; then
#		echo "_INVALID_"
#		return
#	fi
#	local rebase_origin="${BASH_REMATCH[1]}"
#	local rebase_target="${BASH_REMATCH[2]}"

    # Parse rebase string into origin and target using ':' as delimiter
#   IFS=':' read -r rebase_origin rebase_target <<< "$rebase_string"
    
    # Remove trailing slashes from rebase_origin and rebase_target
    rebase_origin=${rebase_origin%/}
    rebase_target=${rebase_target%/}
    
    # Check if dir contains rebase_origin (anywhere in the path)
    if [[ "$dir" == *"$rebase_origin"* ]]; then
        # Replace rebase_origin with rebase_target
        dir_rebased="${dir/$rebase_origin/$rebase_target}"

		# Remove '.ro' from the end of the suffix if it exists
		if [[ "$dir_rebased" = *.ro ]]; then
			dir_rebased="${dir_rebased%.ro}"
		fi
		echo "$dir_rebased"
    else
        # Return original path if rebase_origin not found
        echo "_INVALID_"
    fi
}

#------------------------------------------------------------------------------------------------------------------------------------------

init_directory() {
	local dir="$1"

	ROH_DIR="$dir/.roh.git"

 	$FPATH_BIN write "$dir"
 	if [ $? -ne 0 ]; then
        echo "ERROR: [$FPATH_BIN write] failed for directory: [$dir]"
 		echo
 		exit 1
 	fi		

	if [ ! -d "$ROH_DIR/.git" ]; then
 		$GIT_BIN -C "$dir" init

		echo ".DS_Store.$HASH" > "$ROH_DIR"/.gitignore
		$GIT_BIN -C "$dir" add .gitignore
		$GIT_BIN -C "$dir" commit -m "Initial ignores."
		# $GIT_BIN -C "$dir" status
	fi

	git_status=$($GIT_BIN -C "$dir" status)
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
		$GIT_BIN -C "$dir" add "*"
		$GIT_BIN -C "$dir" commit -m "Initial hashes."
		$GIT_BIN -C "$dir" status
	fi

	dir_ro="$(rename_to_ro "$dir")"
	if [ "$dir" != "$dir_ro" ] && mv "$dir" "$dir_ro"; then
		echo "Renamed [$dir] to [$dir_ro]"
	fi
	echo "$dir_ro" >> "$LOOP_TXT_RO"
}

verify_directory() {
	local dir="$1"

	local archive_name="_.roh.git.zip"
	if [ -f "$dir/$archive_name" ]; then
		tmp_dir=$(mktemp -d)

		unzip -q "$dir/$archive_name" -d "$tmp_dir"
		if [ $? -eq 0 ]; then
		    echo "Extracted [$tmp_dir] from [$dir/$archive_name]"
		else
		    echo "ERROR: failed to extract [$tmp_dir] from [$dir/$archive_name]"
		    echo
		    exit 1
		fi

		ROH_DIR="$tmp_dir/.roh.git"

		$FPATH_BIN verify --roh-dir "$ROH_DIR" "$dir"
		if [ $? -ne 0 ]; then
	        echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$dir]"
			echo
			exit 1
		fi		
		git_status=$($GIT_BIN -C "$tmp_dir" status)
		echo "$git_status"
		if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
			echo
	        echo "ERROR: local repo [$ROH_DIR] not clean"
			echo
			exit 1
		fi

		rm -r "$tmp_dir"
		echo "Removed [$tmp_dir]"

	else
		ROH_DIR="$dir/.roh.git"

		$FPATH_BIN verify "$dir"
		if [ $? -ne 0 ]; then
	        echo "ERROR: [$FPATH_BIN verify] failed for directory: [$dir]"
			echo
			exit 1
		fi		

		if [ ! -d "$ROH_DIR/.git" ]; then
			echo "ERROR: local repo [$ROH_DIR/.git] does not exist"
			echo
			exit 1
		fi

		git_status=$($GIT_BIN -C "$dir" status)
		echo "$git_status"
		if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
			echo
	        echo "ERROR: local repo [$ROH_DIR] not clean"
			echo
			exit 1
		fi

	fi
}

archive_directory() {
	local dir="$1"

	ROH_DIR="$dir/.roh.git"

	if [ -f "$dir/_.roh.git.zip" ]; then
		echo "SKIP: directory [$dir] -- [$dir/_.roh.git.zip] exists"
		return 0
	fi

	if [ ! -d "$ROH_DIR/.git" ]; then
		echo "ERROR: local repo [$ROH_DIR/.git] does not exist"
		echo
		exit 1
	fi

	# local tmp=$(find "$dir" -name '*.sha256' -type f -not -path '*/.roh.git/*')
	# echo "$tmp"

	verify_directory "$dir"
	if [ -f "$dir/_.roh.sqlite3" ]; then
		rm -r "$dir/.roh.sqlite3"
	fi
	$GIT_BIN -zC "$dir" 
}

extract_directory() {
	local dir="$1"

	$GIT_BIN -xC "$dir" 
}

# - get the absolute path of $TARGET
# - for each (non-comment) dir in fpath_ro 
# 	- 2] get the common parent with $TARGET; get remainder of dir
# 	- 1] cut off the .ro extension
# 	- 3] paste remainder onto the absolute of $TARGET gives result
# 	- 4] do a roh.fpath verify of result, with --roh-dir $ROH_DIR
#
verify_target() {
	local dir="$1"
	local rebase_string="$2"
    IFS=':' read -r rebase_origin rebase_target <<< "$rebase_string"

	local dir_rebased=$(rebase_directory "$dir" "$rebase_origin" "$rebase_target")
	if [ "$dir_rebased" = "_INVALID_" ]; then
        echo "ERROR: invalid rebase string [$rebase_string]"
 		echo
 		exit 1
	fi
	# echo "* [$rebase_string] => [$dir_rebased]"

	ROH_DIR="$dir/.roh.git"

	# echo "Using [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to"
	echo "Verifying [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
	$FPATH_BIN verify --roh-dir "$ROH_DIR" "$dir_rebased"
	if [ $? -ne 0 ]; then
        echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$dir_rebased]"
		echo
		exit 1
	fi		
}

#TODO: what if hashes are SHOWN/not hidden!?
copy_to_target() {
	local dir="$1"
	local rebase_string="$2"
    IFS=':' read -r rebase_origin rebase_target <<< "$rebase_string"

	local dir_rebased=$(rebase_directory "$dir" "$rebase_origin" "$rebase_target")
	if [ "$dir_rebased" = "_INVALID_" ]; then
        echo "ERROR: invalid rebase string [$rebase_string]"
 		echo
 		exit 1
	fi
	# echo "* [$rebase_string] => [$dir_rebased]"

	ROH_DIR="$dir/.roh.git"

	# parent_dir="blammy/cheeze"
	# echo "ECHO ${parent_dir}/${dir#*${parent_dir}/}"

	if [ -d "$dir_rebased/.roh.git" ]; then
		echo "Error: Directory [$dir_rebased/.roh.git] already exists"
		exit 1
	fi
 
 	if cp -R "$ROH_DIR" "$dir_rebased/."; then
 		# echo "Copied [$ROH_DIR] to [$dir_rebased/.]"
		echo "Copied [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
	else
		exit 1
 	fi

 	dir_rebased_ro=$(rename_to_ro "$dir_rebased")
	if [ "$dir_rebased" != "$dir_rebased_ro" ] && mv -n "$dir_rebased" "$dir_rebased_ro"; then
 		# echo "Renamed [$dir_rebased] to [$dir_rebased_ro]"
		echo "Renamed [${rebase_target}/${dir_rebased#*${rebase_target}/}] to [${rebase_target}/${dir_rebased_ro#*${rebase_target}/}]"
	else
		exit 1
	fi
 	echo "$dir_rebased_ro" >> "$LOOP_TXT_RO"
}

#------------------------------------------------------------------------------------------------------------------------------------------

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

# Read directories from the file
while IFS= read -r dir; do
	# Skip lines that start with '#'
	if [[ "$dir" =~ ^#.* ]]; then
		echo "$dir" >> "$LOOP_TXT_RO"
		continue
	fi

	echo "Looping on: [$dir]"

	#---

	base_dir=${dir%.ro}
	base_resume_string=${resume_string%.ro}
	# echo "* base_dir: [$base_dir]"
	if [ "$skipping_mode" = "true" ] && [[ ! "$base_dir" == *"$base_resume_string" ]]; then
		echo "OK: directory entry [$dir] -- SKIPPING"
		echo "■"
		if [ "$cmd" = "init" ] || [ "$cmd" = "copy" ]; then
			echo "#SKIPPED: $dir" >> "$LOOP_TXT_RO"
		fi
		continue
	fi
	skipping_mode="false"

	#---

    # Check if the directory exists
    if [ -d "$dir" ]; then

		if [ "$cmd" = "init" ]; then
			init_directory "$dir"

		elif [ "$cmd" = "verify" ]; then
			if [ "$rebase_mode" = "true" ]; then
				verify_target "$dir" "$rebase_string"
			else
				verify_directory "$dir"
			fi

		elif [ "$cmd" = "archive" ]; then
			archive_directory "$dir"

		elif [ "$cmd" = "extract" ]; then
			extract_directory "$dir"

		elif [ "$cmd" = "copy" ]; then
			copy_to_target "$dir" "$rebase_string"

		elif [ "$cmd" = "delete" ]; then
			echo delete
			
		fi

    else
        echo "ERROR: Directory [$dir] does not exist."
		echo
		exit 1
    fi
	echo "■"

done < "$file_path"

if [ "$cmd" = "init" ] || [ "$cmd" = "copy" ]; then
	# Filter out comments at the end of lines and compare
	if diff <(sed 's/#.*$//' "$file_path") <(sed 's/#.*$//' "$LOOP_TXT_RO") > /dev/null 2>&1; then
		rm "$LOOP_TXT_RO"
	fi
fi

