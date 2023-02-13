## Overview
This guide will take you through the steps to:

- Create a Jenkins pipeline

That will do the following steps.

On the agent machine:

- Checkout and clone the python app repo
   - URL: https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project
    - Branch: feature/capstone_solution
- Build the python app image using docker
- Authenticate with GCP
- Push the docker image to Google Container Registry (GCR)

On the webserver vm:

- Pull docker image from GCR
- Run with image the credentials from the DB

## Getting Started
Before following this guide, please make sure that you have followed all the previous guides. You should have 1 jenkins controller with 1 permanent slave agent. The pipeline we will create a Jenkins pipeline that will run on the jenkins agent.

## Creating a new Jenkins pipeline
1. In the web browser where you have your Jenkins dashboard UI open, click New Item

2. Enter the name `jenkins-pipeline` and select Pipeline as the item type

3. You have now created a new empty pipeline. Let's create a basic pipeline that runs `hello world` on our agent vm. Scroll down to Pipeline section, make sure the definition is Pipeline script, and paste the following code block into the pipeline. This pipeline has 1 stage, with 1 step that will echo "hello world".
```
pipeline {
    agent any
    stages {
        stage('Stage 1') {
            steps {
                echo 'Hello world!'
            }
        }
    }
}
```

4. Build Now and see that it passes.

## Checking out and cloning the python app repo
To authenticate with GitHub, a personal access token (PAT) is needed. PAT are an alternative to using passwords for authentication when using the command line.

1. Create a PAT token
    1. https://github.com/lbg-cloud-platform/playpen-incubationlab-jenkins/blob/main/github-token/README.md

2. Add it as a Jenkins credential. Go to the jenkins dashboard -> Manage Jenkins -> Manage Credentials -> Global -> Add credentials
Copy steps 5 to 7 in this guide: https://github.com/lbg-cloud-platform/playpen-incubationlab-jenkins/tree/main/Build%20Labs/build-lab-2-freestyle_job


3. Now we should be able to authenticate with GitHub which should allow us to clone the repo. Replace the stage that is already in your pipeline with our new first stage 'checkout and clone python app repo'. To clone the repo, we use the Jenkins Git step. The git step performs a clone from a specified repository, using the pat credential we just generated. In this case, we use the GitHub pat as our credentials, we checkout the capstone project repo, to the specific branch feature/capstone_solution.

For more information: https://www.jenkins.io/doc/pipeline/steps/git/
```
pipeline {
    agent any
    stages {
        stage('checkout and clone python app repo') {
            steps {
                git credentialsId: 'github-pat', branch: 'feature/capstone_solution', url: 'https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project'
            }
        }
    }
}
```

4. Build Now and see that it passes.

## Creating a docker image
The next steps require Docker as we will need to build and use Docker images.

1. Install the Docker Pipeline plugin in jenkins dashboard.
- Go to Jenkins dashboard -> Manage Jenkins -> Manage Plugins -> Available plugins -> type docker pipeline and install without restart.

For more information: https://www.jenkins.io/doc/book/pipeline/docker/

2. Enable Container Registry in the GCP console

3. In the Jenkins pipeline, add a new stage called `build docker image`, containing a steps and script block.
```
stage('build docker image') {
            steps{
                script{
                }
            }
        }
```

4. Now that the docker plugin is installed, the next step is to build the image from the Dockerfile. The Docker Pipeline plugin provides a `build()` method for creating a new image, from a Dockerfile in the repository, during a pipeline run.

The `build()` method takes some parameters, in this case we will supply the imageName:imageTag and the location of the Dockerfile. The location of the Dockerfile has to be specified the Dockerfile in the current repository is used by default, however our Dockerfile isn't there - it's in the flask-example-cicd folder.

In the build method, state the name of the image and a tag (e.g., `flask-web-app:1.0`) and where the Dockerfile is (`./flask-example-cicd/`). Create a new stage that builds the Dockerfile.

One major benefit of using the syntax `docker.build("my-image-name")` is that a Pipeline can use the return value for subsequent Docker Pipeline calls. As we want to build an image now and push that image in a later step, lets assign the return value to `dockerImage`.

The line `sh "sudo chmod 666 /var/run/docker.sock"` changes the permissions for that file to anyone, as our pipeline needs access to it to run docker commands.

The line `docker images` will show that the image has been created with the given image name and tag along with the base image. You will be able to view this in the console output.

