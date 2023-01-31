resource "google_sql_database_instance" "postgres" {
  name             = "capstone-postgres-instance"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = "false"
      private_network = data.google_compute_network.vpc_network.id
    }
  }
  depends_on          = [google_service_networking_connection.private_db_connector]
  deletion_protection = false
}

resource "random_password" "db_password" {
  length  = 10
  special = true
}

resource "google_sql_user" "user" {
  name     = "application-user"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}

resource "google_sql_database" "python_app" {
  name     = "application"
  instance = google_sql_database_instance.postgres.name
}
