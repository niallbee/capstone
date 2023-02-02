terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0.0"
    }
  }

    cloud {
    organization = "lbg-cloud-platform"

    workspaces {
            name = "<YOUR WORKSPACE HERE>"
        }
    }   
}

provider "google" {
  project = var.project_id
}