```
pipeline {
    agent any
    stages {
        stage('checkout and clone python app repo') {
            steps {
                ...
            }
        }

        stage('build docker image') {
            steps{
                script{
                    sh "sudo chmod 666 /var/run/docker.sock"
                    dockerImage = docker.build("flask-web-app:1.0", "./flask-example-cicd/")
                    sh "docker images"
                }
            }
        }
    }
}
```

4. Build Now and see that it passes.

## Authenticating with GCP and pushing the docker image to GCR
So far, you should have checked out and clone the python app repo, then created an image using the Dockerfile in that repo. The next step is to authenticate with GCP so that we can push the built image to Google Container Registry (GCR). This is required as for the webserver-vm to run the image, it needs to get it from somewhere. GCR is a google service that lets you store, manage, and secure your Docker container images. If we push to GCR from our jenkins agent, then the webserver-vm will be able to pull from GCR and run it.

1. Install google compute engine plugin in Jenkins. This plugin is responsible to communicate with GCP.

- Go to Jenkins dashboard -> Manage Jenkins -> Manage Plugins -> Available plugins -> type Google Compute Engine Plugin and install without restart.

2. In order for Jenkins to authenticate with GCP, a service account key is required. Create a new service account key and download the JSON file.

- Go to the Google Cloud Console, go to Service Accounts page

- Click the email address of the service account

- Go to the Keys tab

- Click Add Key, then select Create new key

- Select JSON as the Key type and click Create

-  Clicking create downloads a service account key file. Note where it has been downloaded in your file system.

For more information: https://cloud.google.com/iam/docs/creating-managing-service-account-keys

3. In order for Jenkins to authenticate with GCP, it's required to add the service account key to the Credentials section in Jenkins.

- Go to Jenkins dashboard -> Manage Jenkins -> Manage Credentials -> Global -> Add Credentials of kind "Secret File". Give the file a relevant ID and description and upload the downloaded JSON file. Click Create.

4. Create a new stage called `push image to GCR`, containing a steps block and a script block.
```
stage('push image to GCR'){
            steps{
                script{

                }
            }
        }
```

5. Now that the service key is managed in a Jenkins credential, we can use it in the pipeline to authenticate with GCP. Jenkins offers a `withCredentials:` binding plugin which binds credentials to variables. This means that we can use the service key in our shell command by assigning it to a variable, in this case, it's assigned to 'GC_KEY' where the ID of the JSON file is gcp-json-secret-file. Inside of the script{} brackets, add the following line.

```
withCredentials([file(credentialsId: 'gcp-json-secret-file', variable: 'GC_KEY')]) {}
```

For more information: https://www.jenkins.io/doc/pipeline/steps/credentials-binding/

5. Inside of the curly brackets of the `withCredentials`, add a shell script that activates the service account using the JSON key variable. The shell script is run inside the jenkins agent vm.
```
sh """
gcloud auth activate-service-account --key-file=${GC_KEY}
"""
```

6. Next, the agent vm needs to authenticate with Docker. As Docker will be used to push the image to GCR.

`gcloud auth configure-docker` adds the Docker credHelper entry to Docker's configuration file, or creates the file if it doesn't exist. This will register gcloud as the credential helper for all Google-supported Docker registries. The following line configures docker authentication with GCR. Still inside of the shell command, add the following line.

```
gcloud auth configure-docker eu.gcr.io
```

7. Now that the agent has authenticated with GCP, and configured docker to authenticate with GCR, the agent can push the image to GCR.

GCP is very specific about the name of the image being pushed, so it needs to be tagged. It must combine the hostname, project-id, and target image name.

Consider the following example:

- Hostname: gcr.io
- Google Cloud project: my-project
- Target image name: web-site

Combining the hostname, project, and target image name gives you the full image path to use for tagging: `gcr.io/my-project/web-site`.

Add the following line to tag your image appropriately (still inside of the shell command).

```
docker tag flask-web-app:1.0 eu.gcr.io/PROJECT-ID/flask-web-app:1.0
```

For more information: https://cloud.google.com/container-registry/docs/pushing-and-pulling

8. Now that the image has been tagged correctly, it can be pushed to GCR from the agent vm. As we are still inside a shell script running in the agent vm, we can simply run `docker push imageName:imageTag.`

```
docker push eu.gcr.io/PROJECT-ID/flask-web-app:1.0
```

