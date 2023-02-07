# Guide 1 - Jenkins Architecture

## Overview
This first guide will take you through creating the architecture for a Jenkins controller and its agent. In this session you will create the following resources:
- VPC
- Subnet 1
- VM1 with external SSH connection enabled
- VM2 with SSH enabled to receive connections only from VM1

VM1 will be the Jenkins controller. The Jenkins controller is the original node in the Jenkins installation. The Jenkins controller administers the Jenkins agents and orchastrates their work, including scheduling jobs on agents and monitoring agents. This means that it requires external SSH connection to allow us to SSH into it and configure it.


VM2 will be the Jenkins agent. A Jenkins agent connects to its controller and executes tasks when directed by the controller. This explains why the agent VM needs to allow SSH traffic from controller VM and nowhere else, as it is it's controller.


## Setting up the project
1. In the current folder, create a file called `networks.tf`, `firewall.tf`, `variables.tf`, `main.tf` and `providers.tf`

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

## Creating a VPC and a subnet

1. To create a VPC insert the following code block in `networks.tf`
   ```
    resource "google_compute_network" "vpc_network" {
        name                    = "vpc-network"
        auto_create_subnetworks = false
    }
   ```
   This will create a VPC in your project with the name "vpc-network". As we want to create our own subnet, we have set the argument "auto_create_subnetworks" to false.

2. To test that your VPC is configured correctly run
   ```
   terraform plan
   ```
   This will show you if you have any syntax errors and a plan of what will be provisioned in your GCP project

3. To create the subnet insert the following code block into `networks.tf`
   ```
    resource "google_compute_subnetwork" "subnet_1" {
        name          = "subnetwork-1"
        ip_cidr_range = "10.0.0.0/24"
        region        = var.region
        network       = google_compute_network.vpc_network.id
    }
   ```
   This will create a subnet called "subnetwork-1" within the VPC we have just declared. We have referenced the VPC with `google_compute_network.vpc_network.id` which fetches the ID of the VPC resource.

4. Currently, the variable var.region is not defined. In `variables.tf`, add the following block of code to define var.region
   ```
      variable "region" {
      description = "The default GCP region to deploy resources to"
      type        = string
      default     = "europe-west2"
   }
   ```

5. To test if the subnet is configured correctly run
   ```
   terraform plan
   ```
   If you are happy with the plan output, run
   ```
   terraform apply
   ```
   When  prompted type "yes" to execute the apply. This will provision the VPC and subnet in your GCP project. Once the apply is complete your VPC and subnet will be visible in the console.

## Creating a VM with External SSH - Jenkins Controller
To create an easy to read, reusable Terraform configuration we are going to use modules for the Capstone project. Terraform modules allow you to group resources that are used together into a self contained Terraform directory. This makes your code much easier to reuse as you can simply reference the module and pass through your requirements and it will build the same set of infrastructure every time. There are many premade modules available in the Terraform registry and on GitHub that you could use but you can also create your own modules - which is what we are going to do in this project.

1. In the `capstone-project` folder create a new folder called `day-1`. Then within the `day-1` folder create two new files `vms.tf` and `variables.tf`.

   This will be the folder for our first module. It is important to note that modules are self contained and so cannot see resources outside their current directory. In our case this means that any resource created in the day-1 folder cannot see the reources we have created in the `capstone-project` folder. This means that for any information that we need from outside the module we need to create variables to allow the information to be passed through

   In `variables.tf` insert the following code blocks
   ```
   variable "region" {
     type = string
   }

   variable "vpc_name" {
     type = string
   }

   variable "subnet_name" {
     type = string
   }
   ```
   This will allow us to pass our region, VPC and subnet name to the VMs that we will create in this module.

