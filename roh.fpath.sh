#!/bin/bash

usage() {
	echo
    echo "Usage: $(basename "$0") <COMMAND|write [--force] [--show]|<show|hide> [--force]> [--roh-dir PATH] <PATH>"
    echo "       $(basename "$0") <write|verify --hash> <PATH/GLOBSPEC>"
    echo "Commands:"
	echo "      verify     Verify computed hashes against stored hashes"
    echo "      write      Write SHA256 hashes for files into .roh directory"
    echo "      delete     Delete hash files for specified files"
    echo "      hide       Move hash files from file's directory to .roh"
    echo "      show       Move hash files from .roh to file's directory"
    echo "      recover    Attempt to recover orphaned hashes using verify"
	echo
	echo "Options:"
	echo "      --hash     Generate a hash of a single file(s)"
	echo "      --roh-dir  Specify the readonly hash path"
    echo "      --force    Force operation even if hash files do not match"
    echo "  -h, --help     Display this help and exit"
    echo
    echo "If no directory is specified, the current directory is used."
	echo
}

# List of file extensions to avoid, comma separated
EXTENSIONS_TO_AVOID="rslsi,rslsv,rslsz,rsls"

ROOT="_INVALID_"
ROH_DIR="./.roh.git"

# Variable for SHA-256 hash command
#SHA256_BIN="sha256sum" # linux native, macOS via brew install coreutils
SHA256_BIN="shasum -a 256" # macOS native
#SHA256_BIN="openssl sha256" # pre-installed on macOS
HASH="sha256"

ERROR_COUNT=0
WARN_COUNT=0

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

remove_top_dir() {
  local base_dir="$1"
  local full_path="$2"

  # If the base_dir and full_path are identical, return an empty string
  if [[ "$base_dir" == "$full_path" ]]; then
    echo ""
    return
  fi

  # Normalize base_dir: remove trailing slashes and replace multiple slashes with a single slash
  base_dir=$(echo "$base_dir" | sed 's:/*$::' | sed 's://*:/:g')
  full_path=$(echo "$full_path" | sed 's://*:/:g')

  # Append a trailing slash to base_dir for matching
  base_dir="${base_dir}/"

  # Check if full_path starts with base_dir
  if [[ "$full_path" == "$base_dir"* ]]; then
    echo "${full_path#"$base_dir"}"
  else
    echo "$full_path"
  fi
}

# echo $(remove_top_dir "test" "test")"]" # output: ]
# echo $(remove_top_dir "2002 X.ro" "2002 X.ro/2002_FIRE!") # output: 2002_FIRE!
# echo $(remove_top_dir "2002.ro/." "2002.ro/./2002_FIRE!") # output: 2002_FIRE!
# echo $(remove_top_dir "2002.ro/" "2002.ro//2002_FIRE!") # output: 2002_FIRE!
# echo $(remove_top_dir "Fotos [space]/" "Fotos [space]//1999.ro/1999-07 Cool Runnings Memories") # output: 1999.ro/1999-07 Cool Runnings Memories
# echo $(remove_top_dir "Fotos [space/" "Fotos [space//1999.ro/1999-07 Cool Runnings Memories") # output: 1999.ro/1999-07 Cool Runnings Memories
# echo $(remove_top_dir "$PWD" "$PWD/Fotos") #output: Fotos
# echo $(remove_top_dir "$PWD/Fotos [space]/1999.ro" "$PWD/Fotos [space]/1999.ro/1999-07 Cool Runnings Memories") # output: 1999-07 Cool Runnings Memories
# exit


