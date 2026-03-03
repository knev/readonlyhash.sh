#!/bin/bash

shopt -s nullglob

#set -x

usage() {
	echo
	echo "Usage: $(basename "$0") <COMMAND|[<write|show|hide> --force]|[verify --export]> [--roh-dir PATH] <ROOT> -- <PATHSPEC/GLOBSPEC>"
	echo "       $(basename "$0") <write|verify> -- <PATH/GLOBSPEC>"
	echo "       $(basename "$0") <query [--db PATH] [ROOT] -- <HASH>"
	echo "Commands:"
	echo "      v|verify         Verify computed hashes against stored hashes; check for orphaned hashes"
	echo "      w|write          Write SHA256 hashes for existing files"
	echo "      i|index          Index hash files in a DB (sqlite3 required), including orphaned hashes"
	echo "      verify index     ..."
	echo "      write index      .."
	echo "      d|delete         Delete hash related to files"
	echo "      h|hide           Move hash files from the files location to .roh"
	echo "      s|show           Move hash files from .roh to the file's location"
	echo "      write show       ."
	echo "      write hide       ."
	echo "      q|query          ..."
	echo "      index query      .."
	echo "      r|recover        Write/index files with hashes found in the DB; remove orphaned duplicates"
	echo "      index recover    ..."
	echo "      e|sweep          Remove all orphaned hashes"
	echo "      write sweep      ..."
	echo "      delete sweep     ..."
	echo
	echo "Options:"
	echo "      --verbose      Verbose operational output"
	echo "      --force        Force operation even if hash files do not match"
	echo "      --roh-dir      Specify the readonly hash path"
	echo "      --db           ..."
	echo "      --only-files   ..."
	echo "      --only-hashes  ..."
	echo "      --export       ..."
    echo "      --version      Display the version and exit"
	echo "  -h, --help         Display this help and exit"
	echo
}

# readonlyhash
#TODO: readonlyhash commit
#TODO: do we need the --rebase switch? isn't alway required?
#TODO: --force verify stops immediately on error
#TODO: option to keep archives after extract

#TODO: on rebase, use the rebase string to rename output .roh.txt file; create a roh.copy command that accepts a rebase string; accepts export output too

#BUGS
#TODO: on ?write? possibly SHOW the hash, if it is mismatched with the computed hash?


#Features:
#TODO: do the "more" with matched FILENAMES on recover files as with hashes
#TODO: multiple "copies" using readonlyhash write the loop file to the same ~ro.loop.txt
#TODO: permissions: git created as user account, access as different user or root
#TODO: prune all index hashes that point to files that no longer exist
#TODO: archive, then try a retarget
#TODO: how does the extract to tmp of zip interact with the --retarget ?!
#TODO: update readme
#TODO: ? write parts in C++ or rust to improve performance
#TODO: should probably add a delete on the ROH level to delete the hashes and .git
#TODO: when using --roh-dir, perhaps the output paths should show that the roh-dir is different than the file location.
#TODO: rm -rf .roh.git.rslsc


# List of file extensions to avoid, comma separated
EXTENSIONS_TO_AVOID="rslsi,rslsv,rslsz,rsls"

ROOT="_INVALID_"
PATHSPEC="_INVALID_"
ROH_DIR="_INVALID_"
DB_SQL="_INVALID_"

EXPORT_FN_NEW="_INVALID_"
EXPORT_FN_DELETED="_INVALID_"

HASH="sha256"

ERROR_COUNT=0
WARN_COUNT=0

VERBOSE_MODE="false"
EXPORT_MODE="false"

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

