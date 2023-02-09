# Guide 2 - Install and Configure Jenkins
## Overview
This guide will take you through the steps to:

- Install Jenkins on subnet1-VM1
- Configure subnet1-VM2 as a permanent agent.

## Prerequisites
Before completing this session you should have completed [Guide 1](https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project/blob/main/guides/day-1/guide-1-jenkins-architecture.md) as we will be configuring the VMs from this guide to be our Jenkins controller and agent.

Please ensure that you have completed the [Getting Started](https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project/blob/main/README.md) section and are on the branch you created with the folder `capstone-project`

## Installing Jenkins and Java on the Jenkins controller (VM1)
We already have the architecture for subnet-1 containing VM1 and VM2 (the architecture for our jenkins controller and agent). We want to write a script for the controller to start up with so it boots with Jenkins and Java installed. Java is required to run Jenkins.

1. Create a new file in day-1 called `jenkins_java_script.sh` and paste the following code. This script first installs Java, then Jenkins.
   ```
   #!/bin/bash
   set -exo pipefail

   # This script installs Jenkins and Java. Java is required for Jenkins to run

   sudo apt update -y
   sudo apt install openjdk-11-jre -y
   java -version
   curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee   /usr/share/keyrings/jenkins-keyring.asc > /dev/null
   echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]   https://pkg.jenkins.io/debian-stable binary/ | sudo tee   /etc/apt/sources.list.d/jenkins.list > /dev/null
   sudo apt-get update -y
   sudo apt-get install jenkins -y
   ```

2. We want this script to run on the controller VM upon startup so that when we SSH into it, Java and Jenkins are already installed. Open `vms.tf` in the day-1 folder and insert the following into our google_compute_instance.jenkins-controller-vm.

   ```
   metadata_startup_script = file("./day-1/jenkins_java_script.sh")
   ```
   The `metadata_startup_script` is an argument for a `google_compute_instance` resource where the script will run on the instance when it first starts up. Therefore if we provide the instance our Jenkins script, Jenkins and Java will be installed when the VM starts up.

   To add this change to the VM run
   ```
   terraform apply
   ```

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

4. After installing and running Jenkins, the post-installation setup wizard begins. This setup wizard takes you through a few quick "one-off" steps to unlock Jenkins, customize it with plugins and create a user through which you can continue accessing Jenkins.

5. Browse to `<JENKINS_INSTANCE_EXTERNAL_IP>:8080` and wait until the Unlock Jenkins page appears

6. Back in the Linux session currently open, paste the following command to get the automatically generated password needed to access Jenkins for the first time.
   ```
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

## Creating an admin user for the Jenkins controller (VM1)

1. In the Jenkins set up wizard in your browser, paste the copied password into the Administrator password box. Click continue.

2. In the Jenkins UI page you should see options to install suggested plugins or select plugins to install. Click install suggested plugins.

3. Once all the plugins have installed, you can create your admin user. Enter a username and password of your chosing and make a note of them as you will need them further on in the project (you will need them to access the Jenkins instance if you are logged out). You will also need to provide a name and email (you can use you lloydsbanking.com email).

4. Leave the Jenkins URL as it is. Make sure to copy the URL and paste it in a notepad, then click Save and Finish

5. You have now set up Jenkins!

## Creating SSH keys for the controller to agent connection
As mentioned in the previous guide the controller and agent are going to communicate over SSH. To configure this connection we need to generate SSH keys on the controller VM and add the public key to the agent VM
1. SSH to the controller using the commnad we used before
   ```
   ssh -i ~/.ssh/myKeyFile testUser@<jenkins-controller-vm EXTERNAL_IP>
   ```
2. You should now be in the jenkins-controller-vm terminal. Similar to how we generated our previous key pair, run the following commands
   ```
   cd ~/.ssh
   ```
   Then to generate your key pair run the following command in your terminal
   ```
   ssh-keygen -t rsa -f ~/.ssh/myKeyFile -C testUser -b 2048
   ```
   You will then be prompted to enter a passphrase for your private key and confirm it. It is good practice to add a passphrase as it makes your private key more secure and it is often a requirement set by organisations to connect to their servers. However for this lab it is not required and you can simply press enter twice.

   Once this has run it will create two files: myKeyFile (the private key) and myKeyFile.pub (the public key) in the .ssh directory
3. To authenticate your connection over SSH to your jenkins-agent-vm machine it will need the public key of your key pair. We can do this by adding the public key file to the jenkins-agent-vm. But first we will need to retrieve the contents of your public key file. In your terminal run the following command:
   ```
   cat ~/.ssh/myKeyFile.pub
   ```
   This will output the contents of the public key file into the terminal. Copy the entire contents of the file from `ssh-rsa` to `testUser` inclusive.
   Type `exit` to exit the VM session.

4. In `vms.tf` of the `day-1` folder, in the `jenkins_agent_vm` resource block, add the following block of code to add the copied SSH key onto the jenkins-agent-vm. This will allow SSH access from the jenkins-controller-vm into the jenkins-agent-vm.
   ```
   metadata = {
       ssh-keys = "testUser:<SSH KEY HERE>"
     }
   ```
5. To add the change to the configuration in the terminal, run
   ```
   terraform plan
   ```
   You should see `0 to add, 1 change, 0 to destroy`. Where the change is the addition of the SSH key. If you're happy with the plan, run
   ```
   terraform apply
   ```
   This should add the new SSH key to the jenkins_agent_vm.
6. To test the connectivity to the jenkins-agent-vm, we first must SSH back into the jenkins-controller-vm.
   ```
   ssh -i ~/.ssh/myKeyFile testUser@<EXTERNAL_IP>
   ```
   Run the following command to test the SSH connection from our jenkins-controller-vm to our jenkins-agent-vm. Where the <INTERNAL_IP> is the internal IP of the jenkins-agent-vm.
   ```
   ssh -i ~/.ssh/myKeyFile testUser@<INTERNAL_IP>
   ```


## Configure VM2 as a permanent agent

1. Click `start using Jenkins` if you are still in the Jenkins wizard. Otherwise go to the Jenkins URL you copied.

2. Enter the your username and password you created earlier.

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

1. While logged into the agent VM as the jenkins user, cd into the .ssh directory
   ```
   cd ~/.ssh
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
1. Go to the jenkins dashboard UI in the browser (you should have noted this down earlier). Go to Manage Jenkins -> Manage Credentials. Click `(global)` and click 'Add credentials'.

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

## Troubleshooting Jenkins
### Start up script logs
When a start up script runs it automatically stores its logs in `/var/log/syslog` so that you can view the output of the script after it has run. This is very useful to debug your script if the VM is not behaving as you'd expect. To check the logs of the start up script SSH to the jenkins controller Vm
```
ssh -i ~/.ssh/myKeyFile testUser@<jenkins-controller-vm EXTERNAL_IP>
```
Then run the following command to view the logs
```
tail -f /var/log/syslog
```
This command will output the last 10 lines of the syslog file and update the output if the file changees. This is especially helpful for watching the logs of a script as it will update each time a new command is run. To view more of the syslog file at once you can run the following command
```
tail -n 50 /var/log/syslog
```
This prints out the last 50 lines of the file but does not update the output.

We haven't used `cat` to view the syslog file here as the `cat` command outputs the entire file. This syslog file is very large contains the logs for the entire start up of the VM as well as our start up script right at the end. As the relevant logs to us are at the end of the file it is much easier for us to use the `tail` command.
### Checking for another service using port 8080
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
cd /usr/share/java/
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
