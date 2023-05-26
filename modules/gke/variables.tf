variable "project_name" {
  type        = string
  description = "Name of the GCP project"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "machine_type" {
  type        = string
  description = "GCP machine type"
  default     = "e2-standard-2"
}



variable "zone" {
type = string
description = "GCP region"
}


variable "max_node_count" {
type = string
description = "Maximum number of GKE nodes"
default = 6
}


variable "preemptible" {
  type        = bool
  default     = true
  description = "Use preemptible instances"
}

variable "service_account" {
  type        = string
  description = "Service account to use"
}
