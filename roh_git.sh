#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") [(-zC|(-z) -C) PATH] [ARGUMENTS]"
    echo "Options:"
	echo "  -C             Specify the working directory"
	echo "  -z             Archive the roh_git storage"
    echo "      --force    Force operation"	
    echo "  -h, --help     Display this help and exit"
}

current_working_dir="."
archive_mode="false"
force_mode="false"
# Parse command line options
while getopts ":zC:h" opt; do
  case $opt in
    C)
	  current_working_dir="$OPTARG"
      ;;	
	z)
	  archive_mode="true"
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

echo "$current_working_dir"
echo "$@"

archive_roh() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"
    local roh_path="$dir/$ROH_DIR"
    
    if [ -d "$roh_path" ]; then
        # If force_mode is true, remove existing archive before creating a new one
        if [ "$force_mode" = "true" ] && [ -f "$dir/$archive_name" ]; then
            rm "$dir/$archive_name"
        fi
        
        # zip -r "$archive_name" "$roh_path"
		#archive_name shouldn't end in .zip: tar -cvzf "$dir/$archive_name" -C "$dir" "$ROH_DIR"
		tar -cvf "$dir/$archive_name" --format=zip -C "$dir" "$ROH_DIR"
        if [ $? -eq 0 ]; then
            echo "Archived $ROH_DIR to $dir/$archive_name"
        else
            echo "ERROR: Failed to archive $ROH_DIR to $dir/$archive_name"
            ((ERROR_COUNT++))
        fi
    else
        echo "ERROR: $ROH_DIR directory does not exist in $dir"
        ((ERROR_COUNT++))
    fi
}

if [ "$archive_mode" = "true" ]; then
	archive_roh "$current_working_dir" "$force_mode"
else
	# Now, $@ contains all arguments after -C PATH
	git -C "$current_working_dir/$ROH_DIR" "$@"
fi

