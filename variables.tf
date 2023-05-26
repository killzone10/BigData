
variable "project_name" {
  type        = string
  description = "Project name"
}


variable "region" {
  type        = string
  description = "GCP region"
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
