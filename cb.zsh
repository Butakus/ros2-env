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

# Temporarily set the ROS_DISTRO var to source the first setup
# After this first source in /opt/..., this var will be properly set and exported
# TODO: Find a proper way to configure this.
#       Maybe add new subcommands to set distro and cb_extra_args.
#       Those values can be persistent in a config file.
local ROS_DISTRO=${ROS_DISTRO:-humble}

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
            # Build the active ws
            source /opt/ros/$ROS_DISTRO/setup.zsh
            _colcon_build_path ${rosws_workspaces[$ROSWS_ACTIVE_WS]/#\~/$HOME}
            source ${rosws_workspaces[$ROSWS_ACTIVE_WS]/#\~/$HOME}/install/local_setup.zsh
        fi
    else
        echo "There is no active workspace. Use rosws <workspace> to activate a workspace"
    fi
else
    # Custom workspace selected. Build it and set is as the active one
    if [[ -z $rosws_workspaces[$1] ]]
    then
        echo "Please enter a valid workspace. Use rosws list to see the list of registered workspaces."
    else
        source /opt/ros/$ROS_DISTRO/setup.zsh
        _colcon_build_path ${rosws_workspaces[$1]/#\~/$HOME}
        source ${rosws_workspaces[$1]/#\~/$HOME}/install/local_setup.zsh
        # Now this will be the active workspace
        export ROSWS_ACTIVE_WS=$ws_name
    fi
fi
