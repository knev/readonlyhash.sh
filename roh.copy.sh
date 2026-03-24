#!/bin/bash

usage() {
    echo "Usage:"
	echo "      $(basename "$0") <[OPTIONS]|--rebase [\"]BASEPATH:TARGET_BASEPATH[\"]> <PATHSPEC>"
	echo
    echo "Options:"
	echo "  -n, --dry-run		Display output result without any operations"
	echo "      --rebase        Replace the BASEPATH prefix of the PATHSPEC with the TARGET_BASEPATH"
    echo "      --version       Display the version and exit"
    echo "  -h, --help          Display this help and exit"
    echo
}

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

# ----

dry_run_mode="false"
rebase_mode="false"
rebase_string="_INVALID_"

while getopts "nh-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
	n)
	  dry_run_mode="true"
	  ;;
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
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
		dry-run)
		  dry_run_mode="true"
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

# echo "[$@]"

PATHSPEC=""

# capture all remaining arguments after the options have been processed
shift $((OPTIND-1))

PATHSPEC="$1"
if [ -z "$PATHSPEC" ]; then
	echo "ERROR: expected argument after Options" >&2
	usage
	exit 1	
fi
shift # this will fail if there are not enough args
if [ $# -ne 0 ]; then 
	echo "ERROR: too many arguments after PATHSPEC" >&2
	usage
	exit 1	
fi
# echo "* PATHSPEC (ROOT) set to [$PATHSPEC]"

# echo "[$@]"

#------------------------------------------------------------------------------------------------------------------------------------------

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
		echo "$dir_rebased"
    else
        # Return original path if rebase_origin not found
        echo "_INVALID_"
    fi
}

copy_to_target() {
	local dir="$1"
	local rebase_string="$2"
    IFS=':' read -r rebase_origin rebase_target <<< "$rebase_string"

	if [ ! -d "$dir" ]; then
		echo "ERROR: rebase origin [$dir] not accessible"
		echo 
		exit 1
	fi

	local dir_rebased=$(rebase_directory "$dir" "$rebase_origin" "$rebase_target")
	if [ "$dir_rebased" = "_INVALID_" ]; then
        echo "ERROR: invalid rebase string [$rebase_string]"
 		echo
 		exit 1
	fi

	# rebased *.not, *.not exists -AND rebased *.ro, *.ro exists
	if [ -d "$dir_rebased" ]; then
		:
	# rebased *.ro, *.not exists
	elif [[ "$dir_rebased" = *.ro ]] && [ -d "${dir_rebased%.ro}" ]; then
		dir_rebased="${dir_rebased%.ro}" # Remove '.ro' from the end of the suffix
	# rebased X, *.ro exists
	elif [ -d "$dir_rebased".ro ]; then
		dir_rebased="$dir_rebased.ro"
	else
		:
	fi
	# echo "* [$rebase_string] => [$dir_rebased]"

	# parent_dir="blammy/cheeze"
	# echo "ECHO ${parent_dir}/${dir#*${parent_dir}/}"

	if [ -d "$dir_rebased/.roh.git" ] || [ -f "$dir_rebased/_.roh.git.zip" ]; then
		echo "Error: Directory [$dir_rebased] already ROH; [.roh.git] or [_.roh.git.zip] exists"
		exit 1
	fi

	if [ -d "$dir/.roh.git" ]; then
		ROH_DIR="$dir/.roh.git"

		if [ "$dry_run_mode" = "true" ]; then
			if [ -d "$dir_rebased" ]; then
				echo "DRY-RUN: copied [$ROH_DIR] to [$dir_rebased/.] -- existing"
			else
				echo "DRY-RUN: copied [$ROH_DIR] to [$dir_rebased/.] -- NEW!"
			fi
		else
			mkdir -p "$dir_rebased"
		 	if cp -R "$ROH_DIR" "$dir_rebased/."; then
		 		# echo "Copied [$ROH_DIR] to [$dir_rebased/.]"
				echo "Copied [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
			else
				exit 1
		 	fi
		fi
	fi

	if [ -f "$dir/_.roh.git.zip" ]; then
		ROH_DIR="$dir/_.roh.git.zip"

		if [ "$dry_run_mode" = "true" ]; then
			if [ -d "$dir_rebased" ]; then
				echo "DRY-RUN: copied [$ROH_DIR] to [$dir_rebased/.] -- existing"
			else
				echo "DRY-RUN: copied [$ROH_DIR] to [$dir_rebased/.] -- NEW!"
			fi
		else
			mkdir -p "$dir_rebased"
		 	if cp "$ROH_DIR" "$dir_rebased/."; then
		 		# echo "Copied [$ROH_DIR] to [$dir_rebased/.]"
				echo "Copied [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
			else
				exit 1
		 	fi
		fi
	fi

# 	dir_rebased_ro=$(rename_to_ro "$dir_rebased")
#	if [ "$dir_rebased" != "$dir_rebased_ro" ] && mv -n "$dir_rebased" "$dir_rebased_ro"; then
# 		# echo "Renamed [$dir_rebased] to [$dir_rebased_ro]"
#		echo "Renamed [${rebase_target}/${dir_rebased#*${rebase_target}/}] to [${rebase_target}/${dir_rebased_ro#*${rebase_target}/}]"
#	else
#		echo "[$dir_rebased]"
#	fi
# 	echo "$dir_rebased_ro" >> "$ALT_TXT"
}

#------------------------------------------------------------------------------------------------------------------------------------------


copy_to_target "$PATHSPEC" "$rebase_string"

