#!/usr/bin/env bash
#
# Handles output verbosity level.
# See https://github.com/juliendufresne/verbosity-bash-lib for more details.

if [[ "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]}" -lt 3 ]] \
    || [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
then
    >&2 echo "verbosity lib only works with bash version 4.3+"
    false

    exit
fi

# do not import this lib twice
[[ "$(type -t "verbosity::from_command_line")" =~ ^function$ ]] && return

################################################################################
# If set to true, then no verbosity level will be specified and you will have to
# specify them manually by using verbosity::add_level_definition
#
# Usage:
# VERBOSITY_CUSTOM=true source verbosity.sh
#
# Note: we could have used a source argument (source verbosity.sh "--custom")
#       but there is no way to check if arguments are coming from the source
#       command or by the command line.
################################################################################
declare -g VERBOSITY_CUSTOM=${VERBOSITY_CUSTOM:-false}

################################################################################
# List of file descriptor open.
# Key = verbosity level
# Value = file descriptor
#
# Please use it as if it was a read only variable
#
# Usage:
# echo "displayed in given level" >&${VERBOSITY_FD[2]}
#
# If you think the variable is too long, do not hesitate to copy it:
# declare -r V=${VERBOSITY_FD[2]}
# echo "displayed in given level" >&$V
################################################################################
declare -g -a VERBOSITY_FD=()

################################################################################
# verbosity::add_level_definition level [cli_option [...]]
#
# Add a verbosity level with - optionally - some command line option to
# match the level.
# This allows you to control the number of verbosity level and adapt command
# line options to your script context.
#
# You will then be able to output to the corresponding file descriptor
#  >&${VERBOSITY_FD[level]} echo "This is only shown if the script execution \
#                                 level is equal or bigger to level"
#
# Globals:
#   VERBOSITY_FD will contain a new entry with the level as key
# Arguments:
#   level        Integer. The level you want to add.
#   cli_option   string. List of command line option that will wet the verbosity
#                level to the one specified in first argument.
#   ...          other cli_option
# Returns:
#   0 in case of success
#   1 if an option has already been defined
################################################################################
function verbosity::add_level_definition
{
    declare -r -i level="$1"
    shift

    declare -i exit_status=0

    # we could mark this variable global but there is no need to mess with the
    # global scope for a very weird usage. Sourcing lib and level definition
    # should be on the same scope (and yes, most of the time it's on the global
    # scope anyway)
    if ! grep -q "__verbosity_option_level_list=" <<<"$(declare -A)"
    then
        verbosity::_error \
"this function call must be on the same scope than the one sourcing the \
verbosity lib"

        return
    fi

    for option in "$@"
    do
        if [[ -v __verbosity_option_level_list["${option}"] ]] && \
           [[ "${__verbosity_option_level_list["${option}"]}" -ne "${level}" ]]
        then
            verbosity::_error "cli option '${option}' already used for level \
'${__verbosity_option_level_list["${option}"]}'" || true
            exit_status=1
        else
            __verbosity_option_level_list["${option}"]="${level}"
        fi
    done

    # do not open a file descriptor for the quiet mode
    if [[ "${level}" -gt 1 ]] && ! [[ -v VERBOSITY_FD["${level}"] ]]
    then
        # open file descriptor
        # shellcheck disable=SC1083
        exec {VERBOSITY_FD["${level}"]}>/dev/null
    fi

    return "${exit_status}"
}

################################################################################
# Search for option in command line arguments.
# Only last option corresponding to a verbosity option will take effect.
# Options after "--" are not parsed.
# Note that this lib does not parse grouped short options. For example,
# it will not detect `-q` nor `-v` in `my_script -qav`
#
# Globals:
#   VERBOSITY_FD to activate every level up to the one defined in the cli.
# Arguments:
#   list of options and arguments of command line.
# Returns:
#   None
################################################################################
function verbosity::from_command_line
{
    declare level=""

    # we could mark this variable global but there is no need to mess with the
    # global scope for a very weird usage. Sourcing lib and level definition
    # should be on the same scope (and yes, most of the time it's on the global
    # scope anyway)
    if ! grep -q "__verbosity_option_level_list=" <<<"$(declare -A)"
    then
        verbosity::_error \
"this function call must be on the same scope than the one sourcing the \
verbosity lib"

        return
    fi

    # strategy: only take care of the last option
    for option in "$@"
    do
        if [[ "${option}" == "--" ]]
        then
            break
        fi

        for verbosity_option in "${!__verbosity_option_level_list[@]}"
        do
            if [[ "${option}" == "${verbosity_option}" ]]
            then
                level="${__verbosity_option_level_list[${verbosity_option}]}"
                continue 2 # back to the option loop
            fi
        done
    done

    [[ -z "${level}" ]] && return

    verbosity::set_current_level "${level}"
}

################################################################################
# Specify current execution verbosity level. This is a more manual alternative
# to the `verbosity::from_command_line` function.
#
# Every level below the one specified will output to stdout, others will be
# redirected to /dev/null
#
# Globals:
#   VERBOSITY_FD to redirect file descriptors to the right output
# Arguments:
#   level  the level you want to use for the current script execution.
# Returns:
#   None
################################################################################
function verbosity::set_current_level
{
    declare -i -r level="$1"

    # stdout must be set and can not be changed
    VERBOSITY_FD[1]=1

    # loop over fd and activate all fd up to level
    for fd_level in "${!VERBOSITY_FD[@]}"
    do
        # VERBOSITY_FD is global hence untrusted
        [[ "${fd_level}" -eq 0 ]] && continue

        if [[ "${fd_level}" -le "${level}" ]]
        then
            eval "exec ${VERBOSITY_FD[${fd_level}]}>$(tty)"
        else
            eval "exec ${VERBOSITY_FD[${fd_level}]}>/dev/null"
        fi
    done
}

#
#
# INTERNAL functions. Not supposed to be used outside this lib
#
#

################################################################################
# Specifies some default levels and corresponding command line options.
#
# Globals:
#   VERBOSITY_FD to add new file descriptors for verbosity level 2 and above
# Arguments:
#   None
# Returns:
#   None
################################################################################
function verbosity::_configure_default_levels
{
    # configure
    verbosity::add_level_definition 0 "-q" "--quiet"
    verbosity::add_level_definition 2 "-v" "--verbose"
}

################################################################################
# Display an error message.
# Message will contain filename and line of the script calling this lib.
#
# This assume the error is not within the lib itself but from a user wrong call.
#
# Globals:
#   None
# Arguments:
#   Message to be displayed
# Returns:
#   generic error code (1)
################################################################################
function verbosity::_error
{
    declare -r message="$1"

    declare -r    lib_prefix="verbosity::"
    declare -r -i lib_prefix_length="${#lib_prefix}"

    declare caller_filename="${BASH_SOURCE[0]}"
    declare caller_line="${BASH_LINENO[0]}"
    declare function_name="${FUNCNAME[0]}"

    # goal: show the line of developer's own code that fails, not the internal
    # recipe
    for history_line in "${!BASH_SOURCE[@]}"
    do
        caller_filename="${BASH_SOURCE[${history_line}]}"

        # case the lib lives in its own file
        [[ "${caller_filename}" != "${BASH_SOURCE[0]}" ]] && break

        declare _function_name="${FUNCNAME[${history_line}]}"

        # case the lib is copy/pasted or error happened during source
        # meaning _function_name is not a lib function
        if [[ "${_function_name:0:${lib_prefix_length}}" != "${lib_prefix}" ]]
        then
            break
        fi

        function_name="${_function_name}"
        caller_line="${BASH_LINENO[${history_line}]}"
    done

    >&2 echo \
"${caller_filename}: line ${caller_line}: ${function_name}: ${message}"

    false
}

#
# This is only used during configuration and is therefore not defined global
# structure:
#   [option] => level
# example:
#   [-q] => 0
#   [--quiet] => 0
#   [-v] => 2
#   [--verbose] => 2
declare -A __verbosity_option_level_list=()

if ! ${VERBOSITY_CUSTOM}
then
    verbosity::_configure_default_levels
    verbosity::from_command_line "$@"
fi
