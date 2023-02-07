## Overview
This guide will take you through the steps to:

- Create a Jenkins pipeline

That will do the following steps.

On the agent machine:

- Checkout and clone the python app repo
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


3. Now we should be able to authenticate with GitHub which should allow us to clone the repo. Replace the stage that is already in your pipeline with our first stage 'checkout and clone python app repo'. To clone the repo, we use the Jenkins Git step. The git step performas a clone from a specified repository, using the pat credential we just generated. In this case, we use the GitHub pat as our credentials, we checkout the capstone project repo, to the specific branch feature/capstone_solution.

---------------- Do I need to install the GitHub plugin here?? ----------------

For more information: https://www.jenkins.io/doc/pipeline/steps/git/

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

## Creating a docker image
The next steps require Docker as we will need to build and use Docker images.

1. Install the Docker Pipeline plugin in jenkins dashboard.
- Go to Jenkins dashboard -> Manage Jenkins -> Manage Plugins -> Available plugins -> type docker pipeline and install without restart.

For more information: https://www.jenkins.io/doc/book/pipeline/docker/

2. Enable Container Registry in the GCP console

2. Now that the docker plugin is installed, the next step is to build the image from the Dockerfile. The Docker Pipeline plugin provides a `build()` method for creating a new image, from a Dockerfile in the repository, during a pipeline run.

The `build()` method takes some paramteres, in this case we will supply the imageName:imageTag and the location of the Dockerfile. The location of the Dockerfile has to be specified the Dockerfile in the current repository is used by default, however our Dockerfile isn't there - it's in the flask-example-cicd folder.

In the build method, state the name of the image and a tag (e.g., `flask-web-app:1.0`) and where the Dockerfile is (`./flask-example-cicd/`). Create a new stage that builds the Dockerfile.