generate_hash() {
    local file="$1"
	if [ ! -r "$file" ]; then
        echo "ERROR: -- file [$file] not readable or permission denied" >&2
		echo "0000000000000000000000000000000000000000000000000000000000000000"
		return
    fi
    # echo $($SHA256_BIN "$file" | awk '{print $1}')
	# echo $(stdbuf -i0 shasum -a 256 "$file" | cut -c1-64) # brew install coreutils || gstdbuf Instead
	# echo $(stdbuf -i0 openssl sha256 "$file" | tail -c 65) # brew install coreutils || gstdbuf Instead
	echo $(openssl sha256 "$file" | tail -c 65) # brew install coreutils || gstdbuf Instead
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

hex_encode() {
	printf '%s' "$1" | xxd -p | tr -d '\n'
}

hex_decode() {
	printf '%s' "$1" | xxd -r -p
}

roh_sqlite3_db_init() {
    local db="$1"

    # Remove existing database file if it exists (no point if using mktemp)
	if [ -f "$db" ]; then
		# rm "$db"; echo "db: [$db] -- removed"
		return 0
	fi

    # Create or open the SQLite database with a new schema
    sqlite3 "$db" <<EOF
CREATE TABLE IF NOT EXISTS hashes (
    id INTEGER PRIMARY KEY,
    hash TEXT NOT NULL,
    filename TEXT NOT NULL,
    fpath TEXT UNIQUE,
    roh_hash_fpath TEXT NOT NULL UNIQUE
);

-- Index for faster hash lookups
CREATE INDEX IF NOT EXISTS idx_hash ON hashes(hash);

-- Index for faster filename lookups
CREATE INDEX IF NOT EXISTS idx_filename ON hashes(filename);

-- Remove all existing entries before inserting new ones (if needed)
-- DELETE FROM hashes;

EOF

    echo "DB_SQL: [$db] -- initialized"
	return 0
}

# sqlite3 "$DB_SQL" ".dump hashes" >&2

roh_sqlite3_db_insert() {
    local db="$1"
    local fpath="$2"
    local roh_hash_fpath="$3"
    local stored="$4"
	
    if [ ! -f "$db" ]; then
		echo "ERROR: can not access database file [$db]" >&2
		exit 1
	fi

    # Escape single quotes for SQLite
    local fn=$(basename "$fpath")
    local enc_fn=$(hex_encode "$fn")

    local abs_roh_hash_fpath=$(readlink -f "$roh_hash_fpath")
    local enc_abs_roh_hash_fpath=$(hex_encode "$abs_roh_hash_fpath")

    local abs_fpath=$(readlink -f "$fpath")
	if [ -z "$abs_fpath" ]; then
		sqlite3 "$db" "INSERT INTO hashes (hash, filename, fpath, roh_hash_fpath) VALUES ('$stored', '$enc_fn', NULL, '$enc_abs_roh_hash_fpath');"
	else
		local enc_abs_fpath=$(hex_encode "$abs_fpath")
		sqlite3 "$db" "INSERT INTO hashes (hash, filename, fpath, roh_hash_fpath) VALUES ('$stored', '$enc_fn', '$enc_abs_fpath', '$enc_abs_roh_hash_fpath');"
	fi
}

roh_sqlite3_db_find_hash() {
    local db="$1"
    local stored="$2"

    if [ ! -f "$db" ]; then
		echo "ERROR: can not access database file [$db]" >&2
		exit 1
	fi

	sqlite3 "$db" "SELECT IFNULL(fpath, '<NULL>') || char(13) || roh_hash_fpath FROM hashes WHERE hash = '$stored';"
	# '$enc_abs_fpath' \r '$enc_abs_roh_hash_fpath'
}

roh_sqlite3_db_find_fn() {
    local db="$1"
    local fn="$2"

    if [ ! -f "$db" ]; then
		echo "ERROR: can not access database file [$db]" >&2
		exit 1
	fi

    local enc_fn=$(hex_encode "$fn")
	sqlite3 "$db" "SELECT IFNULL(fpath, '<NULL>') || char(13) || roh_hash_fpath || char(13) || hash FROM hashes WHERE filename = '$enc_fn';"
	# '$enc_abs_fpath' \r '$enc_abs_roh_hash_fpath' \r '$stored'
}

roh_sqlite3_db_find_fpath() {
    local db="$1"
	local fpath="$2"
	local stored="$3"

    if [ ! -f "$db" ]; then
		echo "ERROR: can not access database file [$db]" >&2
		exit 1
	fi

	local abs_fpath=$(readlink -f "$fpath")
	if [ -z "$abs_fpath" ]; then
		sqlite3 "$db" "SELECT COUNT(*) FROM hashes WHERE hash = '$stored' AND fpath IS NULL;"
	else
		local enc_abs_fpath=$(hex_encode "$abs_fpath")
		sqlite3 "$db" "SELECT COUNT(*) FROM hashes WHERE fpath = '$enc_abs_fpath';"	
	fi
}

roh_sqlite3_db_get_1fpath_hash() {
    local db="$1"
	local fpath="$2"
	
    if [ ! -f "$db" ]; then
		echo "ERROR: can not access database file [$db]" >&2
		exit 1
	fi

	local abs_fpath=$(readlink -f "$fpath")
	if [ -z "$abs_fpath" ]; then
		return "0000000000000000000000000000000000000000000000000000000000000000";
	else
		local enc_abs_fpath=$(hex_encode "$abs_fpath")
		sqlite3 "$db" "SELECT hash FROM hashes WHERE fpath = '$enc_abs_fpath';"
		# '$stored'
	fi
}

#------------------------------------------------------------------------------------------------------------------------------------------

recover_file() {
    local db="$1"
    local fpath="$2"
    local roh_hash_fpath="$3"
    local computed_hash="$4"

	list_roh_hash_fpaths=$(roh_sqlite3_db_find_hash "$db" "$computed_hash") || return 1

	# while IFS=$'\r' read -r found_fpath found_roh_hash_fpath; do
	#	echo "[$found_fpath:$found_roh_hash_fpath]"
	# done <<< "$list_roh_hash_fpaths"
	if [ -n "$list_roh_hash_fpaths" ]; then
		write_hash "$dir" "$fpath" "hide" "false"

		# ----
		# index file

		local stored=$(stored_hash "$roh_hash_fpath")

		local fpath_exists=$(roh_sqlite3_db_find_fpath "$db" "$fpath" "$stored") || return 1
		if [ "$fpath_exists" -eq 0 ]; then
			roh_sqlite3_db_insert "$db" "$fpath" "$roh_hash_fpath" "$stored"
			echo " IDX: >$stored<: [$fpath] -- written INDEXED"
		else
			[ "$VERBOSE_MODE" = "true" ] && echo " IDX: [$stored]: [$fpath] -- already indexed, skipping"
		fi

		# ----

		return 0
	fi

	# echo "OK: -- [$computed_hash]: [$fpath] -- NEW!?"
	# [ "$VERBOSE_MODE" = "true" ] && echo "OK: -- [$computed_hash]: [$fpath] -- NEW!?"

	# else
	# no matching hash found, file identical file names

    local fn=$(basename "$fpath")
#    local enc_fn=$(hex_encode "$fn")

    local abs_fpath=$(readlink -f "$fpath")
#    local enc_abs_fpath=$(hex_encode "$abs_fpath")

	list_roh_hash_fpaths=$(roh_sqlite3_db_find_fn "$db" "$fn") || return 1
	if [ -n "$list_roh_hash_fpaths" ]; then

		# echo "* Found in file(s): [ ..."
		# echo "$list_roh_hash_fpaths"
		# echo "...]"

		echo "WARN: [$computed_hash]: [$fpath] -- NEW!?"
		echo "       ... hash mismatch -- FILENAME matches ..."
		((WARN_COUNT++))

		local files_found=0

	    # Only print non-empty paths
	    while IFS= read -r found; do
			if [ -n "$found" ]; then
				IFS=$'\r' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath found_hash <<< "$found"

				((files_found++))

				local found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")
				# echo "[$found_hash] [$found_abs_fpath] [$found_enc_abs_roh_hash_fpath]==$enc_abs_roh_hash_fpath"

				# diff fpath
				if [ "$found_enc_abs_fpath" = "<NULL>" ]; then
					if [ "$files_found" -lt 3 ]; then
						local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
						echo "           ... [$found_hash]: [$found_abs_roh_hash_fpath] orphaned hash"
					fi

				elif [ -f "$found_abs_fpath" ]; then
					if [ "$files_found" -lt 3 ]; then
						echo "           ... [$found_hash]: [$found_abs_fpath]"
					fi
#  					found_computed_hash=$(generate_hash "$found_abs_fpath")
# 					local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
# 					if [ -f "$found_abs_roh_hash_fpath" ]; then
# 						found_stored=$(stored_hash "$found_abs_roh_hash_fpath")
# 						if [ "$found_computed_hash" != "$found_stored" ]; then
#							echo "  ERROR:    ... hash mismatch -- matching FILENAME found ..."
#							echo "                ...   stored [$found_stored]: [$found_abs_roh_hash_fpath]"
#							echo "                ... computed [$found_computed_hash]: [$found_abs_fpath]"
# 							((ERROR_COUNT++))
# 							continue
# 						fi
# 					fi
# 					# echo "computed_hash: $found_computed_hash:$stored"
#  					if [ "$found_computed_hash" = "$stored" ]; then
# 						# the indexed and found file at a different location was indexed with a wrong/outdated hash
#  						echo "         ... duplicate FOUND [$found_abs_fpath]"
#  					else
#  						echo "            ... hash mismatch -- matching FILENAME found ..."
# 						echo "                ...   stored [$stored]: [$abs_roh_hash_fpath]"
# 						echo "                ... computed [$found_computed_hash]: [$found_abs_fpath]"
#  					fi

				else
					[ "$VERBOSE_MODE" = "true" ] && echo "           ... [$found_abs_fpath] -- indexed, but missing"
				fi

				if [ "$files_found" -gt 2 ]; then
					echo "               ... $((files_found - 2)) more ..."
					break;
				fi

			fi
	    done <<< "$list_roh_hash_fpaths"

	else
		echo "OK: [$computed_hash]: [$fpath] -- NEW!?"
	fi

	return 0

#	[ "$VERBOSE_MODE" = "true" ] && echo "RECOVER: [$stored]: [$roh_hash_fpath] -- orphaned hash"
#	
#    local abs_roh_hash_fpath=$(readlink -f "$roh_hash_fpath")
#    local enc_abs_roh_hash_fpath=$(hex_encode "$abs_roh_hash_fpath")
#
#	if [ "$VERBOSE_MODE" = "true" ]; then
#	   	echo "  ERROR:    ... hash not in IDX [$fpath] -- file DELETED !?"
#	else
#		echo "  ERROR: [$stored] -- NOT in IDX [$fpath] -- file DELETED !?"
#	fi
#	((ERROR_COUNT++))
#


				# same fpath
#				if [ "$found_enc_abs_roh_hash_fpath" = "$enc_abs_roh_hash_fpath" ]; then
#					# echo "found_hash: $found_hash:$stored"
#					local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
#					if [ -f "$found_abs_roh_hash_fpath" ]; then
#						if [ "$found_hash" != "$stored" ]; then
#							echo "  ERROR:    ... hash mismatch: ..."
#							echo "                ... indexed [$found_hash]: [$found_abs_roh_hash_fpath]"
#							echo "                ...  stored [$stored]: [$abs_roh_hash_fpath]"
#							((ERROR_COUNT++))
#						fi								
#						continue
#					else
#						echo "this should not happen, because we are processing orphans that exist"
#						((ERROR_COUNT++))
#						continue
#					fi
#				fi
#


#
#	# else
#	# echo "      ■: -- orphaned hash [$stored]: [$roh_hash_fpath] -- NOOP!"
#	[ "$VERBOSE_MODE" = "true" ] && echo "      ■: -- NOOP!"

	return 0
}

x_roh_hash="true" # exclusively roh hashes

verify_hash() {
    local dir="$1"
    local fpath="$2"

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

        echo "ERROR: -- two hash files exist ..."
		echo "            ... hidden [$stored_roh][$roh_hash_fpath]"
		echo "             ... shown [$stored_dir][$dir_hash_fpath]"
		echo "          ... computed [$computed_hash][$fpath]"

		x_roh_hash="false"
        ((ERROR_COUNT++))
        return 0  
	fi

    if [ -f "$roh_hash_fpath" ]; then
		local stored=$(stored_hash "$roh_hash_fpath")

		if [ "$computed_hash" = "$stored" ]; then
			[ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$computed_hash]: [$fpath]"
			return 0
		else
			echo "ERROR: -- hash mismatch: ..."
			echo "          ...   stored [$stored][$roh_hash_fpath]"
			echo "          ... computed [$computed_hash][$fpath]"
			((ERROR_COUNT++))
			return 0
		fi

    elif [ -f "$dir_hash_fpath" ]; then
		local stored=$(stored_hash "$dir_hash_fpath")
	        
		x_roh_hash="false"
	        
		if [ "$computed_hash" = "$stored" ]; then
			[ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$computed_hash]: [$fpath]"
			return 0
		else
			echo "ERROR: -- hash mismatch: ..."
			echo "          ...   stored [$stored][$dir_hash_fpath]"
			echo "          ... computed [$computed_hash][$fpath]"
			((ERROR_COUNT++))
			return 0
		fi 
	fi

	if contains "recover"; then
		recover_file "$DB_SQL" "$fpath" "$roh_hash_fpath" "$computed_hash"
		return $?
	else
		echo "WARN: -- [$computed_hash]: [$fpath] -- NEW!?"
		((WARN_COUNT++))
		[ "$EXPORT_MODE" = "true" ] && echo "$fpath" >> "$EXPORT_FN_NEW"
	fi
	return 0
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

	# optimization for if we run "write index" more than once
	if contains "index"; then
		# fpath must exist for roh_sqlite3_db_find_fpath() to succeed here
		if [ ! -f "$fpath" ]; then 
			echo "ERROR"
			exit 1
		fi
		local fpath_exists=$(roh_sqlite3_db_find_fpath "$DB_SQL" "$fpath" "0000000000000000000000000000000000000000000000000000000000000000") || return 1
		if [ "$fpath_exists" -eq 0 ]; then
			:
		elif [ "$fpath_exists" -eq 1 ]; then
			local stored=$(roh_sqlite3_db_get_1fpath_hash "$DB_SQL" "$fpath") || return 1
			echo " IDX: [$stored]: [$fpath] -- already exists, skipping"
			return
		else
			echo "ERROR"
			exit 1
		fi
	fi

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

	# exist-R=T
    if [ -f "$roh_hash_fpath" ]; then
		local stored=$(stored_hash "$roh_hash_fpath")
		if [ "$computed_hash" != "$stored" ]; then
			# exist-R=T (eq-R=F)
			if [ "$force_mode" = "true" ]; then
				rm "$roh_hash_fpath"
				echo "  OK: -- hash mismatch: ..."
				echo "      ... computed [$computed_hash][$fpath]"
				echo "      ...   stored [$stored][$roh_hash_fpath] -- removed (FORCED)!"
			else
				echo "WARN: -- hash mismatch: ..."
				echo "      ... computed [$computed_hash][$fpath]"
				echo "      ...   stored [$stored][$roh_hash_fpath]"
				((WARN_COUNT++))

				exists_and_not_eq="true"
			fi
		fi
	fi

	# exist-D=T
	if [ -f "$dir_hash_fpath" ]; then
		local stored=$(stored_hash "$dir_hash_fpath")
		if [ "$computed_hash" != "$stored" ]; then
			# exist-D=T (eq-D=F)
			if [ "$force_mode" = "true" ]; then
				rm "$dir_hash_fpath"
				echo "  OK: -- hash mismatch: ..."
				echo "      ... computed [$computed_hash][$fpath]"
				echo "      ...   stored [$stored][$dir_hash_fpath] -- removed (FORCED)!"
			else
				echo "WARN: -- hash mismatch: ..."
				echo "      ... computed [$computed_hash][$fpath]"
				echo "      ...   stored [$stored][$dir_hash_fpath]"
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

	# exist-R=F         , exist-D=F
	if ! [ -f "$dir_hash_fpath" ] && ! [ -f "$roh_hash_fpath" ]; then
		# write to R
		local new_hash=$(generate_hash "$fpath")
	
		if [ "$visibility_mode" = "show" ]; then
			# write to $dir_hash_fpath, because it exist, then let visibility handle the move
			echo "$new_hash" > "$dir_hash_fpath"
			[ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$new_hash]: [$fpath] -- file hash written"
		else
			local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
			if mkdir -p "$roh_hash_just_path" 2>/dev/null && { echo "$new_hash" > "$roh_hash_fpath"; } 2>/dev/null; then
				[ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$new_hash]: [$fpath] -- file hash written"
			else
				echo "ERROR: [$fpath] -- failed to write hash to [$roh_hash_fpath]"
				((ERROR_COUNT++))
				return 0  # Signal that an error occurred
			fi
		fi
		return 0
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
		manage_hash_visibility "$dir" "$fpath" "show" "$force_mode"

	elif [ "$visibility_mode" != "show" ] && [ -f "$dir_hash_fpath" ]; then
		# move D->R: hide
		manage_hash_visibility "$dir" "$fpath" "hide" "$force_mode"
	
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
	# 			# echo "  OK: [$computed_hash]: [$dir] $(basename "$fpath") -- SKIPPING"
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

	return 0
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
		[ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$fpath] -- hash file [$dir_hash_fpath] -- deleted"
	fi

    if [ -f "$roh_hash_fpath" ]; then
		rm "$roh_hash_fpath"
		[ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$fpath] -- hash file [$roh_hash_fpath] -- deleted"
    fi

	return 0
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
			echo "ERROR: [$fpath] -- not moving/(not $past_tense) ..." 
			echo "                   ... destination [$dest_fpath] -- exists"
			echo "                    ... for source [$src_fpath]"
			((ERROR_COUNT++))
			return 0
		fi

		if [ "$action" = "hide" ]; then
			local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
			if ! mkdir -p "$roh_hash_just_path" 2>/dev/null; then
				echo "ERROR: [$fpath] -- failed to make (hash) directory [$roh_hash_just_path]"
				((ERROR_COUNT++))
				return 0
			fi
		fi
		if ! mv -- "$src_fpath" "$dest_fpath" 2>/dev/null; then
			echo "ERROR: [$fpath]: [$src_fpath] to [$dest_fpath] -- failed to move hash file"
			((ERROR_COUNT++))
			return 0
		fi
        [ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$fpath]: [$dest_fpath] hash file -- moved($past_tense)"
        return 0
	else
		if [ -f "$dest_fpath" ]; then
		# 	local stored=$(stored_hash "$dest_fpath")
		# 	if [ "$computed_hash" = "$stored" ]; then
			[ "$VERBOSE_MODE" = "true" ] && echo "  OK: [$fpath]: [$dest_fpath] hash file already exists($past_tense) -- nothing to move($action), NOOP"
			return 0  # No error
		# 	fi
		fi

        echo "ERROR: [$fpath]: [$src_fpath] hash file -- NOT found, not $past_tense"
        ((ERROR_COUNT++))
        return 0
    fi

	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Function to process directory contents recursively
process_directory() {
    local dir="$1"
	# local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local visibility_mode="$2"
    local force_mode="$3"

	# ?! do we care about empty directories
	#
	#	if [ "$verify_mode" = "true" ]; then
	#		if [ ! -d "$ROH_DIR/$sub_dir" ]; then
	#			echo "ERROR: [$dir] -- not a READ-ONLY directory, missing [$ROH_DIR/$sub_dir]"
	#			((ERROR_COUNT++))
	#			return 0 
	#		fi
	#	fi

	if [ -d "$dir" ]; then
		: # echo "Processing directory: [$dir]"
	else
		echo "ERROR: can't find directory [$dir] for processing"
		((ERROR_COUNT++))
		return 0
	fi

	if [ -f "$dir/_.roh.git.zip" ]; then
		echo "ERROR: found archived ROH_DIR [$dir/_.roh.git.zip] at [$dir]"
		((ERROR_COUNT++))
		return 0
	fi

    for entry in "$dir"/*; do
		if [ -L "$entry" ]; then
			[ "$VERBOSE_MODE" = "true" ] && echo "Avoiding symlink [$entry] like the Plague"
			continue

		# If the entry is a directory, process it recursively
        elif [ -d "$entry" ]; then
			if [ -d "$entry/.roh.git" ] || [ -f "$entry/_.roh.git.zip" ]; then
				echo " WARN: [$entry] is a readonlyhash directory -- SKIPPING"
				((WARN_COUNT++))
				continue
			fi

			if contains "verify" && [ "$VERBOSE_MODE" = "false" ]; then
				local sub_dir="$(remove_top_dir "$ROOT" "$entry")"
				local roh_hash_path="$ROH_DIR${sub_dir:+/}$sub_dir"
				# echo "ROH_HASH_PATH(entry) is [$roh_hash_path]"

				if [ ! -d "$roh_hash_path" ]; then
					if [[ -z "$(ls -A -- "$entry")" ]]; then
					    : # echo "Directory '$entry' is empty (including hidden files)"
					else
						hash_found=$(find "$entry" -type f -name "*.$HASH" -print | head -n 1)
						if [ -z "$hash_found" ]; then
							echo "WARN: -- [$entry] -- NEW DIRECTORY!?"
							((WARN_COUNT++))
							continue
						fi
					fi
				fi

			fi

			process_directory "$entry" "$visibility_mode" "$force_mode" || return 1

		# else ...
        elif [ -f "$entry" ] && [[ ! $(basename "$entry") =~ \.${HASH}$ ]] && [[ $(basename "$entry") != "_.roh.git.zip" ]]; then
			if ! contains "delete"; then
				if check_extension "$entry"; then
					echo "ERROR: [$dir] \"$(basename "$entry")\" -- file with restricted extension"
					((ERROR_COUNT++))
					continue;
				fi
				if contains "verify" || contains "recover"; then
					verify_hash "$dir" "$entry" || return 1
				elif contains "write"; then
					write_hash "$dir" "$entry" "$visibility_mode" "$force_mode" || return 1
				elif [ ${#commands[@]} -eq 1 ] && contains "hide"; then
					manage_hash_visibility "$dir" "$entry" "hide" "$force_mode" || return 1
				elif [ ${#commands[@]} -eq 1 ] && contains "show"; then 
					manage_hash_visibility "$dir" "$entry" "show" "$force_mode" || return 1
				fi
			else
				delete_hash "$dir" "$entry" || return 1
            fi
        fi
    done

	# it is not guaranteed that sub_dir has been created in $ROH_DIR for the
	# sub_dir we are processing e.g., it could be an empty sub dir.
	#
	# local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
	# [ ! -d "$roh_hash_just_path" ] && return 0
	# ...

	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

QUERY_HASH="0000000000000000000000000000000000000000000000000000000000000000"

# ----

# Compatible with bash 3.2+ (macOS default) and bash 4+

# List of valid full commands
valid_long="verify write index delete hide show query recover sweep"

# Short to long mapping (using case statement instead of assoc array)
get_long() {
    case "$1" in
        v) echo "verify" ;;
        w) echo "write" ;;
        i) echo "index" ;;
        d) echo "delete" ;;
        h) echo "hide" ;;
        s) echo "show" ;;
        q) echo "query" ;;
        r) echo "recover" ;;
        e) echo "sweep" ;;
        *) echo "" ;;  # empty = invalid
    esac
}

commands=()  # normal array is fine even in 3.2

contains() {
    local needle="$1"
    local item
    for item in "${commands[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

i=1
while [ $i -le $# ]; do
    arg=$(eval echo "\$$i")

    # Stop on any switch-like argument
    case "$arg" in
        -*) break ;;
    esac

    # 1. Try full word match
    if echo "$valid_long" | grep -qw "$arg"; then
        commands+=("$arg")
        i=$((i+1))
        continue
    fi

    # 2. Try short letters (consecutive, no separators)
    if echo "$arg" | grep -qE '^[vwidhsqre]+$'; then
        invalid=0
        for ((j=0; j<${#arg}; j++)); do
            c="${arg:$j:1}"
            long=$(get_long "$c")
            if [ -n "$long" ]; then
                commands+=("$long")
            else
                echo "ERROR: unknown short operation '$c' in '$arg'" >&2
                invalid=1
                break
            fi
        done
        if [ $invalid -eq 0 ]; then
            i=$((i+1))
            continue
        fi
    fi

	if [ ${#commands[@]} -eq 0 ]; then
		# If we get here → error
		echo "ERROR: invalid command [$arg]" >&2
		# echo "Allowed full: verify write index delete hide show query recover sweep" >&2
		# echo "     short:  v      w     i      d      h    s    q     r      e" >&2
		# echo "Shorts can be concatenated like: vwidhsqre" >&2
		usage
		exit 1
	fi
	break
done
# echo "Parsed commands (${#commands[@]}):"
# for cmd in "${commands[@]}"; do
#     echo "  - $cmd"
# done

# Reset positional parameters to remaining arguments only
shift $((i-1))   # now $1 is the first -something argument

# -----

# Parse command line options
roh_dir_mode="false"
roh_dir="_INVALID_"
db=""
force_mode="false"
only_files="false"
only_hashes="false"
while getopts "h-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
        roh-dir)
		  roh_dir_mode="true"
          roh_dir="${!OPTIND}"
          OPTIND=$((OPTIND + 1))
          ;;		  
        db)
          db="${!OPTIND}"
          OPTIND=$((OPTIND + 1))
          ;;		  
        force)
          force_mode="true"
          ;;
		only-files)
		  only_files="true"
		  ;;
		only-hashes)
		  only_hashes="true"
		  ;;
		export)
		  EXPORT_MODE="true"
		  ;;
		verbose)
		  VERBOSE_MODE="true"
		  ;;
	    version)
	      echo "$(basename "$0") version: $VERSION"
		  echo
	      exit 0
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

# echo "[$@]"

globspec_mode="false"
PATHSPEC=""

# is "--" the very first parameter after all the switches (no ROOT)
prev=$((OPTIND-1))
if [[ $OPTIND -ge 2 && ${!prev} == "--" ]]; then
	# capture all remaining arguments after the options have been processed
	shift $((OPTIND-1))

	if [ $# -eq 0 ]; then 
		echo "ERROR: expected argument after \"--\"" >&2
		usage
		exit 1	
	fi

	globspec_mode="true"
else
	# capture all remaining arguments after the options have been processed
	shift $((OPTIND-1))

	# Bash's parameter expansion feature, specifically the ${parameter:-default_value} syntax
	# ROOT="${1:-.}"
	ROOT=$1
	if [ -z "$ROOT" ]; then 
		echo "ERROR: NO valid ROOT specified [$ROOT]" >&2
		usage
		exit 1	
	fi
	# echo "* ROOT [$ROOT]"
	if ! contains "query" && [ ! -d "$ROOT" ]; then
		echo "ERROR: Directory [$ROOT] does not exist"
		echo
		exit 1
	fi
	shift

	if [ "$1" = "--" ]; then
		shift
		PATHSPEC="$1"
		if [ -z "$PATHSPEC" ]; then
			echo "ERROR: expected argument after \"--\"" >&2
			usage
			exit 1	
		fi
		shift # this will fail if there are not enough args
		if [ $# -ne 0 ]; then 
			echo "ERROR: too many arguments after \"--\"" >&2
			usage
			exit 1	
		fi
		# echo "* PATHSPEC (ROOT) set to [$PATHSPEC]"
	fi
fi

# echo "[$@]"

visibility_mode="none"

if [ ${#commands[@]} -eq 2 ]; then
	if [ "$globspec_mode" = "true" ] && ! contains "query"; then 
		echo "ERROR: invalid globspec command combination [${commands[@]}]" >&2
		usage
		exit 1	
	fi


	if contains "index" && ( contains "query" || contains "recover" || contains "verify" || contains "write"); then
		:
	elif contains "sweep" && ( contains "write" || contains "delete" ); then
		:
	elif contains "write" && contains "show"; then
		visibility_mode="show"
	elif contains "write" && contains "hide"; then
		visibility_mode="hide"
	else
		echo "ERROR: invalid double command combination [${commands[@]}]" >&2
		usage
		exit 1	
	fi
elif [ ${#commands[@]} -eq 1 ]; then
	:
else
	echo "ERROR: invalid command combination [${commands[@]}]" >&2
	usage
	exit 1	
fi

# Check for force_mode usage
if [ "$force_mode" = "true" ] && ! contains "write" && ! contains "show" && ! contains "hide"; then
    echo "ERROR: --force can only be used with: write|show|hide" >&2
    usage
    exit 1
fi

# ----

if [ "$roh_dir_mode" = "true" ]; then
	ROH_DIR="$roh_dir"
	echo "Using ROH_DIR [$ROH_DIR]"
else 
	ROH_DIR="$ROOT/.roh.git"
fi
# echo "* ROH_DIR [$ROH_DIR]"
EXPORT_FN_NEW="$ROH_DIR/../.roh.new-files.txt"
EXPORT_FN_DELETED="$ROH_DIR/../.roh.deleted-files.txt"

if [ -z "$db" ]; then
    DB_SQL=("$ROOT/.roh.sqlite3")  # Single path as an array
else	
	#IFS=':' read -r -a DB_SQL <<< "$db"  # Assign colon-separated paths to DB_SQL array
	DB_SQL="$db"
fi
# echo "* DB_SQL [${DB_SQL[*]}]"

if contains "index"; then
	if ! roh_sqlite3_db_init "$DB_SQL"; then
		echo "ERROR: database file [$DB_SQL]? this should not happen" >&2
		exit 1
	fi
fi

if contains "verify"; then
	if  [ -f "$DB_SQL" ]; then
		echo "WARN: database file [$DB_SQL] exists; has not been removed"
		((WARN_COUNT++))
	fi
elif contains "recover" || contains "index"; then
	if  [ -f "$DB_SQL" ]; then
		echo "Using DB_SQL [$DB_SQL]"
	else
		echo "ERROR: database file [$DB_SQL] not found" >&2
		exit 1
	fi
fi

#------------------------------------------------------------------------------------------------------------------------------------------

recover_hash() {
    local db="$1"
    local fpath="$2"
    local roh_hash_fpath="$3"
    local stored="$4"

	[ "$VERBOSE_MODE" = "true" ] && echo "RECOVER: [$stored]: [$roh_hash_fpath] -- orphaned hash"
	
    local fn=$(basename "$fpath")
    local enc_fn=$(hex_encode "$fn")

    local abs_fpath=$(readlink -f "$fpath")
    local enc_abs_fpath=$(hex_encode "$abs_fpath")

    local abs_roh_hash_fpath=$(readlink -f "$roh_hash_fpath")
    local enc_abs_roh_hash_fpath=$(hex_encode "$abs_roh_hash_fpath")

	list_roh_hash_fpaths=$(roh_sqlite3_db_find_hash "$db" "$stored") || return 1
	if [ -n "$list_roh_hash_fpaths" ]; then

		# echo "* Found in file(s): [ ..."
		# echo "$list_roh_hash_fpaths"
		# echo "...]"

		local files_found=0
	
	    # Only print non-empty paths
	    while IFS= read -r found; do
	        if [ -n "$found" ]; then
				IFS=$'\r' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath <<< "$found"
				# echo "[$found_enc_abs_fpath] [$found_enc_abs_roh_hash_fpath]"

				# same hash fpath
				if [ "$found_enc_abs_roh_hash_fpath" = "$enc_abs_roh_hash_fpath" ]; then
					local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
					if [ -f "$found_abs_roh_hash_fpath" ]; then
						continue
					else
						echo "this should not happen, because we are processing orphans that exist"
						((ERROR_COUNT++))
						continue
					fi
				fi

				local found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")

				# diff fpath
				if [ -f "$found_abs_fpath" ]; then
					local computed_hash=$(generate_hash "$found_abs_fpath")
					if [ "$computed_hash" = "$stored" ]; then
						((files_found++))
						if [ "$files_found" -lt 3 ]; then
							[ "$VERBOSE_MODE" = "true" ] && echo "            ... [$found_abs_fpath] -- duplicate FOUND"
						fi
					else
						echo "  ERROR:    ... [$found_abs_fpath] -- hash mismatch: ..."
						echo "                ... computed [$computed_hash]"
						echo "                ...   stored [$stored]"
						((ERROR_COUNT++))
					fi
				else
					# we found another orphaned hash, assume the rest of the loop will take care of it
					[ "$VERBOSE_MODE" = "true" ] && echo "            ... [$found_abs_fpath] -- indexed, but missing"
				fi

			fi
	    done <<< "$list_roh_hash_fpaths"

		if [ "$files_found" -ne 0 ]; then
			if [ "$files_found" -gt 2 ]; then
				echo "            ... $((files_found - 2)) more ..."
			fi
			if rm "$roh_hash_fpath"; then
				if [ "$VERBOSE_MODE" = "true" ]; then
					echo "      ■: -- orphaned hash [$stored]: [$roh_hash_fpath] -- removed"
				else
					echo "RECOVER: [$stored]: [$roh_hash_fpath] orphaned hash -- removed"
				fi
			else
				echo "ERROR: Failed to remove hash [$roh_hash_fpath]"
				((ERROR_COUNT++))
			fi			
			return 0
		fi

	fi

	# else
	# no matching hash found, file identical file names

	if [ "$VERBOSE_MODE" = "true" ]; then
	   	echo "  ERROR:    ... hash not in IDX [$fpath] -- file DELETED !?"
	else
		echo "  ERROR: [$stored] -- hash not in IDX [$fpath] -- file DELETED !?"
	fi
	((ERROR_COUNT++))

	list_roh_hash_fpaths=$(roh_sqlite3_db_find_fn "$db" "$fn") || return 1
	if [ -n "$list_roh_hash_fpaths" ]; then

		# echo "* Found in file(s): [ ..."
		# echo "$list_roh_hash_fpaths"
		# echo "...]"

		#TODO: indexed, but missing 4 times
		local files_found=0

	    # Only print non-empty paths
	    while IFS= read -r found; do
			if [ -n "$found" ]; then
				IFS=$'\r' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath found_hash <<< "$found"
				# echo "[$found_enc_abs_fpath] [$found_enc_abs_roh_hash_fpath]==$enc_abs_roh_hash_fpath"

				# same fpath
				if [ "$found_enc_abs_roh_hash_fpath" = "$enc_abs_roh_hash_fpath" ]; then
					# echo "found_hash: $found_hash:$stored"
					local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
					if [ -f "$found_abs_roh_hash_fpath" ]; then
						if [ "$found_hash" != "$stored" ]; then
							echo "  ERROR:    ... hash mismatch: ..."
							echo "                ... indexed [$found_hash]: [$found_abs_roh_hash_fpath]"
							echo "                ...  stored [$stored]: [$abs_roh_hash_fpath]"
							((ERROR_COUNT++))
						fi								
						continue
					else
						echo "this should not happen, because we are processing orphans that exist"
						((ERROR_COUNT++))
						continue
					fi
				fi

				local found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")

				# diff fpath
				if [ -f "$found_abs_fpath" ]; then
 					found_computed_hash=$(generate_hash "$found_abs_fpath")
					local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
					if [ -f "$found_abs_roh_hash_fpath" ]; then
						found_stored=$(stored_hash "$found_abs_roh_hash_fpath")
						if [ "$found_computed_hash" != "$found_stored" ]; then
							echo "  ERROR:    ... hash mismatch -- matching FILENAME found ..."
							echo "                ...   stored [$found_stored]: [$found_abs_roh_hash_fpath]"
							echo "                ... computed [$found_computed_hash]: [$found_abs_fpath]"
							((ERROR_COUNT++))
							continue
						fi
					fi
					# echo "computed_hash: $found_computed_hash:$stored"
 					if [ "$found_computed_hash" = "$stored" ]; then
						# the indexed and found file at a different location was indexed with a wrong/outdated hash
 						echo "         ... duplicate FOUND [$found_abs_fpath]"
 					else
 						echo "            ... hash mismatch -- matching FILENAME found ..."
						echo "                ...   stored [$stored]: [$abs_roh_hash_fpath]"
						echo "                ... computed [$found_computed_hash]: [$found_abs_fpath]"
 					fi
				else
					echo "            ... [$found_abs_fpath] -- indexed, but missing"
				fi
			fi
	    done <<< "$list_roh_hash_fpaths"
	fi

	# else
	# echo "      ■: -- orphaned hash [$stored]: [$roh_hash_fpath] -- NOOP!"
	[ "$VERBOSE_MODE" = "true" ] && echo "      ■: -- NOOP!"

	return 0
}

run_directory_process() {
    local dir="$1"
	#local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local visibility_mode="$2"
    local force_mode="$3"

	if contains "hide" || ( contains "write" && [ "$visibility_mode" != "show" ] ); then
		if [ ! -d "$ROH_DIR" ]; then
			mkdir "$ROH_DIR"
		fi
 	elif contains "recover" || ( contains "show" && ! contains "write" ); then
		if [ ! -d "$ROH_DIR" ] || ! [ -x "$ROH_DIR" ]; then
			echo "ERROR: [$ROOT] -- missing or inacccessible [$ROH_DIR]. Aborting." >&2
			return 1
		fi 
	fi

	process_directory "$@" || return 1
	return 0
}

process_hash_repo()
{
	local dir="$1"

	if [ -d "$dir" ]; then
		: # echo "Processing directory: [$dir]"
	else
		echo "ERROR: can't find directory [$dir] for processing"
		((ERROR_COUNT++))
		return 0
	fi

    for roh_hash_fpath in "$dir"/*; do
 		# echo "* roh_hash_fpath: [$roh_hash_fpath]"

		if [ -L "$roh_hash_fpath" ]; then
			[ "$VERBOSE_MODE" = "true" ] && echo "Avoiding symlink [$roh_hash_fpath] like the Plague"
			continue

		# if the fpath is a directory AND empty, remove it on delete|sweep
        elif [ -d "$roh_hash_fpath" ]; then

			# save to local variable, because $roh_hash_fpath gets trash during recursion
			local recursive_dir="$roh_hash_fpath"

			#if [ "$(ls -A "/path/to/directory" | wc -l)" -eq 0 ]; then
			#if [[ -z "$(ls -A -- "$entry")" ]]; then
			# echo "Directory '$entry' is empty (including hidden files)"
			if [ -n "$(find "$recursive_dir" -mindepth 1 -print -quit)" ]; then

	 			if contains "verify" && [ "$VERBOSE_MODE" = "false" ]; then
					local dir_fpath="$(hash_fpath_to_fpath "$recursive_dir")"
					# echo "   * fpath DIRECTORY: [$dir_fpath]"
	 
	 				if [ ! -d "$dir_fpath" ]; then
						echo "ERROR: -- [$recursive_dir] -- orphaned hash DIRECTORY!"
						((ERROR_COUNT++))
						continue
	 				fi
	 
	 			fi

				process_hash_repo "$recursive_dir" || return 1
			fi

			if [ -z "$(find "$recursive_dir" -mindepth 1 -print -quit)" ]; then
				if contains "delete" || contains "sweep" || contains "recover"; then
					if ! rmdir "$recursive_dir"; then
						echo "ERROR: Failed to remove directory [$recursive_dir]"
						((ERROR_COUNT++))
					else
						[ "$VERBOSE_MODE" = "true" ] && echo "OK: orphaned hash directory [$recursive_dir] -- removed"
					fi
				fi
			fi

        elif [ -f "$roh_hash_fpath" ]; then

			local stored=$(stored_hash "$roh_hash_fpath")
			local fpath="$(hash_fpath_to_fpath "$roh_hash_fpath")"
			# echo "   * fpath: [$fpath]"

	 		# if the file corresponding to the hash doesn't exist (orphaned), remove it on sweep
	 		if ! stat "$fpath" >/dev/null 2>&1; then
	 			if contains "sweep"; then
	 				if ! rm "$roh_hash_fpath"; then
	 					echo "ERROR: Failed to remove hash [$roh_hash_fpath]"
	 					((ERROR_COUNT++))
	 				else
	 					echo "OK: orphaned hash [$stored]: [$roh_hash_fpath] -- removed"
						continue;
	 				fi
				fi
				if contains "verify"; then
	 				echo "ERROR: -- [$stored]: [$roh_hash_fpath] -- orphaned hash"
	 				#                                    "          [dfc5388fd5213984e345a62ff6fac21e0f0ec71df44f05340b0209e9cac489db]: [$fpath] -- NO corresponding file"
	 				[ "$VERBOSE_MODE" = "true" ] && echo "          ...                                          NO corresponding file: [$fpath]"
	 				((ERROR_COUNT++))
					[ "$EXPORT_MODE" = "true" ] && echo "$fpath" >> "$EXPORT_FN_DELETED"
	 			fi
 	 			if contains "index"; then
   			        local fpath_exists=$(roh_sqlite3_db_find_fpath "$DB_SQL" "$fpath" "$stored") || return 1
   			        if [ "$fpath_exists" -eq 0 ]; then
						roh_sqlite3_db_insert "$DB_SQL" "$fpath" "$roh_hash_fpath" "$stored"
						if [ "$VERBOSE_MODE" = "true" ] || contains "verify"; then
							echo " IDX: >$stored<: [$roh_hash_fpath] orphaned hash -- INDEXED"
						fi
						[ "$VERBOSE_MODE" = "true" ] && echo "      ...                                          NO corresponding file: [$fpath]"
   			        else
						[ "$VERBOSE_MODE" = "true" ] && echo " IDX: [$stored]: [$roh_hash_fpath] orphaned hash -- already indexed, skipping"
   			        fi
				fi
	 			if contains "recover"; then
	 				recover_hash "$DB_SQL" "$fpath" "$roh_hash_fpath" "$stored" || return 1 # never happens ?
				fi

			else
		 		if contains "index"; then
					local fpath_exists=$(roh_sqlite3_db_find_fpath "$DB_SQL" "$fpath" "$stored") || return 1
		 			if [ "$fpath_exists" -eq 0 ]; then
		 				roh_sqlite3_db_insert "$DB_SQL" "$fpath" "$roh_hash_fpath" "$stored"
		 				[ "$VERBOSE_MODE" = "true" ] && echo " IDX: >$stored<: [$roh_hash_fpath] -- INDEXED"
		 			else
		 				[ "$VERBOSE_MODE" = "true" ] && echo " IDX: [$stored]: [$roh_hash_fpath] -- already indexed, skipping"
		 			fi
		 		fi
			fi

        fi
    done

	return 0
}


hash_maintanence() {
    local dir="$1"
	#local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
#	local visibility_mode="$3"
#   local force_mode="$4"

	# searching for hashes, because .git exists
	if contains "index"; then
		if [ -z "$(find "$ROH_DIR" -name "*.sha256" -mindepth 1 -print -quit)" ]; then
			echo "ERROR: nothing to index [$ROH_DIR]"
			echo
			return 1
		fi
	fi

	# ROH_DIR must exist and be accessible for the while loop to execute
	[ ! -d "$ROH_DIR" ] || ! [ -x "$ROH_DIR" ] && return 0;

	process_hash_repo "$dir"

	# This will fail if git is being used
	if contains "sweep" || contains "show"; then
		#if [ "$(ls -A "/path/to/directory" | wc -l)" -eq 0 ]; then
		if [ -z "$(find "$ROH_DIR" -mindepth 1 -print -quit)" ]; then
			if ! rmdir "$ROH_DIR"; then
				echo "ERROR: Failed to remove [$ROH_DIR]"
				((ERROR_COUNT++))
			else
				[ "$VERBOSE_MODE" = "true" ] && echo "OK: remove [$ROH_DIR]"
			fi
		fi
	fi

	if contains "delete" && contains "sweep"; then
		if [ -f "$DB_SQL" ]; then
			if rm "$DB_SQL"; then
				echo "Removing DB_SQL [$DB_SQL]"
			else
				echo "ERROR: Failed to delete [$DB_SQL]"
				((ERROR_COUNT++))
			fi
		fi
	fi

	if [ "$x_roh_hash" = "false" ]; then
		echo "WARN: hashes not exclusively hidden in [$ROH_DIR]"
		((WARN_COUNT++))
	fi
	
	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

process_query() {
    local db="$1"
	local query_hash="$2"

    echo "query hash: [$query_hash]"
	list_roh_hash_fpaths=$(roh_sqlite3_db_find_hash "$db" "$query_hash")
	if [ $? -ne 0 ]; then
		echo "ERROR: failed to query db [$db]"
		return 1
	fi

	[ -z "$list_roh_hash_fpaths" ] && echo "  --"
	while IFS=$'\r' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath; do
		#[ -n "$found_enc_abs_fpath" ] && echo "[$fpath:$roh_hash_fpath]"
		if [ -n "$found_enc_abs_roh_hash_fpath" ]; then
			found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
			found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")
			echo "OK: --      hash path [$found_abs_roh_hash_fpath]"
			echo "       absolute fpath [$found_abs_fpath]"
		fi
	done <<< "$list_roh_hash_fpaths"
#    # Loop through DB_SQL array
#    for db_path in "${DB_SQL[@]}"; do
#		echo "db: [$db_path]"
#        list_roh_hash_fpaths=$(roh_sqlite3_db_search "$db_path" "$QUERY_HASH")
#        # Only print non-empty paths
#        while IFS= read -r fpath; do
#            [ -n "$fpath" ] && echo "[$fpath]"
#        done <<< "$list_roh_hash_fpaths"
#    done
}

if [ "$globspec_mode" = "true" ]; then
	# echo "* $@"
	for fpath in "$@"; do
		if contains "query"; then
			QUERY_HASH="$fpath"
			process_query "$DB_SQL" "$QUERY_HASH"
			continue
		fi

		[[ "${fpath}" = *.sha256 ]] && continue
	
		if ! [ -f "$fpath" ]; then
			echo "WARN: [$fpath] not a file -- SKIPPING"
			((WARN_COUNT++))
			continue
		fi
		
		dir=$(dirname -- "$fpath")
		entry="$fpath"

		VERBOSE_MODE="true" 

		if contains "write"; then
			write_hash "$dir" "$entry" "show" "$force_mode"
		fi
		if contains "verify"; then
			verify_hash "$dir" "$entry" 
		fi
		if contains "delete"; then
			delete_hash "$dir" "$entry" 
		fi
	done

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
	exit 0
fi

if contains "index" && ( contains "recover" || contains "query" ); then
	cmds_copy=("${commands[@]}")
	commands=("index")

	echo "Indexing ... [${ROH_DIR%/}]"
	hash_maintanence "${ROH_DIR%/}" # "$visibility_mode" "$force_mode"
	[ $? -ne 0 ] && echo && exit 1

	commands=("${cmds_copy[@]/index}")
fi

if contains "query"; then
    QUERY_HASH="$PATHSPEC"
	if ! process_query "$DB_SQL" "$QUERY_HASH"; then
		echo && exit 1
	fi

    echo "Done."
    exit 0
fi

if [ "$only_hashes" = "true" ]; then
	:
elif contains "write" || contains "delete" || contains "show" || contains "hide" || contains "verify" || contains "recover"; then
	# append a folder to ROOT without having a double /; and if the folder is "", no trailing slash on ROOT
	echo "Processing files ... [${ROOT%/}${PATHSPEC:+/$PATHSPEC}]"
	run_directory_process "${ROOT%/}${PATHSPEC:+/$PATHSPEC}" "$visibility_mode" "$force_mode"
	[ $? -ne 0 ] && echo && exit 1
	[ "$EXPORT_MODE" = "true" ] && echo " >> [$EXPORT_FN_NEW]"
fi

if [ "$only_files" = "true" ]; then
	:
elif contains "verify" || contains "recover" || contains "sweep" || contains "index"; then
	echo "Hash maintanence ... [${ROH_DIR%/}${PATHSPEC:+/$PATHSPEC}]"
	hash_maintanence "${ROH_DIR%/}${PATHSPEC:+/$PATHSPEC}" # "$visibility_mode" "$force_mode"
	[ $? -ne 0 ] && echo && exit 1
	[ "$EXPORT_MODE" = "true" ] && echo " >> [$EXPORT_FN_DELETED]"
fi

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

