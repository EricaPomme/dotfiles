#!/bin/bash

# Check if GNU awk (gawk) is installed
if ! command -v gawk >/dev/null 2>&1; then
    echo "Error: GNU awk (gawk) is required for this script to run." >&2
    exit 1
fi

gawk '
BEGIN {
    RS = "";  # Treat blocks as records separated by blank lines
    split("", key_array);  # Explicitly initialize key_array as an empty array
    split("", blocks);     # Explicitly initialize blocks as an empty associative array
}

{
    split($0, lines, "\n");                      # Split the current record into an array of lines
    if (length(lines) > 0 && lines[1] ~ /^#/) {  # Check if the first line is a comment
        key = lines[1];                          # Extract the first line
        sub(/^#\s*/, "", key);                   # Remove "# " and any leading spaces to get the key
        blocks[key] = $0;                        # Store the full block in the associative array
        key_array[length(key_array) + 1] = key;  # Add the key to the array for sorting
    }
}

END {
    asort(key_array, sorted_keys);  # Sort the keys array
    for (i = 1; i <= length(sorted_keys); i++) {
        if (i > 1) {
            print "";  # Print a blank line between blocks
        }
        print blocks[sorted_keys[i]];  # Output the sorted block
    }
}
'
