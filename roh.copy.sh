#!/bin/bash

usage() {
	echo
    echo "Usage: $(basename "$0") < --rebase BASEPATH:TARGET_BASEPATH> [OPTIONS] <FPATH/FN.roh.txt>"
    echo "Options:"
	echo "      --rebase        ..."
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
        rebase)
		  if [ "$cmd" != "copy" ] && [ "$cmd" != "verify" ]; then
			echo "ERROR: invalid use of --rebase"
		  	usage
			exit 1
		  fi
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
	if [ -d "$dir_rebased".ro ]; then
		dir_rebased="$dir_rebased.ro"
	fi
	# echo "* [$rebase_string] => [$dir_rebased]"

	# parent_dir="blammy/cheeze"
	# echo "ECHO ${parent_dir}/${dir#*${parent_dir}/}"

	mkdir -p "$dir_rebased"
	if [ -d "$dir_rebased/.roh.git" ] || [ -f "$dir_rebased/_.roh.git.zip" ]; then
		echo "Error: Directory [$dir_rebased] already ROH; [.roh.git] or [_.roh.git.zip] exists"
		exit 1
	fi

	if [ -d "$dir/.roh.git" ]; then
		ROH_DIR="$dir/.roh.git"
	 	if cp -R "$ROH_DIR" "$dir_rebased/."; then
	 		# echo "Copied [$ROH_DIR] to [$dir_rebased/.]"
			echo "Copied [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
		else
			exit 1
	 	fi
	fi

	if [ -f "$dir/_.roh.git.zip" ]; then
		ROH_DIR="$dir/_.roh.git.zip"

	 	if cp "$ROH_DIR" "$dir_rebased/."; then
	 		# echo "Copied [$ROH_DIR] to [$dir_rebased/.]"
			echo "Copied [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
		else
			exit 1
	 	fi
	fi

 	dir_rebased_ro=$(rename_to_ro "$dir_rebased")
	if [ "$dir_rebased" != "$dir_rebased_ro" ] && mv -n "$dir_rebased" "$dir_rebased_ro"; then
 		# echo "Renamed [$dir_rebased] to [$dir_rebased_ro]"
		echo "Renamed [${rebase_target}/${dir_rebased#*${rebase_target}/}] to [${rebase_target}/${dir_rebased_ro#*${rebase_target}/}]"
	else
		echo "[$dir_rebased]"
	fi
 	echo "$dir_rebased_ro" >> "$ALT_TXT"
}


#		elif [ "$cmd" = "copy" ]; then
#			copy_to_target "$dir" "$rebase_string"


