#!/bin/bash

#TODO;
# - output the actual hash when on is generated
# - not equal hashes should be BOLDLY output
# - hashes should only be written when they don't exist
# - deal with moved files? git?
# - deal with orphaned hash files? git?
# - what about entirely missing directories? git?

# List of file extensions to avoid, comma separated
EXTENSIONS_TO_AVOID="rslsi,rslsv,rslsz,rsls"

# Variable for SHA-256 hash command
SHA256_BIN="sha256sum" # linux native, macOS via brew install coreutils
SHA256_BIN="shasum -a 256" # macOS native
SHA256_BIN="openssl sha256" # pre-installed on macOS

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


# New function for hashing
generate_hash() {
    local file="$1"
    local hash_file=".$(basename "$file").sha256"
    
    # Use the SHA256_BIN variable to compute the hash
    $SHA256_BIN "$file" | awk '{print $1}' > "$hash_file"
	echo -n " -- hash written"
}

# Function to delete hash files
delete_hash() {
    local file="$1"
    local hash_file=".$(basename "$file").sha256"
    
    # Check if hash file exists before attempting to delete
    if [ -f "$hash_file" ]; then
        rm "$hash_file"
        echo -n " -- hash deleted"
    else
        echo -n " -- no hash to delete"
    fi
}

compare_hash() {
    local file="$1"
    local hash_file=".$(basename "$file").sha256"
    
    if [ -f "$hash_file" ]; then
        local current_hash=$($SHA256_BIN "$file" | awk '{print $1}')
        local stored_hash=$(cat "$hash_file")
        
        if [ "$current_hash" = "$stored_hash" ]; then
            echo -n " -- hash matches"
        else
            echo -n " -- hash mismatch"
        fi
    else
        echo -n " - no hash file exists"
    fi
}

rename_hash() {
    local file="$1"
    local old_hash_file=".$(basename "$file").sha256"
    local new_hash_file="$(basename "$file").sha256"
    
    if [ -f "$old_hash_file" ]; then
        mv "$old_hash_file" "$new_hash_file"
        echo -n " -- hash renamed"
    else
        echo -n " -- no hash to rename"
    fi
}

hide_hash() {
    local file="$1"
    local old_hash_file="$(basename "$file").sha256"
    local new_hash_file=".$(basename "$file").sha256"
    
    if [ -f "$old_hash_file" ]; then
        mv "$old_hash_file" "$new_hash_file"
        echo -n " -- hash hidden"
    else
        echo -n " -- no hash to hide"
    fi
}

# Function to process directory contents recursively
process_directory() {
    local dir="$1"
    local write_mode="$2"
    local delete_mode="$3"
    local rename_mode="$4"
    local hide_mode="$5"

    for entry in "$dir"/*; do
        if [ -d "$entry" ]; then
            # If the entry is a directory, echo it and process it recursively
            echo "Directory: $entry"
			process_directory "$entry" "$write_mode" "$delete_mode" "$rename_mode" "$hide_mode"
        elif [ -f "$entry" ]; then
            if check_extension "$entry"; then
                echo "Error: Encountered file with restricted extension: $(basename "$entry")"
                exit 1
            else
                echo -n "File: $(basename "$entry")"
                if [ "$delete_mode" = "true" ]; then
                    delete_hash "$entry"
                elif [ "$write_mode" = "true" ]; then
                    generate_hash "$entry"
                elif [ "$rename_mode" = "true" ]; then
                    rename_hash "$entry"
                elif [ "$hide_mode" = "true" ]; then
                    hide_hash "$entry"
                else
                    compare_hash "$entry"
                fi
                echo  # New line after the operation message
            fi
        fi
    done
}

# Parse command line options
write_mode="false"
delete_mode="false"
rename_mode="false"
hide_mode="false"
while getopts ":dwuh" opt; do
  case $opt in
    d)
      delete_mode="true"
      ;;
    w)
      write_mode="true"
      ;;
    u)
      rename_mode="true"
      ;;
    h)
      hide_mode="true"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Use the first non-option argument as the directory, if provided
if [ $OPTIND -le $# ]; then
    dir="${@:$OPTIND:1}"
else
    dir="."
fi

if [ -d "$dir" ]; then
    echo "Processing directory: $dir"
	process_directory "$dir" "$write_mode" "$delete_mode" "$rename_mode" "$hide_mode"
else
    echo "Error: Directory $dir does not exist."
    exit 1
fi
