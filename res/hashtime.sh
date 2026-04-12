#!/bin/bash

# Function to time hash computation
time_hash() {
    local file="$1"
    local hash_command="$2"
    
    echo "Timing $hash_command for file: $file"
    
    # Start timing
    start_time=$(date +%s.%N)
    
    # Compute hash and suppress output
	if [ "$hash_command" = "shasum" ]; then
		echo $(shasum -a 256 "$file" | awk '{print $1}')
	elif [ "$hash_command" = "stdbuf-shasum" ]; then
		echo $(stdbuf -i0 shasum -a 256 "$file" | cut -c1-64) # brew install coreutils || gstdbuf Instead
	elif [ "$hash_command" = "openssl" ]; then
		echo $(openssl sha256 "$file" | tail -c 65) # brew install coreutils || gstdbuf Instead
	elif [ "$hash_command" = "stdbuf-openssl" ]; then
		echo $(stdbuf -i0 openssl sha256 "$file" | tail -c 65) # brew install coreutils || gstdbuf Instead
	# elif [ "$hash_command" = "ramdisk-openssl" ]; then
	# 	# Create a RAM disk (example size, adjust as needed)
	# 	mkdir ramdisk
	# 	mount -t tmpfs -o size=2G tmpfs ramdisk
	# 	cp "$file" ramdisk/.
	# 	echo $(stdbuf -i0 openssl sha256 ramdisk/$(basename "$file") | tail -c 65) # brew install coreutils || gstdbuf Instead
	fi
    
    # End timing
    end_time=$(date +%s.%N)
    
    # Calculate elapsed time
    elapsed_time=$(echo "$end_time - $start_time" | bc)
    
    echo "Elapsed time: $elapsed_time seconds"
}

# File to hash (replace with your file)
file_to_hash="Fotos.zip"

time_hash "$1" "shasum"
time_hash "$1" "stdbuf-shasum"
time_hash "$1" "openssl"
time_hash "$1" "stdbuf-openssl"
