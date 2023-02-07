resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_service.webserver_backend.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "http-proxy"
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "web-app-forwarding-rule"
  target     = google_compute_target_http_proxy.http_proxy.self_link
  port_range = "8080"
}
