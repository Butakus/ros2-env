#!/bin/zsh

# Tool to manage multiple ROS 2 workspaces.
# Code extracted and adapted from wd plugin: @github.com/mfaerevaag/wd
#
# Repo URL: github.com/butakus/ros2-env


# version
readonly ROSWS_VERSION=0.2.0

# colors
readonly ROSWS_BLUE="\033[96m"
readonly ROSWS_GREEN="\033[92m"
readonly ROSWS_YELLOW="\033[93m"
readonly ROSWS_RED="\033[91m"
readonly ROSWS_NOC="\033[m"

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
    <workspace>               Set the given workspace as the active one
    activate <workspace>      Set the given workspace as the active one
    add <workspace>           Adds the current working directory to your registered workspaces
    add                       Adds a new workspace with current directory's name
    add <workspace> <distro>  Adds a new workspace using a specific ROS distro
    add <workspace> <distro> [<parent dirs>]  Adds a new workspace using a specific ROS distro and a list of parent workspaces
    cd <workspace> [<dir>]    Change directory to the workspace. You can also cd to a dir inside the workspace.
    clean                     Remove workspaces pointing to non-existent directories (will prompt unless --force is used)
    default                   Print the default workspace
    default set <workspace>   Set the default workspace. It will be activated automatically on every new shell.
    default unset             Unset the default workspace.
    distro <distro>           Set and source the given ROS 2 distro (humble, iron, rolling, etc.)
    domain <domain>           Set the ROS 2 domain ID (0-250)
    list                      Print all registered workspaces
    path <workspace>          Show the path to given workspace (pwd)
    rm <workspace>            Removes the given workspace
    rmw <rmw_implementation>  Set the RMW implementation (rmw_fastrtps_cpp, rmw_cyclonedds_cpp, etc.)
    show <workspace>          Print info of given workspace (name and path)

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

parse_ws_data()
{
    local ws_name=$1
    if [[ ${rosws_workspaces[$ws_name]} != "" ]]
    then
        # Split the ws data to extract distro and ws paths
        local rosws_data=(${(s,:,)rosws_workspaces[$ws_name]})
        ws_distro=${rosws_data[1]}
        ws_path=${rosws_data[-1]}
        # List of paths for parent workspaces to be sourced in cascade
        ws_parents=(${rosws_data[2,-2]})
        return 0
    fi
    # Return error if ws_name is not in the list
    return 1
}

# core
activate_ws()
{
    local ws_name=$1
    # Activate the workspace
    export ROSWS_ACTIVE_WS=$ws_name

    parse_ws_data $ws_name
    # First source the base ROS distro environment
    source "/opt/ros/${ws_distro}/setup.zsh"
    # Source all parent workspaces, if any
    for parent in $ws_parents
    do
        source "${parent/#\~/$HOME}/install/local_setup.zsh"
    done
    # Source active workspace
    source "${ws_path/#\~/$HOME}/install/local_setup.zsh"
}

rosws_activate()
{
    local ws_name=$1

    if [[ ${rosws_workspaces[$ws_name]} != "" ]]
    then
        activate_ws $ws_name
    else
        rosws_exit_fail "Unknown workspace '${ws_name}'"
    fi
}