One major benefit of using the syntax `docker.build("my-image-name")` is that a Pipeline can use the return value for subsequent Docker Pipeline calls. As we want to build an image now and push that image in a later step, lets assign the return value to `dockerImage`.

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
                    dockerImage = docker.build("flask-web-app:1.0", "./flask-example-cicd/")
                }
            }
        }
    }
}
```
## Authenticating with GCP
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

4. Now that the service key is managed in a Jenkins credential, we can use it in the pipeline to authenticate with GCP. Jenkins offers a `withCredentials:` binding plugin which binds credentials to variables. This means that we can use the service key in our shell command by assigning it to a variable, in this case, it's assigned to 'GC_KEY' where the ID of the JSON file is gcp-json-secret-file.

```
withCredentials([file(credentialsId: 'gcp-json-secret-file', variable: 'GC_KEY')]) {}
```

For more information: https://www.jenkins.io/doc/pipeline/steps/credentials-binding/

5. Inside of the curly brackets of the `withCredentials`, add a shell script that activates the service account using the JSON key variable. The shells script is run inside the jenkins agent vm.
```
gcloud auth activate-service-account --key-file=${GC_KEY}
```

6. Next, the agent vm needs to authenticate with Docker. As Docker will be used to push the image to GCR.

`gcloud auth configure-docker` adds the Docker credHelper entry to Docker's configuration file, or creates the file if it doesn't exist. This will register gcloud as the credential helper for all Google-supported Docker registries. The following line configures docker authentication with GCR.

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

Add the following line to tag your image appropriately.

```
docker tag flask-web-app:1.0 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
```

For more information: https://cloud.google.com/container-registry/docs/pushing-and-pulling

8. Now that the image has been tagged correctly, it can be pushed to GCR from the agent vm. As we are still inside a shell script running in the agent vm, we can simply run `docker push imageName:imageTag.`

```
docker push eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
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

                    docker tag flask-web-app:1.0 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0

                    docker push eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                    """
                    }
                }
            }
        }
    }
}

```
------------ DOES THE VM NEED THE SERVICE ACCOUNT ATTACHED?? -----------
10. If you now check in Container Registry in the GCP console, you should see your pushed image.

## Pulling the image from GCR from the webserver-vm
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

Copy the output. Open `vms.tf` in VS Code and add the following block of code to each webserver-vm, pasting the copied public key into KEY_FILE_HERE
```
metadata = {
    ssh-keys = "jenkins:KEY_FILE_HERE"
  }
```

4. Add the private key as a jenkins credential. Only private key base credentials can be used for SSH in Jenkins.
```
cat webserver-key
```

Go to Jenkins dashboard -> Manage Jenkins -> Manage Credentials -> Global -> Add Credentials of kind "SSH username with private key". Give the file a relevant ID and description. Add `jenkins` as the username and enter the private key directly.

5. The webservers need to be assigned the GCP service account to be able to pull from GCR. In `/day-2/webserver/webserver.tf`, add the following resource block
```
data "google_service_account" "default" {
  account_id = "SERVICE_ACCOUNT_KEY_ID_HERE"
}
```

The SERVICE_ACCOUNT_KEY_ID can be found in GCP by going to Service Accounts -> Copy the Key ID of the only service account and past it into the terraform. This block gets the service account of our project. This can then be assigned to our webserver vms by adding the following block of code into the file `/day-2/webserver/webserver.tf`, in the `google_compute_instance.webserver` resource block. The argument `allow_stopping_for_update` allows Terraform to stop the instance to update its properties, as the instance must be stopped to update the service account.

```
service_account {
    email = data.google_service_account.default.email
    scopes = ["cloud-platform"]

  }
  allow_stopping_for_update = true
```

5. Now that the agent and vms have setup SSH ability, the jenkins pipeline needs SSH ability. Install the SSH Agent Plugin in Jenkins. This plugin allows you to provide SSH credentials to builds via a ssh-agent. This plugin we will be using later.
- Go to the Jenkins dashboard -> Manage Jenkins -> Manage Plugins -> Available plugins -> type SSH Agent Plugin and install without restart.

For more information: https://plugins.jenkins.io/ssh-agent/

6. To use the ssh-agent in Jenkins, we use `sshagent(credentials: [ssh-webserver-key ])`. This configures the build to use the webservers private SSH key for future ssh commands, allowing a future ssh command to succesfully connect to the webserver-vms.
```
sshagent (credentials: ['webserver-ssh-key']){

}
```

7. Inside of the curly brackets of the sshagent block, we can add any shell commands that need to run on the webserver vm. The next step towards running the image on the webserver, is to SSH to the webserver vm from the agent VM. Inside of the curly brackets, add the following shell commands.
```
sh """
    ssh jenkins@WEBSERVER_1_INTERNAL_IP -i /home/jenkins/.ssh/webserver-key <<EOF
    hostname
"""
```

This first SSH onto the first webserver using it's internal IP and the generated key pair in /home/jenkins/.ssh/webserver-key. The << EOF breaks the SSH connection when there are no more shell commands to run. The next line `hostname` should display the name of the current host, in this case, it should display the webserver vm name.

8. Now that we have SSH connection the the webserver-vm, the next step is to pull the image from GCR. Since we have a database that we want to use, we will need to pass in the database variables in our `docker run` command. The following values are required: database username, database password, database IP.

In the GCP console, type SQL in the search bar and click on the database `capstone-postgres-instance`. You should be able to see the private IP address. Note this.

On the left hand side, click the Users tab. Click Add User Account and enter a username. Note this username. Enter a password. Note this password.

9. Go to the Jenkins dashboard UI.

For the database IP, username, and password, create 3 separate jenkins credentials.

- Go to Jenkins dashboard -> Manage Jenkins -> Manage Credentials -> Global -> Add Credentials of kind "Secret Text". Click Create. Add your database password OR database IP OR database password in the Secret input. Assign an appropriate ID, e.g., dp-ip, db-username, db-password.

You should now have 3 credentials specificying the database username, password, and IP.

8.  Now that the database credentials are in Jenkins and can be used in the pipeline, the image in GCR can now be pulled and ran. Inside the `sh"""` block and after the `hostname` command, add the following 2 lines
```
    sudo docker pull eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
    sudo docker run --rm -d -p 8080:8080/tcp -e 'DB_IP=${DB_IP}' -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
