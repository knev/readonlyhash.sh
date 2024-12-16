#!/bin/bash

# List of file extensions to avoid, comma separated
EXTENSIONS_TO_AVOID="rslsi,rslsv,rslsz,rsls"

ROH_DIR=".roh"

# Variable for SHA-256 hash command
#SHA256_BIN="sha256sum" # linux native, macOS via brew install coreutils
SHA256_BIN="shasum -a 256" # macOS native
#SHA256_BIN="openssl sha256" # pre-installed on macOS

ERROR_COUNT=0

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

# Ensure .roh directory exists
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir "$dir"
    fi
}

# New function for hashing
generate_hash() {
    local dir="$1"
    local file="$2"
    local hash_file="$(basename "$file").sha256"
    local roh_hash_file="$(dirname "$file")/$ROH_DIR/$hash_file"

    if [ -f "$roh_hash_file" ]; then
        echo "ERROR: [$dir] $(basename "$file") -- hash file [$roh_hash_file] already exists"
        ((ERROR_COUNT++))
        return 1  # Signal that an error occurred
    elif [ -f "$hash_file" ]; then
        echo "ERROR: [$dir] $(basename "$file") -- hash file [$hash_file] already exists"
        ((ERROR_COUNT++))
        return 1  # Signal that an error occurred
    else
        local hash=$($SHA256_BIN "$file" | awk '{print $1}')
        if echo "$hash" > "$roh_hash_file"; then
            # echo "File: $dir $(basename "$file") -- hash written: [$hash]"
            echo "File: [$dir] $(basename "$file") -- hash written: [$hash] -- OK"
            return 0  # No error
        else
            echo "ERROR: [$dir] $(basename "$file") -- failed to write hash to [$roh_hash_file]"
            ((ERROR_COUNT++))
            return 1  # Signal that an error occurred
        fi
    fi
}

# Function to delete hash files
delete_hash() {
    local dir="$1"
    local file="$2"
    local hash_file="$(basename "$file").sha256"
    local roh_hash_file="$(dirname "$file")/$ROH_DIR/$hash_file"

    if [ -f "$roh_hash_file" ]; then
        rm "$roh_hash_file"
        echo "File: [$dir] $(basename "$file") -- hash deleted: [$roh_hash_file] -- OK"
        return 0  # No error
    elif [ -f "$hash_file" ]; then
        echo "ERROR: [$dir] $(basename "$file") -- found [$hash_file]; can only delete hidden hashes"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
    else
        echo "ERROR: [$dir] $(basename "$file") -- NO hash file found in [$dir/$ROH_DIR]"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
    fi
}

compare_hash() {
    local file="$1"
    local hash_file=".$(basename "$file").sha256"
    local current_hash
    
    if [ -f "$hash_file" ]; then
        current_hash=$($SHA256_BIN "$file" | awk '{print $1}')
        local stored_hash=$(cat "$hash_file")
        
        if [ "$current_hash" = "$stored_hash" ]; then
            #echo "File: $(basename "$file") -- hash matches: [$current_hash]"
            echo "File: [$current_hash]: $(basename "$file") -- OK"
            return 0  # No error
        else
            echo "ERROR: $(basename "$file") - hash mismatch, expected [$stored_hash], got [$current_hash]"
            ((ERROR_COUNT++))
            return 1  # Error, hash mismatch
        fi
    else
        echo "ERROR: $(basename "$file") -- no hash file exists"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
    fi
}

manage_hash_visibility() {
    local dir="$1"
    local file="$2"
    local action="$3"
    local hash_file="$(basename "$file").sha256"
    local roh_hash_file="$(dirname "$file")/$ROH_DIR/$hash_file"
    local old_hash_file
    local new_hash_file
    
    if [ "$action" = "show" ]; then
        old_hash_file=$roh_hash_file
        new_hash_file=$hash_file
    elif [ "$action" = "hide" ]; then
        old_hash_file=$hash_file
        new_hash_file=$roh_hash_file
    else
        echo "ERROR: $(basename "$file") -- invalid hash visibility action"
        ((ERROR_COUNT++))
        return 1
    fi

    if [ -f "$old_hash_file" ]; then
        mv "$old_hash_file" "$new_hash_file"
        echo "File: [$dir] $(basename "$file") -- ${action}ing hash: [$new_hash_file] -- OK"
        return 0  # No error
    else
        echo "ERROR: [$dir] $(basename "$file") -- hash file [$old_hash_file] NOT found for ${action}ing"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist for the action
    fi
}

# Function to process directory contents recursively
process_directory() {
    local dir="$1"
    local write_mode="$2"
    local delete_mode="$3"
    local show_mode="$4"
    local hide_mode="$5"

	echo "Processing directory: [$dir]"
	if [ "$write_mode" = "true" ] || [ "$hide_mode" = "true" ]; then
	    ensure_dir "$dir/$ROH_DIR"
	fi

    for entry in "$dir"/*; do
		# If the entry is a directory, process it recursively
        if [ -d "$entry" ]; then
            process_directory "$entry" "$write_mode" "$delete_mode" "$show_mode" "$hide_mode"

		# else ...
        elif [ -f "$entry" ] && [[ ! $(basename "$entry") =~ \.sha256$ ]]; then
            if check_extension "$entry"; then
                echo "ERROR: $(basename "$entry") -- encountered file with restricted extension"
                exit 1
            else
                if [ "$delete_mode" = "true" ]; then
                    delete_hash "$dir" "$entry"
                elif [ "$write_mode" = "true" ]; then
					generate_hash "$dir" "$entry"
                elif [ "$show_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "show"
                elif [ "$hide_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "hide"
                else
                    compare_hash "$entry" 
                fi
            fi
        fi
    done

	if [ "$delete_mode" = "true" ] && [ -d "$dir/$ROH_DIR" ]; then
		if ! rmdir "$dir/$ROH_DIR" 2>/dev/null; then
			echo "Directory [$dir/$ROH_DIR] not empty"
			((ERROR_COUNT++))
		fi
	fi
}

# Parse command line options
write_mode="false"
delete_mode="false"
show_mode="false"
hide_mode="false"
while getopts ":dwsh" opt; do
  case $opt in
    d)
      delete_mode="true"
      ;;
    w)
      write_mode="true"
      ;;
    s)
      show_mode="true"
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

if [ $OPTIND -le $# ]; then
    dir="${@:$OPTIND:1}"
else
    dir="."
fi

if [ -d "$dir" ]; then
    process_directory "$dir" "$write_mode" "$delete_mode" "$show_mode" "$hide_mode"
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "Number of ERRORs encountered: [$ERROR_COUNT]"
        exit 1
    fi
else
    echo "Error: Directory $dir does not exist."
    exit 1
fi
