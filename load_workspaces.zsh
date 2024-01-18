#!/bin/zsh

# Function to load the workspaces from the configuration file


export ROSWS_CONFIG=${ROSWS_CONFIG:-$HOME/.config/ros2-env/workspaces}


typeset -A rosws_workspaces
function load_workspaces() {
    # check if config file exists
    if [ ! -e "$ROSWS_CONFIG" ]
    then
        # if not, check if config dir exists and create everything
        if [ ! -d "$(dirname "${ROSWS_CONFIG}")" ]; then
            mkdir -p "$(dirname "${ROSWS_CONFIG}")"
        fi
        touch "$ROSWS_CONFIG"
    fi

    # load workspaces
    while read -r line
    do
        arr=(${(s,:,)line})
        ws_name=${arr[1]}
        # join the rest, in case the path contains colons
        ws_path=${(j,:,)arr[2,-1]}
        rosws_workspaces[$ws_name]=$ws_path
    done < "$ROSWS_CONFIG"

    unset ws_path &> /dev/null # fixes issue #1 (from wd's original code)
}
