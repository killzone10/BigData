locals {
  project = "${var.tbd_semester}-${var.group_id}"
}





resource "google_dataproc_cluster" "mycluster" {
  name   = "mycluster"
  region = var.region
  project = local.project

  cluster_config {
    autoscaling_config {
      policy_uri = google_dataproc_autoscaling_policy.asp.name
    }

    gce_cluster_config {
      internal_ip_only = true
    }

    encryption_config{
      kms_key_name="SecretSquirrel" 
    }

    worker_config {
      num_instances    = 3
      disk_config {
        boot_disk_size_gb = 30
        num_local_ssds    = 1
      }
    }
  
  }
  
}

  



resource "google_dataproc_autoscaling_policy" "asp" {
  policy_id = "dataproc-policy"
  location  = var.region

  worker_config {
    max_instances = 3
  }
  secondary_worker_config {
    max_instances = 3
    weight = 1
  }
  basic_algorithm {
    yarn_config {
      graceful_decommission_timeout = "30s"

      scale_up_factor   = 0.5
      scale_down_factor = 0.5
    }
  }
}


resource "google_dataproc_job" "spark" {
  region       = google_dataproc_cluster.mycluster.region
  force_delete = true
  placement {
    cluster_name = google_dataproc_cluster.mycluster.name
  }

  spark_config {
    main_class    = "org.apache.spark.examples.SparkPi"
    jar_file_uris = ["file:///usr/lib/spark/examples/jars/spark-examples.jar"]
    args          = ["210000"]

    properties = {
      "spark.logConf" = "true"
    }

    logging_config {
      driver_log_levels = {
        "root" = "INFO"
      }
    }
  }
}


