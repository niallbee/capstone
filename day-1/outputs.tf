output "jenkins_agent_ip" {
  value = google_compute_instance.jenkins_agent_vm.network_interface.0.network_ip
}

output "jenkins_controller_ip" {
  value = google_compute_instance.jenkins_controller_vm.network_interface.0.access_config.0.nat_ip
}