2. To create the linux compute instance required for the Jenkins controller, insert the following code block into `vms.tf`. Eventually we will need to run Jenkins on this instance. A prerequisite for a Jenkins installation requires the RAM provided by an e2-small, an e2-micro does not provide enough RAM to run Jenkins.
   ```
   resource "google_compute_instance" "jenkins_controller_vm" {
     name         = "jenkins-controller-vm"
     machine_type = "e2-small"
     zone         = "${var.region}-b"

     boot_disk {
       initialize_params {
         image = "ubuntu-os-cloud/ubuntu-1804-lts"
       }
     }

     network_interface {
       network    = var.vpc_name
       subnetwork = var.subnet_name
       access_config {
         // Ephemeral public IP
       }
     }
   }
   ```
   We reference the VPC and subnet name with our variables here but this configuration won't run until we reference the module and pass through the values for the VPC and subnet name.
4. In `main.tf` of the `capstone-project` insert the following code block
   ```
   module "jenkins" {
     source = "./day-1"
     vpc_name = google_compute_network.vpc_network.name
     subnet_name = google_compute_subnetwork.subnet_1.name
     region = var.region
   }
   ```
   This module block declares a module that will be refered to as `Jenkins` in the Terraform configuration files. We use the `source` argument to tell Terraform where to find the module (in our case the `day-1` folder). Then we assign values to the variables that we declared in step one using `variable name = value`

   We could now deploy this module with a `terraform apply` but first we would need to run a `terraform init` as we have introduced a new module. The `terraform init` command installs modules in your configuration so you must run it whenever you introduce a new module.

   However before we deploy our infrastructure we want to make a few more configurations.

5. To use the Jenkin UI we will need to use our web browser to access it via port 8080 over HTTP. To allow the traffic to get to the Jenkins contoller we need to create a firewall rule. To do this insert the following code block into `firewall.tf` in the `capstone-project` folder.
   ```
   resource "google_compute_firewall" "allow_http" {
     name    = "allow-http"
     network = google_compute_network.vpc_network.name

     allow {
       protocol = "tcp"
       ports    = ["8080", "80"]
     }
     target_tags   = ["allow-http"]
     source_ranges = ["0.0.0.0/0"]
   }
   ```

5. To allow SSH access into this jenkins-controller-vm, we need to create a firewall rule. To do this insert the following code block into `firewall.tf` in the `capstone-project` folder.
   ```
   resource "google_compute_firewall" "allow_external_ssh" {
     name    = "allow-external-ssh"
     network = google_compute_network.vpc_network.name

     allow {
       protocol = "tcp"
       ports    = ["22"]
     }
     target_tags   = ["allow-external-ssh"]
     source_ranges = ["0.0.0.0/0"]
   }
   ```
As we want SSH access from any source, we have allowed the source_ranges 0.0.0.0/0. We can use tags here to identify that which instances in the network may make network connections as specified in the firewall rule. In this case, let's assign it with the target_tags "allow-external-ssh". Any instance in the network that has this tag, will allow all SSH connections.

6. Lets now add that target tags to the jenkins-controller-vm so that the firewall rules applies. Add the following line in `vms.tf` in the `day-1` folder in the jenkins_controller_vm instance, above the boot disk block.
   ```
   tags = ["allow-external-ssh", "allow-http"]
   ```
   Now anyone from anywhere is able to connect via SSH or HTTP to this instance.


7. To connect to the jenkins-controller-vm, we need to generate an SSH key pair. Open a new terminal outside your code editor and ensure that you are in the root directory of your machine.  Then run the following line
   ```
   mkdir .ssh
   ```
   This will create a .ssh directory for you to store your SSH key pairs
   Then to generate your key pair run the following command in your terminal
   ```
   ssh-keygen -t rsa -f ~/.ssh/myKeyFile -C testUser -b 2048
   ```
   You will then be prompted to enter a passphrase for your private key and confirm it. It is good practice to add a passphrase as it makes your private key more secure and it is often a requirement set by organisations to connect to their servers. However for this lab it is not required and you can simply press enter twice.

   Once this has run it will create two files: myKeyFile (the private key) and myKeyFile.pub (the public key) in the .ssh directory

