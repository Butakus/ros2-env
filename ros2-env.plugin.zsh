
export CB_EXTRA_ARGS="--symlink-install"

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
