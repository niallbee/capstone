resource "google_compute_subnetwork" "subnet_2" {
  name          = "webserver-subnetwork"
  purpose       = "PRIVATE"
  ip_cidr_range = "10.0.1.0/24"
  region        = "europe-west2"
  network       = data.google_compute_network.vpc_network.id
}



resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = data.google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8080", "80"]
  }
  source_ranges = [google_compute_subnetwork.subnet_2.ip_cidr_range]
}

resource "google_compute_firewall" "default" {
  name          = "fw-allow-health-check"
  direction     = "INGRESS"
  network       = data.google_compute_network.vpc_network.name
  priority      = 1000
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-health-check"]
  allow {
    ports    = ["8080"]
    protocol = "tcp"
  }
}


resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_db_connector" {
  network                 = data.google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}


resource "google_compute_address" "nat_ip" {
  name   = "nat-ip"
  region = "europe-west2"
}

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = data.google_compute_network.vpc_network.id
  region  = "europe-west2"
}

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.subnet_2.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  depends_on = [
    google_compute_address.nat_ip
  ]
}