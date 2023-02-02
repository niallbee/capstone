# Guide 4 - Load Balancer

## Overview
This session expands upon the architecture in subnet 2 by adding a load balancer and an extra webserver to our deployment. This guide will take you through the following:
- Creating a Load balancer and health check
- Creating an instance group and backend service
- Outputting values from a module
- Creating multiple resources using a count

## Prerequisites
To follow this guide you should have completed [Guide 3](LINK) as we will be adding a load balancer to the infrastructure we created.

If you added a external IP and the target tag "allow-http" to the webserver when completing Guide 3 please make sure to remove the `access_config` block and the `tags` argument from the `google_compute_instance` resource block in the `webserver.tf` file in `capstone-project/day-2/webserver` directory. Then apply the change by running `terraform apply`

## Getting Started 
1. Open your playpen repo in VS Code checkout the branch you used in the previous session

2. You should already be authenticated with GCP and Terraform Cloud from completing the previous Guide 1. If you would like a you would like a refresher please look at [Getting Started - Guide 1](LINK)


## Setting up the project
Within the `capstone-project/day-2` create a new folder called `load_balancer`. In the `load_balancer` folder create the following files 
    - `backend_service.tf`
    - `load_balancer.tf` 
    - `variables.tf` 
    - `outputs.tf`

## Creating multiple webservers
To make our application more scalable we can introduce more webservers to our configuration. This means that there will be more webservers to handle traffic to our website allowing more users to access the site at once. We can then place a load balancer in front of our webservers so that users enter the IP of the load balancer to view the website and then the traffic is routed to the webservers. 
1. To create two copies of our VMs we can introduce the `count` argument to the `google_compute_instance` resource block. Insert the following line in the `google_compute_instance` resource block in `webserver.tf` in the `day-2/webserver` folder
   ```
   count        = 2
   ```
   This will create two identical VMs but we want to ensure that the VMs have different names as you cannot have more than one VM with the same name in a project. To do this we can add a suffix to the VM name. Add `-${count.index}` to the name argument in the google_compute_instance resource block so that it looks like this
   ```
   name         = "python-web-server-${count.index}"
   ```
   This will add the count iterator to the end of the VM name creating two vms called "python-web-server-0" and "python-web-server-1".
3. When we create our load balancer we will need the IDs of our VMs to create our instance group. In the `day-2/webserver` folder create a file called `outputs.tf` and insert the following code blocks
   ```
   output "webserver_1_id" {
     value = google_compute_instance.webserver[0].id
   }
   
   output "webserver_2_id" {
     value = google_compute_instance.webserver[1].id
   }
   ```
   This will output the webserver IDs from the `web_application` module so that these values are accessible from our main configuration file in the `capstone-project` folder.
