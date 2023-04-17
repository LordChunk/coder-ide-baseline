# Coder Workspace Template for running Devcontainers

This repository contains all the required files to run a [Devcontainer](https://code.visualstudio.com/docs/remote/containers) in [Coder](https://github.com/coder/coder) workspace. The devcontainer image supports both ARM64 and AMD64 architectures. A guide on how to run Docker in Docker using Sysbox can be found [here](https://coder.com/docs/v2/latest/templates/docker-in-workspaces#use-sysbox-in-docker-based-templates).

## Structure

The structure of this repository is as follows:

- `root-container`: Contains the container used by Coder as the base for your workspaces. It contains the minimal amount of software required to run Docker and VS Code.
- `template`: Contains the template used in Coder to create your workspaces.

## Usage

After setting up Coder and Sysbox, you'll need to install the Coder CLI on your local machine to create and push the template. You can find the installation instructions [here](https://coder.com/docs/v2/latest/templates#get-the-cli).

Once you have the CLI installed, you can create the template by running the ``./template/create.sh`` script. This will create a new template in your Coder instance.

If you want to push/update the template, you can run the ``./template/push.sh`` script.