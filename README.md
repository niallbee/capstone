# Capstone Project

This repository contains the Capstone project for the Incubation Lab. This includes:
- Terraform code for the infrastrucute
- Start up scripts
- Jenkins pipeline to deploy the web application
- Python Web App
- Guides

## Infrastructure
The capstone project includes the Terraform code to deploy the following infrastructure
- VPC
- Firewall rules
- 2 subnets, one for the Jenkins controller and agent and one for the webservers and database
- 2 Linux VMs to be used as a Jenkins controller and agent
- 2 webservers
- A Cloud SQL instance running PostgreSQL
- Backend Servic and Instance Group
- Load Balancer
The Terraform code has been configured into modules so that one module is created for each of part of the infrastrucute (i.e. jenkins, webeserver, and load balancer). Each module has a corresponding guide. To read more about the modules please look at the Terraform Documentation section

## Additional Deployments
The capstone project also includes
- Start up scripts to install NGINX
- Start up scripts to install Jenkins
- Jenkins pipeline to deploy a python web application

## Python Web Application
The Python Flask application for the Capstone Project can be found on the `feature/capstone_solution` branch. This is used in the Jenkins pipeline on Day 3 to deploy a simple website that can connect to the database.

## Guides
Guides to completing the project can be found in the "guides" folder. It is important to complete the guides in order as each guides is dependant on the previous. The guide content is as follows:
- Day 1
  - Guide 1 Jenkins architecture - learn how deploy the VPC, subnet and VMs for a Jenkins controller and agent
  - Guide 2 Install Jenkins - Learn how to install Jenkins using a start up script and configuere it to use an agent
- Day 2
  - Guide 3 Webserver and Database - Learn how to deploy a webserver VM with NGINX and a CLoud SQL Postgres instance database
  - Guide 4 Load Balancer - Learn how to deploy multiple VMs into a backend service that can be access with a load balancer
- Day 3
  - Guide 5 Jenkins Pipeline - Learn how to create a Jenkins pipeline that deploys a python web app onto the webservers from day 2


# Getting Started - PLEASE READ
Before completing any of the guides ensure that you have completed the following steps. This should only need to be completed before starting the first guide.
1. Open your playpen repo in VS Code then create and checkout a new branch

2. Create a new folder `capstone-project`, and in this directory in the terminal and run the following commands:
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


# Terraform Documentation
<!-- BEGIN_TF_DOCS -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_google"></a> [google](#requirement\_google) (~> 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_google"></a> [google](#provider\_google) (~> 4.0.0)

## Modules

The following Modules are called:

### <a name="module_jenkins"></a> [jenkins](#module\_jenkins)

Source: ./day-1

Version:

### <a name="module_load_balancer"></a> [load\_balancer](#module\_load\_balancer)

Source: ./day-2/load_balancer

Version:

### <a name="module_web_application"></a> [web\_application](#module\_web\_application)

Source: ./day-2/webserver

Version:

## Resources

The following resources are used by this module:

- [google_compute_firewall.allow_external_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_firewall.allow_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_firewall.allow_internal_ssh_controller_agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_firewall.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) (resource)
- [google_compute_subnetwork.subnet_1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) (resource)
- [google_compute_subnetwork.subnet_2](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) (resource)

## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_project_id"></a> [project\_id](#input\_project\_id)

Description: The ID of the GCP project where resources will be deployed

Type: `string`

Default: `"<YOUR PROJECT HERE>"`

### <a name="input_region"></a> [region](#input\_region)

Description: The default GCP region to deploy resources to

Type: `string`

Default: `"europe-west2"`

## Outputs

The following outputs are exported:

### <a name="output_load_balancer_ip"></a> [load\_balancer\_ip](#output\_load\_balancer\_ip)

Description: n/a
<!-- END_TF_DOCS -->