4. Now that we have added these changes to the `web_application` module run 
   ````
   terraform apply
   ``` 
   To deploy them


## Creating the Backend Service
A backend service defines a group of VMs that will serve traffic from a load balancer. A backend service refers to an instance group of which there are two types: managed and unmanaged. A managed instance group is a group of VMs that is managed by GCP based on parameters that you set. This means that you define a compute instance template which declares the configuration of the VMs you want and when there is sufficient demand GCP will deploy VMs based on this template. This results in a group of identical VMs the increase and decrease in number based on the demand of the user and the parameter you set (e.g. if CPU use is above 50% deploy a new VM). This is known as **auto scaling**. An unmanaged instance group is a group of VMs that have been deployed and configured by you and only increase or decrease in number if you add more VMs yourself. This means that it doesn't auto-scale to suit demand. However we are going to use an unmanaged instance group for our purposes as we will not have enough traffic to our website to require auto-scaling. 

1. To create our instance group insert the following code block into `backend_service.tf` in the `day-2/load_balancer` folder
   ```
   resource "google_compute_instance_group" "webservers" {
     name = "python-webservers"
     zone = "${var.region}-b"
   
     instances = [
       var.webserver_1_id,
       var.webserver_2_id,
     ]
   
     named_port {
       name = "http"
       port = "8080"
     }
   }  
   ```
2. We now want to add our instance group to a backend service. Insert the following code block into `backend_service.tf` in the `day-2/load_balancer` folder
   ```
   resource "google_compute_backend_service" "webserver_backend" {
     name        = "backend-service"
     port_name   = "http"
     protocol    = "HTTP"
     timeout_sec = 10
   
     health_checks = [google_compute_health_check.healthcheck.id]
   
     backend {
       group                 = google_compute_instance_group.webservers.self_link
       balancing_mode        = "RATE"
       max_rate_per_instance = 100
     }
   } 
   ```
3. To ensure that our webservers are able to recieve the HTTP traffic we want to create a health check. Health checks regularly poll instances to ensure that they are able to recieve traffic by sending health probes over a designated port. If the health probe doesn't reach the instance successfully the instance is marked as "unhealthy" and traffic from the load balancer will not be sent to that instance. To create the health check insert the following code block into `backend_service.tf` in the `day-2/load_balancer` folder 
   ```
   resource "google_compute_health_check" "healthcheck" {
     name                = "http-health-check"
     check_interval_sec  = 5
     timeout_sec         = 5
     unhealthy_threshold = 10
     http_health_check {
       port = 8080
     }
   }
   ```
   This will send a health probe to port 8080 every 5 seconds and allow 5 seconds for a response. If 10 health probes do not recieve a response then the instance will be deemed unhealthy. We have targeted port 8080 here as this is the port that our python webserver runs on.
4. To allow the health probes to reach our VMs we need to create a firewall rule that allows them to reach the health check port. Insert the following code block into `firewall.tf` in the `capstone-project` folder
   ```
   resource "google_compute_firewall" "default" {
     name          = "fw-allow-health-check"
     direction     = "INGRESS"
     network       = google_compute_network.vpc_network.name
     priority      = 1000
     source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
     target_tags   = ["allow-health-check"]
     allow {
       ports    = ["8080"]
       protocol = "tcp"
     }
   }
   ```
   The source ranges we use here are for the Google Cloud health checking systems which will be the origin of the health probes. To allow them to reach our VMs we need to add the tag allow-health-check. In `webserver.tf` in the `day-2/webserver` folder insert the following line into the google_compute_instance resource block so that it looks like this
   ```
   tags = ["allow-health-check"] 
   ```

## Creating the Load Balancer
Now that we have set up our backend service we need to introduce a load balancer. Because our VMs only have private IPs we need to provide an external IP in the form of a load balancer so that users can access our website. For our purposes we are going to use a global external HTTP load balancer.
1. Insert the following code blocks into `load_balancer.tf` in the `day-2/load_balancer` folder 
   ```
   resource "google_compute_url_map" "url_map" {
     name            = "url-map"
     default_service = google_compute_backend_service.webserver_backend.id
   }
   
   resource "google_compute_target_http_proxy" "http_proxy" {
     name    = "http-proxy"
     url_map = google_compute_url_map.url_map.id
   }
   
   resource "google_compute_global_forwarding_rule" "forwarding_rule" {
     name       = "web-app-forwarding-rule"
     target     = google_compute_target_http_proxy.http_proxy.self_link
     port_range = "8080"
   }
   ```
   Here the `google_compute_global_forwarding_rule` represents the load balancer - it creates the IP and is the inititail resource that HTTP requests to our website will hit. Our traffic will then be routed via the `google_compute_target_http_proxy` to the `google_compute_url_map` which will distribute the requests to the backend service.
2. We will need the IP of our load balancer to access the website so let's create an output so that we can access it easily. In `output.tf` in the `day-2/load_balancer` folder insert the following code block]
   ```
   output "load_balancer_ip" {
     value = google_compute_global_forwarding_rule.forwarding_rule.ip_address
   }
   ```

## Calling the module and deploying the infrastructure
Now that we have created the infrastructure for our module lets configure the variables and call it in our main configuration file. 
1. Insert the following code blocks into `variables.tf` in the `day-2/load_balancer` folder
   ```
   variable "region" {
       type = string
   }
   
   variable "webserver_1_id" {
       type = string
   }
   
   variable "webserver_2_id" {
       type = string
   }
   ```
   This is so we can pass the webserver IDs and region to the instance group.
2. To declare the module insert the following code block into `main.tf` in the `capstone-project` folder
   ```
   module "load_balancer" {
       source = "./day-2/load_balancer"
       webserver_1_id = module.web_application.webserver_1_id
       webserver_2_id = module.web_application.webserver_2_id
       region = var.region
   }
   ```
   This module block declares a module that will be refered to as `load_balancer` in the Terraform configuration files. We use the `source` argument to tell Terraform where to find the module (in our case the `day-2/load_balancer` folder). Then we assign values to the variables that we declared in step one using `variable name = value`. For our webserver IDs we are referencing the output of the web_application module with the format `module.<module name>.<output name>`
3. As part of creating our `load_balancer` module we output the load balancer IP. However this just made it visible to the `capstone-project` directory. We now need to output it from this directory so that it comes through in the terminal. In `output.tf` in the `capstone-project` folder insert the following code block
   ```
   output "load_balancer_ip" {
       value = module.load_balancer.load_balancer_ip
   }
   ```
4. Now we are ready to deploy our load balancer. First run 
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

## Viewing the NGINX homepage
Now that we have deployed our load balancer when can use it to view the NGINX webpage that we deployed on the VMs. 

Copy the IP of the load balancer from the output in the terminal where you ran the terraform apply and paste it into the web browser along with the port like below
   ```
   <LOAD BALANCER IP>:8080
   ```

## Viewing the Load Balancer
You can view information about your load balancer and the health of the backend service in the GCP console.

1. Open the GCP console and in the search bar search for "Load Balancing"
2. Click on "Load balancing" and you will be able to see the "url-map" and the backend health.
3. Click on the URL map to display more information about the backend service and health.