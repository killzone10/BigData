provider "google" {
  project = local.project
  region  = var.region
  user_project_override = true
}
terraform {
  required_providers {
    google = {
      version = "~> 4.8.0"
    }
  }
}