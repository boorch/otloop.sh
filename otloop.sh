#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-r] [-a] [filename or folder path] [slice_number]"
    echo "       -r: restore from backup if a backup file exists"
    echo "       -a: apply to all .ot files in the specified folder recursively. Requires a folder path instead of a filename."
    echo "       filename: the filename of the .ot file to modify"
    echo "       slice_number: the slice number to use for the loop start and loop length"
    echo "       Example usage for single file:  $0 -r my_file.ot 2"
    echo "       Example usage for all files in a folder and subfolders, starting from current folder:  $0 -a . 2"
    echo "       Example usage for all files in a folder and subfolders, starting from a specific folder:  $0 -a my_folder 2"
    echo "       Example usage for restoring all files in a folder and subfolders, starting from current folder:  $0 -r -a ."
    echo "       Example usage for restoring all files in a folder and subfolders, starting from a specific folder:  $0 -r -a my_folder"

    exit 1
}

# Check for no arguments, or wrong order or type of arguments.
if [[ $# -eq 0 ]] || [[ $# -gt 3 ]] || \
   { [[ "$1" != "-r" ]] && [[ "$1" != "-a" ]] && [[ ! -d "$1" ]] && [[ ! -f "$1" ]]; } || \
   { [[ $# -ge 2 ]] && [[ "$2" != "-a" ]] && [[ "$2" != "-r" ]] && [[ ! -d "$2" ]] && [[ ! -f "$2" ]] && ! [[ "$2" =~ ^[0-9]+$ ]]; } || \
   { [[ $# -eq 3 ]] && ! [[ "$3" =~ ^[0-9]+$ ]]; }; then
    usage
fi

# Function to restore from backup
restore_backup() {
    local original_file="$1"
    local backup_file="${original_file}.bak"
    
    if [[ -f "$backup_file" ]]; then
        if [[ -f "$original_file" ]]; then
            cp -f "$backup_file" "$original_file"
            rm -f "$backup_file"
            echo "Restored the original file from backup and deleted the backup file for $original_file."
        else
            echo "Original file $original_file does not exist. Backup cannot be restored."
        fi
    else
        echo "Backup for $original_file not found. Skipping."
    fi
}


# Function to get the number of slices
get_slice_count() {
    dd if="$1" bs=1 skip=826 count=4 status=none | od -An -tx4 | tr -d ' ' | perl -pe '$_ = unpack("V", pack("H*", $_))'
}

# Function to compute the checksum
compute_checksum() {
    local file="$1"
    local sum=0
    local file_size=$(stat -f%z "$file")
    local byte_count=$((file_size - 16 - 2))

    local bytes=$(dd if="$file" bs=1 skip=16 count=$byte_count status=none | od -An -tx1 -v | tr -d ' \n')

    for (( i=0; i<${#bytes}; i+=2 )); do
        local byte="${bytes:$i:2}"
        sum=$((sum + 0x$byte))
    done
    
    sum=$((sum & 0xFFFF))
    
    local high_byte=$(printf '%02x' $((sum >> 8)))
    local low_byte=$(printf '%02x' $((sum & 0xFF)))
    CHECKSUM="${low_byte}${high_byte}"
    echo "$CHECKSUM"
}

# Function to process a single file
process_file() {
    local file="$1"
    local slice_num="$2"

    # Create a backup of the file
    cp "$file" "${file}.bak"

    # Get the total number of slices
    TOTAL_SLICES=$(get_slice_count "$file")

    # Validate slice number input
    if [[ "$slice_num" -lt 1 ]] || [[ "$slice_num" -gt "$TOTAL_SLICES" ]]; then
        echo "Error: Slice number for $file should be between 1 and $TOTAL_SLICES."
        return 1
    fi

    # Calculate offsets for slice start and slice length
    local SLICE_START_OFFSET=$((58 + ($slice_num - 1) * 12))
    local SLICE_LENGTH_OFFSET=$((SLICE_START_OFFSET + 4))

    # Read slice start point and length
    local SLICE_START_HEX=$(dd if="$file" bs=1 skip=$SLICE_START_OFFSET count=4 status=none | od -An -tx4 | tr -d ' ')
    local SLICE_LENGTH_HEX=$(dd if="$file" bs=1 skip=$SLICE_LENGTH_OFFSET count=4 status=none | od -An -tx4 | tr -d ' ')

    # Modify loop start and loop length
    echo -n -e "\\x${SLICE_START_HEX:6:2}\\x${SLICE_START_HEX:4:2}\\x${SLICE_START_HEX:2:2}\\x${SLICE_START_HEX:0:2}" | dd of="$file" bs=1 seek=54 count=4 conv=notrunc status=none
    echo -n -e "\\x${SLICE_LENGTH_HEX:6:2}\\x${SLICE_LENGTH_HEX:4:2}\\x${SLICE_LENGTH_HEX:2:2}\\x${SLICE_LENGTH_HEX:0:2}" | dd of="$file" bs=1 seek=58 count=4 conv=notrunc status=none

    # Report changes
    echo "Changed loop start to slice start for $file: $SLICE_START_HEX"
    echo "Changed loop length to slice length for $file: $SLICE_LENGTH_HEX"

    # Recalculate and update checksum
    local CHECKSUM=$(compute_checksum "$file")
    echo -n -e "\\x${CHECKSUM:2:2}\\x${CHECKSUM:0:2}" | dd of="$file" bs=1 seek=830 count=2 conv=notrunc status=none

    echo "Checksum updated to: $CHECKSUM for $file"
}

# Export functions so they are available to sub-shells
export -f restore_backup
export -f process_file
export -f get_slice_count
export -f compute_checksum

# Parse options
restore_flag=false
all_flag=false
while getopts 'ra' flag; do
    case "${flag}" in
        r) restore_flag=true ;;
        a) all_flag=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND -1))

TARGET="$1"
SLICE_NUM="$2"


# Restore functionality for multiple files
if [[ "$restore_flag" == true ]]; then
    if [[ "$all_flag" == true ]]; then
        # Apply restore to all .bak files in directory and subdirectories, skipping macOS generated files
        find "$TARGET" -type f -name "*.bak" ! -name "._*" -exec bash -c 'restore_backup "${0%.bak}"' {} \;
    else
        # Restore a single file
        [[ -f "$TARGET" ]] && restore_backup "$TARGET" || echo "Error: Backup file $TARGET does not exist."
    fi
    exit 0
fi

# Functionality for modifying all .ot files in a directory
if [[ "$all_flag" == true ]]; then
    # Check if target is a directory
    if [[ ! -d "$TARGET" ]]; then
        echo "Error: When using the -a option, the target must be a directory."
        exit 1
    fi
    # Find all .ot files and process them, skipping macOS generated files
    find "$TARGET" -type f -name "*.ot" ! -name "._*" -exec bash -c 'process_file "$0" "$1"' {} "$SLICE_NUM" \;
    exit 0
fi

# Process a single file if not using -a
if [[ ! -f "$TARGET" ]]; then
    echo "Error: File does not exist."
    exit 1
fi

process_file "$TARGET" "$SLICE_NUM"
