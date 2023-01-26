# Day 1 - Deploying a webserver and database

# Overview
This session will create the architecture for subnet 2 of the Capstone project. This guide will take you through deploying the following architecute
- Subnet
- Webserver with a python web app
- Postgres database
- Firewall rules

This session will use Terraform, shell scripts and docker to deploy a complete web app. 


## Getting Started 
1. Open your playpen repo in VS Code then create and checkout a new branch (if you completed the previous session use the same branch for this lab)

2. If required create a new folder capstone-project, inside it create a folder called day-2 and cd into the folder in the terminal and run the following commands:

   ```
   gcloud auth login
   ```
   This will open a browser window that will ask you to log into your Google account. 
   Once you are logged in run
   ```
   gcloud config set project <YOUR PROJECT NAME>
   ```
   This will set your playpen project as your default project for gcloud operations.
4. To authenticate with terraform cloud run
   ```
   terraform login
   ```
   Then when prompted type "yes"
   This should open a window for you to log into Terraform Cloud. Click "Sign in with SSO" near the bottom of the page. On the next page type in your Organization name "lbg-cloud-platform" and hit next. You will then be asked to sign into your dev account. 

   When you reach your account you will be prompted to create an API token. Click create token and copy the token generated. Go back to your terminal and where it says enter value paste the API token you copied.



## Setting up the project
1. In the current folder (day-2), create the following files: 
    - `networks.tf`
    - `webserver.tf.tf` 
    - `database.tf` 
    - `variables.tf` 
    - `outputs.tf`
    -  `providers.tf`

2. In `providers.tf`, add the following block of code. Replace <WORKSPACE_HERE> with the name of your workspace. e.g. playpen-a1b2cd-gcp
```
   terraform {
   required_providers {
      google = {
         source  = "hashicorp/google"
         version = "~> 4.0.0"
      }
   }

      cloud {
      organization = "lbg-cloud-platform"

      workspaces {
               name = "<WORKSPACE_HERE>"
         }
      }   
   }

   provider "google" {
   project = var.project_id
   }
```

3. Currently, var.project_id is not defined, let's add the following block of code in `variables.tf` to define it. Replace the <PLAYPEN_PROJECT_ID_HERE> with the name of your playpen project, e.g. playpen-a1b2cd
```
variable "project_id" {
  description = "The ID of the GCP project where resources will be deployed"
  type        = string
  default     = "<PLAYPEN_PROJECT_ID_HERE>"
}
```

4. To initialise your Terraform directory and download the Google provider run
   ```
   terraform init
   ```

## Creating the VPC, Subnet and Firewall rule
1. To create a VPC insert the following code block in `networks.tf`
   ```
    resource "google_compute_network" "vpc_network" {
        name                    = "vpc-network"
        auto_create_subnetworks = false
    }
   ```
2. To create subnet-2 insert the following code block into `networks.tf`
   ```
   resource "google_compute_subnetwork" "subnet_2" {
     name          = "webserver-subnetwork"
     ip_cidr_range = "10.0.0.0/24"
     region        = "europe-west2"
     network       = google_compute_network.vpc_network.id
   }
   ```
3. Currently, the variable `var.region` is not defined. In `variables.tf`, add the following block of code to define var.region
   ```
   variable "region" {
     description = "The default GCP region to deploy resources to"
     type        = string
     default     = "europe-west2"
   }
   ```
4. To check if your VPC and subent are configured correctly run
   ```
   terraform plan
   ```
5. So that traffic from the internet can access our webserver we need to create a firewall rule to allow traffic over HTTP. Add the following code block to `networks.tf`
   ```
   resource "google_compute_firewall" "allow_http" {
     name    = "allow-http"
     network = google_compute_network.vpc_network.name
   
     allow {
       protocol = "tcp"
       ports    = ["8080"]
     }
     target_tags   = ["allow-http"]
     source_ranges = ["0.0.0.0/0"]
   }
   ```
   This rule opens port 8080 and allows TCP traffic to any resource with the target tag `allow-http`. Usually the port for HTTP is 80 but our web application has been configured to use port 8080. 

