#!/bin/bash

#ROH_BIN="./readonlyhash.sh"
ROH_BIN="readonlyhash"
ROH_GIT=".roh.git"
GIT_BIN="roh.git"
HASH="sha256"

usage() {
	echo
    echo "Usage: $(basename "$0") [OPTIONS|(-w|-d) --force] [PATH]"
    echo "Options:"
    echo "  -h, --help     Display this help and exit"
#	echo 
#	echo "Flags:"
#	echo "  --loop         PATH specifies a \".loop.txt\"; a dir list to loop over"
#   echo "  --force        Force operation even if hash files do not match"
    echo
}

cmd="$1"
file_path="$2"

# Check if the file ends with .ro.txt
if [[ ! "$file_path" =~ \.loop\.txt$ ]]; then
    echo "ERROR: No file path argument ending with '.loop.txt' found."
	usage
    exit 1
fi

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
			echo "Looping on: [$dir]"
	 		$ROH_BIN -w "$dir"
	 		if [ $? -ne 0 ]; then
	            echo "ERROR: [$ROH_BIN -w] failed for directory: [$dir]"
	 			echo
	 			exit 1
	 		fi		

			if [ ! -d "$dir/$ROH_GIT/.git" ]; then
	 			$GIT_BIN -C "$dir" init

				echo ".DS_Store.$HASH" > "$dir/$ROH_GIT"/.gitignore
				$GIT_BIN -C "$dir" add .gitignore
				$GIT_BIN -C "$dir" commit -m "Initial ignores"
				# $GIT_BIN -C "$dir" status
			fi

			$GIT_BIN -C "$dir" add "*"
			$GIT_BIN -C "$dir" commit -m "Initial hashes"
			$GIT_BIN -C "$dir" status

			$GIT_BIN -zC "$dir" 

			dir_ro="${dir}.ro"

			echo "$dir_ro" >> "${file_path%.loop.txt}~.loop.txt"

			# Check if the directory name ends with '.ro'
			if [[ "$dir" != "." && "$dir" != ".." && ! $dir == *.ro ]]; then
				# Rename the directory by adding '.ro' if it doesn't already have it
				mv "$dir" "$dir_ro"
				echo "Renamed [$dir] to [${dir_ro}]"
			fi					

		elif [ "$cmd" = "verify" ]; then
	 		$ROH_BIN -v "$dir"
	 		if [ $? -ne 0 ]; then
	            echo "ERROR: [$ROH_BIN -w] failed for directory: [$dir]"
	 			echo
	 			exit 1
	 		fi		
			$GIT_BIN -C "$dir" status

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
fi









exit

# Check if at least one argument is provided (command)
if [ $# -lt 1 ]; then
    echo "Usage: $0 <command> [arguments...] <file_path>.loop.txt"
    exit 1
fi

# Check if the first argument is an executable command
if ! which "$1" &> /dev/null; then
    echo "Error: '$1' is not an executable command."
    exit 1
fi

# Find the file path argument with '.ro-list.txt' extension
file_path=""
for arg in "$@"; do
    if [[ "$arg" == *".loop.txt" ]]; then
        file_path="$arg"
        break
    fi
done



# Replace file path with placeholder in arguments
args=()
while [ "$#" -gt 0 ]; do
    if [ "$1" = "$file_path" ]; then
        args+=("%%DIR%%")
    else
        args+=("$1")
    fi
    shift
done

# Construct the base command with placeholder
cmd="${args[@]}"





exit


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
