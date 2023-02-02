module "jenkins" {
  source = "./day-1"
  vpc_name = google_compute_network.vpc_network.name
  subnet_name = google_compute_subnetwork.subnet_1.name
  region = var.region
}

module "web_application" {
  source = "./day-2/webserver"
  vpc_id = google_compute_network.vpc_network.id
  vpc_name = google_compute_network.vpc_network.name
  subnet_2_name = google_compute_subnetwork.subnet_2.name
  subnet_2_id = google_compute_subnetwork.subnet_2.id
  region = var.region
}

module "load_balancer" {
    source = "./day-2/load_balancer"
    webserver_1_id = module.web_application.webserver_1_id
    webserver_2_id = module.web_application.webserver_2_id
    region = var.region
}