# given the path of the file, return the path of the hash (hidden in $ROH_DIR)
fpath_to_hash_fpath() {
    local dir="$1"
	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
    local fpath="$2"

    local hash_fname="$(basename "$fpath").$HASH"
    local roh_hash_path="$ROH_DIR${sub_dir:+/}$sub_dir/$hash_fname"
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

	local sub_filepath="$(remove_top_dir "$ROH_DIR" "$roh_hash_fpath")"
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
				((WARN_COUNT++))
			else
				local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
				mkdir -p "$roh_hash_just_path"
				mv "$found_roh_hash_fpath" "$roh_hash_fpath"
				# echo "MV: mkdir $roh_hash_just_path; [$found_roh_hash_fpath] [$roh_hash_fpath]"
				echo "Recovered: [$dir] \"$(basename "$fpath")\" -- hash in [$found_roh_hash_fpath][$found_stored]"
				echo "           ... restored for [$fpath]"
				echo "           ...           in [$roh_hash_fpath]"
				return 0 
			fi
        fi
	done < <(find "$ROH_DIR" -name "*.$HASH" -type f -print0)

    echo "ERROR: [$dir] \"$(basename "$fpath")\" -- could not recover hash for file [$fpath][$computed_hash]"
    ((ERROR_COUNT++))
    return 1  # Recovery failed
}

x_roh_hash="true" # exclusively roh hashes

verify_hash() {
    local dir="$1"
    local fpath="$2"
    local recover_mode="$3"	

	# local hash_fname="$(basename "$fpath").$HASH"
	# local roh_hash_path="$ROH_DIR${sub_dir:+/}$sub_dir" # ${sub_dir:+/} expands to a slash / if sub_dir is not empty, otherwise, it expands to nothing. 
	# local roh_hash_fpath=$roh_hash_path/$hash_fname

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")

	local computed_hash=$(generate_hash "$fpath")

    if [ -f "$roh_hash_fpath" ] && [ -f "$dir_hash_fpath" ]; then
		local stored_roh=$(stored_hash "$roh_hash_fpath")
		local stored_dir=$(stored_hash "$dir_hash_fpath")

        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- two hash files exist ..."
		echo "         ... hidden [$stored_roh][$roh_hash_fpath]"
		echo "          ... shown [$stored_dir][$dir_hash_fpath]"
		echo "       ... computed [$computed_hash]: [$fpath]"

		x_roh_hash="false"
        ((ERROR_COUNT++))
        return 1  
	fi

    if [ -f "$roh_hash_fpath" ]; then
		local stored=$(stored_hash "$roh_hash_fpath")

		if [ "$computed_hash" = "$stored" ]; then
			if [ "$recover_mode" != "true" ]; then
				#echo "  OK: $(basename "$file") -- hash matches: [$computed_hash]"
				echo "  OK: [$computed_hash]: [$dir] \"$(basename "$fpath")\" -- [$fpath]"
			fi
			return 0  # No error
		else
			echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
			echo "       ...   stored [$stored]: [$roh_hash_fpath]"
			echo "       ... computed [$computed_hash]: [$fpath]"
			((ERROR_COUNT++))
			return 1  # Error, hash mismatch
		fi

    elif [ -f "$dir_hash_fpath" ]; then
		local stored=$(stored_hash "$dir_hash_fpath")
	        
		x_roh_hash="false"
	        
		if [ "$computed_hash" = "$stored" ]; then
			if [ "$recover_mode" != "true" ]; then
				#echo "  OK: $(basename "$file") -- hash matches: [$computed_hash]"
				echo "  OK: [$computed_hash]: [$dir] \"$(basename "$fpath")\" -- [$fpath]"
			fi
			return 0  # No error
		else
			echo "ERROR: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
			echo "       ...   stored [$stored]: [$dir_hash_fpath]"
			echo "       ... computed [$computed_hash]: [$fpath]"
			((ERROR_COUNT++))
			return 1  # Error, hash mismatch
		fi 
	
	else
		# echo "$dir" "$fpath" "[$computed_hash]"
		if [ "$recover_mode" = "true" ]; then
			recover_hash "$dir" "$fpath"
			return 1
		else
			echo "WARN: [$dir] \"$(basename "$fpath")\" -- ..."
			echo "      ... hash file [$roh_hash_fpath] -- NOT found"
			echo "            ... for [$fpath][$computed_hash]"
			((WARN_COUNT++))
			return 1  # Error, hash file does not exist
		fi
	fi
}

