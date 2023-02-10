# Guide 3 - Webserver and Database

# Overview
This session will create the architecture for subnet 2 of the Capstone project. This guide will take you through deploying the following architecture
- Subnet
- Webserver with NGINX
- Postgres database
- Firewall rules

This session will create a new module for the webserver and its database. The webserver deployed here will be used to host a python web application that will be able to connect to the postgres database. We will deploy the web app as part of the Jenkins pipeline on day 3.

## Prerequisites
Before completing this session you should have completed [Guide 1](https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project/blob/main/guides/day-1/guide-1-jenkins-architecture.md) as this contains the inital set up of our Terraform configuration.

Please ensure that you have completed the [Getting Started](https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project/blob/main/README.md) section and are on the branch you created with the folder `capstone-project`


## Setting up the project
Within the `capstone-project` folder create a new folder called `day-2`. Within the `day-2` folder create a folder called `webserver`. In the `webserver` folder create the following files
    - `networking.tf`
    - `webservertf`
    - `database.tf`
    - `variables.tf`


## Creating Subnet 2
In `networks.tf` of the `capstone-project` folder input the following code block
```
resource "google_compute_subnetwork" "subnet_2" {
  name          = "webserver-subnetwork"
  purpose       = "PRIVATE"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}
```
This will create a private subnet for our webserver VM.


