output "load_balancer_ip" {
  value = module.load_balancer.load_balancer_ip
}

output "jenkins_controller_ip" {
  value = module.jenkins.jenkins_controller_ip
}

output "jenkins_agent_ip" {
  value = module.jenkins.jenkins_agent_ip
}
