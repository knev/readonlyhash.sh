#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") [OPTIONS|((-w|-d) --force)] [PATH]"
    echo "Options:"
	echo "  -v, --verify   Verify computed hashes against stored hashes"
    echo "  -w, --write    Write SHA256 hashes for files into .roh directory"
    echo "  -d, --delete   Delete hash files for specified files"
    echo "  -s, --show     Move hash files from .roh to file's directory"
    echo "  -i, --hide     Move hash files from file's directory to .roh"
    echo "      --force    Force operation even if hash files do not match"
    echo "  -h, --help     Display this help and exit"
    echo
	echo "Note: Options -v, -w, -d, and -s are mutually exclusive."
    echo "If no directory is specified, the current directory is used."
}

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
    local force_mode="$3"

    local hash_fname="$(basename "$fpath").sha256"
    #local roh_hash_file="$(dirname "$file")/$ROH_DIR/$hash_file"
    local roh_hash_fpath="$dir/$ROH_DIR/$hash_fname"

    if [ -f "$dir/$hash_fname" ]; then
        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash file [$dir/$hash_fname] exists and is NOT hidden"
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
			if [ "$force_mode" = "true" ]; then
				if echo "$new_hash" > "$roh_hash_fpath"; then
					echo "File: [$dir] \"$(basename "$fpath")\" -- hash mismatch, [$roh_hash_fpath] exists; new hash stored [$new_hash] -- FORCED!"
					return 0  # No error
				else
					echo "ERROR: [$dir] \"$(basename "$fpath")\" -- failed to write hash to [$roh_hash_fpath] -- (FORCED)"
					((ERROR_COUNT++))
					return 1  # Signal that an error occurred
				fi
			else
				echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch, [$roh_hash_fpath] exists with stored [$stored]"
				((ERROR_COUNT++))
				return 1  # Signal that an error occurred
			fi
		fi
	fi

	if echo "$new_hash" > "$roh_hash_fpath"; then
		echo "File: [$new_hash]: [$dir] \"$(basename "$fpath")\" -- OK"
		return 0  # No error
	else
		echo "ERROR: [$dir] \"$(basename "$fpath")\" -- failed to write hash to [$roh_hash_fpath]"
		((ERROR_COUNT++))
		return 1  # Signal that an error occurred
	fi
}

# Function to delete hash files
delete_hash() {
    local dir="$1"
    local fpath="$2"
    local force_mode="$3"

    local hash_fname="$(basename "$fpath").sha256"
    local roh_hash_fpath="$dir/$ROH_DIR/$hash_fname"

    if [ -f "$dir/$hash_fname" ]; then
        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- found existing hash in [$dir]; can only delete hidden hashes"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
	fi

    if [ ! -f "$roh_hash_fpath" ]; then
        # echo "ERROR: [$dir] \"$(basename "$file")\" -- NO hash file found in [$dir/$ROH_DIR]"
        # ((ERROR_COUNT++))
        # return 1  # Error, hash file does not exist
		return 0
    fi

	local computed_hash=$(generate_hash "$fpath")
	local stored=$(stored_hash "$roh_hash_fpath")
	
	if [ "$computed_hash" = "$stored" ]; then
		rm "$roh_hash_fpath"
		echo "File: [$dir] \"$(basename "$fpath")\" -- hash file in [$dir/$ROH_DIR] deleted -- OK"
		return 0  # No error
	else
		if [ "$force_mode" = "true" ]; then
			rm "$roh_hash_fpath"
			echo "File: [$dir] \"$(basename "$fpath")\" -- hash mismatch, [$roh_hash_fpath] deleted with stored [$stored] -- FORCED!"
			return 0
		else
			echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch, cannot delete [$roh_hash_fpath] with stored [$stored]"
			((ERROR_COUNT++))
			return 1  # Error, hash mismatch
		fi
	fi
}

