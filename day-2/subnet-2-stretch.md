# Day 2 - Stretch

## Overview
This session expands upon the architecture in subnet 2 by adding a load balancer and an extra webserver to our deployment.  This guide will take you through the following:
- Creating a Load balancer and health check
- Creating an instance group and backend service
- Creating a private connection to the database

This session will use Terraform, shell scripts and docker to deploy a complete web app. 

## Prerequisites
To complete this lab you should have already completed the first subnet 2 session. You will also need to ensure that the infrastructure from day 1 has been deployed as we will deploy this infrastructure into the same VPC. 

## Getting Started
1. Open your playpen repo in VS Code then checkout the branch you used in the previous session

2. You should already be authenticated with GCP and Terraform Cloud from completing the previous session. If you would like a you would like a refresher please look at [Getting Started - subnet2-webserver-database](https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project/blob/main/day-2/subnet2-webserver-database.md#getting-started)

## Setting up the project
1. In the current folder (day-2), create a file called `loadbalancer.tf`
2. You should have already set up the providers, variables and initialised the directory in the previous session. If you would like a refresher please look at [Setting up the project - subnet2-webserver-database](https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project/blob/main/day-2/subnet2-webserver-database.md#setting-up-the-project)
3. During this session there will be lots of changes to our configuration. To simplify the process ensure that the infrastructure from the previous Day 2 session has been destroyed by running
   ```
   terraform destroy
   ```
   In the `day-2` directory


## Creating a backend service
A backend service defines a group of VMs that will serve traffic from a load balancer. By introducing a load balancer to our web application we can make it more scalable as there will be multiple instances that can serve the traffic. We can also make it more secure as user will not connect to the public IP of the VMs directly. Instead they will connect to the load balancer which will route the traffic to the VMs' private IPs allowing us to lock down access to the VMs in a private subnet. 
So lets create our backend service for our load balancer
1. In `networks.tf` insert the following line into the `google_compute_subnetwork` resource block
   ```
     purpose       = "PRIVATE"
   ```
   This will turn subnet 2 into a private subnet making it more secure. We also want to remove the external IP of our VM instance. Remove the `access_config` block from the `network_interface` block in the `google_compute_subnetwork` resource block so that it looks like this
   ```
     network_interface {
       network    = data.google_compute_network.vpc_network.name
       subnetwork = google_compute_subnetwork.subnet_2.name
     }
    ```

2. To create multiple instances of our webserver VM we can introduce a `count` argument. In `webserver.tf` insert the following line into the `google_compute_instance` resource block
   ```
     count        = 2
   ```  
   This will create two identical VMs but we want to ensure that they have different names as you cannot have more than one VM with the same name in a project. To do this we can add a suffix to the VM name. Add `-${count.index}` to the name argument in the `google_compute_instance` resource block so that it looks like this
   ```
     name         = "python-web-server-${count.index}"
   ```
   This will add the  count iterator to the end of the VM name creating two vms called "python-web-server-0" and "python-web-server-1". 
   We can assign these VMs to a local varaible to make it more readable in the code by inserting the following code block into `webserver.tf`
   ```
   locals {
     webserver_1 = google_compute_instance.webserver[0]
     webserver_2 = google_compute_instance.webserver[1]
   }
   ```
3. Now that we have two VM instances we need to assign them to an instance group. In `webserver.tf` insert the following code block
   ```
   resource "google_compute_instance_group" "webservers" {
     name = "python-webservers"
     zone = "europe-west2-b"
   
     instances = [
       local.webserver_1.id,
       local.webserver_2.id,
     ]
   
     named_port {
       name = "http"
       port = "8080"
     }
   
   }
   ```
   This creates an unmanaged instance group which allows you to add VMs directly to an instance group. We could have also created a managed instance group by creating a compute instance template instead of configuring our VMs directly. This would allow autoscaling of our application as GCP would use the template to create more instances as traffic demanded it. This is what you would use for large scale applitions but for our purposes we can stick with two fixed instances. 
4. We now want to add our instance group to a backend service. In `webserver.tf` insert the following code block
   ```
   resource "google_compute_backend_service" "webserver_backend" {
     name        = "webserver-backend-service"
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
5. To ensure that our webservers are able to recieve the HTTP traffic we want to create a health check. Health checks regularly poll instances to ensure that they are able to recieve traffic by sending health probes over a designated port. If the health probe doesn't reach the instance successfully the instance is marked as "unhealthy" and traffic from the load balancer will not be sent to that instance. To create the health check insert the following code block in `webserver.tf`
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
6. To allow the health probes to reach our VMs we need to create a firewall rule that allows them to reach the health check port. Insert the following code block into `networks.tf`
   ```
   resource "google_compute_firewall" "default" {
     name          = "fw-allow-health-check"
     direction     = "INGRESS"
     network       = data.google_compute_network.vpc_network.name
     priority      = 1000
     source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
     target_tags   = ["allow-health-check"]
     allow {
       ports    = ["8080"]
       protocol = "tcp"
     }
   }
   ```
   The source ranges we use here are for the Google Cloud health checking systems which will be the origin of the health probes. To allow them to reach our VMs we need to add the tag `allow-health-check`. In `webserver.tf` insert the following into the tags list of the `google_compute_instance` resource block so that it looks like this
   ```
   tags = ["allow-http", "allow-health-check"] 
   ```

## Creating a NAT router
A NAT (Network Address Translation) router enables devices without a public IP to access the internet. Instances that only have private IPs 
(i.e. instances with IPs in the range of 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) cannot access the internet as they are assigned an IP that never leaves the LAN (local area network) which means that they only have to be unique in that network. This essentially means that multiple instances across the world could have the same IP but because they do not access the internet the addresses do not get confused. By setting up a NAT router we will provide our VM instances a public IP that they can use to access the internet. 

1. To create the public NAT IP that our VMs will use insert the following code block into `networks.tf`
   ```
   resource "google_compute_address" "nat_ip" {
     name   = "nat-ip"
     region = "europe-west2"
   }
   ```
2. To create the router that will direct the traffic from our VMs to the internet via the NAT IP insert the following code blocks into `networks.tf`
   ```
   resource "google_compute_router" "nat_router" {
     name    = "nat-router"
     network = data.google_compute_network.vpc_network.id
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


## Creating the Load Balancer
Now that we have set up our backend service and its connectivity to the internet we need to introduce a load balancer. Because our VMs only have private IPs we need to provide an external IP in the form of a load balancer so that users can access our website. For our purposes we are going to use a global external HTTP load balancer. 
1. In `loadbalancer.tf` insert the following code blocks
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
   Here the `google_compute_global_forwarding_rule` represents the load balancer - it creates the IP and is the inititail resource that HTTP requests to our website will hit. 
   Our traffic will then be routed via the `google_compute_target_http_proxy` to the `google_compute_url_map` which will distribute the requests to the backend service.
2. We will need the IP of our load balancer to access the website so let's create an output so that we can access it easily. In `output.tf` insert the following code block
   ```
   output "load_balancer_ip" {
     value = google_compute_global_forwarding_rule.forwarding_rule.ip_address
   }
   ```
   Our VMs no longer have a public IP and we are going to reconfigure our database to use a private IP, removing the external. So we will want to remove these outputs as the public IPs will no longer exist. In `outputs.tf` remove the `webserver_ip` and `database_ip` code blocks.


## Creating a private connection for the database
Our VMs are now in a private subnet and no longer have public IPs. The Cloud SQL service sits outside this subnet and so is not part of the LAN network. This means that we cannot whitelist the webservers using their private IPs as the Cloud SQL service will not know which instance we are refering to (remember private IPs only need to be unique within their LAN). To allow a connection between the Cloud SQL instance and our private webservers we create a private IP for our database within our VPC network and a private connection to the Cloud SQL service from our VPC. 
1. To create a private IP within our VPC for our database insert the following code blocks into `networks.tf`
   ```
   resource "google_compute_global_address" "private_ip_address" {
     name          = "private-ip-address"
     purpose       = "VPC_PEERING"
     address_type  = "INTERNAL"
     prefix_length = 16
     network       = data.google_compute_network.vpc_network.id
   }
   ```
2. To establish a private connection between our private IP and the Cloud SQL service's network insert the following code block into `networks.tf`
   ```
   resource "google_service_networking_connection" "private_db_connector" {
     network                 = data.google_compute_network.vpc_network.id
     service                 = "servicenetworking.googleapis.com"
     reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
   }   
   ```
3. Now that we have created a private connection to the service we need to configure the database to use our VPC network. In `database.tf` replace the `ip_configuration` in the `google_sql_database_instance` resource block with the following
   ```
    ip_configuration {
      ipv4_enabled    = "false"
      private_network = data.google_compute_network.vpc_network.id
    }
   ```
   This will allocate the private IP we created to the databse via the `google_service_networking_connection` as we have referenced thhe IP in this resource block.
   As there is no implicit dependancy between the database resource and the networking connection we need to create an explicit dependancy with the `depends_on` argument. In `database.tf` insert the following line in the `google_sql_database_instance` resource block
   ```
   depends_on          = [google_service_networking_connection.private_db_connector]
   ```
   When you have finished the `google_sql_database_instance` resource block should look like this
   ```
   resource "google_sql_database_instance" "postgres" {
     name             = "capstone-postgres-instance"
     database_version = "POSTGRES_14"
     region           = var.region
   
     settings {
       tier = "db-f1-micro"
   
       ip_configuration {
         ipv4_enabled    = "false"
         private_network = data.google_compute_network.vpc_network.id
       }
     }
     depends_on          = [google_service_networking_connection.private_db_connector]
     deletion_protection = false
   }
   ```
4. As we have changed the connection method of the database we need to change the details that we pass through to the start up script on our VMs. In `webserver.tf` replace the `metadata_startup_script` argument in the `google_compute_instance` resource block with the following
   ```
   metadata_startup_script = templatefile("./application_script.sh", { db_ip = google_sql_database_instance.postgres.private_ip_address, db_username = google_sql_user.user.name, db_password = random_password.db_password.result })
   ```
   This changes the database IP to be the new private IP rather than the previous public IP

## Deploying the infrastructure and accessing the website
Now that all the resources are configured we can deploy our infrastructure to our GCP project. Noramlly we would have been running `terraform plan` and `terraform apply` as we went along so that we could continually check that our configuration was valid. However we couldn't here as we changed multiple resources that were dependant on each other. Now that we have configured everything to connect privately and introduced a load balancer we can deploy all our changes. Run the following
```
terraform plan
```
If you are happy with the configuration run
```
terraform apply
```
This apply will take ~ 15 - 20 minutes as the database takes a little while to deploy. Once the apply is complete the start up scripts will take ~ 5 minutes to execute, after which you will be able to access the website. Copy the IP of the load balancer from the output in the terminal where you ran the `terraform apply` and paste it into the web browser along with the port like below
```
<LOAD BALANCER IP>:8080
```
You should be able to see the website homepage. You can then check the database connection by navigating to 
```
<LOAD BALANCER IP>:8080/database/
```
### Viewing the load balancer
You can view information about your load balancer and the health of the backend service in the GCP console. 
1. Open the GCP console and in the search bar search for "Load Balancing"
2. Click on "Load balancing" and you will be able to see the "url-map" and the backend health. 
3. Click on the URL map to display more information about the backend service and health. 

