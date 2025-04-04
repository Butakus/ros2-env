
export CB_EXTRA_ARGS="--symlink-install"
export ROSWS_CONFIG=${ROSWS_CONFIG:-$HOME/.config/ros2-env}
local _ROSWS_CONFIG_DEFAULT=$ROSWS_CONFIG/default_ws

# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# Load workspaces before sourcing rosws file
source ${0:A:h}/load_workspaces.zsh
load_workspaces

# Source rosws function file
eval "rosws() { source '${0:A:h}/rosws.zsh' }"
# Source cb function file
eval "cb() { source '${0:A:h}/cb.zsh' }"
# Source colcon_clean function file
eval "colcon_clean() { source '${0:A:h}/colcon_clean.zsh' }"

# Activate the default workspace (if any)
# Check if the config file exists and load the workspace from the name inside the file
if [ -e "$_ROSWS_CONFIG_DEFAULT" ]
then
    # Read the default workspace name from the file
    local default_ws_name=$(< $_ROSWS_CONFIG_DEFAULT)
    # Check if the filewas empty
    if [ -n "$default_ws_name" ]
    then
        # Check if the workspace is in the list of workspaces
        if [[ -v rosws_workspaces[$default_ws_name] ]]
        then
            # Set the active workspace to the one in the file
            rosws activate $default_ws_name
        else
            echo "Default workspace $default_ws_name is not in the list of workspaces!"
            echo "Please check your configuration and/or re-activate the workspace."
        fi
    fi
fi

# alias to clear old ROS logs
alias rosclean='find ~/.ros/log/* -mtime +5 -exec rm -r {} \;'

# Reuse cb autocompletion for colcon_clean
compdef _cb colcon_clean

# Autocomplete fix for ros2 and colcon commands
if command -v register-python-argcomplete3 &> /dev/null
then
    eval "$(register-python-argcomplete3 ros2)"
    eval "$(register-python-argcomplete3 colcon)"
elif command -v register-python-argcomplete &> /dev/null
then
    eval "$(register-python-argcomplete ros2)"
    eval "$(register-python-argcomplete colcon)"
fi
