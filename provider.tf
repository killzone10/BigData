provider "google" {
  project = var.project_name
  region  = var.region
}
terraform {
  required_providers {
    google = {
      version = "~> 4.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}
