#!/bin/bash

# List of file extensions to avoid, comma separated
EXTENSIONS_TO_AVOID="rslsi,rslsv,rslsz,rsls"

# Function to check if a file's extension is in the list to avoid
check_extension() {
    local file="$1"
    # Convert comma separated list to a space separated list for easier comparison
    local extensions=$(echo "$EXTENSIONS_TO_AVOID" | tr ',' ' ')
    
    # Get only the extension part of the filename, supporting double extensions
    local file_extension="${file##*.}"
    # Check if the file's extension matches any in our list
    for ext in $extensions; do
        if [[ "$file_extension" == "$ext" ]]; then
            return 0  # Extension found, exit with success (0) for the function
        fi
    done
    return 1  # Extension not found
}

# Function to process directory contents recursively
process_directory() {
    local dir="$1"
    
    # Iterate over each entry in the directory
    for entry in "$dir"/*; do
        if [ -d "$entry" ]; then
            # If the entry is a directory, echo it and process it recursively
            echo "Directory: $entry"
            process_directory "$entry"
        elif [ -f "$entry" ]; then
            # If it's a file, check its extension before echoing
            if check_extension "$entry"; then
                echo "Error: Encountered file with restricted extension: $(basename "$entry")"
                exit 1
            else
                echo "File: $(basename "$entry")"
            fi
        fi
    done
}

# If no argument, use the current directory
if [ -z "$1" ]; then
    dir="."
else
    dir="$1"
fi

# Check if the directory exists
if [ -d "$dir" ]; then
    echo "Processing directory: $dir"
    process_directory "$dir"
else
    echo "Error: Directory $dir does not exist."
    exit 1
fi