```

The first command pulls the image we originally pushed to GCR. The specific image name is required here. The second command is `docker run` followed by some arguments. The `-rm` flag automatically removes the container when it exits. The `-d` flag runs the container in the background and the `-p` flag publishes the containers ports to the host. In this case we have specified 8080:8080/tcp. The `-e` flags followed by the database ip, username, and password credential ID's sets the environment variables. The `-name` flag specifies what we want the name of the container to be, `flask-example-1` and finally the image name we want docker to run, `eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0`.

For more information: https://docs.docker.com/engine/reference/commandline/run/

9. Although the database credentials have been specified in the `docker run` command and they are a jenkins credential, we need to use `withCredentials` to pass in the values of the credentials. As we did before, `withCredentials` takes a jenkins credential ID and assigns it to a variable. These variables can then be used in the pipeline. Add the following line of code, encasing the sshagent command in the withCredentials command. This make the database credentials available for use in the `docker run` command.

Replace `db-ip`, `db-username`, and `db-password` with your jenkins credential ID's if you named them differently.
```
 withCredentials([string(credentialsId: 'db-ip', variable: 'DB_IP'), string(credentialsId: 'db-username', variable: 'DB_USERNAME'), string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
```

10. If you have followed the above steps correctly, your pipeline should now look like this.
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
        stage('pulling the image from GCR'){
                steps{
                    withCredentials([string(credentialsId: 'db-ip', variable: 'DB_IP'), string(credentialsId: 'db-username', variable: 'DB_USERNAME'), string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
                        sshagent (credentials: ['webserver-ssh-key']){
                            sh """
                            ssh jenkins@WEBSERVER_1_INTERNAL_IP -i /home/jenkins/.ssh/webserver-key <<EOF
                            hostname
                            sudo docker pull eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                            sudo docker run --rm -d -p 8080:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                            """
                        }
                    }
                }
        }
    }
}
```

11. Before running this pipeline, we need to make sure the second VM has the image and is running the container. Add the following block of code into the sshagent command, after the first shell block.
```
sh """
ssh jenkins@WEBSERVER_2_INTERNAL_IP -i /home/jenkins/.ssh/webserver-key <<EOF
hostname
sudo docker pull eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
sudo docker run --rm -d -p 8080:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
"""
```

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
                    dockerimage = docker.build("eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0", "./flask-example-cicd/")
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

                    docker tag flask-web-app:1.0 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0

                    docker push eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                    """
                    }
                }
            }
        }
        stage('ssh connection'){
                steps{
                    withCredentials([file(credentialsId: 'gcp-json-secret-file', variable: 'GC_KEY'), string(credentialsId: 'db-ip', variable: 'DB_IP'), string(credentialsId: 'db-username', variable: 'DB_USERNAME'), string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
                        sshagent (credentials: ['webserver-ssh-key']){
                            sh """
                            ssh jenkins@10.0.1.2 -i /home/jenkins/.ssh/webserver-key <<EOF
                            hostname
                            sudo docker pull eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                            sudo docker run --rm -d -p 8080:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                            """

                            sh """
                            ssh jenkins@10.0.1.3 -i /home/jenkins/.ssh/webserver-key <<EOF
                            hostname
                            sudo docker pull eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                            sudo docker run --rm -d -p 8080:8080/tcp -e 'DB_IP=${DB_IP}'  -e 'DB_USERNAME=${DB_USERNAME}' -e 'DB_PASSWORD=${DB_PASSWORD}' --name flask-example-1 eu.gcr.io/playpen-v3w3cn/flask-web-app:1.0
                            """
                        }
                    }
                }
        }
    }
}
```




2. These VMs will eventually run our python application, requiring them to have the service account assigned. Enable the Identity and Access Management (IAM) API in the GCP console.
Insert the following line in the `google_compute_instance` resource block in `webserver.tf` in the `day-2/webserver` folder.
```
service_account {
    email = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]

  }
```

data "google_compute_default_service_account" "default" {
}
