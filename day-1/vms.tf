// External SSH enabled
resource "google_compute_instance" "jenkins_controller_vm" {
  name         = "jenkins-controller-vm"
  machine_type = "e2-small"
  zone         = "${var.region}-b"

  tags = ["allow-external-ssh", "allow-http"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network    = var.vpc_name
    subnetwork = var.subnet_name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "testUser:KEY FILE HERE"
  }
  metadata_startup_script = file("./jenkins_java_script.sh")
}


// SSH enabled to receive connections only from VM1
resource "google_compute_instance" "jenkins_agent_vm" {
  name         = "jenkins-agent-vm"
  machine_type = "e2-small"
  zone         = "${var.region}-b"

  tags = ["allow-internal-ssh"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network    = var.vpc_name
    subnetwork = var.subnet_name
    access_config {
      // Ephemeral public IP
    }
  }
  metadata = {
    ssh-keys = "testUser:KEY FILE HERE"
  }
}