rosws_default()
{
    # The first argument may be empty, a ws_name, or the verbs 'set' and 'unset'
    # If empty, return the current default workspace from _ROSWS_CONFIG_DEFAULT
    # If 'set', set the default workspace to the value of $2
    # If 'unset', remove the default workspace from _ROSWS_CONFIG_DEFAULT
    # If a ws_name, set the default workspace to the value of $1
    if [[ $1 == "" ]]
    then
        if [[ -e $_ROSWS_CONFIG_DEFAULT ]]
        then
            local default_ws=$(cat $_ROSWS_CONFIG_DEFAULT)
            if [[ $default_ws != "" ]]
            then
                echo "Default workspace:"
                (rosws show $default_ws)
            else
                echo "No default workspace set"
            fi
        else
            echo "No default workspace set"
        fi
    elif [[ $1 == "set" ]]
    then
        if [[ -z $2 ]]
        then
            rosws_exit_fail "You must enter a workspace name to set as default"
        else
            # Check if the workspace is in the list of workspaces
            if [[ -z $rosws_workspaces[$2] ]]
            then
                rosws_exit_fail "Workspace '$2' is not in the list of workspaces"
                return
            else
                echo "$2" >| $_ROSWS_CONFIG_DEFAULT
                rosws_print_msg "$ROSWS_GREEN" "Default workspace set to '$2'"
                rosws_activate "$2"
            fi
        fi
    elif [[ $1 == "unset" ]]
    then
        # Clear the file contents
        echo "" >| $_ROSWS_CONFIG_DEFAULT
        rosws_print_msg "$ROSWS_GREEN" "Default workspace unset"
    else
        # Check if the workspace is in the list of workspaces
        if [[ -z $rosws_workspaces[$1] ]]
        then
            rosws_exit_fail "Workspace '$1' is not in the list of workspaces"
            return
        else
            echo "$1" >| $_ROSWS_CONFIG_DEFAULT
            rosws_print_msg "$ROSWS_GREEN" "Default workspace set to '$1'"
            rosws_activate "$1"
        fi
    fi
}

rosws_distro()
{
    source /opt/ros/$1/setup.zsh || rosws_exit_fail "ROS distro '${1}' is not installed"
}

rosws_domain()
{
    local domain=$1
    if [[ $domain =~ ^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|250)$ ]]
    then
        export ROS_DOMAIN_ID=$domain
    else
        rosws_exit_fail "ROS DOMAIN ID must be a number between 0 and 250"
    fi
}

rosws_rmw()
{
    export RMW_IMPLEMENTATION=$1
}