9. If you have followed all the above steps correctly, your pipeline should look like this so far.
```
pipeline {
    agent any
    stages {
        stage('checkout and clone python app repo') {
            ...
        }

        stage('build docker image') {
            ...
        }

        stage('push image to GCR'){
            steps{
                script{
                    withCredentials([file(credentialsId: 'gcp-json-secret-file', variable: 'GC_KEY')]) {

                    sh """
                    gcloud auth activate-service-account --key-file=${GC_KEY}
                    gcloud auth configure-docker eu.gcr.io

                    docker tag flask-web-app:1.0 eu.gcr.io/PROJECT-ID/flask-web-app:1.0

                    docker push eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                    """
                    }
                }
            }
        }
    }
}

```
10. Build Now and see that it passes. If you now check in Container Registry in the GCP console, you should see your pushed image.


## Pulling the image from GCR to the webserver vms: SSH connection
The image should now successfully be stored in GCR. The next step is to pull it onto the webserver-vm. To be able to do this, first we need to SSH to it. This requires a few steps.

1. First, SSH into the jenkins controller vm, then the jenkins agent vm, then change to the jenkins user.
```
ssh -i ~/.ssh/myKeyFile testUser@<controllerExternalIP>
ssh -i ~/.ssh/myKeyFile testUser@<agentInternalIP>
su jenkins
```

2. On the jenkins agent, remember the jenkins user we created in a previous guide. This user needs to be given SSH permission. Go into the SSH config file
```
sudo vi /etc/ssh/sshd_config
```
and add the following line
```
AllowUsers jenkins
```

Then type `:wq` to save and exit the file

This grants SSH permissions to the jenkins user

2. For all SSH connections, an SSH key pair needs to be generated. This is the same method we have used for all other SSH key pairs. While still logged in as the jenkins user in the jenkins agent vm, run the following commands to create a new key pair
```
cd /home/jenkins/.ssh/
ssh-keygen -t rsa -f webserver-key -C jenkins -b 2048
```

3. Add the public key to both webserver-vms in Terraform.

```
cat webserver-key.pub
```

Copy the output. Open `day-2/webserver/webserver.tf` in VS Code and add the following block of code into the webserver-vm instance, pasting the copied public key into KEY_FILE_HERE
```
metadata = {
    ssh-keys = "jenkins:KEY_FILE_HERE"
  }
```

4. Add the private key as a jenkins credential. Only private key base credentials can be used for SSH in Jenkins.
```
cat webserver-key
```

Go to Jenkins dashboard -> Manage Jenkins -> Manage Credentials -> Global -> Add Credentials of kind "SSH username with private key". Give the file a relevant ID (e.g., webserver-ssh-key) and description. Add `jenkins` as the username and enter the private key directly.


5. These VMs will eventually run our python application, requiring them to have the service account assigned. Enable the Identity and Access Management (IAM) API in the GCP console.
Add a new data block at the top of the file. This gets the service account for the project that has the email `PROJECT-ID-sa@PROJECT-ID.iam.gserviceaccount.com`, where PROJECT-ID is the ID of your GCP project. E.g., your project ID is playpen-a1b2cd, then the email would be playpen-a1b2cd-sa@playpen-a1b2cd.iam.gserviceaccount.com
```
data "google_service_account" "default" {
  account_id = "PROJECT-ID-sa@PROJECT-ID.iam.gserviceaccount.com"
}
```

Insert the following line in the `google_compute_instance` resource block in `webserver.tf` in the `day-2/webserver` folder. This assigns the service account to the webserver vms.
```
service_account {
    email = data.google_service_account.default.email
    scopes = ["cloud-platform"]

  }
```

6. In addition to the above changes required to the webserver vms, we need to change the NGINX start-up script. NGINX is currently running and will prevent the python image from running on the webservers as the address is already in use. In `nginx_startup.sh`, comment out or delete the final line `sudo docker run --name mynginx1 -p 80:80 -d nginx`.


7. To update GCP with the new webserver SSH-key, assigned service account, and new start up script, run
```
terraform plan
terraform apply
```
This should destroy and recreate the webserver vms. If not, please delete the webserver vms and recreate with the new changes.

8. Now that the webserver-vms have been redeployed with the SSH key, attempt to SSH to both the webservers to confirm the connection works.
```
ssh -i ~/.ssh/myKeyFile testUser@<CONTROLLER_EXTERNAL_IP>
ssh -i ~/.ssh/myKeyFile testUser@<AGENT_INTERNAL_IP>

ssh jenkins@<WEBSERVER1_INTERNAL_IP> -i /home/jenkins/.ssh/webserver-key
exit
ssh jenkins@<WEBSERVER2_INTERNAL_IP> -i /home/jenkins/.ssh/webserver-key
```

