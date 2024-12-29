#!/bin/bash

usage() {
	echo
    echo "Usage: $(basename "$0") [OPTIONS|(-w|-d) --force] [PATH]"
    echo "Options:"
	echo "      --hash     Generate a hash of a single file"
	echo "  -v, --verify   Verify computed hashes against stored hashes"
    echo "  -w, --write    Write SHA256 hashes for files into .roh directory"
    echo "  -d, --delete   Delete hash files for specified files"
    echo "  -i, --hide     Move hash files from file's directory to .roh"
    echo "  -s, --show     Move hash files from .roh to file's directory"
    echo "  -r, --recover  Attempt to recover orphaned hashes using verify"
    echo "  -h, --help     Display this help and exit"
	echo 
	echo "Note: options -v, -w, -d, -i, -s and -r are mutually exclusive."
	echo 
	echo "Flags:"
    echo "  --force        Force operation even if hash files do not match"
    echo
    echo "If no directory is specified, the current directory is used."
	echo
}

# List of file extensions to avoid, comma separated
EXTENSIONS_TO_AVOID="rslsi,rslsv,rslsz,rsls"

ROOT="."
ROH_DIR=".roh.git"

# Variable for SHA-256 hash command
#SHA256_BIN="sha256sum" # linux native, macOS via brew install coreutils
SHA256_BIN="shasum -a 256" # macOS native
#SHA256_BIN="openssl sha256" # pre-installed on macOS
HASH="sha256"

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

#------------------------------------------------------------------------------------------------------------------------------------------

# Ensure .roh directory exists
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir "$dir"
    fi
}

generate_hash() {
    local file="$1"
	if [ ! -r "$file" ]; then
        echo "ERROR: -- file [$file] not readable or permission denied" >&2
        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash file [$dir_hash_fpath] exists/(NOT hidden)"
        return 1
    fi
    echo $($SHA256_BIN "$file" | awk '{print $1}')
}

stored_hash() {
    local hash_file="$1"
    cat "$hash_file" 2>/dev/null || echo "0000000000000000000000000000000000000000000000000000000000000000"
}

#------------------------------------------------------------------------------------------------------------------------------------------

remove_top_dir() { [ "$1" = "$2" ] && echo || echo "${2#$1/}"; }
# remove_top_dir() {
#     local parent_dir="$1"
#     local dir="$2"
#     local result=${dir#${parent_dir}/}
#     # If string1 is the same as string2, result should be an empty string
#     if [ "$parent_dir" = "$dir" ]; then
#         result=""
#     fi
#     echo "$result"
# }

# given the path of the file, return the path of the hash (hidden in $ROH_DIR)
fpath_to_hash_fpath() {
    local dir="$1"
	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
    local fpath="$2"

    local hash_fname="$(basename "$fpath").$HASH"
    local roh_hash_path="$ROOT/$ROH_DIR${sub_dir:+/}$sub_dir/$hash_fname"
    echo "$roh_hash_path"
}

# given the path of the file, return the path of the hash (placed/shown next to the file)
fpath_to_dir_hash_fpath() {
    local dir="$1"
    local fpath="$2"

    local hash_fname="$(basename "$fpath").$HASH"
    echo "$dir/$hash_fname"
}

