resource "google_compute_instance_group" "webservers" {
  name = "python-webservers"
  zone = "${var.region}-b"

  instances = [
    var.webserver_1_id,
    var.webserver_2_id,
  ]

  named_port {
    name = "http"
    port = "80"
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

resource "google_compute_health_check" "healthcheck" {
  name                = "http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  unhealthy_threshold = 10
  http_health_check {
    port = 80
  }
}