# New function for hashing
write_hash() {
    local dir="$1"
    local fpath="$2"
	local visibility_mode="$3"
    local force_mode="$4"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")

	# echo "* [$dir]-[$ROOT]= [$sub_dir]; $roh_hash_fpath"
	# echo "* dir_hash_fpath: $dir_hash_fpath"

	# exist-R=F         , exist-D=T (eq-D=F)
	# exist-R=F         , exist-D=T (eq-D=T)
	# exist-R=F         , exist-D=F
	#---
	# exist-R=T (eq-R=F), exist-D=T (eq-D=F)
	# exist-R=T (eq-R=F), exist-D=T (eq-D=T)
	# exist-R=T (eq-R=F), exist-D=F
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=F)
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T)
	# exist-R=T (eq-R=T), exist-D=F

	local computed_hash=$(generate_hash "$fpath")

	local exists_and_not_eq="false"

    if [ -f "$roh_hash_fpath" ]; then
		local stored=$(stored_hash "$roh_hash_fpath")
		if [ "$computed_hash" != "$stored" ]; then
			# exist-R=T (eq-R=F)
			if [ "$force_mode" = "true" ]; then
				rm "$roh_hash_fpath"
				echo "WARN: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
				echo "      ... computed [$computed_hash]: [$fpath]"
				echo "      ...   stored [$stored]: [$roh_hash_fpath] -- removed (FORCED)!"
				((WARN_COUNT++))
			else
				echo "WARN: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
				echo "      ... computed [$computed_hash]: [$fpath]"
				echo "      ...   stored [$stored]: [$roh_hash_fpath]"
				((WARN_COUNT++))

				exists_and_not_eq="true"
			fi
		fi
	fi

	if [ -f "$dir_hash_fpath" ]; then
		local stored=$(stored_hash "$dir_hash_fpath")
		if [ "$computed_hash" != "$stored" ]; then
			# exist-D=T (eq-D=F)
			if [ "$force_mode" = "true" ]; then
				rm "$dir_hash_fpath"
				echo "WARN: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
				echo "      ... computed [$computed_hash]: [$fpath]"
				echo "      ...   stored [$stored]: [$dir_hash_fpath] -- removed (FORCED)!"
				((WARN_COUNT++))
			else
				echo "WARN: [$dir] \"$(basename "$fpath")\" -- hash mismatch: ..."
				echo "      ... computed [$computed_hash]: [$fpath]"
				echo "      ...   stored [$stored]: [$dir_hash_fpath]"
				((WARN_COUNT++))

				exists_and_not_eq="true"
			fi
		fi
	fi

	if [ "$exists_and_not_eq" = "true" ]; then
		return 0
	fi
	# echo "* \"$(basename "$fpath")\" "

	# exist-R=F         , exist-D=T (eq-D=T) // sh= T, nop
	# exist-R=F         , exist-D=F			 // sh= T, write to R, move R->D
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= T, (write to R), move R->D
	# exist-R=T (eq-R=T), exist-D=F          // sh= T, (write to R), move R->D

	# exist-R=F         , exist-D=T (eq-D=T) // sh= F, (write to R), move D->R
	# exist-R=F         , exist-D=F			 // sh= F, write to R
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= F, (write to R), move D->R
	# exist-R=T (eq-R=T), exist-D=F          // sh= F, (write to R)

	if ! [ -f "$dir_hash_fpath" ] && ! [ -f "$roh_hash_fpath" ]; then
		# write to R
		local new_hash=$(generate_hash "$fpath")
		local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
	
		if mkdir -p "$roh_hash_just_path" 2>/dev/null && { echo "$new_hash" > "$roh_hash_fpath"; } 2>/dev/null; then
			echo "  OK: [$new_hash]: [$dir] \"$(basename "$fpath")\""
			return 0  # No error
		else
			echo "ERROR: [$dir] \"$(basename "$fpath")\" -- failed to write hash to [$roh_hash_fpath]"
			((ERROR_COUNT++))
			return 1  # Signal that an error occurred
		fi
	fi

	# exist-R=F         , exist-D=T (eq-D=T) // sh= T, nop
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= T, move R->D, clobber
	# exist-R=T (eq-R=T), exist-D=F          // sh= T, move R->D

	# exist-R=F         , exist-D=T (eq-D=T) // sh= F, move D->R
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= F, move D->R, clobber
	#---
	# exist-R=T (eq-R=T), exist-D=F          // sh= F, nop

	if [ "$visibility_mode" = "show" ] && [ -f "$roh_hash_fpath" ]; then
		# move R->D: show
		manage_hash_visibility "$dir" "$entry" "show" "$force_mode"

	elif [ "$visibility_mode" != "show" ] && [ -f "$dir_hash_fpath" ]; then
		# move D->R: hide
		manage_hash_visibility "$dir" "$entry" "hide" "$force_mode"
	
	# else
	#	echo "  OK: [$computed_hash]: [$dir] \"$(basename "$fpath")\""
	fi

	#------

    # if [ -f "$roh_hash_fpath" ]; then
	# 	if [ "$force_mode" = "true" ]; then
	# 		local computed_hash=$(generate_hash "$fpath")
	#         local stored=$(stored_hash "$roh_hash_fpath")
	# 
	#         if [ "$computed_hash" = "$stored" ]; then
	# 			# echo "SKIP: [$computed_hash]: [$dir] $(basename "$fpath")"
	# 			return 0
	# 		else
	# 			if { echo "$computed_hash" > "$roh_hash_fpath"; } 2>/dev/null; then
	# 				echo "  OK: [$dir] \"$(basename "$fpath")\" -- hash mismatch: -- ..."
	# 				echo "       ...   stored [$stored]: [$roh_hash_fpath]"
	# 				echo "       ... computed [$computed_hash]: [$fpath] -- new hash stored -- FORCED!"
	# 				return 0  # No error
	#  			else
	#  				echo "ERROR: [$dir] \"$(basename "$fpath")\" -- failed to write hash to [$roh_hash_fpath] -- (FORCED)"
	#  				((ERROR_COUNT++))
	#  				return 1  # Signal that an error occurred
	# 			fi
	# 		fi
	# 	else
	# 		# echo "WARN: [$dir] \"$(basename "$fpath")\" -- hash file [$dir_hash_fpath] exists -- SKIPPED!"
	#		((WARN_COUNT++))
	# 		return 0  
	# 	fi
	# fi
}

