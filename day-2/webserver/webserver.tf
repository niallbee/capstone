data "google_service_account" "default" {
  account_id = "PROJECT-ID-sa@pPROJECT-ID.iam.gserviceaccount.com"
}

resource "google_compute_instance" "webserver" {
  count        = 2
  name         = "python-web-server-${count.index}"
  machine_type = "e2-small"
  zone         = "${var.region}-b"

  tags = ["allow-health-check","allow-internal-ssh-target"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = var.vpc_name
    subnetwork = var.subnet_2_name
  }

  service_account {
    email = data.google_service_account.default.email
    scopes = ["cloud-platform"]

  }

  metadata_startup_script = file("./day-2/webserver/nginx_startup.sh")
  metadata = {
    ssh-keys = "jenkins:JENKINS KEY HERE"
  }

}
