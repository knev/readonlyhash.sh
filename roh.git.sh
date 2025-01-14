#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") [--force] [OPTIONS][-C PATH] [ARGUMENTS]"
    echo "Options:"
	echo "  -z             Archive the roh_git storage"
	echo "  -x             Extract the roh_git storage"
	echo "  -C             Specify the working directory"
    echo "      --force    Force operation"	
    echo "  -h, --help     Display this help and exit"
	echo
	echo "Examples:"
	echo "  \$ $(basename "$0") -zC <PATH>"
	echo "  \$ $(basename "$0") -C <PATH> add \"*\""
	echo
}

current_working_dir="."
archive_mode="false"
extract_mode="false"
force_mode="false"
# Parse command line options
while getopts ":zxC:h-:" opt; do
  case $opt in
	z)
	  archive_mode="true"
	  ;;
	x)
	  extract_mode="true"
	  ;;
    C)
	  current_working_dir="$OPTARG"
      ;;	
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
		force)
          force_mode="true"
          ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "Invalid option: --${OPTARG}" >&2
          usage
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done

# Shift off the options and their arguments
shift $((OPTIND-1))

ROH_DIR=".roh.git"

# echo "* current_working_dir $current_working_dir"
# echo "* $@"

archive_roh() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"
    local roh_path="$dir/$ROH_DIR"
    
	# If force_mode is true, remove existing archive before creating a new one
	if [ -f "$dir/$archive_name" ]; then
		if [ "$force_mode" = "true" ]; then
			rm "$dir/$archive_name"
			echo "Removed [$dir/$archive_name]"
		else
			echo "ERROR: archive [$archive_name] exists in [$dir]; aborting"
			echo
			exit 1
		fi
	fi
        
     if [ -d "$roh_path" ]; then
       # zip -r "$archive_name" "$roh_path"
		#archive_name shouldn't end in .zip: tar -cvzf "$dir/$archive_name" -C "$dir" "$ROH_DIR"
		tar -cvf "$dir/$archive_name" --format=zip -C "$dir" "$ROH_DIR" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Archived [$ROH_DIR] to [$dir/$archive_name]"
        else
            echo "ERROR: failed to archive [$ROH_DIR] to [$dir/$archive_name]"
			echo
            exit 1
        fi

		if [ -f "$dir/$archive_name" ]; then
			rm -rf "$dir/$ROH_DIR"
			echo "Removed [$dir/$ROH_DIR]"
		fi
    else
        echo "ERROR: directory [$ROH_DIR] does NOT exist in [$dir]"
		echo
        exit 1
    fi
}

extract_roh() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"
    local roh_path="$dir/$ROH_DIR"
    
	if [ -d "$roh_path" ]; then
		if [ "$force_mode" = "true" ]; then
			rm -rf "$dir/$ROH_DIR"
			echo "Removed [$dir/$ROH_DIR]"
		else
			echo "ERROR: directory [$ROH_DIR] exists in [$dir]; aborting"
			echo
			exit 1
		fi
	fi

	if [ -f "$dir/$archive_name" ]; then
		unzip -q "$dir/$archive_name" -d "$dir"
		if [ $? -eq 0 ]; then
		    echo "Extracted [$ROH_DIR] from [$dir/$archive_name]"
		else
		    echo "ERROR: failed to extract [$ROH_DIR] from [$dir/$archive_name]"
		    echo
		    exit 1
		fi

		if [ -d "$dir/$ROH_DIR" ]; then
			rm -rf "$dir/$archive_name"
			echo "Removed [$dir/$archive_name]"
		fi

	else
        echo "ERROR: archive [$archive_name] does NOT exist in [$dir]"
		echo
        exit 1
    fi
}

if [ "$archive_mode" = "true" ]; then
	archive_roh "$current_working_dir" "$force_mode"

elif [ "$extract_mode" = "true" ]; then
	extract_roh "$current_working_dir" "$force_mode"

else
	# External drive fatal error, because ownership ids are from another system
	# fatal: detected dubious ownership in repository at '/Volumes/Fractal/o1oc/INST.ro/.roh.git'
	# To add an exception for this directory, call:
	# git config --global --add safe.directory <PATH>
	
	# GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$current_working_dir/$ROH_DIR" git status
	export GIT_CONFIG_COUNT=1
	export GIT_CONFIG_KEY_0=safe.directory
	export GIT_CONFIG_VALUE_0="$current_working_dir/$ROH_DIR"

	# Your name and email address were configured automatically based
	# on your username and hostname. Please check that they are accurate.
	# You can suppress this message by setting them explicitly. Run the
	# following command and follow the instructions in your editor to edit
	# your configuration file:
	#     git config --global --edit
	# After doing this, you may fix the identity used for this commit with:
	#     git commit --amend --reset-author
	export GIT_ADVICE_IMPLICIT_IDENTITY=false

	# Now, $@ contains all arguments after -C PATH
	git -C "$current_working_dir/$ROH_DIR" "$@"

	unset GIT_ADVICE_IMPLICIT_IDENTITY
	unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
fi

