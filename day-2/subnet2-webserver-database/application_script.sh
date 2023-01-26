#!/bin/bash
set -exo pipefail
# This script installs and runs the python web application
sudo apt-get update

sudo apt install docker.io -y

git clone https://github.com/zeg22/capstone-web-app.git

cd capstone-web-app/flask-example-cicd

sudo docker build . -t flask-example-cicd:latest --build-arg db_ip=${db_ip}  --build-arg db_username=${db_username} --build-arg db_password=${db_password} 

sudo docker run --rm -d -p 8080:8080/tcp --name flask-example flask-example-cicd:latest