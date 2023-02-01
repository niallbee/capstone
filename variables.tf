variable "project_id" {
  description = "The ID of the GCP project where resources will be deployed"
  type        = string
  default     = "playpen-4rj1sn"
}

variable "region" {
  description = "The default GCP region to deploy resources to"
  type        = string
  default     = "europe-west2"
}