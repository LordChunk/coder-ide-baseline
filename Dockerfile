FROM ubuntu:20.04

# Set arch as arm64

RUN apt-get update \
  # Prevent interactive dialog during apt-get install
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install -y \
    python3 \
    python3-pip \
    git \
    curl \
    wget \
    # Install Docker CLI
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository \
       "deb [arch=arm64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable" \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose 