9. Now that the agent and vms have setup SSH ability, the jenkins pipeline needs SSH ability. Install the SSH Agent Plugin in Jenkins. This plugin allows you to provide SSH credentials to builds via a ssh-agent. This plugin we will be using later.
- Go to the Jenkins dashboard -> Manage Jenkins -> Manage Plugins -> Available plugins -> type SSH Agent Plugin and install without restart.

For more information: https://plugins.jenkins.io/ssh-agent/

10. Configure the jenkins pipeline to have a new stage called `pull image from GCR to the webserver and run`. Inside this stage, add a steps block. To use the ssh-agent in Jenkins, we use `sshagent(credentials: [ssh-webserver-key ])`. This configures the build to use the webservers private SSH key for future ssh commands, allowing a future ssh command to successfully connect to the webserver-vms.
```
stage('pull image from GCR to the webserver and run'){
   steps{
     sshagent (credentials: ['webserver-ssh-key']){
     }
   }
}
```

11. Inside of the curly brackets of the sshagent block, we can add any shell commands that need to run on the webserver vm. The next step towards running the image on the webserver, is to SSH to the webserver vm from the agent VM. Inside of the curly brackets, add the following shell commands.
```
sh """
    ssh jenkins@WEBSERVER_1_INTERNAL_IP -i /home/jenkins/.ssh/webserver-key <<EOF
    hostname
"""
```

This first SSH onto the first webserver using it's internal IP and the generated key pair in /home/jenkins/.ssh/webserver-key. The << EOF breaks the SSH connection when there are no more shell commands to run. The next line `hostname` should display the name of the current host, in this case, it should display the webserver vm name.

11. Build Now and see that it passes.
## Pulling the image from GCR to the webserver vms: Docker pull

1. Now that we have SSH connection the the webserver-vm, the next step is to pull the image from GCR. Since we have a database that we want to use, we will need to pass in the database variables in our `docker run` command. The following values are required: database username, database password, database IP.

In the GCP console, type SQL in the search bar and click on the database `capstone-postgres-instance`. You should be able to see the private IP address. Note this.

On the left hand side, click the Users tab. Click Add User Account and enter a username. Note this username. Enter a password. Note this password.

2. Go to the Jenkins dashboard UI.

For the database IP, username, and password, create 3 separate jenkins Secret Text credentials.

- Go to Jenkins dashboard -> Manage Jenkins -> Manage Credentials -> Global -> Add Credentials of kind "Secret Text". Click Create. Add your database password OR database IP OR database password in the Secret input. Assign an appropriate ID, e.g., dp-ip, db-username, db-password.

You should now have 3 credentials specifying the database username, password, and IP.

3.  Now that the database credentials are in Jenkins and can be used in the pipeline, the image in GCR can now be pulled and ran. Inside the `sh"""` block and after the `hostname` command, add the following 2 lines
```
    gcloud auth configure-docker eu.gcr.io -q
    sudo docker pull eu.gcr.io/PROJECT-ID/flask-web-app:1.0
    sudo docker run --rm -d -p 80:8080/tcp -e 'DB_IP=${DB_IP}' -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/PROJECT-ID/flask-web-app:1.0
```

The first command configures our docker setup. The second pulls the image we originally pushed to GCR. The specific image name is required here. The second command is `docker run` followed by some arguments. The `-rm` flag automatically removes the container when it exits. The `-d` flag runs the container in the background and the `-p` flag publishes the containers ports to the host. In this case we have specified 8080:8080/tcp. The `-e` flags followed by the database ip, username, and password credential ID's sets the environment variables. The `-name` flag specifies what we want the name of the container to be, `flask-example-1` and finally the image name we want docker to run, `eu.gcr.io/PROJECT-ID/flask-web-app:1.0`.

For more information: https://docs.docker.com/engine/reference/commandline/run/

4. Although the database credentials have been specified in the `docker run` command and they are a jenkins credential, we need to use `withCredentials` to pass in the values of the credentials. As we did before, `withCredentials` takes a jenkins credential ID and assigns it to a variable. These variables can then be used in the pipeline. Add the following line of code, encasing the sshagent command in the withCredentials command. This make the database credentials available for use in the `docker run` command.

