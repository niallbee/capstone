## Overview
This guide will take you through the steps to:

- Install Jenkins on subnet1-VM1
- Configure subnet1-VM2 as a permanent agent.

This folder also provides the Terraform code for this architecture session. 

## Getting Started 
Before following this guide, please make sure that you have followed all the previous guides. 

1. Open your playpen repo in VS Code then create and checkout a new branch (if you completed the previous session, use the same branch for this lab)

2. cd into the following folder Capstone Project > day-1 and run the following commands (unless you are following on from the previous guide)

   ```
   gcloud auth login
   ```
   This will open a browser window that will ask you to log into your Google account. 
   Once you are logged in run
   ```
   gcloud config set project <YOUR PROJECT NAME>
   ```
   This will set your playpen project as your default project for gcloud operations.
3. To authenticate with terraform cloud run
   ```
   terraform login
   ```
   Then when prompted type "yes"
   This should open a window for you to log into Terraform Cloud. Click "Sign in with SSO" near the bottom of the page. On the next page type in your Organization name "lbg-cloud-platform" and hit next. You will then be asked to sign into your dev account. 

   When you reach your account you will be prompted to create an API token. Click create token and copy the token generated. Go back to your terminal and where it says enter value paste the API token you copied.

## Install Jenkins on subnet1-VM1
create script that will be the start up script for vm1 - it will install java and jenkins 

We already have the architecture for subnet-1 containing VM1 and VM2. We want to write a script for the VM to start up with so it boots with Jenkins installed.

1. Create a new file in day-1 called `jenkins_script.sh` and paste the following code. This script first curls the LTS (long-term support) release of Jenkins. We then install Java (it is required to run Jenkins), Jenkins, and check the status of Jenkins. 

```
#!/bin/bash
set -exo pipefail

# This script installs Jenkins and Java. Java is required for Jenkins to run

sudo apt update
sudo apt install openjdk-11-jre
java -version
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee   /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]   https://pkg.jenkins.io/debian-stable binary/ | sudo tee   /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins
systemctl status jenkins
```

The output from `systemctl status jenkins` should contain `active (running)`. 

2. This script now needs to apply to the external-vm (the Jenkins instance). Open `vms.tf` in the day-1 folder (this is the architecture for the VM's in subnet 1) and insert the following into our google_compute_instance.external-vm. The `metadata_startup_script` is an argument for a `google_compute_instance` resource where the script will run on the instance when it first starts up. Therefore if we provide the instance our Jenkins script, Jenkins will be downloaded and started.

```
metadata_startup_script = file("./jenkins_script.sh")
```

3. After downloading, installing and running Jenkins, the post-installation setup wizard begins. This setup wizard takes you through a few quick "one-off" steps to unlock Jenkins, customize it with plugins and create the first administrator user through which you can continue accessing Jenkins. 

When you first access a new Jenkins instance, you are asked to unlock it using an automatically generated password. 

1. Browse to `<JENKINS_INSTANCE_EXTERNAL_IP>:8080` and wait until the Unlock Jenkins page appears

2. Back in the Linux session currently open, paste the following command to get the automatically generated password. Copy this password.
```
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

3. In the Jenkins setup wizard, paste the copied password into the Administrator password box. Click continue.

4. The Jenkins UI page you should now be able to see will allow you to install suggested plugins or select plugins to install. For now, don't install any, and click the x on the page. You have now successfully installed and setup Jenkins! 

------ Do I need to setup an admin user? Do I need to configure the Jenkins URL? ------

