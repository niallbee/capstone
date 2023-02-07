#!/bin/bash
set -exo pipefail

# This script installs Jenkins and Java. Java is required for Jenkins to run

sudo apt update -y
sudo apt install openjdk-11-jre -y
java -version

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee \
        /usr/share/keyrings/jenkins-keyring.asc >/dev/null
# shellcheck disable=SC2102
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list >/dev/null

sudo apt-get update -y
sudo apt-get install jenkins
sudo reboot
