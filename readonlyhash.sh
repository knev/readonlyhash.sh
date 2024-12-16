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

generate_hash() {
    local file="$1"
    echo $($SHA256_BIN "$file" | awk '{print $1}')
}

stored_hash() {
    local hash_file="$1"
    cat "$hash_file" 2>/dev/null || echo "no_hash_file"
}

# New function for hashing
write_hash() {
    local dir="$1"
    local fpath="$2"
    local hash_fname="$(basename "$fpath").sha256"
    #local roh_hash_file="$(dirname "$file")/$ROH_DIR/$hash_file"
    local roh_hash_fpath="$dir/$ROH_DIR/$hash_fname"

    if [ -f "$dir/$hash_fname" ]; then
        echo "ERROR: [$dir] $(basename "$fpath") -- hash file [$dir/$hash_fname] exists and is NOT hidden"
        ((ERROR_COUNT++))
        return 1  # Signal that an error occurred
	fi

	local new_hash=$(generate_hash "$fpath")

    if [ -f "$roh_hash_fpath" ]; then
        local stored=$(stored_hash "$roh_hash_fpath")

        if [ "$new_hash" = "$stored" ]; then
			# echo "File: [$new_hash]: [$dir] $(basename "$fpath") -- OK"
			return 0
		else
			echo "ERROR: [$dir] $(basename "$fpath") -- hash mismatch, [$roh_hash_fpath] exists with stored [$stored]"
			((ERROR_COUNT++))
			return 1  # Signal that an error occurred
		fi
	fi

	if echo "$new_hash" > "$roh_hash_fpath"; then
		echo "File: [$new_hash]: [$dir] $(basename "$fpath") -- OK"
		return 0  # No error
	else
		echo "ERROR: [$dir] $(basename "$fpath") -- failed to write hash to [$roh_hash_fpath]"
		((ERROR_COUNT++))
		return 1  # Signal that an error occurred
	fi
}

# Function to delete hash files
delete_hash() {
    local dir="$1"
    local fpath="$2"
    local hash_fname="$(basename "$fpath").sha256"
    local roh_hash_fpath="$dir/$ROH_DIR/$hash_fname"

    if [ -f "$dir/$hash_fname" ]; then
        echo "ERROR: [$dir] $(basename "$fpath") -- found existing hash in [$dir]; can only delete hidden hashes"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
	fi

    if [ ! -f "$roh_hash_fpath" ]; then
        # echo "ERROR: [$dir] $(basename "$file") -- NO hash file found in [$dir/$ROH_DIR]"
        # ((ERROR_COUNT++))
        # return 1  # Error, hash file does not exist
		return 0
    fi

	local computed_hash=$(generate_hash "$fpath")
	local stored=$(stored_hash "$roh_hash_fpath")
	
	if [ "$computed_hash" = "$stored" ]; then
		rm "$roh_hash_fpath"
		echo "File: [$dir] $(basename "$fpath") -- hash file in [$dir/$ROH_DIR] deleted -- OK"
		return 0  # No error
	else
		echo "ERROR: [$dir] $(basename "$fpath") -- hash mismatch, cannot delete [$roh_hash_fpath] with stored [$stored]"
		((ERROR_COUNT++))
		return 1  # Error, hash mismatch
	fi
}

verify_hash() {
    local dir="$1"
    local fpath="$2"
    local hash_fname="$(basename "$fpath").sha256"
    local roh_hash_fpath="$dir/$ROH_DIR/$hash_fname"

    if [ ! -f "$roh_hash_fpath" ]; then
        echo "ERROR: [$dir] $(basename "$fpath") -- no hash file exists in [$dir/$ROH_DIR]"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
	fi

	local computed_hash=$(generate_hash "$fpath")
	local stored=$(stored_hash "$roh_hash_fpath")
        
	if [ "$computed_hash" = "$stored" ]; then
		#echo "File: $(basename "$file") -- hash matches: [$computed_hash]"
		echo "File: [$computed_hash]: [$dir] $(basename "$file") -- OK"
		return 0  # No error
	else
		echo "ERROR: [$dir] $(basename "$fpath") - hash mismatch: [$roh_hash_fpath] stored [$stored], computed [$computed_hash]"
		((ERROR_COUNT++))
		return 1  # Error, hash mismatch
	fi
}

manage_hash_visibility() {
    local dir="$1"
    local fpath="$2"
    local action="$3"
    local hash_fname="$(basename "$fpath").sha256"

	local src_path
    local dest_path
    if [ "$action" = "show" ]; then
		src_path="$dir/$ROH_DIR"
		dest_path="$dir"
    elif [ "$action" = "hide" ]; then
		src_path="$dir"
		dest_path="$dir/$ROH_DIR"
    else
        echo "ERROR: invalid hash visibility action"
        exit 1
    fi

	# src yes, dest yes -> check dest hash, if computed!=dest= err else mv
	# src yes, dest no  -> mv
	# src no,  dest yes -> check dest hash, if computed=dest; OK else err
	# src no,  dest no  -> err
	
	local computed_hash=$(generate_hash "$fpath")

	if [ -f "$src_path/$hash_fname" ]; then
		if [ -f "$dest_path/$hash_fname" ]; then
			local stored=$(stored_hash "$dest_path/$hash_fname")
			if [ "$computed_hash" != "$stored_hash" ]; then
				echo "ERROR: [$dir] $(basename "$fpath") -- existing hash file found in [$src_path], not ${action}ing"
				((ERROR_COUNT++))
				return 1
			fi
		fi

        mv "$src_path/$hash_fname" "$dest_path/$hash_fname"
        echo "File: [$dir] $(basename "$fpath") -- ${action}ing hash file [$dest_path/$hash_fname] -- OK"
        return 0  # No error
	else
		if [ -f "$dest_path/$hash_fname" ]; then
			local stored=$(stored_hash "$dest_path/$hash_fname")
			if [ "$computed_hash" = "$stored_hash" ]; then
				echo "File: [$dir] $(basename "$fpath") -- ${action}ing hash file [$dest_path/$hash_fname] -- OK"
				return 0  # No error
			fi
		fi

        echo "ERROR: [$dir] $(basename "$fpath") -- hash file NOT found in [$src_path], not ${action}ing"
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
					write_hash "$dir" "$entry"
                elif [ "$show_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "show"
                elif [ "$hide_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "hide"
                else
                    verify_hash "$dir" "$entry" 
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
		echo
        exit 1
    fi
else
    echo "Error: Directory $dir does not exist."
	echo
    exit 1
fi

echo "Done."
echo
