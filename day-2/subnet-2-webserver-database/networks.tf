resource "google_compute_subnetwork" "subnet_2" {
  name          = "webserver-subnetwork"
  ip_cidr_range = "10.0.1.0/24"
  region        = "europe-west2"
  network       = data.google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = data.google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags   = ["allow-ssh"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = data.google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  target_tags   = ["allow-http"]
  source_ranges = ["0.0.0.0/0"]
}