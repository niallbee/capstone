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

## Installing Jenkins and Java on the Jenkins controller (VM1)
We already have the architecture for subnet-1 containing VM1 and VM2 (the architecture for our jenkins controller and agent). We want to write a script for the controller to start up with so it boots with Jenkins and Java installed. Java is required to run Jenkins.

1. Create a new file in day-1 called `jenkins_java_script.sh` and paste the following code. This script first installs Java, then Jenkins.

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
```

2. We want this script to run on the controller VM upon startup so that when we SSH into it, Java and Jenkins are already installed. Open `vms.tf` in the day-1 folder and insert the following into our google_compute_instance.jenkins-controller-vm. 

```
metadata_startup_script = file("./jenkins_java_script.sh")
```
The `metadata_startup_script` is an argument for a `google_compute_instance` resource where the script will run on the instance when it first starts up. Therefore if we provide the instance our Jenkins script, Jenkins and Java will be installed when the VM starts up.


3. SSH into the Jenkins controller (jenkins-controller-vm)
```
ssh -i ~/.ssh/myKeyFile testUser@<jenkins-controller-vm EXTERNAL_IP>
```
To check that status of Jenkins. Run
```
systemctl status jenkins
```

The output should contain `active (running)`.

If you come across the following error. Please wait a few minutes and try again, it can take some time to run the start up script
```
Unit jenkins.service could not be found.
```

If you are having trouble here with Jenkins being stuck on `active(start)` for a long period of time. Please skip the end of the guide for further instructions (section: Steps to follow if you are having trouble running Jenkins)

4. After installing and running Jenkins, the post-installation setup wizard begins. This setup wizard takes you through a few quick "one-off" steps to unlock Jenkins, customize it with plugins and create the first administrator user through which you can continue accessing Jenkins. 

When you first access a new Jenkins instance, you are asked to unlock it using an automatically generated password. 

5. Browse to `<JENKINS_INSTANCE_EXTERNAL_IP>:8080` and wait until the Unlock Jenkins page appears

6. Back in the Linux session currently open, paste the following command to get the automatically generated password. Copy this password and save it somewhere (you will need this whenever you access the Jenkins UI). 
```
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Creating an admin user for the Jenkins controller (VM1)

1. In the Jenkins setup wizard, paste the copied password into the Administrator password box. Click continue.

2. In the Jenkins UI page you should see options to install suggested plugins or select plugins to install. Click install suggested plugins. 

3. Once all the plugins have installed, click skip and continue with admin

4. Leave the Jenkins URL as it is. Make sure to copy the URL and paste it in a notepad, then click Save and Finish

5. You have now set up Jenkins! 

## Configure VM2 as a permanent agent 

1. Click `start using Jenkins` if you are still in the Jenkins wizard. Otherwise go to the Jenkins URL you copied. 

2. Enter the admin username (it should be admin), and the password you used to access the setup wizard. 

3. A prerequisite of the next steps is that the Jenkins agent must have Java installed. SSH into the jenkins agent (jenkins-agent-vm) and install java
```
ssh -i ~/.ssh/myKeyFile testUser@<jenkins-agent-vm INTERNAL_IP>
sudo apt update
sudo apt install openjdk-11-jre -y
```

## Creating a new user
 
1. Still inside of the jenkins agent terminal, create a jenkins user and password using the following command
```
sudo adduser jenkins --shell /bin/bash
```

Type a password when prompted. E.g. password: jenkins. The above commands should create a user and a home directory names jenkins under `/home`.

2. Now login as the jenkins user using the password just created
```
su jenkins
```

3. Create a `jenkins_slave` directory under /home/jenkins
```
mkdir /home/jenkins/jenkins_slave
```

## Setting up Jenkins slave using ssh keys

1. While logged in as the jenkins user, create a .ssh directory and cd into the directory
```
mkdir ~/.ssh && cd ~/.ssh
```

2. Create an ssh key pair using the following command. Press enter for all defaults when prompted
```
ssh-keygen -t rsa -C "The access key for Jenkins slaves"
```

3. Add the public key to `authorized_keys` using the following command
```
cat id_rsa.pub >> ~/.ssh/authorized_keys
```

4. Now copy the contents of the private key and paste it in a notepad.
-----BEGIN RSA PRIVATE KEY----- and -----END RSA PRIVATE KEY----- inclusive.
```
cat id_rsa
```

## Adding the SSH Private Key to Jenkins Credentials

1. Go to the jenkins dashboard (you should have noted this down earlier). Go to Manage Jenkins -> Manage Credentials. Click `(global)` and click 'Add credentials'.

2. Add the following fields to the credential
- Kind: SSH username with private key
- ID: jenkins
- Description: jenkins ssh key
- Username: jenkins
- Private key -> Enter directly -> Add -> paste the copied content from `cat id_rsa` 
(-----BEGIN RSA PRIVATE KEY----- and -----END RSA PRIVATE KEY----- inclusive.)

Click Create.

## Setting up the agent
1. In the Jenkins dashboard -> Manage Jenkins -> Manage Nodes and Clouds

2. Select the New Node option

3. Give the agent a name like `agent1`, select the Permanent Agent option and click Create

4. Add the following fields to the agent
- Remote root directory: `/home/jenkins/jenkins_slave`
- Usage: Only build jobs with label expressions matching this node
- Launch method: Launch agents via SSH
- Host: internal IP of the agent vm (jenkins-agent-vm)
- Credentials: select the jenkins credential you previous added 
- Host Key Verification Strategy: Manually trusted key Verification Strategy

5. Click save. Jenkins will automatically connect to the slave machine and configure it as an agent. 

6. Click on the agent you just created. Click Log, you should see `This node is being launched`, eventually you should see `Agent successfully connected and online`. You have now made the second VM a permanent Jenkins slave! 

## Finishing up
You have now configured:
- A Jenkins controller VM  
- A Jenkins agent VM

## Next steps
Link to next guide here!











http://34.105.128.155:8080/
decef54614cd4343b1bf9c54eb5a63d1

## Steps to follow if you are having trouble running Jenkins
Jenkins won't run on port 8080 if there is already something else using the same port. In this case, let's change the port that Jenkins is running on.

In the external VM terminal, type 
```
jenkins
```

This will output a lot of text. Scroll to the top of the output and find where it says 
```
Running from: /usr/share/java/jenkins.war
```
Note: the directory may be different on your machine.

cd into the directory above the .war file
```
/usr/share/java/
```

Run the following: 
```
sudo java -jar jenkins.war --httpPort=8081
```

Let this run until you see 'Jenkins is fully up and running'

Press CTRL c to exit that run

Now run
```
systemctl status jenkins
```
It should now be fixed and say active (running).
