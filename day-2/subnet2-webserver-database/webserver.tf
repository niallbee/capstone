resource "google_compute_address" "webserver_ip" {
  name   = "webserver-ip"
  region = "europe-west2"
}

resource "google_compute_instance" "webserver" {
  name         = "python-web-server"
  machine_type = "e2-small"
  zone         = "europe-west2-b"

  tags         = ["allow-ssh","allow-http"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet_2.name
    access_config {
      nat_ip = google_compute_address.webserver_ip.address
    }
  }
  metadata = {
    ssh-keys = "testUser:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkKntYUWfaapQjqLKXxufcEPkBagqV2tBs+xwJqgoBaOOAExICKRRNn8zdtMRAtlOw+n2TM6AqtrLx4ks/H90QWJVgUeSwIZc516VSHv1GwIIRc5wZIwLkHIAQono5sgaVgA0VLGMBRF0JO0RSr2Sg8Wa1TJ1r6vpC1va99DPqYV8neZ3tlSu84SdyI2W1nxAkFNfOk+5gRWUvhAH8cnlQnRlbZx0RNGRSTQ2YvPN1LfV4Cv37vYPV0ueUMdl7FIxfRCkx8EE3b7qlX0rHhFQfPGvybUtyPCpVWZfznxD2XrRn0uBylxysC7zeywaH30VB8n5HpbooNt1LuK1P3J5l testUser"
  }

  metadata_startup_script = templatefile("./application_script.sh", {db_ip = google_sql_database_instance.postgres.public_ip_address, db_username = google_sql_user.user.name, db_password = random_password.db_password.result})

  depends_on = [
    google_sql_database_instance.postgres,
    google_sql_user.user
  ]
}