verify_hash() {
    local dir="$1"
    local fpath="$2"

    local hash_fname="$(basename "$fpath").sha256"
    local roh_hash_fpath="$dir/$ROH_DIR/$hash_fname"

    if [ ! -f "$roh_hash_fpath" ]; then
        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- no hash file exists in [$dir/$ROH_DIR]"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
	fi

	local computed_hash=$(generate_hash "$fpath")
	local stored=$(stored_hash "$roh_hash_fpath")
        
	if [ "$computed_hash" = "$stored" ]; then
		#echo "File: $(basename "$file") -- hash matches: [$computed_hash]"
		echo "File: [$computed_hash]: [$dir] \"$(basename "$fpath")\" -- OK"
		return 0  # No error
	else
		echo "ERROR: [$dir] \"$(basename "$fpath")\" - hash mismatch: [$roh_hash_fpath] stored [$stored], computed [$computed_hash]"
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
			if [ "$computed_hash" != "$stored" ]; then
				echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch, [$dest_path/$hash_fname] exists with stored [$stored], not moving (${action})"
				((ERROR_COUNT++))
				return 1
			fi
		fi

        mv "$src_path/$hash_fname" "$dest_path/$hash_fname"
        echo "File: [$dir] \"$(basename "$fpath")\" -- ${action}ing hash file [$dest_path/$hash_fname] -- OK"
        return 0  # No error
	else
		if [ -f "$dest_path/$hash_fname" ]; then
			local stored=$(stored_hash "$dest_path/$hash_fname")
			if [ "$computed_hash" = "$stored" ]; then
				echo "File: [$dir] \"$(basename "$fpath")\" -- hash file [$dest_path/$hash_fname] exists, not moving (${action}) -- OK"
				return 0  # No error
			fi
		fi

        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- NO hash file found in [$src_path], not ${action}ing"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist for the action
    fi
}

# Function to process directory contents recursively
process_directory() {
    local dir="$1"
    local verify_mode="$2"
    local write_mode="$3"
    local delete_mode="$4"
    local show_mode="$5"
    local hide_mode="$6"
    local force_mode="$7"
	
	echo "Processing directory: [$dir]"
	if [ "$write_mode" = "true" ] || [ "$hide_mode" = "true" ]; then
	    ensure_dir "$dir/$ROH_DIR"
	fi

    for entry in "$dir"/*; do
		# If the entry is a directory, process it recursively
        if [ -d "$entry" ]; then
			process_directory "$entry" "$verify_mode" "$write_mode" "$delete_mode" "$show_mode" "$hide_mode" "$force_mode"

		# else ...
        elif [ -f "$entry" ] && [[ ! $(basename "$entry") =~ \.sha256$ ]]; then
            if check_extension "$entry"; then
                echo "ERROR: [$dir] $(basename "$entry") -- file with restricted extension"
				((ERROR_COUNT++))
            else
                if [ "$delete_mode" = "true" ]; then
                    delete_hash "$dir" "$entry" "$force_mode"
                elif [ "$write_mode" = "true" ]; then
					write_hash "$dir" "$entry" "$force_mode"
                elif [ "$show_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "show"
                elif [ "$hide_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "hide"
                elif [ "$verify_mode" = "true" ]; then
                    verify_hash "$dir" "$entry" 
				#else	
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
verify_mode="false"
write_mode="false"
delete_mode="false"
hide_mode="false"
show_mode="false"
force_mode="false"
while getopts ":vwdsih:-:" opt; do
  case $opt in
    v)
      verify_mode="true"
      ;;	
    w)
      write_mode="true"
      ;;
    d)
      delete_mode="true"
      ;;
    i)
      hide_mode="true"
      ;;
    s)
      show_mode="true"
      ;;
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
        verify)
          verify_mode="true"
          ;;		
        write)
          write_mode="true"
          ;;
        delete)
          delete_mode="true"
          ;;
        hide)
          hide_mode="true"
          ;;
        show)
          show_mode="true"
          ;;
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

# Check if no mode is specified
if [ "$write_mode" = "false" ] && [ "$delete_mode" = "false" ] && [ "$show_mode" = "false" ] && [ "$hide_mode" = "false" ] && [ "$verify_mode" = "false" ]; then
    usage
    exit 0
fi

# Check for mutually exclusive flags
mutual_exclusive_count=0
for mode in "$write_mode" "$delete_mode" "$show_mode" "$hide_mode"; do
    if [ "$mode" = "true" ]; then
        ((mutual_exclusive_count++))
    fi
done

if [ $mutual_exclusive_count -gt 1 ]; then
    echo "Error: Options -w, -d, -s, and -h are mutually exclusive. Please use only one." >&2
    usage
    exit 1
fi

# Check for force_mode usage
if [ "$force_mode" = "true" ] && [ "$delete_mode" != "true" ] && [ "$write_mode" != "true" ]; then
    echo "Error: --force can only be used with -d/--delete or -w/--write." >&2
    usage
    exit 1
fi

# Main execution
if [ $OPTIND -le $# ]; then
    dir="${@:$OPTIND:1}"
else
    dir="."
fi

if [ -d "$dir" ]; then
    process_directory "$dir" "$verify_mode" "$write_mode" "$delete_mode" "$show_mode" "$hide_mode" "$force_mode"
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "Number of ERRORs encountered: [$ERROR_COUNT]"
		echo
        exit 1
    fi
else
    echo "Error: Directory $dir does not exist"
	echo
    exit 1
fi

echo "Done."
echo
