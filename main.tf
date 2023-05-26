resource "google_storage_bucket" "tbd-staging-bucket" {
  name                        = "${var.project_name}-staging"
  location                    = var.region
  uniform_bucket_level_access = false #tfsec:ignore:google-storage-enable-ubla
  force_destroy               = true
  #checkov:skip=CKV_GCP_62: "Bucket should log access"
  #checkov:skip=CKV_GCP_29: "Ensure that Cloud Storage buckets have uniform bucket-level access enabled"
  versioning {
    enabled = true
  }
}

resource "google_service_account" "tbd-sa" {
  account_id = "${var.project_name}-sa"
}

resource "google_project_iam_member" "tbd-sa-role-bindings" {
  project  = var.project_name
  for_each = toset(["roles/storage.admin", "roles/dataproc.editor"])
  role     = each.value
  member   = "serviceAccount:${google_service_account.tbd-sa.email}"
}

module "data-generator" {
  source = "./modules/data-generator"
}

resource "google_storage_bucket_object" "input-data" {
  depends_on = [module.data-generator]
  name       = "data/input.csv"
  source     = module.data-generator.file_path
  bucket     = google_storage_bucket.tbd-staging-bucket.name

}

data "template_file" "pypsark_job" {
  template = file("src/py/pyspark_job.py.tpl")
  vars = {
    staging_bucket = google_storage_bucket.tbd-staging-bucket.name
    service_sufix  = "dataproc"
  }
}

resource "google_storage_bucket_object" "pyspark_job_file" {
  depends_on = [module.data-generator]
  name       = "src/pyspark_job.py"
  content    = data.template_file.pypsark_job.rendered
  bucket     = google_storage_bucket.tbd-staging-bucket.name

}



module "dataproc-pyspark-job" {
  source         = "./modules/dataproc-pyspark-job"
  project_name   = var.project_name
  region         = var.region
  staging_bucket = google_storage_bucket.tbd-staging-bucket.name
  py_file        = "gs://${google_storage_bucket_object.pyspark_job_file.bucket}/${google_storage_bucket_object.pyspark_job_file.name}"
}


data "google_client_config" "default" {}
module "gke" {
  source          = "./modules/gke"
  project_name    = var.project_name
  region = var.region
  zone = var.zone
  service_account = google_service_account.tbd-sa.email
}

provider "kubernetes" {
  alias                  = "gke"
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = module.gke.cluster_ca_certificate
}

provider "helm" {
  debug = true
  alias = "gke"
  kubernetes {
    host                   = module.gke.endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = module.gke.cluster_ca_certificate
  }
}

provider "kubectl" {
  host                   = module.gke.endpoint
  cluster_ca_certificate = module.gke.cluster_ca_certificate
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}


module "k8s-spark-operator" {
  depends_on = [module.gke]
  source     = "github.com/biodatageeks/sequila-cloud-recipes.git?ref=0.1.2/modules/kubernetes/spark-on-k8s-operator"
  providers = {
    helm = helm.gke
  }
}



data "template_file" "pypsark_k8s_job" {
  template = file("src/py/pyspark_job.py.tpl")
  vars = {
    staging_bucket = google_storage_bucket.tbd-staging-bucket.name
    service_sufix  = "k8s"
  }
}

data "template_file" "pypsark_k8s_deployment" {
  depends_on = [module.k8s-spark-operator]
  template   = file("src/k8s/pyspark_job.yaml.tpl")
  vars = {
    staging_bucket = google_storage_bucket.tbd-staging-bucket.name
  }
}


resource "google_storage_bucket_object" "pyspark_k8s_job_file" {
  depends_on = [module.data-generator]
  name       = "src/pyspark_k8s_job.py"
  content    = data.template_file.pypsark_k8s_job.rendered
  bucket     = google_storage_bucket.tbd-staging-bucket.name

}

resource "kubectl_manifest" "pypsark_k8s_manifest" {
  yaml_body = data.template_file.pypsark_k8s_deployment.rendered
}
