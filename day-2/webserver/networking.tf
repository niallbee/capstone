
# NAT routing for private VMs
resource "google_compute_address" "nat_ip" {
  name   = "nat-ip"
  region = "europe-west2"
}

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = var.vpc_id
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
    name                    = var.subnet_2_id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  depends_on = [
    google_compute_address.nat_ip
  ]
}

# Create private connection for database
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_id
}

resource "google_service_networking_connection" "private_db_connector" {
  network                 = var.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}