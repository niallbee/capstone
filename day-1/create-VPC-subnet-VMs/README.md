## Overview
This first session is to create some of the architecture for the Capstone project. This guide will take you through creating the following architecture:
- VPC 
- Subnet 1 
- VM1 with external SSH connection enabled 
- VM2 with SSH enabled to receive connections only from VM1

This provides the architecture for a subnet containing a VM that will be a CI server with Jenkins and SSH enabled, and another that will be a permenant slave agent. 

This folder also provides the Terraform code for this architecture session. 

## Getting Started 
1. Open your playpen repo in VS Code then create and checkout a new branch

2. Create a new folder called Day 1 and inside that, another folder called Create VPC Subnet VM for this particular session

3. cd to the Create VPC Subnet VM folder in the terminal and run the following commands:

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
1. In the current folder, create a file called `networks.tf`, `vms.tf`, `variables.tf`, and `providers.tf`

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
    resource "google_compute_subnetwork" "subnet-1" {
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

5. To test the subnet is configured correctly run
   ```
   terraform plan
   ```
   If you are happy with the plan output run
   ```
   terraform apply
   ```
   When  prompted type "yes" to execute the apply. This will provision the VPC and subnet in your GCP project. Once the apply is complete your VPC and subnet will be visible in the console.

## Creating a VM with external SSH connection enabled - architecture for a CI server with Jenkins
1. To create the linux compute instance, insert the following code block into `vms.tf`
```
   resource "google_compute_instance" "external_vm" {
      name         = "external-vm"
      machine_type = "e2-micro"
      zone         = "${var.region}-b"

     

      boot_disk {
         initialize_params {
            image = "ubuntu-os-cloud/ubuntu-1804-lts"
         }
      }

      network_interface {
         network    = google_compute_network.vpc_network.name
         subnetwork = google_compute_subnetwork.subnet-1.name
         access_config {
            // Ephemeral public IP
         }
      }
   }
```

Here we are creating an e2-micro machine type which is the smallest and cheapest compute instance available on GCP.

We have also selected an Ubuntu 18 LTS image for the instance as it is a free Linux distribution. This is an LTS (Long Term Support) release of the Ubuntu distribution which means that this version of Ubuntu will be updated and patched regularly making it more secure than a non-LTS release.


2. To allow SSH access into this external-vm, we need to create a firewall rule. To do thism insert the following code block into `networks.tf`. 
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
This will allow SSH traffic from anywhere into your subnet to any resources with the tag "allow-external-ssh". 

3. As we have now created the firewall rule along with a target tag, lets add that target tag to the external-vm so that the firewall rule applies to said vm. Add the following line in `vms.tf` in the external_vm instance, above the boot disk block. 
```
 tags = ["allow-external-ssh"]
```
Now anyone from anywhere is able to ssh into this instance. 


4. To connect to the external-vm, we need to generate an SSH key pair. Open a new terminal outside your code editor and ensure that you are in the root directory of your machine.  Then run the following line
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

3. To authenticate your connection over SSH to your Linux machine it will need the public key of your key pair. We can do this by adding the public key file to our terraform code. But first we will need to retrieve the contents of your public key file. In your terminal run the following command:
   ```
   cat ~/.ssh/myKeyFile.pub
   ```
   This will output the contents of the public key file into the terminal. Copy the entire contents of the file from `ssh-rsa` to `testUser` inclusive.

4. Add the following code into `vms.tf` into your compute instance (external_vm) resource block and replace "YOUR KEY FILE HERE" with the contents of your public key file
   ```
    metadata = {
        ssh-keys = "testUser:YOUR KEY FILE HERE"
    }
   ```
   This adds the user testUser to the machine and allows this user to connect to the instance if their machine has the corresponding private key to the public key on the machine.


5. To add the linux compute instance with external ssh access to our GCP project, run the following:
   ```
   terraform plan
   ```
   ```
   terraform apply
   ```

6. You are now ready to test the connection to your VM! Go to the GCP console and copy the external IP from the external-vm. Then run the following commands in the terminal, replacing <EXTERNAL_IP> with the copied external IP from GCP.
   ```
   ssh -i ~/.ssh/myKeyFile testUser@<EXTERNAL_IP>
   ```
   When you have successfully connected you should be able to see a welcome message and `testUser@external-vm`

7. Now you are connected to you Linux VM you can run on it from your local machine. Try running the following command to output the version of Linux on the instance
   ```
   lsb_release -a
   ```


## Creating a VM with SSH enabled to receive connections from our already created external VM only - architecture for a permenant slave agent
1. To create the linux compute instance, insert the following code block into `vms.tf`
```
   resource "google_compute_instance" "internal_vm" {
      name         = "internal-vm"
      machine_type = "e2-micro"
      zone         = "${var.region}-b"

      boot_disk {
         initialize_params {
            image = "ubuntu-os-cloud/ubuntu-1804-lts"
         }
      }

      network_interface {
         network    = google_compute_network.vpc_network.name
         subnetwork = google_compute_subnetwork.subnet-1.name
         access_config {
            // Ephemeral public IP
         }
      }
   }
```
This is idential to our first external-vm but will have a different firewall rule applied to it. 

2. We want to create a firewall rule that applies only to the internal-vm and that only allows ssh connections from our external-vm. 

 In `networks.tf` add the following code block
```
resource "google_compute_firewall" "allow_internal_ssh" {
  name    = "allow-internal-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags   = ["allow-internal-ssh"]
  source_tags = ["allow-external-ssh"]
  
}
```
This firewall rule is very similar to the allow-external-ssh firewall rule, however the source_tags differ. If source tags are specified, the firewall will apply only to traffic with source IP that belongs to a tag listed in source tags. In this case, we want the firewall rule source tags to encompass the external-vm (allow SSH traffic only from the external-vm) only. Therefore we set the source_tags to all instances with the tag "allow-external-ssh", which applies only to our external vm. 

3. The target tag in the above bloc allows the firewall rule to be applied to anything in the network with the tag "allow-internal-ssh". Therefore we need to add this tag to our internal-vm instance. Add the following block of code in `vms.tf` in our internal-vm resource above the boot_disk block. 
```
   tags = ["allow-internal-ssh"]
```

4. To create these changes in our project, run the following
```
terraform plan
terraform apply
```

5. Now we have a vm with a firewall that only allows traffic to our interal vm via our external vm. As we did with our previous vm, we need to add an SSH key. However it will be a different approach this time and will require a manual process rather than terraform. 

In the GCP console, copy the external IP of the external-vm. In the VS Code terminal, run the following code to SSH to the external-vm. Replacing <EXTERNAL_IP> with the copied external IP of the external-vm from GCP.
```
ssh -i ~/.ssh/myKeyFile testUser@<EXTERNAL_IP>
```

6. You should now be in the external-vm terminal. Similar to how we generated our previous key pair, run the following commands 
 ```
   ssh-keygen -t rsa -f ~/.ssh/myKeyFile -C testUser -b 2048
```

   You will then be prompted to enter a passphrase for your private key and confirm it. It is good practice to add a passphrase as it makes your private key more secure and it is often a requirement set by organisations to connect to their servers. However for this lab it is not required and you can simply press enter twice.

   Once this has run it will create two files: myKeyFile (the private key) and myKeyFile.pub (the public key) in the .ssh directory

7. To authenticate your connection over SSH to your internal-vm machine it will need the public key of your key pair. We can do this by adding the public key file to the internal-vm. But first we will need to retrieve the contents of your public key file. In your terminal run the following command:
   ```
   cat ~/.ssh/myKeyFile.pub
   ```
   This will output the contents of the public key file into the terminal. Copy the entire contents of the file from `ssh-rsa` to `testUser` inclusive.

8. Go to the GCP console, click on your internal-vm, and click edit. Under SSH keys, click Add item. Add your public key into the text box that you have previously copied, from `ssh-rsa` to `testUser` inclusive. Click save.

9. Back in VS Code terminal where you should still be SSH into the external-vm, run the following command to test the SSH connection from our external-vm to our internal-vm. Where the <INTERNAL_IP> is the internal IP of the internal-vm. 
 ```
   ssh -i ~/.ssh/myKeyFile testUser@<INTERNAL_IP>
```

10. You should now find that you have an SSH connection into the internal-vm. Therefore for SSH traffic to reach the internal vm, it first must go through the external-vm. To check that the external vm is SSH accessible from anywhere, and that the internal vm is only accessible from the external vm, run the following commands outside of any vm sessions. You can exit a vm session by typing `exit`. The first should form a successful connection. Then type exit to exit the session. The second should time out. 
```
ssh -i ~/.ssh/myKeyFile testUser@<external-vm EXTERNAL_IP>
exit
ssh -i ~/.ssh/myKeyFile testUser@<internal-vm INTERNAL_IP>
```

## Finishing up
You have now created:
- VPC 
- Subnet 1 
- VM1 with external SSH connection enabled 
- VM2 with SSH enabled to receive connections only from VM1

You now have the base architecture for your first subnet where the external-vm will become a CI server with Jenkins, and the internal-vm will become a permenant slave agent.