# Function to delete hash files
delete_hash() {
    local dir="$1"
    local fpath="$2"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
    if [ -f "$dir_hash_fpath" ]; then
		rm "$dir_hash_fpath"
		echo "  OK: [$dir] \"$(basename "$fpath")\" -- hash file [$dir_hash_fpath] -- deleted"
	fi

    if [ -f "$roh_hash_fpath" ]; then
		rm "$roh_hash_fpath"
		echo "  OK: [$dir] \"$(basename "$fpath")\" -- hash file [$roh_hash_fpath] -- deleted"
    fi
}

manage_hash_visibility() {
    local dir="$1"
    local fpath="$2"
    local action="$3"
    local force_mode="$4"

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

	# # src yes, dest yes -> err else mv (forced)
	# # src yes, dest no  -> mv
	# # src no,  dest yes -> check dest hash, if computed=dest; OK else err
	# # src no,  dest no  -> err
	
	local past_tense=$([ "$action" = "show" ] && echo "shown" || echo "hidden")

	if [ -f "$src_fpath" ]; then
		if [ -f "$dest_fpath" ] && [ "$force_mode" = "false" ]; then
			echo "ERROR: [$dir] \"$(basename "$fpath")\" -- [$dest_fpath] exists, for source [$src_fpath], not moving/(not $past_tense)"
			((ERROR_COUNT++))
			return 1
		fi

		if [ "$action" = "hide" ]; then
			local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
			mkdir -p "$roh_hash_just_path"
		fi
        mv "$src_fpath" "$dest_fpath"
        echo "  OK: [$dir] \"$(basename "$fpath")\" -- hash file [$dest_fpath] moved($past_tense)"
        return 0
	else
		if [ -f "$dest_fpath" ]; then
		# 	local stored=$(stored_hash "$dest_fpath")
		# 	if [ "$computed_hash" = "$stored" ]; then
			echo "  OK: [$dir] \"$(basename "$fpath")\" -- hash file [$dest_fpath] exists($past_tense), NOT moving/(NOT $past_tense)"
			return 0  # No error
		# 	fi
		fi

        echo "ERROR: [$dir] \"$(basename "$fpath")\" -- NO hash file found [$src_fpath] for [$fpath], not $past_tense"
        ((ERROR_COUNT++))
        return 1
    fi
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Function to process directory contents recursively
process_directory() {
    local cmd="$1"
    local dir="$2"
	# local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local visibility_mode="$3"
    local force_mode="$4"

	# ?! do we care about empty directories
	#
	#	if [ "$verify_mode" = "true" ]; then
	#		if [ ! -d "$ROH_DIR/$sub_dir" ]; then
	#			echo "ERROR: [$dir] -- not a READ-ONLY directory, missing [$ROH_DIR/$sub_dir]"
	#			((ERROR_COUNT++))
	#			return 1 
	#		fi
	#	fi

	# echo "Processing directory: [$dir]"

    for entry in "$dir"/*; do
		if [ -L "$entry" ]; then
			echo "WARN: Avoiding symlink [$entry] like the Plague =)"
			((WARN_COUNT++))

		# If the entry is a directory, process it recursively
        elif [ -d "$entry" ]; then
			process_directory "$cmd" "$entry" "$visibility_mode" "$force_mode"

		# else ...
        elif [ -f "$entry" ] && [[ ! $(basename "$entry") =~ \.${HASH}$ ]] && [[ $(basename "$entry") != "_.roh.git.zip" ]]; then
			if [ "$cmd" != "delete" ]; then
				if check_extension "$entry"; then
					echo "ERROR: [$dir] \"$(basename "$entry")\" -- file with restricted extension"
					((ERROR_COUNT++))
					continue;
				fi
				case "$cmd" in
				    "verify")
				        verify_hash "$dir" "$entry" "false"
				        ;;
				    "recover")
				        verify_hash "$dir" "$entry" "true"
				        ;;
				    "write")
				        write_hash "$dir" "$entry" "$visibility_mode" "$force_mode"
				        ;;
				    "hide")
				        manage_hash_visibility "$dir" "$entry" "hide" "$force_mode"
				        ;;
				    "show")
				        manage_hash_visibility "$dir" "$entry" "show" "$force_mode"
				        ;;
				    *)
				        # No action for other cases, if needed
				        ;;
				esac
			else
				delete_hash "$dir" "$entry"
            fi
        fi
    done

	# it is not guaranteed that sub_dir has been created in $ROH_DIR for the
	# sub_dir we are processing e.g., it could be an empty sub dir.
	#
	# local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
	# [ ! -d "$roh_hash_just_path" ] && return 0
	# ...
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

cmd="_INVALID_"
# Parse command
case "$1" in
    verify) 
        ;;
    write) 
        ;;
    delete) 
        ;;
    hide) 
        ;;
    show) 
        ;;
    recover) 
        ;;
    -h)
		usage
        exit 0
        ;;
    --help)
		usage
        exit 0
        ;;
    *)
        echo "ERROR: unknown command: [$1]"
		usage
        exit 1
        ;;
esac
cmd="$1"
shift

# Parse command line options
roh_dir_mode="false"
roh_dir="_INVALID_"
hash_mode="false"
visibility_mode="none"
force_mode="false"

while getopts "h-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
        hash)
          hash_mode="true"
          ;;
        roh-dir)
		  roh_dir_mode="true"
          roh_dir="${!OPTIND}"
          OPTIND=$((OPTIND + 1))
          ;;		  
        show)
          visibility_mode="show"
          ;;
        force)
          force_mode="true"
          ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "ERROR: invalid option: [--${OPTARG}]" >&2
          usage
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "ERROR: invalid option: [-${OPTARG}]" >&2
      usage
      exit 1
      ;;
    :)
      echo "ERROR: option [-$OPTARG] requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done

# capture all remaining arguments after the options have been processed
shift $((OPTIND-1))
ROOT="$1"
# Bash's parameter expansion feature, specifically the ${parameter:-default_value} syntax
ROOT=${ROOT:-.}
# echo "* ROOT [$ROOT]"

if [ "$roh_dir_mode" = "true" ]; then
	ROH_DIR="$roh_dir"
	echo "Using ROH_DIR [$ROH_DIR]"
else 
	ROH_DIR="$ROOT/.roh.git"
fi
# echo "* ROH_DIR [$ROH_DIR]"

if [ "$hash_mode" = "true" ]; then
	# echo "* $@"
	for fpath in "$@"; do
		if ! [ -f "$fpath" ]; then
			echo "WARN: [$fpath] not a file -- SKIPPING"
			((WARN_COUNT++))
			continue
		fi

		[[ "${fpath}" = *.sha256 ]] && continue

		computed_hash=$(generate_hash "$fpath")
		dir_hash_fpath="$fpath.$HASH"
		# echo "* dir_hash_fpath: [$dir_hash_fpath]"

		if [ "$cmd" = "write" ]; then
			if echo "$computed_hash" > "$dir_hash_fpath" 2>/dev/null; then
				echo "  OK: [$computed_hash]: \"$(basename "$fpath")\""
			else
				echo "ERROR: can not generate hash for [$fpath]"
				((ERROR_COUNT++))
			fi
		
		elif [ "$cmd" = "verify" ]; then
			stored=$(stored_hash "$dir_hash_fpath")
        
			if [ "$computed_hash" = "$stored" ]; then
				echo "  OK: [$fpath] -- hash matches: [$computed_hash]"
			else
				echo "ERROR: [$fpath] -- hash mismatch: stored [$stored], computed [$computed_hash]"
				((ERROR_COUNT++))
			fi
		fi
	done
	if [ $ERROR_COUNT -gt 0 ]; then
		echo "Number of ERRORs encountered: [$ERROR_COUNT]"
		echo
		exit 1
	fi
	echo "Done."
	exit 0
fi

# Check for force_mode usage
if [ "$force_mode" = "true" ] && [ "$cmd" != "write" ] && [ "$cmd" != "show" ] && [ "$cmd" != "hide" ]; then
    echo "ERROR: --force can only be used with: write|show|hide." >&2
    usage
    exit 1
fi

#------------------------------------------------------------------------------------------------------------------------------------------

run_directory_process() {
	local cmd="$1"
    local dir="$2"
	#local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
    local force_mode="$3"

	if [ "$cmd" = "hide" ] || ( [ "$cmd" = "write" ] && [ "$visibility_mode" != "show" ] ); then
		ensure_dir "$ROH_DIR"

	elif [ "$cmd" = "show" ]; then
		if [ ! -d "$ROH_DIR" ]; then
			echo "ERROR: [$ROOT] -- missing [$ROH_DIR]. Aborting." >&2
			exit 1
		fi 
	fi

    process_directory "$@"	

	# ROH_DIR must exist and be accessible for the while loop to execute
	[ ! -d "$ROH_DIR" ] || ! [ -x "$ROH_DIR" ] && return 0;

	# Now check for hash files without corresponding files
	while IFS= read -r roh_hash_fpath; do
		local fpath="$(hash_fpath_to_fpath "$roh_hash_fpath")"
		# echo "* FPATH: [$roh_hash_fpath] [$fpath]"

		if [ -d "$roh_hash_fpath" ]; then
			if [ "$cmd" = "delete" ] || [ "$cmd" = "write" ]; then
				#if [ "$(ls -A "/path/to/directory" | wc -l)" -eq 0 ]; then
				if [ -z "$(find "$roh_hash_fpath" -mindepth 1 -print -quit)" ]; then
					if ! rmdir "$roh_hash_fpath"; then
						echo "ERROR: Failed to remove directory [$roh_hash_fpath]"
						((ERROR_COUNT++))
					else
						echo "  OK: -- orphaned hash directory [$roh_hash_fpath] -- removed"
					fi
				fi
			fi
			continue;
		fi

		if ! stat "$fpath" >/dev/null 2>&1; then
			if [ "$cmd" = "delete" ] || [ "$cmd" = "write" ]; then
				if ! rm "$roh_hash_fpath"; then
					echo "ERROR: Failed to remove hash [$roh_hash_fpath]"
					((ERROR_COUNT++))
				else
					local stored=$(stored_hash "$roh_hash_fpath")
					echo "  OK: -- orphaned hash [$roh_hash_fpath][$stored] -- removed"
				fi
			else
				local stored=$(stored_hash "$roh_hash_fpath")
				echo "ERROR: --                ... file [$fpath] -- NOT found"
				echo "       ... for corresponding hash [$roh_hash_fpath][$stored]"
				((ERROR_COUNT++))
			fi
		fi
	# exclude "$ROH_DIR/.git" using --prune, return only files
	# sort, because we want lower directories removed first, so upper directories can be empty and removed
	# 	done < <(find "$ROH_DIR" -path "$ROH_DIR/.*" -prune -o -type f -name "*" -print)
	# List all files that DO NOT start with a dot; that includes going into subdirectories and listing files 
	# there that do not start with a dot. The only place in the directory structure where dot files can be
	# expected is in the start directory where .gitignore .git (the entire directory) and .DS_store 
	# should be skipped along with any other dot files or directories.
	# 	done < <(find "$ROH_DIR" -path "$ROH_DIR/.*" -prune -o -print | sort -r)
	done < <(find "$ROH_DIR" -path "*/.git/*" -prune -o -not -name ".*" -print | sort -r)
	# 	-path "*/.git/*" -prune: This specifically prunes .git directories and their contents. 
	# 	It ensures that .git and everything inside it at any level within .roh.git is skipped.
	#	-o -not -name ".*": Then, it prints files that don't start with a dot.
	# Or, if you want to list both files and directories but differentiate them:
	# find "test/.roh.git" -path "*/.git/*" -prune -o \( -type f -not -name ".*" -print \) -o \( -type d -not -name ".*" -print \)
	# This last command will print both non-dot files and directories but in separate -print actions, allowing you to see clearly which are files and which are directories in the output.
	
	# This will fail if git is being used
	if [ "$cmd" = "delete" ] || [ "$cmd" = "show" ] || [ "$visibility_mode" = "show" ]; then
		#if [ "$(ls -A "/path/to/directory" | wc -l)" -eq 0 ]; then
		if [ -z "$(find "$ROH_DIR" -mindepth 1 -print -quit)" ]; then
			if ! rmdir "$ROH_DIR"; then
				echo "ERROR: Failed to delete [$ROH_DIR]"
				((ERROR_COUNT++))
			fi
		fi
	fi

	if [ "$x_roh_hash" = "false" ]; then
		echo "WARN: hashes not exclusively hidden in [$ROH_DIR]"
		((WARN_COUNT++))
	fi
}

#------------------------------------------------------------------------------------------------------------------------------------------

if [ ! -d "$ROOT" ]; then
    echo "ERROR: Directory [$ROOT] does not exist"
	echo
    exit 1
fi

run_directory_process "$cmd" "$ROOT" "$visibility_mode" "$force_mode"
if [ $ERROR_COUNT -gt 0 ] || [ $WARN_COUNT -gt 0 ]; then
	echo "Number of ERRORs encountered: [$ERROR_COUNT]"
	echo "Number of ...       WARNings: [$WARN_COUNT]"
	echo
	if [ $ERROR_COUNT -gt 0 ]; then
		exit 1
	fi
	exit 0 # WARNings
fi

echo "Done."

