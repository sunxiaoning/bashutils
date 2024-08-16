#!/usr/bin/env bash
set -eu

no_empty=false
error=false
output="&1"

case $1 in
    -e|--no-empty)
    no_empty=true
    shift
    ;;
esac

if [[ -n "${2-}" ]]; then
  output="$2"
fi

echo "output: $output" >&2


# Get all variable names used in the template
varnames=$(grep -oE '\{\{([A-Za-z0-9_]+)\}\}' $1 | sed -rn 's/.*\{\{([A-Za-z0-9_]+)\}\}.*/\1/p' | sort | uniq)

# Initialize the string of expressions to be used with sed
expressions=""

for varname in $varnames; do
        # Check if the variable named $varname is defined
        if [ -z ${!varname+x} ]; then
                if [[ $error = false ]]; then
                        echo "Error found in file $1:" >&2
                fi
                echo "ERROR: $varname is not defined" >&2
                error=true
        elif [ $no_empty = true ] && [ -z ${!varname} ]; then
                if [[ $error = false ]]; then
                        echo "Error found in file $1:" >&2
                fi
                echo "ERROR: $varname is empty" >&2
                error=true
        else
                # Get the value of the variable named $varname and escape
                # all forward slashes so that it doesn't break sed
                value="$(echo "${!varname}" | sed 's/\//\\\//g')"
                expressions+="-e 's/\{\{$varname\}\}/${value}/g' "
        fi
done

if [[ $error = true ]]; then
        exit 1
elif [[ -n $expressions ]]; then
        cat $1 | eval sed -r "$expressions" > $output
        exit 0
else
	      cat $1 > $output
        exit 0
fi