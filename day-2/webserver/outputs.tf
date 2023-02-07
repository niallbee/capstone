
output "webserver_1_id" {
  value = google_compute_instance.webserver[0].id
}

output "webserver_2_id" {
  value = google_compute_instance.webserver[1].id
}
