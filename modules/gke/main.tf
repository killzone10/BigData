resource "google_project_service" "gke-service" {
  for_each                   = toset(["container.googleapis.com"])
  project                    = var.project_name
  service                    = each.value
  disable_dependent_services = true
}

#tfsec:ignore:google-iam-no-privileged-service-accounts
resource "google_project_iam_member" "serviceUsage" {
  project = var.project_name
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${var.service_account}"
}


#tfsec:ignore:google-gke-enable-stackdriver-monitoring
#tfsec:ignore:google-gke-enforce-pod-security-policy
#tfsec:ignore:google-gke-use-cluster-labels
#tfsec:ignore:google-gke-enable-stackdriver-logging
#tfsec:ignore:google-gke-enable-private-cluster
#tfsec:ignore:google-gke-enable-network-policy
#tfsec:ignore:google-gke-enable-master-networks
#tfsec:ignore:google-gke-enable-ip-aliasing
resource "google_container_cluster" "primary" {
  depends_on = [google_project_service.gke-service, google_project_iam_member.serviceUsage]
  #checkov:skip=CKV_GCP_24:"Ensure PodSecurityPolicy controller is enabled on the Kubernetes Engine Clusters"
  #checkov:skip=CKV_GCP_61:"Enable VPC Flow Logs and Intranode Visibility"
  #checkov:skip=CKV_GCP_70:"Ensure the GKE Release Channel is set"
  #checkov:skip=CKV_GCP_23:"Ensure Kubernetes Cluster is created with Alias IP ranges enabled"
  #checkov:skip=CKV_GCP_20:"Ensure master authorized networks is set to enabled in GKE clusters"
  #checkov:skip=CKV_GCP_21:"Ensure Kubernetes Clusters are configured with Labels"
  #checkov:skip=CKV_GCP_13:"Ensure a client certificate is used by clients to authenticate to Kubernetes Engine Clusters"
  #checkov:skip=CKV_GCP_67:"Ensure legacy Compute Engine instance metadata APIs are Disabled"
  #checkov:skip=CKV_GCP_19:"Ensure GKE basic auth is disabled"
  #checkov:skip=CKV_GCP_65:"Manage Kubernetes RBAC users with Google Groups for GKE"
  #checkov:skip=CKV_GCP_66:"Ensure use of Binary Authorization"
  #checkov:skip=CKV_GCP_69:"Ensure the GKE Metadata Server is Enabled"
  #checkov:skip=CKV_GCP_12:"Ensure Network Policy is enabled on Kubernetes Engine Clusters"
  #checkov:skip=CKV_GCP_10:"Ensure 'Automatic node upgrade' is enabled for Kubernetes Clusters"
  project               = var.project_name
  name                  = "${var.project_name}-cluster"
  location              = var.zone
  enable_shielded_nodes = true

  private_cluster_config {
    enable_private_endpoint = false
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}
#tfsec:ignore:google-gke-enable-auto-repair
#tfsec:ignore:google-gke-node-pool-uses-cos
#tfsec:ignore:google-gke-enable-auto-upgrade
resource "google_container_node_pool" "primary_preemptible_nodes" {
  depends_on = [google_project_service.gke-service, google_project_iam_member.serviceUsage]
  #checkov:skip=CKV_GCP_69:"Ensure the GKE Metadata Server is Enabled"
  #checkov:skip=CKV_GCP_9:"Ensure 'Automatic node repair' is enabled for Kubernetes Clusters"
  #checkov:skip=CKV_GCP_68:"Ensure Secure Boot for Shielded GKE Nodes is Enabled"
  #checkov:skip=CKV_GCP_22:"Ensure Container-Optimized OS (cos) is used for Kubernetes Engine Clusters Node image"
  #checkov:skip=CKV_GCP_10:"Ensure 'Automatic node upgrade' is enabled for Kubernetes Clusters"


  project    = var.project_name
  name       = "${var.project_name}-lab-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 6


  autoscaling {
    min_node_count = 6
    max_node_count = var.max_node_count
  }
  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type
    disk_size_gb = 50

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = var.service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}