8. To authenticate your connection over SSH to your Linux machine it will need the public key of your key pair. We can do this by adding the public key file to our terraform code. But first we will need to retrieve the contents of your public key file. In your terminal run the following command:
   ```
   cat ~/.ssh/myKeyFile.pub
   ```
   This will output the contents of the public key file into the terminal. Copy the entire contents of the file from `ssh-rsa` to `testUser` inclusive.

9. Add the following code into your compute instance (jenkins_controller_vm) resource block in `vms.tf` in the `day-1` and replace "YOUR KEY FILE HERE" with the contents of your public key file
   ```
    metadata = {
        ssh-keys = "testUser:YOUR KEY FILE HERE"
    }
   ```
   This adds the user testUser to the machine and allows this user to connect to the instance if their machine has the corresponding private key to the public key on the machine.

10. Now we are ready to deploy our Jenkins controller VM. First run
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

11. You are now ready to test the connection to your VM! Go to the GCP console and copy the external IP from the jenkins-controller-vm. Then run the following commands in the terminal, replacing <EXTERNAL_IP> with the copied external IP from GCP.
   ```
   ssh -i ~/.ssh/myKeyFile testUser@<EXTERNAL_IP>
   ```
   When you have successfully connected you should be able to see a welcome message and `testUser@jenkins-controller-vm`

12. Now you are connected to you Linux VM you can run on it from your local machine. Try running the following command to output the version of Linux on the instance
   ```
   lsb_release -a
   ```


## Creating a VM with Private SSH to the Jenkins Controller - Jenkins Agent
1. To create the linux compute instance for the Jenkins Agent, insert the following code block into `vms.tf` in the `day-1` folder
   ```
   resource "google_compute_instance" "jenkins_agent_vm" {
     name         = "jenkins-agent-vm"
     machine_type = "e2-small"
     zone         = "${var.region}-b"

     boot_disk {
       initialize_params {
         image = "ubuntu-os-cloud/ubuntu-1804-lts"
       }
     }

     network_interface {
       network    = var.vpc_name
       subnetwork = var.subnet_name
     }
   }
   ```
   This creates a Linux VM that does not have an external IP as we only want to be able to access this VM from within our local network (subnet-1).
2. We want to create a firewall rule that applies only to the jenkins-agent-vm and that only allows ssh connections from our jenkins-controller-vm. We will also need internal SSH for the connections between the agent VM and the webserver that we will create in guide 3 that will host our web application.

   In `firewall.tf` in the `capstone-project` folder add the following code block
   ```
   resource "google_compute_firewall" "allow_internal_ssh_controller_agent" {
     name    = "allow-internal-ssh"
     network = google_compute_network.vpc_network.name

     allow {
       protocol = "tcp"
       ports    = ["22"]
     }
     target_tags = ["allow-internal-ssh-target"]
     source_tags = ["allow-internal-ssh-source"]

   }
   ```
   This firewall rule is very similar to the allow-external-ssh firewall rule, however we are using source_tags over source_ranges. If source tags are specified, any traffic coming from an instance in the network with that tag will be allowed. In this case, we want our jenkins-controller-vm to have SSH access to our jenkins-agent-vm. Our jenkins-controller-vm currently has the tag "allow-external-ssh", so let's make that a source_tag. Let's create a tag called "allow-internal-ssh" and any instances in the network with that tag will have this firewall applied.

3. Now let's add the tags from this firewall into our VMs. This will allow SSH connection from our jenkins-controller-vm into our jenkins-agent-vm as well as from our jenkins-agent-vm to the webserver which we will need to deploy the web application.
   Add the following block of code into our jenkins-controller-vm resource above the boot_disk block in `vms.tf` in the `day-1` folder.
   ```
   tags = ["allow-internal-ssh-source"]
   ```

   Add the following block of code into our jenkins-agent-vm resource above the boot_disk block in `vms.tf` in the `day-1` folder.
   ```
      tags = ["allow-internal-ssh-target"]
   ```

4. To create these changes in our project, run the following
   ```
   terraform plan
   terraform apply
   ```
   No need to run `terraform init` this time as we have already installed the module

