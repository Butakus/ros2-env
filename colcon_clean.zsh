#!/bin/zsh

# colcon clean utility.
#
# Repo URL: github.com/butakus/ros2-env

# load workspaces
# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
source ${0:A:h}/load_workspaces.zsh
load_workspaces

# If no arguments, clean the active workspace
if [ -z "$1" ]
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
            ws_path=${rosws_workspaces[$ROSWS_ACTIVE_WS]/#\~/$HOME}
            rm -rf $ws_path/build/* $ws_path/install/* $ws_path/log/*
        fi
    else
        echo "There is no active workspace. Use rosws <workspace> to activate a workspace"
    fi
else
    # Custom workspace selected. Clean it
    if [[ -z $rosws_workspaces[$1] ]]
    then
        echo "Please enter a valid workspace. Use rosws list to see the list of registered workspaces."
    else
        ws_path=${rosws_workspaces[$1]/#\~/$HOME}
        rm -rf $ws_path/build/* $ws_path/install/* $ws_path/log/*
    fi
fi
