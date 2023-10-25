# Based on: https://github.com/sharkymark/v2-templates/tree/main/docker-in-docker/sysbox

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.7.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {
}

provider "coder" {
  feature_use_managed_variables = "true"
}

data "coder_workspace" "me" {
}

data "coder_parameter" "image" {
  name = "Base image"
  type = "string"
  description = <<-EOF
  Base image to use for the workspace.

  EOF
  mutable = true
  # Generate a list of options from the local.images map
  option {
    name   = "lordchunk/coder-ide-baseline"
    value = "ghcr.io/lordchunk/coder-ide-baseline:latest" # This value is modified by root-container.yml Step: Write hash to main.tf
  }
}


data  "coder_parameter" "repo" {
  name = "Repository SSH URL"
  type = "string"
  description = <<-EOF
  Code repository to clone

  e.g. git@github.com:LordChunk/7beek-admin-dashboard.git

  EOF
}

data "coder_parameter" "git_email" {
  name = "Git email address"
  type = "string"
  description = <<-EOF
  Git email address used for commits.

  EOF
  default = "LordChunk@users.noreply.github.com"
}

data "coder_parameter" "git_name" {
  name = "Git name"
  type = "string"
  default = "LordChunk"
}

resource "docker_image" "base_image" {
  name = data.coder_parameter.image.value
  keep_locally = true
}

resource "coder_agent" "dev" {
  arch           = "arm64"
  os             = "linux"
  startup_script  = <<EOT
    #!/bin/bash

    # Start Docker
    sudo dockerd &

    # Setup git
    mkdir -p ~/.ssh
    ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
    ssh-keyscan -t ed25519 gitlab.com >> ~/.ssh/known_hosts

    # Setup git user
    git config --global user.email "${data.coder_parameter.git_email.value}"
    git config --global user.name "${data.coder_parameter.git_name.value}"

    # Clone repo
    git clone ${data.coder_parameter.repo.value}

    # Set to lower case and strip user and .git from repo and 
    repo_folder=$(echo ${data.coder_parameter.repo.value} | tr '[:upper:]' '[:lower:]' | sed 's/.*\///' | sed 's/\.git//')

    # Manually add nvm to path for devcontainer prebuild
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

    # Navigate to repo if it exists
    if [ -d "$repo_folder" ]; then
      cd $repo_folder

      # Check if there is a .devcontainer folder
      if [ -d ".devcontainer" ]; then
        # Prebuild the devcontainer
        devcontainer up --workspace-folder=.
      fi
    fi

    # install code-server
    echo "Installing code-server"
    curl -fsSL https://code-server.dev/install.sh | sh
    echo "Starting code-server"
    code-server --auth none --port 13337 ./ &
    echo "Agent script finished"
  EOT
}

resource "coder_app" "code-server" {
  agent_id = coder_agent.dev.id
  slug          = "code-server"
  display_name  = "VS Code"
  url      = "http://localhost:13337/?folder=/home/chunk"
  icon     = "/icon/code.svg"
  subdomain = false
  share     = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 15
  }  
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.base_image.image_id
  # Uses lower() to avoid Docker restriction on container names.
  name     = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1"]

  # Use the docker gateway if the access URL is 127.0.0.1
  #entrypoint = ["sh", "-c", replace(coder_agent.dev.init_script, "127.0.0.1", "host.docker.internal")]

  # Use the docker gateway if the access URL is 127.0.0.1
  command = [
    "bash", "-c",
    <<EOT
    trap '[ $? -ne 0 ] && echo === Agent script exited with non-zero code. Sleeping infinitely to preserve logs... && sleep infinity' EXIT
    ${replace(coder_agent.dev.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")}
    EOT
  ]
  # required for sysbox runc to be used
  runtime = "sysbox-runc"
  env        = ["CODER_AGENT_TOKEN=${coder_agent.dev.token}"]
  volumes {
    container_path = "/home/chunk/"
    volume_name    = docker_volume.coder_volume.name
    read_only      = false
  }  
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
}

resource "docker_volume" "coder_volume" {
  name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
}
