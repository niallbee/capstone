resource "google_compute_instance" "webserver" {
  count        = 2
  name         = "python-web-server-${count.index}"
  machine_type = "e2-small"
  zone         = "${var.region}-b"

  tags = ["allow-http", "allow-health-check"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = var.vpc_name
    subnetwork = var.subnet_2_name
  }

  metadata_startup_script = file("./nginx_startup.sh")

}
