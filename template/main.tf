# Based on: https://github.com/sharkymark/v2-templates/tree/main/docker-in-docker/sysbox

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.6.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.22.0"
    }
  }
}

provider "docker" {

}

provider "coder" {
}

data "coder_workspace" "me" {
}

variable "image" {
  description = <<-EOF
  Container images from coder-com

  EOF
  default = "ghcr.io/lordchunk/coder-ide-baseline:latest"
  validation {
    condition = contains([
      "ghcr.io/lordchunk/coder-ide-baseline:latest"
      # "codercom/enterprise-node:ubuntu",
      # "codercom/enterprise-golang:ubuntu",
      # "codercom/enterprise-java:ubuntu",
      # "codercom/enterprise-base:ubuntu",
      # "marktmilligan/clion-rust:latest"
    ], var.image)
    error_message = "Invalid image!"   
}  
}

variable "repo" {
  description = <<-EOF
  Code repository to clone

  e.g. LordChunk/7beek-admin-dashboard.git

  EOF
  # Allow any repo for now
  default = ""
  
  # default = "coder/coder.git"
  # validation {
  #   condition = contains([
  #     "sharkymark/coder-react.git",
  #     "coder/coder.git", 
  #     "sharkymark/java_helloworld.git", 
  #     "sharkymark/python_commissions.git",                 
  #     "sharkymark/pandas_automl.git",
  #     "sharkymark/rust-hw.git"     
  #   ], var.repo)
  #   error_message = "Invalid repo!"   
  # }  
}

variable "git_email" {
  description = <<-EOF
  Git email address

  EOF
  default = "LordChunk@users.noreply.github.com"
}

variable "git_name" {
  description = <<-EOF
  Git name

  EOF
  default = "LordChunk"
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

# Setup git user
git config --global user.email "${var.git_email}"
git config --global user.name "${var.git_name}"

# Clone repo
git clone git@github.com:${var.repo}

# install code-server
curl -fsSL https://code-server.dev/install.sh | sh
code-server --auth none --port 13337 &

# Navigate to repo if it exists
repo_folder=${replace(var.repo, ".git", "")}
if [ -d "$repo_folder" ]; then
  cd $repo_folder

  # Check if there is a .devcontainer folder
  if [ -d ".devcontainer" ]; then
    # Pull the devcontainer image
    docker compose pull

    # Start the devcontainer
    devcontainer up    
  fi
fi

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
  image = "${var.image}"
  # Uses lower() to avoid Docker restriction on container names.
  name     = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1"]

  # Use the docker gateway if the access URL is 127.0.0.1
  #entrypoint = ["sh", "-c", replace(coder_agent.dev.init_script, "127.0.0.1", "host.docker.internal")]

  # Use the docker gateway if the access URL is 127.0.0.1
  command = [
    "sh", "-c",
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
