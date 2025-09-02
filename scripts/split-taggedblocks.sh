#!/bin/bash

if ! command -v gawk >/dev/null 2>&1; then
    echo "Error: GNU awk (gawk) is required for this script to run." >&2
    exit 1
fi

gawk '
BEGIN {
    RS = "";
    split("", key_array);
    split("", blocks);
}

{
    split($0, lines, "\n");
    if (length(lines) > 0 && lines[1] ~ /^
        key = lines[1];
        sub(/^
        blocks[key] = $0;
        key_array[length(key_array) + 1] = key;
    }
}

END {
    asort(key_array, sorted_keys);
    for (i = 1; i <= length(sorted_keys); i++) {
        if (i > 1) {
            print "";
        }
        print blocks[sorted_keys[i]];
    }
}
'
