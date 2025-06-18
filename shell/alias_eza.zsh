# Programmatically generate an alias for eza

typeset -a ARGS=(
    -a                        # show all files, including hidden ones
    --classify=always         # append indicator (one of */=>@|) to entries
    -g                        # print group name in long format
    --group-directories-first # list directories before other files
    -h                        # human-readable sizes
    --hyperlink               # enable hyperlinks
    --icons=auto              # display icons if supported
    -l                        # use a long listing format
    -M                        # display metadata
    --time-style=long-iso     # use long ISO time format
)

alias l="eza ${ARGS[@]}"