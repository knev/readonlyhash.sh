#!/bin/bash

ROH_BIN="readonlyhash"
ROH_SWITCHES="-w"  # Add more switches as needed, space separated

# Check if an argument (file path) was provided
if [ $# -eq 0 ]; then
    echo "Error: No file path provided."
    echo "Usage: "$(basename $0)" <path_to_file.ro.txt>"
    exit 1
fi

# Store the argument
fpath="$1"

# Check if the file ends with .ro.txt
if [[ ! "$fpath" =~ \.ro\.txt$ ]]; then
    echo "Error: File path must end with .ro.txt"
    exit 1
fi

# Check if the file exists
if [ ! -f "$fpath" ]; then
    echo "Error: File [$fpath] does not exist."
    exit 1
fi

# Read each line from the file, assuming each line contains a directory path
while IFS= read -r dir; do
    # Skip lines that start with '#'
    if [[ "$dir" =~ ^#.* ]]; then
        continue
    fi

    # Check if directory exists
    if [ -d "$dir" ]; then
        # Execute readonlyhash with switches for each directory and check exit status
        echo "Executing [$ROH_BIN $ROH_SWITCHES] on directory: $dir"
        if ! "$ROH_BIN" $ROH_SWITCHES "$dir"; then
            echo "Error: [$ROH_BIN $ROH_SWITCHES] failed for directory: [$dir]"
            exit 1
        fi
    else
        echo "Warning: Directory [$dir] does not exist, skipping."
    fi
done < "$fpath"

echo "All executions completed successfully."
echo



#	# Define the command
#	ROH_BIN="readonlyhash"
#	
#	# Default switches if none provided
#	ROH_DEFAULT_SWITCHES="-h"
#	
#	# Check if an argument (file path) was provided
#	if [ $# -eq 0 ]; then
#	    echo "Error: No file path provided."
#	    echo "Usage: $(basename $0) <path_to_file.ro.txt> [switches for readonlyhash]"
#	    exit 1
#	fi
#	
#	# Store the first argument (file path)
#	fpath="$1"
#	
#	# Shift arguments so $@ no longer includes the script name or file path but only switches
#	shift
#	
#	# Use default switches if no switches are provided
#	if [ $# -eq 0 ]; then
#	    set -- $ROH_DEFAULT_SWITCHES
#	fi
#	
#	# Check if the file ends with .ro.txt
#	if [[ ! "$fpath" =~ \.ro\.txt$ ]]; then
#	    echo "Error: File path must end with .ro.txt"
#	    exit 1
#	fi
#	
#	# Check if the file exists
#	if [ ! -f "$fpath" ]; then
#	    echo "Error: File [$fpath] does not exist."
#	    exit 1
#	fi
#	
#	# Read each line from the file, assuming each line contains a directory path
#	while IFS= read -r dir; do
#	    # Check if directory exists
#	    if [ -d "$dir" ]; then
#	        # Execute readonlyhash with all passed or default switches for each directory and check exit status
#	        echo "Executing [$ROH_BIN $@] on directory: $dir"
#	        if ! "$ROH_BIN" "$@" "$dir"; then
#	            echo "Error: [$ROH_BIN $@] failed for directory: [$dir]"
#	            exit 1
#	        fi
#	    else
#	        echo "Warning: Directory [$dir] does not exist, skipping."
#	    fi
#	done < "$fpath"
#	
#	echo "All executions of readonlyhash completed successfully."
