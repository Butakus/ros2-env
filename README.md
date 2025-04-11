# ros2-env
A zsh plugin to manage ROS 2 environment and workspaces

## What is this and why do I need it?
If you are working with ROS, you probably have more than one workspace (different projects, robots, maybe even different versions of the same package). This means having to manually source the current workspace we are working on, which is no bueno. Moreover, when using `colcon` to build the workspace, you need to manually `cd` to the workspace's dir and run the command there.

Over the years working with ROS 1 and 2, I have seen (and created) multiple solutions, "hacks", aliases, functions and tears, usually included in the shell configuration to tackle these problems. This plugin is a cured compilation of all that.

The `ros2-env` plugin allows you to define a list of workspaces, and to assign a name to each one of them. Then you can "activate" one of the workspaces, sourcing it and making it the target for the colcon utility functions that are also provided by this plugin.

It is also possible to select a base ROS 2 distro (rolling, jazzzy, etc.) for each workspace, as well as a list of parent workspaces to [overlay on top of them](https://colcon.readthedocs.io/en/released/user/using-multiple-workspaces.html). You can find more info and some examples below.

The active workspace is stored in the environment variable `$ROSWS_ACTIVE_WS`, which can be changed with the `rosws` command described below.

## Disclaimer
This workspace management part of the `ros2-env` plugin is heavily inspired by [wd](https://github.com/mfaerevaag/wd). Most of the functions and completions have been extracted from this repository. Check it out if you still don't know about that amazing plugin!

# Installation

### Install for Oh-My-Zsh (recomended)

To install with [Oh-My-Zsh](https://github.com/ohmyzsh/ohmyzsh), first clone the repo from an interactive Zsh session:

```zsh
# make sure your $ZSH_CUSTOM is set
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# now, clone the plugin
git clone https://github.com/butakus/ros2-env $ZSH_CUSTOM/plugins/ros2-env
```

Then, add the plugin to your Oh-My-Zsh plugins list in your .zshrc

```zsh
# in your .zshrc, add this plugin to your plugins list
plugins=(... ros2-env)
```

### Manual installation

To install manually, first clone the repo:

```zsh
git clone https://github.com/butakus/ros2-env ${ZDOTDIR:-~}/.zplugins/ros2-env
```

Then, in your .zshrc, add the following line:

```zsh
source ${ZDOTDIR:-~}/.zplugins/ros2-env/ros2-env.plugin.zsh
```


# Colcon build utility

Build the active workspace with the `cb` (colcon build) command. No matter where you are.

### Usage (`cb`)

* Compile the current active workspace:

```zsh
cb
```

* Compile any workspace by name:

```zsh
cb foo
cb bar
```

**Note:** If you build any listed workspace with `cb ws_name`, the just-built workspace will be sourced and set as the active one:

```zsh
# Active workspace is 'foo'
cb bar
# Now 'bar' is sourced and 'foo' is not.
```

## Cleaning workspaces
If sometimes you feel the need to clear all the compilation files that are generated in the `build`, `install` and `log` subdirectories, this comes in handy (sometimes we just need a compilation break):

### Usage (`colcon_clean`)

* Clean the compilation files from the current active workspace:

```zsh
colcon_clean
```

* Clean any workspace by name:

```zsh
colcon_clean foo
colcon_clean bar
```

This command is simmilar to `colcon clean` plugin, except you don't need to cd to the workspace's root dir. On the other hand, it is not possible to clean specific packages (the whole workspace is cleaned).

# Workspace management
Similar to `wd`, this plugin provides a `rosws` command that allows you to change the active workspace, and to manage the list of registered workspaces. Only one workspace can be active at the same time.

## Usage (`rosws`)

### Add current working directory to list of workspaces:

```zsh
rosws add foo
```

If a workspace with the same name exists, use `rosws add foo --force` to overwrite it.

**Note:** The workspace cannot contain colons (':') in neither the name nor the path. This will conflict in how `rosws` stores the workspaces.

You can omit the workspace name to automatically use the current directory's name instead.

### Add a new workspace under a specific ROS 2 distro:

```zsh
rosws add foo rolling
```

This will configure workspace `foo` with ROS 2 rolling as the base. When building and sourcing the `foo` workspace, the base environment from `/opt/ros/<distro>/setup.zsh` will be sourced first.

**Note:** By default, the `rosws add` command will link the new workspace with whatever environment is set in the `$ROS_DISTRO` environment variable.

### Make `foo` the active workspace:

```zsh
rosws foo
# or
rosws activate foo
```

### Remove workspace:

```zsh
rosws rm foo
```


### List all registered workspaces:

```zsh
rosws list
```

Workspaces are stored in `~/.config/ros2-env/workspaces` by default.

### Show information of given workspace:

```zsh
rosws show foo
```

### Show path (pwd) of given workspace:

```zsh
rosws path foo
```

### Remove workspaces pointing to non-existent directories.

```zsh
rosws clean
```

Use `rosws clean --force` to not be prompted with confirmation.


### Change directory to the workspace:

You can also cd to any directory inside the workspace, with autocompletion.

```zsh
rosws cd foo
# Or
rosws cd foo src/awesome_package
```

Using `rosws cd` without any additional argument will cd into the current active workspace.

### Setting a default workspace:
Sometimes it may be useful to set a default workspace to be automatically loaded when starting a new shell. This is specially true if you are working on a project and want to open many new terminals without having to manually activate the workspace on each one:

```zsh
# Set foo as default workspace
rosws default set foo
# Or
rosws default foo
```

Note that after setting a default workspace, it is also activated in the terminal where the command is executed.

Use `rosws default unset` to clear the default workspace and disable the automatic source:
```zsh
# Unset (clear) the default workspace
rosws default unset
```

The current default can be displayed by just using `rosws default`. The configuration with the default workspace name is stored in `$ROSWS_CONFIG/default_ws`.


### Print usage info:

```zsh
rosws help
```

The usage will be printed also if you call `rosws` with no command

### Print the running version of `rosws`:

```zsh
rosws --version
```

# Configuration

The configuration files for the plugin are stored by default in `~/.config/ros2-env`. It is possible to modify this by setting the environment variable `$ROSWS_CONFIG`.

## Colcon arguments
It is also possible to control the arguments passed to colcon when using the `cb` command, by setting the `$CB_EXTRA_ARGS` environment variable. For example:

```zsh
export CB_EXTRA_ARGS="--symlink-install"
```

By default, this variable only includes the `--symlink-install` option.

In addition, `cb` also allows passing extra arguments to colcon, that will be added after those in the environment variable. All the remainder arguments in the `cb` command will be forwarded. Example:

```zsh
# Pass custom cmake args (--symlink-install is already by included in $CB_EXTRA_ARGS)
cb foo --cmake-args -DCMAKE_BUILD_TYPE=Release

# If the workspace is already active...
cb --cmake-args -DCMAKE_BUILD_TYPE=Release
```


## ROS 2 distro

It is possible to select a different distro (rolling, jazzy, etc.) when adding a new workspace. By default, the value stored in `$ROS_DISTRO` is used. Example:

```zsh
# Add foo workspace with the ROS 2 humble setup
rosws add foo humble
```

When a workspace is activated, the system will first load the environment for its corresponding ROS distro from `/opt/ros/<distro>/setup.zsh`, and then it will source the workspace environment.

If you want to only load the distribution environment, you can do it by using the `rosws distro` command:

```zsh
rosws distro <distro>
```

This will source the environment in `/opt/ros/<distro>/setup.zsh`, also setting the `$ROS_DISTRO` variable.

## ROS DOMAIN ID

You can select a different ROS_DOMAIN ID between 0 and 250 using `rosws domain` command. The default value is 0. Example:

```zsh
rosws domain <id>
```

This will set the `$ROS_DOMAIN_ID` variable.

## RMW Implementation

In ROS 2, there are several rmw implementations you can use. Some of them are `rmw_fastrtps_cpp` (default), `rmw_cyclonedds_cpp`, `rmw_zenoh_cpp`, etc. To change the implementation to use, you have the `rosws rmw` command, which will give you some rmw options but you can put others. Example:

```zsh
rosws rmw <rmw_implementation>
```

This will set the `$RMW_IMPLEMENTATION` variable.

## Chained workspaces
When adding a new workspace, in addition to setting the base ROS 2 distro, it is also possible to set a list of parent workspaces (or underlay workspaces), that will be sourced before the overlay.

To do this, just pass the paths of the parent workspaces (in order) after the ROS distro. Example:

```zsh
rosws add foo rolling ~/ros2/base_ws ~/ros2/sim_ws
```

This will set "base_ws" and "sim_ws" as underlays of the newly created `foo` workspace. When activating (sourcing) or building `foo` with `cb`, the underlays will be sourced first in the following order:

```
rolling --> base_ws --> sim_ws --> foo
```
