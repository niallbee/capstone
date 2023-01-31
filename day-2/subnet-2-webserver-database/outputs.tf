# See https://www.terraform.io/language/values/outputs

output "webserver_ip" {
  value = google_compute_instance.webserver.network_interface.0.access_config.0.nat_ip
}

output "database_ip" {
  value = google_sql_database_instance.postgres.public_ip_address
}