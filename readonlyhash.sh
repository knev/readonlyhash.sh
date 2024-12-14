#!/bin/bash

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
            # If it's a file, just echo its name
            echo "File: $(basename "$entry")"
        fi
    done
}

# Check if an argument is provided
if [ -z "$1" ]; then
    # If no argument, use the current directory
    dir="."
else
    # Use the provided directory
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
