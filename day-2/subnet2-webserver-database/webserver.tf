resource "google_compute_address" "webserver_ip" {
  name   = "webserver-ip"
  region = "europe-west2"
}

resource "google_compute_instance" "webserver" {
  name         = "python-web-server"
  machine_type = "e2-small"
  zone         = "europe-west2-b"

  tags         = ["allow-http"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = data.google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet_2.name
    access_config {
      nat_ip = google_compute_address.webserver_ip.address
    }
  }

  metadata_startup_script = templatefile("./application_script.sh", {db_ip = google_sql_database_instance.postgres.public_ip_address, db_username = google_sql_user.user.name, db_password = random_password.db_password.result})

  depends_on = [
    google_sql_database_instance.postgres,
    google_sql_user.user
  ]
}