## Deploying a Webserver
To create a webserver we are going to deploy a compute engine that installs NGINX on start up. There are many ways to host a [webserver on GCP](https://cloud.google.com/solutions/web-hosting) all with their own advantages and disadvantages.

1. First we need to declare the variables that our webserver module will need just as we did for the Jenkins module. In `variables.tf` in the `day-2/webserver` folder insert the following code blocks
   ```
   variable "region" {
     type = string
   }

   variable "vpc_name" {
     type = string
   }

   variable "vpc_id" {
     type = string

   }

   variable "subnet_2_name" {
     type = string
   }

   variable "subnet_2_id" {
     type = string
   }
   ```
2. To create the compute engine add the following code block to `webserver.tf` in the `day-2/webserver` folder
   ```
   resource "google_compute_instance" "webserver" {
     name         = "python-web-server"
     machine_type = "e2-small"
     zone         = "${var.region}-b"

     tags         = ["allow-internal-ssh-target"]

     boot_disk {
       initialize_params {
         image = "ubuntu-os-cloud/ubuntu-1804-lts"
       }
     }
     network_interface {
       network    = var.vpc_name
       subnetwork = var.subnet_2_name
     }
   }
   ```
   This creates a Linux VM runninng Ubuntu 18. This VM will only have a private IP as we haven't allocated an external IP. This makes the instance more secure as it will be much harder for a external party to access the instance as they would have to be in our network to use the internal IP.

### Creating a script to install NGINX
To turn our Linux VM into a webserver we need to install a webserver application onto it. We can do this with a start up script that will run when the VM boots up. For this exercise we are going to use NGINX. [NGINX](https://nginx.org/en/docs/) is an open source lightweight webserver that is easy to configure making it it ideal for testing the connectivity of your infrastructure.
1. In the `day-2/webserver` folder create a file called `nginx_startup.sh`
2. In `nginx_startup.sh` insert the following script
   ```
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
     $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

   # Grat read permission for Docker public key file
   sudo chmod a+r /etc/apt/keyrings/docker.gpg

   # Install Docker engine
   sudo apt-get update -y
   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

   # Run nginx container
   sudo docker run --name mynginx1 -p 80:80 -d nginx
   ```
   This script installs the Docker engine and runs an nginx server in a docker container on port 80.

   **Note**

   The first line of the script sets the default shell for the script to be executed in as bash. The second line ensures that our script will output the executed commands to the terminal and that if an error is encounted it will immediately exit and return the error code. These lines are best practice for bash scripts.

   The `-y` at the end of some of the command means that these commands will not waiting for manual input to approve them. Instead we pass the approval with the command so that the script doesn't "hang" waiting for manual input. This is important for automation scripts as it will prevent the script from completing if it is left to wait for manual input


### Adding the start up script to the VM
Now that we have created our start up script we need to add it to our compute instance. Insert the following into the compute instance resource block in `webserver.tf` in the `day-2/webserver` folder
```
  metadata_startup_script = file("./day-2/webserver/nginx_startup.sh")
```
This line passes the script file to the metadata as a start up script and passes through the values of the database IP, username and password from the Terraform configuration.


## Creating a NAT router
A NAT (Network Address Translation) router enables devices without a public IP to access the internet. Instances that only have private IPs (i.e. instances with IPs in the range of 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) cannot access the internet as they are assigned an IP that never leaves the LAN (local area network) which means that they only have to be unique in that network. This essentially means that multiple instances across the world could have the same IP but because they do not access the internet the addresses do not get confused. By setting up a NAT router we will provide our VM instances a public IP that they can use to access the internet which they will need to install NGINX when our start up script runs.

1. To create the public NAT IP that our VMs will use insert the following code block into `networking.tf` in the `day-2/webserver` folder
   ```
   resource "google_compute_address" "nat_ip" {
     name   = "nat-ip"
     region = "europe-west2"
   }
   ```
2. To create the router that will direct the traffic from our VMs to the internet via the NAT IP insert the following code blocks into `networking.tf` in the `day-2/webserver` folder
   ```
  resource "google_compute_router" "nat_router" {
    name    = "nat-router"
    network = var.vpc_id
    region  = "europe-west2"
  }

    resource "google_compute_router_nat" "nat" {
      name                               = "my-router-nat"
      router                             = google_compute_router.nat_router.name
      region                             = google_compute_router.nat_router.region
      nat_ip_allocate_option             = "MANUAL_ONLY"
      nat_ips                            = [google_compute_address.nat_ip.self_link]
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
      subnetwork {
        name                    = google_compute_subnetwork.subnet_2.id
        source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
      }
      depends_on = [
        google_compute_address.nat_ip
      ]
    }
    ```
    This allows any IP in subnet two to use the NAT IP to access the internet.


## Creating the Postgres database
To use with our web application we are going to deploy a [PostgreSQL](https://www.postgresql.org) database which is an open source relational database. To deploy the database we are going to use a [cloud SQL](https://cloud.google.com/sql) instance. This is a fully managed relational database service provided by GCP.

1. To create the [sql database instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) insert the following code block into `database.tf` in the `day-2/webserver` folder
   ```
   resource "google_sql_database_instance" "postgres" {
     name             = "capstone-postgres-instance"
     database_version = "POSTGRES_14"
     region           = var.region

     settings {
       tier = "db-f1-micro"

       ip_configuration {
         ipv4_enabled    = "false"
         private_network = var.vpc_id
       }
     }
     depends_on          = [google_service_networking_connection.private_db_connector]
     deletion_protection = false
   }
   ```
   On this database instance we have configured it to allow private connections from our VPC. The Cloud SQL service sits outside subnet-2 and so is not part of our LAN network. This means that we cannot whitelist the webserver using its private IP as the Cloud SQL service will not know what we are refering to (remember private IPs only need to be unique within their LAN). To allow a connection between the Cloud SQL instance and our private webservers we create a private IP for our database within our VPC network and a private connection to the Cloud SQL service from our VPC.
2. To create a private IP within our VPC for our database insert the following code blocks into `networking.tf` in the `day-2/webserver` folder
   ```
   resource "google_compute_global_address" "private_ip_address" {
     name          = "private-ip-address"
     purpose       = "VPC_PEERING"
     address_type  = "INTERNAL"
     prefix_length = 16
     network       = var.vpc_id
   }
   ```
3. To establish a private connection between our private IP and the Cloud SQL service's network insert the following code block into `networking.tf`in the `day-2/webserver` folder
   ```
   resource "google_service_networking_connection" "private_db_connector" {
     network                 = var.vpc_id
     service                 = "servicenetworking.googleapis.com"
     reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
   }
   ```
4. Now that the database has been configured and the private connection established we can can create a [user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) for our web application so that it can access the database. Insert the following code block into `database.tf` in the `day-2/webserver` folder
   ```
   resource "google_sql_user" "user" {
     name     = "application-user"
     instance = google_sql_database_instance.postgres.name
     password = random_password.db_password.result
   }
   ```
5. To ensure a secure password for the database user we should randomly generate it. Terraform provides a resource for this called [random passsword](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password). To create the random password insert the following code block into `database.tf` in the `day-2/webserver` folder`
   ```
   resource "random_password" "db_password" {
       length = 10
       special = true
   }
   ```
6. We also want to create a database in our Postgres instance for our webserver to use. Insert the following code block into `database.tf` in the `day-2/webserver` folder
   ```
   resource "google_sql_database" "python_app" {
       name = "application"
       instance = google_sql_database_instance.postgres.name
   }
   ```
## Calling the module and deploying the infrastructure
Now that we have created the Terraform code for our webserver module we can call it in our main configuration file and deploy it.
1. Insert the following code block into `main.tf` in the `capstone-project` folder
   ```
   module "web_application" {
     source = "./day-2/webserver"
     vpc_id = google_compute_network.vpc_network.id
     vpc_name = google_compute_network.vpc_network.name
     subnet_2_name = google_compute_subnetwork.subnet_2.name
     subnet_2_id = google_compute_subnetwork.subnet_2.id
     region = var.region
   }
   ```
   This module block declares a module that will be refered to as `web_application` in the Terraform configuration files. We use the `source` argument to tell Terraform where to find the module (in our case the `day-2/webseerver` folder). Then we assign values to the variables that we declared in step one using `variable name = value`
2. Now we are ready to deploy our webserver and database infrastructure. First run
   ```
   terraform init
   ```
   To install our new module. Then run
   ```
   terraform plan
   ```
   To validate the configuration. If you are happy with the configuration run
   ```
   terraform apply
   ```
   This will take ~15 - 20 minutes to deploy.

## Viewing the NGINX homepage
Now that the infrastructure is deployed we want to view the NGINX homepage so that we know that all the connectivity is working correctly. However we have deployed our webserver into a private subnet with no external IP. This means there are two options open to use to view the webpage:
1. We can allocate an external IP to the webserver and create a firewall rule that allows HTTP traffic to it
2. We can add a load balancer that can route traffic to our webserver in the private subnet

The first option is more simplistic but less secure but we will use here to test our configuration. [Guide 4](LINK) walks you through how to deploy a Load balancer.

1. To add an external IP to our webserver insert the following code block into the `google_compute_instance` `network_interface` block in the `weberser.tf` file in the `day-2/webseerver` folder
   ```
   access_config {
     // Ephemeral public IP
   }
   ```
2. To allow traffic to our webserver insert the following code block into the `google_compute_instance` resource block in the `weberser.tf` file in the `day-2/webseerver` folder
   ```
   tags = ["allow-http"]
   ```
3. Run `terraform apply` to add the changes to your configuration
4. In the GCP console search for "compute engine" in the search bar and go to the page. You should be able to see an instance called "python-web-server". Copy the external IP
5. Paste the external IP of the VM into the search bar of you browser as shown below:
   ```
   <EXTERNAL IP>:80
   ```
   You should be greeted with a "Welcome to nginx!" page.
