resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet-1" {
  name          = "subnetwork-1"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow_external_ssh" {
  name    = "allow-external-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags   = ["allow-external-ssh"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal_ssh" {
  name    = "allow-internal-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags   = ["allow-internal-ssh"]
  source_tags = ["allow-external-ssh"]
  
}
