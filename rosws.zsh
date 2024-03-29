#!/bin/zsh

# Tool to manage multiple ROS 2 workspaces.
# Code extracted and adapted from wd plugin: @github.com/mfaerevaag/wd
#
# Repo URL: github.com/butakus/ros2-env


# version
readonly ROSWS_VERSION=0.1.0

# colors
readonly ROSWS_BLUE="\033[96m"
readonly ROSWS_GREEN="\033[92m"
readonly ROSWS_YELLOW="\033[93m"
readonly ROSWS_RED="\033[91m"
readonly ROSWS_NOC="\033[m"

# Temporarily set the ROS_DISTRO var to source the first setup
# After this first source in /opt/..., this var will be properly set and exported
# TODO: Find a proper way to configure this.
#       Maybe add new subcommands to set distro and cb_extra_args.
#       Those values can be persistent in a config file.
local ROS_DISTRO=${ROS_DISTRO:-humble}

## functions

# helpers
rosws_yesorno()
{
    # variables
    local question="${1}"
    local prompt="${question} "
    local yes_RETVAL="0"
    local no_RETVAL="3"
    local RETVAL=""
    local answer=""

    # read-eval loop
    while true ; do
        printf $prompt
        read -r answer

        case ${answer:=${default}} in
            "Y"|"y"|"YES"|"yes"|"Yes" )
                RETVAL=${yes_RETVAL} && \
                    break
                ;;
            "N"|"n"|"NO"|"no"|"No" )
                RETVAL=${no_RETVAL} && \
                    break
                ;;
            * )
                echo "Please provide a valid answer (y or n)"
                ;;
        esac
    done

    return ${RETVAL}
}

rosws_print_msg()
{
    if [[ -z $rosws_quiet_mode ]]
    then
        local color=$1
        local msg=$2

        if [[ $color == "" || $msg == "" ]]
        then
            print " ${ROSWS_RED}*${ROSWS_NOC} Could not print message. Sorry!"
        else
            print " ${color}*${ROSWS_NOC} ${msg}"
        fi
    fi
}

rosws_print_usage()
{
    command cat <<- EOF
Usage: rosws [command] [workspace]

Commands:
    <workspace>            Set the given workspace as the active one
    activate <workspace>   Set the given workspace as the active one
    add <workspace>        Adds the current working directory to your registered workspaces
    add                    Adds the current working directory to your registered workspaces with current directory's name
    rm <workspace>         Removes the given workspace
    list                   Print all registered workspaces
    show <workspace>       Print info of given workspace (name and path)
    path <workspace>       Show the path to given workspace (pwd)
    clean                  Remove workspaces pointing to non-existent directories (will prompt unless --force is used)
    cd <workspace> [<dir>] Change directory to the workspace. You can also cd to a dir inside the workspace.

    -v | --version  Print version
    -d | --debug    Exit after execution with exit codes (for testing)
    -q | --quiet    Suppress all output
    -f | --force    Allows overwriting without warning (for add & clean)

    help            Show this extremely helpful text
EOF
}

rosws_exit_fail()
{
    local msg=$1

    rosws_print_msg "$ROSWS_RED" "$msg"
    ROSWS_EXIT_CODE=1
}

rosws_exit_warn()
{
    local msg=$1

    rosws_print_msg "$ROSWS_YELLOW" "$msg"
    ROSWS_EXIT_CODE=1
}