Replace `db-ip`, `db-username`, and `db-password` with your jenkins credential ID's if you named them differently.
```
 withCredentials([string(credentialsId: 'db-ip', variable: 'DB_IP'), string(credentialsId: 'db-username', variable: 'DB_USERNAME'), string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
```

5. If you have followed the above steps correctly, your pipeline should now look like this.
```
pipeline {
    agent any
    stages {
        stage('checkout and clone python app repo') {
            ...
        }

        stage('build docker image') {
            ...
        }
        stage('push image to GCR'){
            ...
        }
        stage('pull image from GCR to the webserver and run'){
                steps{
                    withCredentials([string(credentialsId: 'db-ip', variable: 'DB_IP'), string(credentialsId: 'db-username', variable: 'DB_USERNAME'), string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
                        sshagent (credentials: ['webserver-ssh-key']){
                            sh """
                            ssh jenkins@<WEBSERVER-1-IP> -i /home/jenkins/.ssh/webserver-key <<EOF
                            hostname
                            gcloud auth configure-docker eu.gcr.io -q
                            sudo docker pull eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                            sudo docker run --rm -d -p 80:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                            """
                        }
                    }
                }
        }
    }
}
```

6. Before running this pipeline, we need to make sure the second VM has the image and is running the container. Add the following block of code into the sshagent command, after the first shell block.
```
sh """
ssh jenkins@<WEBSERVER-2-IP> -i /home/jenkins/.ssh/webserver-key <<EOF
hostname
gcloud auth configure-docker eu.gcr.io -q
sudo docker pull eu.gcr.io/PROJECT-ID/flask-web-app:1.0
sudo docker run --rm -d -p 80:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/PROJECT-ID/flask-web-app:1.0
"""
```
7. Build Now and see that it passes.


## Final pipeline
If you have followed this guide correctly, your pipeline should now look like this.
```
pipeline {
    agent any
    stages {
        stage('checkout and clone python app repo') {
            steps {
                git credentialsId: 'github-pat', branch: 'feature/capstone_solution', url: 'https://github.com/lbg-cloud-platform/playpen-incubationlab-capstone-project'
                sh "ls -lart ./*"
            }
        }

        stage('build docker image') {
            steps{
                script{
                    sh "sudo chmod 666 /var/run/docker.sock"
                    dockerimage = docker.build("flask-web-app:1.0", "./flask-example-cicd/")
                    sh "docker images"
                }
            }
        }
        stage('push image to GCR'){
            steps{
                script{
                    withCredentials([file(credentialsId: 'gcp-json-secret-file', variable: 'GC_KEY')]) {

                    sh """
                    gcloud auth activate-service-account --key-file=${GC_KEY}
                    gcloud auth configure-docker eu.gcr.io

                    docker tag flask-web-app:1.0 eu.gcr.io/PROJECT-ID/flask-web-app:1.0

                    docker push eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                    """
                    }
                }
            }
        }
        stage('pull image from GCR to the webserver and run'){
                steps{
                    withCredentials([file(credentialsId: 'gcp-json-secret-file', variable: 'GC_KEY'), string(credentialsId: 'db-ip', variable: 'DB_IP'), string(credentialsId: 'db-username', variable: 'DB_USERNAME'), string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
                        sshagent (credentials: ['webserver-ssh-key']){
                            sh """
                            ssh jenkins@WEBSERVER-1-IP -i /home/jenkins/.ssh/webserver-key <<EOF
                            hostname
                            gcloud auth configure-docker eu.gcr.io -q
                            sudo docker pull eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                            sudo docker run --rm -d -p 80:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                            """

                            sh """
                            ssh jenkins@WEBSERVER-2-IP -i /home/jenkins/.ssh/webserver-key <<EOF
                            hostname
                            gcloud auth configure-docker eu.gcr.io -q
                            sudo docker pull eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                            sudo docker run --rm -d -p 80:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/PROJECT-ID/flask-web-app:1.0
                            """
                        }
                    }
                }
        }
    }
}
```
## Viewing the webpage
If you have followed the above steps correctly, the python image in the GitHub repo should have been checked out and cloned by the agent vm. The agent should have then create a docker image using the Dockerfile from the cloned files. This image should then have been pushed to GCR. The agent should have then SSH to each webserver in order to pull the image from GCR and use docker to run the image in a container.

1. To view the final webpage, go to the GCP console. Go to Load Balancing -> url-map -> copy the IP:Port and past it into the browser. You should now be able to see the python app!