## Creating the webserver
To create a webserver we are going to deploy a compute engine that runs a Docker image containing a Python Flask web application. There are many ways to host a [webserver on GCP](https://cloud.google.com/solutions/web-hosting) all with their own advantages and disadvantages. 

1. For the webserver to be accessible to the internet it will need an external IP. We are going to assign it a fixed IP so that the database will know which server it can talk to. It will also make accessing our instance easier as no matter how many times we deploy it it will always have the same IP address. Insert the following code block in `webserver.tf`
   ```
   resource "google_compute_address" "webserver_ip" {
     name   = "webserver-ip"
     region = "europe-west2"
   }
   ```

2. To create the compute engine add the following code block to `webserver.tf`
   ```
   resource "google_compute_instance" "webserver" {
     name         = "python-web-server"
     machine_type = "e2-small"
     zone         = "europe-west2-b"
   
     tags         = ["allow-ssh","allow-http"]
   
     boot_disk {
       initialize_params {
         image = "ubuntu-os-cloud/ubuntu-1804-lts"
       }
     }
     network_interface {
       network    = google_compute_network.vpc_network.name
       subnetwork = google_compute_subnetwork.webserver_subnet.name
       access_config {
         nat_ip = google_compute_address.webserver_ip.address
       }
     }
   }
   ```
3. You can check the configuration of your compute engine by running
   ```
   terraform plan
   ```
   And deploy it using
   ```
   terraform apply
   ```

## Creating the Postgres database
To use with our web application we are going to deploy a [PostgreSQL](https://www.postgresql.org) database which is an open source relational database. To deploy the database we are going to use a [cloud SQL](https://cloud.google.com/sql) instance. This is a fully managed relational database service provided by GCP. 
1. To create the [sql database instance])(https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) insert the following code block into `database.tf`
   ```
   resource "google_sql_database_instance" "postgres" {
     name             = "capstone-postgres-instance"
     database_version = "POSTGRES_14"
     region = var.region
   
     settings {
       tier = "db-f1-micro"
   
       ip_configuration {
   
          authorized_networks {
           name  = "web-server"
           value = google_compute_address.webserver_ip.address
           }
           
         }
       }
   
     deletion_protection = false
   }
   ```
   On this database instance we have configured it to only authorise access from our web server with the `authorised_networks` block. In this block we have whitelisted the IP of our webserver instance which means that the database will only accept connections from this IP. 
2. We also need to create a [user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) for our web application so that it can access the database
   ```
   resource "google_sql_user" "user" {
     name     = "application-user"
     instance = google_sql_database_instance.postgres.name
     password = random_password.db_password.result
   }
   ```
3. To ensure a secure password for the database user we should randomly generate it. Terraform provides a resource for this called [random passsword]https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password. To create the random password insert the following code block in `database.tf`
   ```
   resource "random_password" "db_password" {
       length = 10 
       special = true
   }  
   ```
4. We also want to create a database in our Postgres instance for our webserver to use. Insert the following code block into `database.tf`
   ```
   resource "google_sql_database" "python_app" {
       name = "application"
       instance = google_sql_database_instance.postgres.name
   }
   ```
5. To deploy the database run 
   ```
   terraform plan
   ```
   Then 
   ```
   terrform apply
   ```

## Deploying the Python web app
We can deploy our web application with a start up script on our compute instance. A start up script can be passed to the compute engine by Terraform and it will run automatically when the machine turns on. 

For our start up script we will want to pass through bash commands which will run on our Ubuntu web server.
### Creating the start up script
1. In your current folder create a file called `application_script.sh`
2. Insert the following code in `application_script.sh`
   ```
   #!/bin/bash
   set -exo pipefail
   ```
   The first line sets the default shell for the script to be executed in as bash. The second line ensures that our script will output the executed commands to the terminal and that the if an error is encounted it will immediately exit and return the error code. These lines are best practice for bash scripts.
3. Next we want to install Docker so that we can build our python web app into a Docker image. Insert the following lines into `application_script.sh`
   ```
   sudo apt-get update
   sudo apt install docker.io -y
   ```
   The first line updates the Ubuntu OS ensuring we have all the latest packages. The second line installs Docker using Ubuntu's in-built package manager. The `-y` is important for this script as it ensures that the script doesn't "hang" waiting for your input to confirm the install. 
4. Next we want to download the web app onto our compute instance. Insert the following lines into `application_script.sh`
   ```
   git clone https://github.com/zeg22/capstone-web-app.git
   cd capstone-web-app/flask-example-cicd
   ```
5. Finally we want to build the python web app into a docker image and run the image so that our website is up and running. Insert the following lines into `application_script.sh`
   ```
   sudo docker build . -t flask-example-cicd:latest
   sudo docker run --rm -d -p 8080:8080/tcp -e "DB_IP=${db_ip}"  -e "DB_USERNAME=${db_username}" -e "DB_PASSWORD=${db_password}" --name flask-example flask-example-cicd:latest
   ```
   The first line builds the Docker image and passes through the database IP, username and password for the application to use. The second runs the Docker image in detached mode so that our webserver is up and running.


### Adding the start up script to the compute engine
Now that we have created our start up script we need to add it to our compute instance. Insert the following into the compute instance resource block in `webserver.tf`
```
metadata_startup_script = templatefile("./application_script.sh", {db_ip = google_sql_database_instance.postgres.public_ip_address, db_username = google_sql_user.user.name, db_password = random_password.db_password.result})
```
This line passes the script file to the metadata as a start up script and passes through the values of the database IP, username and password from the Terraform configuration. 

As our start up script needs information from the database and database user we need to ensure that these are created first. Insert the following line into the compute instance resource block
```
  depends_on = [
    google_sql_database_instance.postgres,
    google_sql_user.user
  ]
```

To add these changes to the webserver run
```
terraform plan
```
Then 
```
terraform apply
```

## Viewing the website
Copy and paste the IP of the webserver from the Terraform output of the apply. 
Open a webbrowser and in the search bar enter `<EXTERNAL IP>:8080`. This will take you to the home page of your website! To test the database connection enter `<EXTERNAL IP>:8080/database/` in the search bar. 


