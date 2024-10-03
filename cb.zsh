#!/bin/zsh

# colcon build utility.
#
# Repo URL: github.com/butakus/ros2-env

# colors
readonly ROSWS_BLUE="\033[96m"
readonly ROSWS_GREEN="\033[92m"
readonly ROSWS_YELLOW="\033[93m"
readonly ROSWS_RED="\033[91m"
readonly ROSWS_NOC="\033[m"


parse_ws_data()
{
    # TODO: Extract parent workspaces (if any) and store them in a new array $ws_parents
    local ws_name=$1
    if [[ ${rosws_workspaces[$ws_name]} != "" ]]
    then
        # Split the ws data into distro and path
        local rosws_data=(${(s,:,)rosws_workspaces[$ws_name]})
        ws_distro=${rosws_data[1]}
        # join the rest of the path, in case it contains colons
        ws_path=${(j,:,)rosws_data[2,-1]}
        return 0
    fi
    # Return error if ws_name is not in the list
    return 1
}

# TODO: Allow cb command to receive extra args and pass them to colcon.
function _colcon_build_path()
{
    if [ -z "$1" ]
    then
        echo '[Error] _colcon_build_path: Missing workspace path input'
        return 1
    fi
    p=$(pwd)
    cd "$1"
    # colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
    colcon build $CB_EXTRA_ARGS
    cd $p
}

# load workspaces
# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
source ${0:A:h}/load_workspaces.zsh
load_workspaces

# If no arguments, build the active workspace
local ws_name=$1
if [ -z "$ws_name" ]
then
    if [[ -v ROSWS_ACTIVE_WS ]]
    then
        if [[ -z $rosws_workspaces[$ROSWS_ACTIVE_WS] ]]
        then
            # User manually changed something?
            echo "Active workspace $ROSWS_ACTIVE_WS is not in the list of workspaces!"
            echo "Please check your configuration and/or re-activate the workspace."
        else
            parse_ws_data $ROSWS_ACTIVE_WS
            # Build the active ws
            source /opt/ros/$ws_distro/setup.zsh
            # TODO: Source all parent workspaces, if any
            _colcon_build_path ${ws_path/#\~/$HOME}
            source "${ws_path/#\~/$HOME}/install/local_setup.zsh"
        fi
    else
        echo "There is no active workspace. Use rosws <workspace> to activate a workspace"
    fi
else
    # Custom workspace selected. Build it and set is as the active one
    if [[ -z $rosws_workspaces[$ws_name] ]]
    then
        echo "Please enter a valid workspace. Use rosws list to see the list of registered workspaces."
    else
        # TODO: Clear environment variables when switching to a different workspace
        parse_ws_data $ws_name
        source /opt/ros/$ws_distro/setup.zsh
        # TODO: Source all parent workspaces, if any
        _colcon_build_path ${ws_path/#\~/$HOME}
        source "${ws_path/#\~/$HOME}/install/local_setup.zsh"
        # Now this will be the active workspace
        export ROSWS_ACTIVE_WS=$ws_name
    fi
fi

unset parse_ws_data
unset ws_distro
unset ws_path
# unset _colcon_build_path