5. Now we have a VM with a firewall that only allows traffic to our agent vm via our controller vm. However, no SSH keys have been generated to allow this SSH connection. The steps to generate an SSH key are very similar to what we did for our jenkins-controller-vm, however this time it will require a manual process rather than terraform.

In the GCP console, copy the external IP of the jenkins-controller-vm. In the VS Code terminal, run the following code to SSH to the jenkins-controller-vm. Replacing <EXTERNAL_IP> with the copied external IP of the jenkins-controller-vm from GCP.
```
ssh -i ~/.ssh/myKeyFile testUser@<EXTERNAL_IP>
```

6. You should now be in the jenkins-controller-vm terminal. Similar to how we generated our previous key pair, run the following commands
 ```
   cd ~/.ssh
   ```
   Then to generate your key pair run the following command in your terminal
 ```
   ssh-keygen -t rsa -f ~/.ssh/myKeyFile -C testUser -b 2048
```

   You will then be prompted to enter a passphrase for your private key and confirm it. It is good practice to add a passphrase as it makes your private key more secure and it is often a requirement set by organisations to connect to their servers. However for this lab it is not required and you can simply press enter twice.

   Once this has run it will create two files: myKeyFile (the private key) and myKeyFile.pub (the public key) in the .ssh directory

7. To authenticate your connection over SSH to your jenkins-agent-vm machine it will need the public key of your key pair. We can do this by adding the public key file to the jenkins-agent-vm. But first we will need to retrieve the contents of your public key file. In your terminal run the following command:
   ```
   cat ~/.ssh/myKeyFile.pub
   ```
   This will output the contents of the public key file into the terminal. Copy the entire contents of the file from `ssh-rsa` to `testUser` inclusive.

   Type `exit` to exit the VM session.

8. In `vms.tf`, in the `jenkins_agent_vm` resource block, add the following block of code to add the copied SSH key onto the jenkins-agent-vm. This will allow SSH access from the jenkins-controller-vm into the jenkins-agent-vm.
```
metadata = {
    ssh-keys = "testUser:<SSH KEY HERE>"
  }
```

9. In the terminal, run
```
terraform plan
```
You should see 0 to add, 1 change, 0 to destroy. Where the change is the addition of the SSH key. If you're happy with the plan, run
```
terraform apply
```
This should add the new SSH key to the jenkins_agent_vm.

9. To test the connectivity to the jenkins-agent-vm, we first must SSH back into the jenkins-controller-vm.

```
ssh -i ~/.ssh/myKeyFile testUser@<EXTERNAL_IP>
```

10. Run the following command to test the SSH connection from our jenkins-controller-vm to our jenkins-agent-vm. Where the <INTERNAL_IP> is the internal IP of the jenkins-agent-vm.
 ```
   ssh -i ~/.ssh/myKeyFile testUser@<INTERNAL_IP>
```

10. You should now find that you have an SSH connection into the jenkins-agent-vm. Therefore for SSH traffic to reach the jenkins-agent-vm, it first must go through the jenkins-controller-vm. To check that the jenkins-controller-vm is SSH accessible from anywhere, and that the jenkins-agent-vm is only accessible from the jenkins-controller-vm, run the following commands outside of any vm sessions. You can exit a vm session by typing `exit`. The first should form a successful connection. Then type exit to exit the session. The second should time out.
```
ssh -i ~/.ssh/myKeyFile testUser@<jenkins-controller-vm EXTERNAL_IP>
exit
ssh -i ~/.ssh/myKeyFile testUser@<jenkins-agent-vm INTERNAL_IP>
```

## Finishing up
You have now created:
- VPC
- Subnet 1
- The architecture for a Jenkins controller with external SSH connection enabled (VM1)
- The architecture for a Jenkins agent (VM2) with SSH enabled to receive connections only from the controller (VM1)

You now have the base architecture for your first subnet where the jenkins-controller-vm will become a Jenkins controller and the jenkins-agent-vm will become a permenant slave agent.

## Next steps
Link to next guide here!
