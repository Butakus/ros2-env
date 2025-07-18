#!/bin/zsh

# colcon clean utility.
#
# Repo URL: github.com/butakus/ros2-env

parse_ws_data()
{
    local ws_name=$1
    if [[ ${rosws_workspaces[$ws_name]} != "" ]]
    then
        # Split the ws data to extract distro and ws paths
        local rosws_data=(${(s,:,)rosws_workspaces[$ws_name]})
        ws_distro=${rosws_data[1]}
        ws_path=${rosws_data[-1]/#\~/$HOME}
        # List of paths for parent workspaces to be sourced in cascade
        ws_parents=(${rosws_data[2,-2]})
        return 0
    fi
    # Return error if ws_name is not in the list
    return 1
}

# load workspaces
# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
source ${0:A:h}/load_workspaces.zsh
load_workspaces

local ws_name="$1"
# If no arguments, clean the active workspace
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
            # Clean active workspace
            parse_ws_data $ROSWS_ACTIVE_WS
            # ws_path=${rosws_workspaces[$ROSWS_ACTIVE_WS]/#\~/$HOME}
            rm -rf $ws_path/build $ws_path/install $ws_path/log
        fi
    else
        echo "There is no active workspace. Use rosws <workspace> to activate a workspace"
    fi
else
    # Custom workspace selected. Clean it
    if [[ -z $rosws_workspaces[$ws_name] ]]
    then
        echo "Please enter a valid workspace. Use rosws list to see the list of registered workspaces."
    else
        parse_ws_data $ws_name
        rm -rf $ws_path/build $ws_path/install $ws_path/log
    fi
fi

unset -f parse_ws_data
unset -f load_workspaces
unset ws_distro
unset ws_name
unset ws_path
unset ws_parents
