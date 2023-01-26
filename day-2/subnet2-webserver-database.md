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