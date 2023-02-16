pipeline {
	agent any
	environment { // GIVE THESE VALUES
		something=""
		containerName="capstone-app";
		imageName="eu.gcr.io/playpen-95sf2g/capstone-app";
	}
	stages{
		stage('Docker Build'){
			steps{
			sh '''
			docker build -t $imageName:latest -t $imageName:build-$BUILD_NUMBER .
			'''
			}
		}
		stage('Push Images'){
			steps{
			sh '''
			docker push $imageName:latest
			docker push $imageName:build-$BUILD_NUMBER
			'''
			}
            }
        stage('Deploy container'){
			steps{
                sh '''
				ssh -i "~/.ssh/id_rsa" access_user@34.89.96.104 << EOF
				docker stop $containerName
				docker rm $containerName
				docker rmi $imageName
				docker run -d -p 8080:8080 --name $containerName $imageName
                '''
				//                
			    
                }
		}
	}
}