rosws_getdir()
{
    local name_arg=$1

    point=$(rosws_show "$name_arg")
    dir=${point:28+$#name_arg+7}

    if [[ -z $name_arg ]]; then
        rosws_exit_fail "You must enter a workspace"
        break
    elif [[ -z $dir ]]; then
        rosws_exit_fail "Unknown workspace '${name_arg}'"
        break
    fi
}

# core
activate_ws()
{
    # Source ROS2 environment
    source /opt/ros/$ROS_DISTRO/setup.zsh
    # Source active workspace
    source "${rosws_workspaces[$ROSWS_ACTIVE_WS]/#\~/$HOME}/install/local_setup.zsh"

    # Set a custom domain ID
    # export ROS_DOMAIN_ID=101
}

rosws_activate()
{
    local ws_name=$1

    if [[ $ws_name =~ "^\.+$" ]]
    then
        if [[ $#1 < 2 ]]
        then
            rosws_exit_warn "Activate current directory?"
        else
            (( n = $#1 - 1 ))
            cd -$n > /dev/null
        fi
    elif [[ ${rosws_workspaces[$ws_name]} != "" ]]
    then
        # Activate the workspace
        export ROSWS_ACTIVE_WS=$ws_name
        activate_ws
    else
        rosws_exit_fail "Unknown workspace '${ws_name}'"
    fi
}

rosws_add()
{
    local ws_name=$1
    local force=$2
    cmdnames=(add rm show list ls path clean help)

    if [[ $ws_name == "" ]]
    then
        ws_name=$(basename "$PWD")
    fi

    if [[ $ws_name =~ "^[\.]+$" ]]
    then
        rosws_exit_fail "Workspace name cannot be just dots"
    elif [[ $ws_name =~ "[[:space:]]+" ]]
    then
        rosws_exit_fail "Workspace name should not contain whitespace"
    elif [[ $ws_name =~ : ]] || [[ $ws_name =~ / ]]
    then
        rosws_exit_fail "Workspace name contains illegal character (:/)"
    elif (($cmdnames[(Ie)$ws_name]))
    then
        rosws_exit_fail "Workspace name cannot be a rosws command (see rosws -h for a full list)"
    elif [[ ${rosws_workspaces[$ws_name]} == "" ]] || [ ! -z "$force" ]
    then
        rosws_remove "$ws_name" > /dev/null
        printf "%q:%s\n" "${ws_name}" "${PWD/#$HOME/~}" >> "$ROSWS_CONFIG"
        if (whence sort >/dev/null); then
            local config_tmp=$(mktemp "${TMPDIR:-/tmp}/rosws.XXXXXXXXXX")
            # use 'cat' below to ensure we respect $ROSWS_CONFIG as a symlink
            command sort -o "${config_tmp}" "$ROSWS_CONFIG" && command cat "${config_tmp}" >| "$ROSWS_CONFIG" && command rm "${config_tmp}"
        fi

        rosws_print_msg "$ROSWS_GREEN" "Workspace added"

        # override exit code in case rosws_remove did not remove any workspaces
        # TODO: we should handle this kind of logic better
        ROSWS_EXIT_CODE=0
    else
        rosws_exit_warn "Workspace '${ws_name}' already exists. Use 'add --force' to overwrite."
    fi
}

rosws_remove()
{
    local ws_list=$1

    if [[ "$ws_list" == "" ]]
    then
        rosws_exit_fail "You must enter a workspace"
    else
        for ws_name in $ws_list ; do
            if [[ ${rosws_workspaces[$ws_name]} != "" ]]
            then
                local config_tmp=$(mktemp "${TMPDIR:-/tmp}/rosws.XXXXXXXXXX")
                # Copy and delete in two steps in order to preserve symlinks
                if sed -n "/^${ws_name}:.*$/!p" "$ROSWS_CONFIG" >| "$config_tmp" && command cp "$config_tmp" "$ROSWS_CONFIG" && command rm "$config_tmp"
                then
                    rosws_print_msg "$ROSWS_GREEN" "Workspace removed"
                else
                    rosws_exit_fail "Something bad happened! Sorry."
                fi
            else
                rosws_exit_fail "Workspace was not found"
            fi
        done
    fi
}

rosws_list_all()
{
    rosws_print_msg "$ROSWS_BLUE" "All workspaces:"

    entries=$(sed "s:${HOME}:~:g" "$ROSWS_CONFIG")

    max_ws_name_length=0
    while IFS= read -r line
    do
        arr=(${(s,:,)line})
        ws_name=${arr[1]}

        length=${#ws_name}
        if [[ length -gt max_ws_name_length ]]
        then
            max_ws_name_length=$length
        fi
    done <<< "$entries"

    while IFS= read -r line
    do
        if [[ $line != "" ]]
        then
            arr=(${(s,:,)line})
            ws_name=${arr[1]}
            ws_path=${line#"${arr[1]}:"}

            if [[ -z $rosws_quiet_mode ]]
            then
                if [[ $ws_name == $ROSWS_ACTIVE_WS ]]
                then
                    printf "%${max_ws_name_length}s  ->  %s ${ROSWS_GREEN}(active)${ROSWS_NOC}\n" "$ws_name" "$ws_path"
                else
                    printf "%${max_ws_name_length}s  ->  %s\n" "$ws_name" "$ws_path"
                fi
            fi
        fi
    done <<< "$entries"
}

rosws_path()
{
    rosws_getdir "$1"
    echo "$(echo "$dir" | sed "s:~:${HOME}:g")"
}

rosws_show()
{
    local ws_name=$1
    # if there's an argument we look up the value
    if [[ -n $ws_name ]]
    then
        if [[ -z $rosws_workspaces[$ws_name] ]]
        then
            rosws_print_msg "$ROSWS_BLUE" "No workspace named $ws_name"
        else
            if [[ $ws_name == $ROSWS_ACTIVE_WS ]]
            then
                rosws_print_msg "$ROSWS_GREEN" "Workspace: ${ROSWS_GREEN}$ws_name${ROSWS_NOC} -> $rosws_workspaces[$ws_name] ${ROSWS_GREEN}(active)${ROSWS_NOC}"
            else
                rosws_print_msg "$ROSWS_GREEN" "Workspace: ${ROSWS_GREEN}$ws_name${ROSWS_NOC} -> $rosws_workspaces[$ws_name]"
            fi
        fi
    else
        rosws_exit_fail "You must enter a workspace"
    fi
}

rosws_clean()
{
    local force=$1
    local count=0
    local rosws_tmp=""

    while read -r line
    do
        if [[ $line != "" ]]
        then
            arr=(${(s,:,)line})
            ws_name=${arr[1]}
            ws_path=${arr[2]}

            if [ -d "${ws_path/#\~/$HOME}" ]
            then
                rosws_tmp=$rosws_tmp"\n"`echo "$line"`
            else
                rosws_print_msg "$ROSWS_YELLOW" "Nonexistent directory: ${ws_name} -> ${ws_path}"
                count=$((count+1))
            fi
        fi
    done < "$ROSWS_CONFIG"

    if [[ $count -eq 0 ]]
    then
        rosws_print_msg "$ROSWS_BLUE" "No workspaces to clean, carry on!"
    else
        if [ ! -z "$force" ] || rosws_yesorno "Removing ${count} workspaces. Continue? (y/n)"
        then
            echo "$rosws_tmp" >! "$ROSWS_CONFIG"
            rosws_print_msg "$ROSWS_GREEN" "Cleanup complete. ${count} workspace(s) removed"
        else
            rosws_print_msg "$ROSWS_BLUE" "Cleanup aborted"
        fi
    fi
}

rosws_cd()
{
    local ws_name=$1
    local subdir=$2

    # Handle the case with no ws_name (cd to active ws)
    if [[ -z $ws_name ]]
    then
        if [[ -z $ROSWS_ACTIVE_WS ]]
        then
            rosws_exit_fail "There is no active workspace. Use rosws <workspace> to activate a workspace"
        elif [[ rosws_workspaces[$ROSWS_ACTIVE_WS] != "" ]]
        then
            cd ${rosws_workspaces[$ROSWS_ACTIVE_WS]/#\~/$HOME}/$subdir
        else
            rosws_exit_fail "Active workspace $ROSWS_ACTIVE_WS is not in the list of workspaces!\n"\
                            "Please check your configuration and/or re-activate the workspace."

        fi
    elif [[ -z $rosws_workspaces[$ws_name] ]]
    then
        rosws_exit_fail "Unknown workspace '${ws_name}'"
    else
        if [[ $subdir != "" ]]
        then
            cd ${rosws_workspaces[$ws_name]/#\~/$HOME}/$subdir
        else
            cd ${rosws_workspaces[$ws_name]/#\~/$HOME}
        fi
    fi
}

local ROSWS_CONFIG=${ROSWS_CONFIG:-$HOME/.config/ros2-env/workspaces}
local ROSWS_QUIET=0
local ROSWS_EXIT_CODE=0
local ROSWS_DEBUG=0

# Parse 'meta' options first to avoid the need to have them before
# other commands. The `-D` flag consumes recognized options so that
# the actual command parsing won't be affected.

zparseopts -D -E \
    q=rosws_quiet_mode -quiet=rosws_quiet_mode \
    v=rosws_print_version -version=rosws_print_version \
    d=rosws_debug_mode -debug=rosws_debug_mode \
    f=rosws_force_mode -force=rosws_force_mode

if [[ ! -z $rosws_print_version ]]
then
    echo "rosws version $ROSWS_VERSION"
fi

# check if config file exists
# if [ ! -e "$ROSWS_CONFIG" ]
# then
#     # if not, check if config dir exists and create everything
#     if [ ! -d "$(dirname "${ROSWS_CONFIG}")" ]; then
#         mkdir -p "$(dirname "${ROSWS_CONFIG}")"
#     fi
#     touch "$ROSWS_CONFIG"
# fi

# disable extendedglob for the complete rosws execution time
setopt | grep -q extendedglob
rosws_extglob_is_set=$?
(( ! $rosws_extglob_is_set )) && setopt noextendedglob

# load workspaces
# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
source ${0:A:h}/load_workspaces.zsh
load_workspaces

# get opts
args=$(getopt -o a:r:c:lhs -l add:,activate:,rm:,clean,list,path:,help,show -- $*)

# check if no arguments were given, and that version is not set
if [[ ($? -ne 0 || $#* -eq 0) && -z $rosws_print_version ]]
then
    rosws_print_usage

# check if config file is writeable
elif [ ! -w "$ROSWS_CONFIG" ]
then
    # do nothing
    # can't run `exit`, as this would exit the executing shell
    rosws_exit_fail "\'$ROSWS_CONFIG\' is not writeable."

else
    # parse rest of options
    local rosws_o
    for rosws_o
    do
        case "$rosws_o"
            in
            "-a"|"--add"|"add")
                rosws_add "$2" "$rosws_force_mode"
                break
                ;;
            "--activate"|"activate")
                rosws_activate "$2"
                break
                ;;
            "-r"|"--remove"|"rm")
                # Passes all the arguments as a single string separated by whitespace to rosws_remove
                rosws_remove "${@:2}"
                break
                ;;
            "-l"|"list")
                rosws_list_all
                break
                ;;
            "-p"|"--path"|"path")
                rosws_path "$2"
                break
                ;;
            "-h"|"--help"|"help")
                rosws_print_usage
                break
                ;;
            "-s"|"--show"|"show")
                rosws_show "$2"
                break
                ;;
            "-c"|"--clean"|"clean")
                rosws_clean "$rosws_force_mode"
                break
                ;;
            "-d"|"--cd"|"cd")
                rosws_cd "$2" "$3"
                break
                ;;
            *)
                rosws_activate "$rosws_o"
                break
                ;;
            --)
                break
                ;;
        esac
    done
fi

## garbage collection
# if not, next time warp will pick up variables from this run
# remember, there's no sub shell

(( ! $rosws_extglob_is_set )) && setopt extendedglob

unset rosws_extglob_is_set
# unset -f rosws_add
# unset -f rosws_activate
# unset -f rosws_remove
# unset -f rosws_list_all
# unset -f rosws_path
# unset -f rosws_show
# unset -f rosws_clean
# unset -f rosws_yesorno
# unset -f rosws_getdir
# unset -f rosws_exit_warn
# unset -f rosws_exit_fail
# unset -f rosws_print_msg
# unset -f rosws_print_usage
unset rosws_quiet_mode
unset rosws_force_mode
unset rosws_print_version
unset rosws_o

unset args

if [[ -n $rosws_debug_mode ]]
then
    exit $ROSWS_EXIT_CODE
else
    unset rosws_debug_mode
fi
