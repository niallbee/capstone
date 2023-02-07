#!/bin/bash
set -exo pipefail

sudo apt-get update -y
sudo apt install nginx -y

sudo sed -i "/listen 80 default_server;/c\listen 8080 default_server;" /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