# given the path to the hidden hash, return the path to the corresponding file
hash_fpath_to_fpath() {
    local roh_hash_fpath="$1"

	local sub_filepath="$(remove_top_dir "$ROOT/$ROH_DIR" "$roh_hash_fpath")"
	local fpath="$ROOT/${sub_filepath%.$HASH}"
	echo "$fpath"
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Function to recover hash files
recover_hash() {
    local dir="$1"
    local fpath="$2"
 	
	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	local computed_hash=$(generate_hash "$fpath")

    # Search for hash files in current directory and subdirectories
	while IFS= read -r -d '' found_roh_hash_fpath; do
        #if [ -f "$found_roh_hash_fpath" ]; then # "find -type f" takes care of this
		local found_stored=$(stored_hash "$found_roh_hash_fpath")
		#echo "FOUND: $found_roh_hash_fpath [$found_stored]"
        if [ "$computed_hash" = "$found_stored" ]; then
			# check if the hash has a valid corresponding file
			local found_fpath="$(hash_fpath_to_fpath "$found_roh_hash_fpath")"
			if [ -f "$found_fpath" ]; then
				echo "WARN: [$dir] \"$(basename "$fpath")\" -- ..."
				echo "            ... stored [$found_roh_hash_fpath] -- identical file"
				echo "      ... for computed [$fpath][$computed_hash]"
			else
				local roh_hash_just_path="$ROOT/$ROH_DIR${sub_dir:+/}$sub_dir"
				mkdir -p "$roh_hash_just_path"
				mv "$found_roh_hash_fpath" "$roh_hash_fpath"
				# echo "MV: mkdir $roh_hash_just_path; [$found_roh_hash_fpath] [$roh_hash_fpath]"
				echo "Recovered: [$dir] \"$(basename "$fpath")\" -- hash in [$found_roh_hash_fpath][$found_stored]"
				echo "           ... restored for [$fpath]"
				echo "           ...           in [$roh_hash_fpath]"
				return 0 
			fi
        fi
	done < <(find "$ROOT/$ROH_DIR" -name "*.$HASH" -type f -print0)

    echo "ERROR: [$dir] \"$(basename "$fpath")\" -- could not recover hash for file [$fpath][$computed_hash]"
    ((ERROR_COUNT++))
    return 1  # Recovery failed
}

verify_hash() {
    local dir="$1"
    local fpath="$2"
    local recover_mode="$3"	

	# local hash_fname="$(basename "$fpath").$HASH"
	# local roh_hash_path="$ROOT/$ROH_DIR${sub_dir:+/}$sub_dir" # ${sub_dir:+/} expands to a slash / if sub_dir is not empty, otherwise, it expands to nothing. 
	# local roh_hash_fpath=$roh_hash_path/$hash_fname

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	local computed_hash=$(generate_hash "$fpath")

	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
    if [ -f "$dir_hash_fpath" ]; then
        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash file [$dir_hash_fpath] exists/(NOT hidden)"
        ((ERROR_COUNT++))
        return 1  
	fi

    if [ ! -f "$roh_hash_fpath" ]; then
		# echo "$dir" "$fpath" "[$computed_hash]"
		if [ "$recover_mode" = "true" ]; then
			recover_hash "$dir" "$fpath"
			return 1
		else
			#echo "ERROR: [$dir] \"$(basename "$fpath")\" -- NO hash file [$roh_hash_fpath] found for [$fpath][$computed_hash]"
			echo "WARN: [$dir] \"$(basename "$fpath")\" -- ..."
			echo "        ... hash file [$roh_hash_fpath] -- NOT found"
			echo "              ... for [$fpath][$computed_hash]"
			((ERROR_COUNT++))
			return 1  # Error, hash file does not exist
		fi
	fi

	local stored=$(stored_hash "$roh_hash_fpath")
        
	if [ "$computed_hash" = "$stored" ]; then
		if [ "$recover_mode" != "true" ]; then
			#echo "File: $(basename "$file") -- hash matches: [$computed_hash]"
			echo "File: [$computed_hash]: [$dir] \"$(basename "$fpath")\" -- [$fpath] -- OK"
		fi
		return 0  # No error
	else
		# echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch: stored [$roh_hash_fpath][$stored], computed [$fpath][$computed_hash]"
		echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
		echo "       ...   stored [$stored]: [$roh_hash_fpath]"
		echo "       ... computed [$computed_hash]: [$fpath]"
		((ERROR_COUNT++))
		return 1  # Error, hash mismatch
	fi
}

# New function for hashing
write_hash() {
    local dir="$1"
    local fpath="$2"
    local force_mode="$3"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	#echo "* [$dir]-[$ROOT]= [$sub_dir]; $roh_hash_fpath"

	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
    if [ -f "$dir_hash_fpath" ]; then
        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash file [$dir_hash_fpath] exists/(NOT hidden)"
        ((ERROR_COUNT++))
        return 1  
	fi

	# local new_hash=$(generate_hash "$fpath")

    if [ -f "$roh_hash_fpath" ]; then
        # local stored=$(stored_hash "$roh_hash_fpath")

        # if [ "$new_hash" = "$stored" ]; then
		# 	# echo "File: [$new_hash]: [$dir] $(basename "$fpath") -- OK"
		# 	return 0
		# else
		# 	if [ "$force_mode" = "true" ]; then
		# 		if { echo "$new_hash" > "$roh_hash_fpath"; } 2>/dev/null; then
		# 			# echo "File: [$dir] \"$(basename "$fpath")\" -- hash mismatch, [$roh_hash_fpath] exists; new hash stored [$new_hash] -- FORCED!"
		# 			echo "File: [$dir] \"$(basename "$fpath")\" -- hash mismatch: -- ..."
		# 			echo "       ...   stored [$stored]: [$roh_hash_fpath]"
		# 			echo "       ... computed [$new_hash]: [$fpath] -- new hash stored -- FORCED!"
		# 			return 0  # No error
 		# 		else
 		# 			echo "ERROR: [$dir] \"$(basename "$fpath")\" -- failed to write hash to [$roh_hash_fpath] -- (FORCED)"
 		# 			((ERROR_COUNT++))
 		# 			return 1  # Signal that an error occurred
		# 		fi
		# 	else
		# 		echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch, [$roh_hash_fpath] exists with stored [$stored]"
		# 		((ERROR_COUNT++))
		# 		return 1  # Signal that an error occurred
		# 	fi
		# fi

		return 0  
	fi

	local new_hash=$(generate_hash "$fpath")

	local roh_hash_just_path="$ROOT/$ROH_DIR${sub_dir:+/}$sub_dir"
	mkdir -p "$roh_hash_just_path"
	if { echo "$new_hash" > "$roh_hash_fpath"; } 2>/dev/null; then
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

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
    if [ -f "$dir_hash_fpath" ]; then
        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash file [$dir_hash_fpath] exists/(NOT hidden); can only delete hidden hashes"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist
	fi

    if [ ! -f "$roh_hash_fpath" ]; then
        # echo "ERROR: [$dir] \"$(basename "$file")\" -- NO hash file found in []"
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

manage_hash_visibility() {
    local dir="$1"
    local fpath="$2"
    local action="$3"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	local src_fpath
    local dest_fpath
    if [ "$action" = "show" ]; then
		src_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
		dest_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath") 
    elif [ "$action" = "hide" ]; then
		src_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
		dest_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
    else
        echo "ERROR: invalid hash visibility action"
        exit 1
    fi

	# # src yes, dest yes -> check dest hash, if computed!=dest= err else mv
	# # src yes, dest no  -> mv
	# # src no,  dest yes -> check dest hash, if computed=dest; OK else err
	# # src no,  dest no  -> err
	
	# src yes, dest yes -> err
	# src yes, dest no  -> mv
	# src no,  dest yes -> err
	# src no,  dest no  -> err

	local past_tense=$([ "$action" = "show" ] && echo "shown" || echo "hidden")
	# local computed_hash=$(generate_hash "$fpath")

	if [ -f "$src_fpath" ]; then
		if [ -f "$dest_fpath" ]; then
			# local stored=$(stored_hash "$dest_fpath")
			# if [ "$computed_hash" = "$stored" ]; then
			# 	#echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch, [$dest_fpath] exists/($past_tense) with stored [$stored], not moving/(${action}ing)"
			# 	echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
			# 	echo "       ... [$dest_fpath][$stored] exists/($past_tense), not moving/(not $past_tense)"
			# 	((ERROR_COUNT++))
			# 	return 1
			# fi
			echo "ERROR: [$dir] \"$(basename "$fpath")\" -- [$dest_fpath][$stored] exists, not moving/(not $past_tense)"
			((ERROR_COUNT++))
			return 1
		fi

		if [ "$action" = "hide" ]; then
			local roh_hash_just_path="$ROOT/$ROH_DIR${sub_dir:+/}$sub_dir"
			mkdir -p "$roh_hash_just_path"
		fi
        mv "$src_fpath" "$dest_fpath"
        echo "File: [$dir] \"$(basename "$fpath")\" -- hash file [$dest_fpath] moved($past_tense) -- OK"
        return 0  # No error
	else
		# if [ -f "$dest_fpath" ]; then
		# 	local stored=$(stored_hash "$dest_fpath")
		# 	if [ "$computed_hash" = "$stored" ]; then
		# 		echo "File: [$dir] \"$(basename "$fpath")\" -- hash file [$dest_fpath] exists($past_tense), NOT moving/(NOT $past_tense) -- OK"
		# 		return 0  # No error
		# 	fi
		# fi

        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- NO hash file found [$src_fpath] for [$fpath], not $past_tense"
        ((ERROR_COUNT++))
        return 1  # Error, hash file does not exist for the action
    fi
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Function to process directory contents recursively
process_directory() {
    local dir="$1"
	# local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
    local verify_mode="$2"
    local write_mode="$3"
    local delete_mode="$4"
    local hide_mode="$5"
    local show_mode="$6"
    local recover_mode="$7"	
    local force_mode="$8"

	# ?! do we care about empty directories
	#
	#	if [ "$verify_mode" = "true" ]; then
	#		if [ ! -d "$ROOT/$ROH_DIR/$sub_dir" ]; then
	#			echo "ERROR: [$dir] -- not a READ-ONLY directory, missing [$ROOT/$ROH_DIR/$sub_dir]"
	#			((ERROR_COUNT++))
	#			return 1 
	#		fi
	#	fi

	# echo "Processing directory: [$dir]"

    for entry in "$dir"/*; do
		# If the entry is a directory, process it recursively
        if [ -d "$entry" ]; then
			process_directory "$entry" "$verify_mode" "$write_mode" "$delete_mode" "$hide_mode" "$show_mode" "$recover_mode" "$force_mode"

		# else ...
        elif [ -f "$entry" ] && [[ ! $(basename "$entry") =~ \.${HASH}$ ]]; then
			if [ "$delete_mode" != "true" ]; then
				if check_extension "$entry"; then
					echo "ERROR: [$dir] \"$(basename "$entry")\" -- file with restricted extension"
					((ERROR_COUNT++))
					continue;
				fi

                if [ "$verify_mode" = "true" ]; then
                    verify_hash "$dir" "$entry" 
                elif [ "$recover_mode" = "true" ]; then
                    verify_hash "$dir" "$entry" "$recover_mode"
                elif [ "$write_mode" = "true" ]; then
					write_hash "$dir" "$entry" "$force_mode"
                elif [ "$hide_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "hide"
                elif [ "$show_mode" = "true" ]; then
                    manage_hash_visibility "$dir" "$entry" "show"
				#else	
                fi
			else
				delete_hash "$dir" "$entry" "$force_mode"
            fi
        fi
    done

	# it is not guaranteed that sub_dir has been created in $ROH_DIR for the
	# sub_dir we are processing e.g., it could be an empty sub dir.
	#
	# local roh_hash_just_path="$ROOT/$ROH_DIR${sub_dir:+/}$sub_dir"
	# [ ! -d "$roh_hash_just_path" ] && return 0
	# ...
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Parse command line options
hash_mode="false"
verify_mode="false"
write_mode="false"
delete_mode="false"
hide_mode="false"
show_mode="false"
force_mode="false"
recover_mode="false"
while getopts "vwdisrh-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
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
	r)
	  recover_mode="true"
	  ;;
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
        hash)
          hash_mode="true"
          ;;		
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
        recover)
          recover_mode="true"
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

# Main execution
if [ $OPTIND -le $# ]; then
    ROOT="${@:$OPTIND:1}"
fi

# Check if no mode is specified: if there is a [:space:] in getopts, this will fail e.g., hide_mode= "true"
if [ "$hash_mode" = "false" ] && [ "$verify_mode" = "false" ] && [ "$write_mode" = "false" ] && [ "$delete_mode" = "false" ] && [ "$show_mode" = "false" ] && [ "$hide_mode" = "false" ] && [ "$recover_mode" = "false" ]; then
    usage
    exit 0
fi

if [ "$hash_mode" = "true" ]; then
	if [ -f "$ROOT" ]; then
		fpath="$ROOT"
		computed_hash=$(generate_hash "$fpath")

		echo "File: [$computed_hash]: \"$(basename "$fpath")\" -- OK"
		exit 0
	fi

    echo "ERROR: [$ROOT] not a file"
	echo
    exit 1
fi

# Check for mutually exclusive flags
mutual_exclusive_count=0
for mode in "$verify_mode" "$write_mode" "$delete_mode" "$hide_mode" "$show_mode" "$recover_mode"; do
    if [ "$mode" = "true" ]; then
        ((mutual_exclusive_count++))
    fi
done

if [ $mutual_exclusive_count -gt 1 ]; then
    echo "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one." >&2
    usage
    exit 1
fi

# Check for force_mode usage
if [ "$force_mode" = "true" ] && [ "$delete_mode" != "true" ] && [ "$write_mode" != "true" ]; then
    echo "ERROR: --force can only be used with -d/--delete or -w/--write." >&2
    usage
    exit 1
fi

#------------------------------------------------------------------------------------------------------------------------------------------

run_directory_process() {
    local dir="$1"
	#local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
    local verify_mode="$2"
    local write_mode="$3"
    local delete_mode="$4"
    local hide_mode="$5"
    local show_mode="$6"
    local recover_mode="$7"	
    local force_mode="$8"
	
	if [ "$write_mode" = "true" ] || [ "$hide_mode" = "true" ]; then
		ensure_dir "$ROOT/$ROH_DIR"
	fi

    process_directory "$@"	

	# Needed for verifying a directory for which write never got called
	[ ! -d "$ROOT/$ROH_DIR" ] && return 0
    
	# Now check for hash files without corresponding files
	while IFS= read -r roh_hash_fpath; do
		local fpath="$(hash_fpath_to_fpath "$roh_hash_fpath")"
		# echo "FPATH: [$roh_hash_fpath] [$fpath]"

		if [ -d "$roh_hash_fpath" ]; then
			if [ "$delete_mode" = "true" ] || [ "$(basename "$roh_hash_fpath")" != "$ROH_DIR" ]; then
				#if [ "$(ls -A "/path/to/directory" | wc -l)" -eq 0 ]; then
				if [ -z "$(find "$roh_hash_fpath" -mindepth 1 -print -quit)" ]; then
					rmdir "$roh_hash_fpath" || echo "Failed to delete $roh_hash_fpath"
				fi
			fi
			continue;
		fi

		if ! stat "$fpath" >/dev/null 2>&1; then
			local stored=$(stored_hash "$roh_hash_fpath")
			echo "ERROR: --                ... file [$fpath] -- NOT found"
			echo "       ... for corresponding hash [$roh_hash_fpath][$stored]"
			((ERROR_COUNT++))
		fi
	# exclude "$ROOT/$ROH_DIR/.git" using --prune, return only files
	# sort, because we want lower directories removed first, so upper directories can be empty and removed
	# done < <(find "$ROOT/$ROH_DIR" -path "$ROOT/$ROH_DIR/.*" -prune -o -type f -name "*" -print)
	done < <(find "$ROOT/$ROH_DIR" -path "$ROOT/$ROH_DIR/.*" -prune -o -print | sort -r)


	if [ "$write_mode" = "true" ] && [ $ERROR_COUNT -eq 0 ]; then
		# Check if the directory name ends with '.ro'
        if [[ "$dir" != "." && "$dir" != ".." && ! $dir == *.ro ]]; then
			# Rename the directory by adding '.ro' if it doesn't already have it
			mv "$dir" "$dir.ro"
			echo "Renamed $dir to ${dir}.ro"
		fi		
	elif [ "$delete_mode" = "true" ] && [ $ERROR_COUNT -eq 0 ]; then
	    # Check if the directory name ends with '.ro'
        if [[ "$dir" != "." && "$dir" != ".." && $dir == *.ro ]]; then
	        new_name=${dir%.ro}
	        # Rename the directory by removing '.ro'
	        mv "$dir" "$new_name"
	        echo "Renamed $dir to $new_name"
	    fi	
	fi
}

if [ ! -d "$ROOT" ]; then
    echo "ERROR: Directory [$ROOT] does not exist"
	echo
    exit 1
fi

run_directory_process "$ROOT" "$verify_mode" "$write_mode" "$delete_mode" "$hide_mode" "$show_mode" "$recover_mode" "$force_mode"
if [ $ERROR_COUNT -gt 0 ]; then
	echo "Number of ERRORs encountered: [$ERROR_COUNT]"
	echo
	exit 1
fi

echo "Done."
echo

#------------------------------------------------------------------------------------------------------------------------------------------
