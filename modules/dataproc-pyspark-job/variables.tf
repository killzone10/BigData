variable "project_name" {
  type        = string
  description = "Project name"
}

variable "staging_bucket" {
  type        = string
  description = "Dataproc staging bucket"
}

variable "py_file" {
  type        = string
  description = "PySpark script to use"
}

variable "region" {
  type        = string
  description = "GCP region"
}