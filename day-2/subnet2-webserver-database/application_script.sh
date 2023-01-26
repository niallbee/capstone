#!/bin/bash
set -exo pipefail
# This script installs and runs the python web application
sudo apt-get update

sudo apt install docker.io -y

git clone https://github.com/zeg22/capstone-web-app.git

cd capstone-web-app/flask-example-cicd

sudo docker build . -t flask-example-cicd:latest

sudo docker run --rm -d -p 8080:8080/tcp -e "DB_IP=${db_ip}"  -e "DB_USERNAME=${db_username}" -e "DB_PASSWORD=${db_password}" --name flask-example flask-example-cicd:latest
