#!/bin/bash

SPACES_PER_INDENT=2
INDENT=$(eval "printf ' %.0s' {1..$SPACES_PER_INDENT}")

# Dislaimer: This is far for feature complete. 
# TODO: YAML sequences (arrays)

# yaml_to_dumbl 
# ---------------
# Converts YAML to a dumb intermediary format which is easier to process.
# It replaces indentation in the YAML file with comma delimited variable path.
#
# Example:
# (Contents of example.yml)
# | some:
# |   deeply:
# |     nested:
# |       option: 1
#
# cat example.yml | yaml_to_dumbl 
# | some:
# | some.deeply:
# | some.deeply.nested:
# | some.deeply.nested.option: 1
#

yaml_to_dumbl() {
    while IFS= read -r line; do
        num_spaces=$(echo "$line" | sed -e 's/:.*//g' -e 's/[^ ]//g' | wc -c)
        level=$(((num_spaces-1)/$SPACES_PER_INDENT))
        if [ "$level" -le 0 ]; then
            nodes=()
        else
            nodes=("${nodes[@]:0:$level}")
        fi
        node=$(echo "$line" | sed "s/^ *\([^:]\+\):.*$/\1/")
        nodes+=($node)
        doturi=$(IFS=.; echo "${nodes[*]}")
        line=$(echo "$line" | sed "s/^.*:/$doturi:/")
        echo "$line"
    done < "/dev/stdin"
}


# dumbl_to_yaml
# ---------------
# Converts dumbl back into YAML.
#
# Example:
# (Contents of example.dumbl)
# | some:
# | some.deeply:
# | some.deeply.nested:
# | some.deeply.nested.option: 1
#
# cat example.dumbl | dumbl_to_yaml
# | some:
# |   deeply:
# |     nested:
# |       option: 1
#

dumbl_to_yaml() {
    cat /dev/stdin | sed -e ":loop" -e "s/^\( *\)\([^.:]\+\)\./\1$INDENT/g" -e "t loop"
}

yaml_replace() {
    cat /dev/stdin | yaml_to_dumbl | sed "s/^$1:.*/$1: $2/g" | dumbl_to_yaml
}

yaml_remove() {
    cat /dev/stdin | yaml_to_dumbl | grep -v "^$1" | dumbl_to_yaml
}

yaml_rename() {
    cat /dev/stdin | yaml_to_dumbl | sed "s/$1\(.*:\)/$2\1/g" | dumbl_to_yaml
}

yaml_get() {
    cat /dev/stdin | yaml_to_dumbl | grep "$1" - | dumbl_to_yaml
}

yaml_get_value() {
    cat /dev/stdin | yaml_to_dumbl | grep "$1" | dumbl_to_yaml | sed 's/^[^:]\+: *//'
}

# # TODO: BROKEN
# yaml_set() {
#     local level=0
#     local current_doturi=
#     IFS='.' read -r -a parts <<< "$1"
#     while IFS= read -r line; do
#         doturi=$(echo "$line" | sed -e 's/:.*//g' -e 's/^ *//g')
#         if [ -z "$current_doturi" ]; then 
#             current_doturi="${parts[$level]}"
#             level=$((level+1))
#         fi
#         if [ "$doturi" == "$current_doturi" ]; then
#             current_doturi="${parts[$level]}"
#             level=$((level+1))
#         fi
#     done < <(cat /dev/stdin | yaml_to_dumbl | sort)
# }

yaml_parse() {
    local prefix=
    # using tee as a noop filter by default
    local filter=tee
    while true; do
        case "$1" in
            --prefix)
                prefix="$2_"
                shift 2
                ;; 
            *)
                if [ -z "$1" ]; then
                    break;
                fi
                filter="grep '$1'"
                shift
        esac
    done

    cat /dev/stdin | yaml_to_dumbl | eval "$filter" | sed -e ':loop' -e 's/\([^:]\+\)\.\([^:]\+\):/\1_\2:/' -e 't loop' -e 's/: *\(.*\)/="\1"/' -e "s/^/$prefix/"
}
