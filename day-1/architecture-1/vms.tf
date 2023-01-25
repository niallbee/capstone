// External SSH enabled
resource "google_compute_instance" "external_vm" {
  name         = "external-vm"
  machine_type = "e2-micro"
  zone         = "${var.region}-b"

  tags = ["allow-external-ssh"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet-1.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "testUser:YOUR KEY FILE HERE"
  }
}


// SSH enabled to receive connections only from VM1
resource "google_compute_instance" "internal_vm" {
  name         = "internal-vm"
  machine_type = "e2-micro"
  zone         = "${var.region}-b"

  tags = ["allow-internal-ssh"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet-1.name
    access_config {
      // Ephemeral public IP
    }
  }
}