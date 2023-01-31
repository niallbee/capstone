resource "google_compute_instance" "webserver" {
  count        = 2
  name         = "python-web-server-${count.index}"
  machine_type = "e2-small"
  zone         = "europe-west2-b"

  tags = ["allow-http", "allow-health-check"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = data.google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet_2.name
  }

  metadata_startup_script = templatefile("./application_script.sh", { db_ip = google_sql_database_instance.postgres.private_ip_address, db_username = google_sql_user.user.name, db_password = random_password.db_password.result })


}

locals {
  webserver_1 = google_compute_instance.webserver[0]
  webserver_2 = google_compute_instance.webserver[1]
}


resource "google_compute_instance_group" "webservers" {
  name = "python-webservers"
  zone = "europe-west2-b"

  instances = [
    local.webserver_1.id,
    local.webserver_2.id,
  ]

  named_port {
    name = "http"
    port = "8080"
  }

}

resource "google_compute_health_check" "healthcheck" {
  name                = "http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  unhealthy_threshold = 10
  http_health_check {
    port = 8080
  }
}

resource "google_compute_backend_service" "webserver_backend" {
  name        = "backend-service"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10

  health_checks = [google_compute_health_check.healthcheck.id]

  backend {
    group                 = google_compute_instance_group.webservers.self_link
    balancing_mode        = "RATE"
    max_rate_per_instance = 100
  }
}