rosws_add()
{
    local ws_name=$1
    local distro=$2
    local ws_parents=(${@:3})
    local cmdnames=(add activate default set distro domain rmw rm show cd list path clean help)
    local -a ros_distros=(
        ardent
        bouncy
        crystal
        dashing
        eloquent
        foxy
        galactic
        humble
        iron
        jazzy
        rolling
    )

    if [[ $ws_name == "" ]]
    then
        ws_name=$(basename "$PWD")
    fi

    # Set ROS 2 distro
    if [[ $distro == "" ]]
    then
        # Set distro as $ROS_DISTRO if exists or raise error
        if [[ -v ROS_DISTRO ]]
        then
            distro=$ROS_DISTRO
        else
            rosws_exit_fail "Distro not specified and \$ROS_DISTRO is not set"
            return
        fi
    elif (( ! $ros_distros[(Ie)$distro] ))
    then
        # The given distro is not in the list
        rosws_exit_fail "Distro '${distro}' does not exist"
        return
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
    elif [[ ${rosws_workspaces[$ws_name]} == "" ]] || [ ! -z "$rosws_force_mode" ]
    then
        rosws_remove "$ws_name" > /dev/null
        # Build string of parent workspaces
        local parents_str=""
        for parent_ws in $ws_parents
        do
            # Get te absolute path of each parent workspace and escape home for clarity
            parents_str+=":${$(readlink -f "$parent_ws")/#$HOME/~}"
        done
        printf "%q:%s%s:%s\n" "${ws_name}" "${distro}" "${parents_str}" "${PWD/#$HOME/~}" >> "$_ROSWS_CONFIG_WS"
        if (whence sort >/dev/null); then
            local config_tmp=$(mktemp "${TMPDIR:-/tmp}/rosws.XXXXXXXXXX")
            # use 'cat' below to ensure we respect $_ROSWS_CONFIG_WS as a symlink
            command sort -o "${config_tmp}" "$_ROSWS_CONFIG_WS" && command cat "${config_tmp}" >| "$_ROSWS_CONFIG_WS" && command rm "${config_tmp}"
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
                if sed -n "/^${ws_name}:.*$/!p" "$_ROSWS_CONFIG_WS" >| "$config_tmp" && command cp "$config_tmp" "$_ROSWS_CONFIG_WS" && command rm "$config_tmp"
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

    local entries=$(sed "s:${HOME}:~:g" "$_ROSWS_CONFIG_WS")

    # Find the max length of all ws names
    local max_ws_name_length=0
    for ws_name in "${(@k)rosws_workspaces}"
    do
        local length=${#ws_name}
        if [[ length -gt max_ws_name_length ]]
        then
            max_ws_name_length=$length
        fi
    done

    for ws_name in "${(@k)rosws_workspaces}"
    do
        parse_ws_data $ws_name

        if [[ -z $rosws_quiet_mode ]]
        then
            # Build print line depending on parent workspaces and current activation
            local parents_str=""
            for parent_ws in $ws_parents
            do
                parents_str+="--> $parent_ws "
            done
            local active_str=""
            if [[ $ws_name == $ROSWS_ACTIVE_WS ]]
            then
                active_str="${ROSWS_GREEN}(active)${ROSWS_NOC}"
            fi
            # Show info for this ws
            printf " * %${max_ws_name_length}s -- [$ws_distro] $parents_str--> $ws_path $active_str\n" "$ws_name"
        fi
    done
}

rosws_path()
{
    parse_ws_data $1
    echo "$(echo "$ws_path" | sed "s:~:${HOME}:g")"
}

rosws_show()
{
    local ws_name=$1
    parse_ws_data $ws_name
    # if there's an argument we look up the value
    if [[ -n $ws_name ]]
    then
        if [[ -z $rosws_workspaces[$ws_name] ]]
        then
            rosws_print_msg "$ROSWS_BLUE" "No workspace named $ws_name"
        else
            # Build print line depending on parent workspaces and current activation
            local parents_str=""
            [[ ${#ws_parents} == 0 ]] && parents_str="\n    None"
            for ((i = 1; i <= $#ws_parents; i++))
            do
                parents_str+="\n    $i. $ws_parents[$i]"
            done
            local active_str=""
            if [[ $ws_name == $ROSWS_ACTIVE_WS ]]
            then
                active_str="${ROSWS_GREEN}(active)${ROSWS_NOC}"
            fi
            # Show info for this ws
            rosws_print_msg "$ROSWS_BLUE" "Workspace: ${ROSWS_BLUE}$ws_name${ROSWS_NOC} $active_str"
            rosws_print_msg "$ROSWS_NOC" "Path: $ws_path"
            rosws_print_msg "$ROSWS_NOC" "Distro: ${ROSWS_BLUE}$ws_distro${ROSWS_NOC}"
            rosws_print_msg "$ROSWS_NOC" "Parent workspaces: $parents_str"
        fi
    else
        rosws_exit_fail "You must enter a workspace"
    fi
}

rosws_clean()
{
    # TODO: This currently does not check parent workspaces
    local count=0
    local rosws_tmp=""

    while read -r line
    do
        if [[ $line != "" ]]
        then
            local arr=(${(s,:,)line})
            local ws_name=${arr[1]}
            local ws_path=${arr[-1]}

            if [ -d "${ws_path/#\~/$HOME}" ]
            then
                rosws_tmp=$rosws_tmp"\n"`echo "$line"`
            else
                rosws_print_msg "$ROSWS_YELLOW" "Nonexistent directory: ${ws_name} -> ${ws_path}"
                count=$((count+1))
            fi
        fi
    done < "$_ROSWS_CONFIG_WS"

    if [[ $count -eq 0 ]]
    then
        rosws_print_msg "$ROSWS_BLUE" "No workspaces to clean, carry on!"
    else
        if [ ! -z "$rosws_force_mode" ] || rosws_yesorno "Removing ${count} workspaces. Continue? (y/n)"
        then
            echo "$rosws_tmp" >! "$_ROSWS_CONFIG_WS"
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
            parse_ws_data $ROSWS_ACTIVE_WS
            cd ${ws_path/#\~/$HOME}/$subdir
        else
            rosws_exit_fail "Active workspace $ROSWS_ACTIVE_WS is not in the list of workspaces!\n"\
                            "Please check your configuration and/or re-activate the workspace."

        fi
    elif [[ -z $rosws_workspaces[$ws_name] ]]
    then
        rosws_exit_fail "Unknown workspace '${ws_name}'"
    else
        parse_ws_data $ws_name
        if [[ $subdir != "" ]]
        then
            cd ${ws_path/#\~/$HOME}/$subdir
        else
            cd ${ws_path/#\~/$HOME}
        fi
    fi
}

local ROSWS_CONFIG=${ROSWS_CONFIG:-$HOME/.config/ros2-env}
local _ROSWS_CONFIG_WS=$ROSWS_CONFIG/workspaces
local _ROSWS_CONFIG_DEFAULT=$ROSWS_CONFIG/default_ws
local ROSWS_QUIET=0
local ROSWS_EXIT_CODE=0
local ROSWS_DEBUG=0

# Parse 'meta' options first to avoid the need to have them before
# other commands. The `-D` flag consumes recognized options so that
# the actual command parsing won't be affected.

zparseopts -D -E \
    {q,-quiet}=rosws_quiet_mode \
    {v,-version}=rosws_print_version \
    {d,-debug}=rosws_debug_mode \
    {f,-force}=rosws_force_mode

if [[ ! -z $rosws_print_version ]]
then
    echo "rosws version $ROSWS_VERSION"
fi

# check if config file exists
# if [ ! -e "$_ROSWS_CONFIG_WS" ]
# then
#     # if not, check if config dir exists and create everything
#     if [ ! -d "$(dirname "${_ROSWS_CONFIG_WS}")" ]; then
#         mkdir -p "$(dirname "${_ROSWS_CONFIG_WS}")"
#     fi
#     touch "$_ROSWS_CONFIG_WS"
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
args=$(getopt -o a:r:c:lhs -l add:,activate:,default:,distro:,rm:,clean,list,path:,help,show -- $*)

# check if no arguments were given, and that version is not set
if [[ ($? -ne 0 || $#* -eq 0) && -z $rosws_print_version ]]
then
    rosws_print_usage

# check if config dir is writeable
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
                rosws_add "${@:2}"
                # rosws_add "$2" "$3"
                break
                ;;
            "--activate"|"activate")
                rosws_activate "$2"
                break
                ;;
            "--default"|"default")
                rosws_default "${@:2}"
                break
                ;;
            "--distro"|"distro")
                rosws_distro "$2"
                break
                ;;
            "--domain"|"domain")
                rosws_domain "$2"
                break
                ;;
            "--rmw"|"rmw")
                rosws_rmw "$2"
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
                rosws_clean
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
unset -f rosws_activate
unset -f rosws_add
unset -f rosws_cd
unset -f rosws_clean
unset -f rosws_default
unset -f rosws_distro
unset -f rosws_domain
unset -f rosws_exit_fail
unset -f rosws_exit_warn
unset -f rosws_list_all
unset -f rosws_path
unset -f rosws_print_msg
unset -f rosws_print_usage
unset -f rosws_remove
unset -f rosws_rmw
unset -f rosws_show
unset -f rosws_yesorno
unset -f parse_ws_data
unset -f activate_ws
unset -f load_workspaces
unset rosws_quiet_mode
unset rosws_force_mode
unset rosws_print_version
unset rosws_parent_ws_paths
unset rosws_o
unset ws_distro
unset ws_path
unset ws_parents

unset args

if [[ -n $rosws_debug_mode ]]
then
    exit $ROSWS_EXIT_CODE
else
    unset rosws_debug_mode
fi
