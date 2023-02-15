pipeline {
	agent any
	environment { // GIVE THESE VALUES
		something=""
		//containerName="flask-app-alpine-niall";
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
		// stage('Push Images'){
		// 	steps{
		// 	sh '''
		// 	docker push $imageName:latest
		// 	docker push $imageName:build-$BUILD_NUMBER
		// 	'''
		// 	}
        //         }
        stage('Stopping container'){
			steps{
                sh '''
                echo hi there again
                '''
			    // script {
				// 	if ("${GIT_BRANCH}" == 'origin/main') {
				// 		sh '''
				// 		ssh -i "~/.ssh/id_rsa" jenkins@34.142.90.72 << EOF
						
				// 		'''
                //         //docker rm -f $containerName
				// 	} else if ("${GIT_BRANCH}" == 'origin/development') {
				// 		sh '''
				// 		ssh -i "~/.ssh/id_rsa" jenkins@34.105.192.100 << EOF
						
				// 		'''
                //         //docker rm -f $containerName
				// 	}
				// 	}
                }
		}
	}
}