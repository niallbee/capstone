#!/bin/bash
set -exo pipefail

# Update apt and allow apt to use repository over HTTPS
sudo apt-get update
sudo apt-get install \
  ca-certificates \
  curl \
  gnupg \
  lsb-release -y

# Add Docker's official GPG key
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Grat read permission for Docker public key file
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Install Docker engine
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Run nginx container. This line is commented out of the final script to stop it interfering with the python app running on port 80
# sudo docker run --name mynginx1 -p 80:80 -d nginx
