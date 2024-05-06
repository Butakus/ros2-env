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
        # Config line example --> foo_ws:rolling:/path/to/foo_ws
        arr=(${(s,:,)line})
        ws_name=${arr[1]}
        # Save the distro and the path in an array
        # join the rest of the path, in case it contains colons
        ws_data=${(j,:,)arr[2,-1]}
        # The value stored in ws_data contains the ROS distro and the path
        # Example value after removing ws_name: --> rolling:/path/to/foo_ws
        rosws_workspaces[$ws_name]=$ws_data
    done < "$ROSWS_CONFIG"

    unset ws_data &> /dev/null # fixes issue #1 (from wd's original code)
    unset arr &> /dev/null
    unset ws_name &> /dev/null
}
