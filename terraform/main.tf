#--------------------------------------------------------#
# Create Service Account to deploy TokenApp on Cloud-Run |
#--------------------------------------------------------#
resource "google_service_account" "cloud-run-sa" {
  project = var.project_id  
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account to manage Token App"
}

#--------------------------------------------------------------------------------#
# Define roles to be assigned to secret Manger SA and Cloud Run SA for Token App |
#--------------------------------------------------------------------------------#

locals {
  cloud_run_roles = [
    "roles/run.developer",
    "roles/secretmanager.secretAccessor",
    "roles/run.invoker",
    "roles/logging.logWriter"
  ]
}

#-------------------------------------------------#
# Assign roles/permisions to Cloud Run SA account |
#------------------------------------------------ #

resource "google_project_iam_member" "cloud_run_sa" {
  for_each = toset(local.cloud_run_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud-run-sa.email}"
}

#-----------------------------------------------#
# Create 3 secrets keys only in Secret Manager. |
# Remember to add secret values through conole. | 
#-----------------------------------------------#

resource "google_secret_manager_secret" "oauth2-client-id" {
  project = var.project_id  
  secret_id = "oauth2-client-id"
  replication {
    user_managed {
      replicas {
        location =  "northamerica-northeast1"
      }
      replicas {
        location =  "northamerica-northeast2"
      }
    }
  }
}

resource "google_secret_manager_secret" "oauth2-client-clientSecret" {
  project = var.project_id  
  secret_id = "oauth2-client-clientSecret"
  replication {
    user_managed {
      replicas {
        location =  "northamerica-northeast1"
      }
      replicas {
        location =  "northamerica-northeast2"
      }
    }
  }
}

resource "google_secret_manager_secret" "security-api-key" {
  project = var.project_id  
  secret_id = "security-api-key"
  replication {
    user_managed {
      replicas {
        location =  "northamerica-northeast1"
      }
      replicas {
        location =  "northamerica-northeast2"
      }
    }
  }
}

#------------------------------------------#
# Deploy Token App to Cloud-Run            |
#------------------------------------------#

# Token app Service in Montreal
resource "google_cloud_run_v2_service" "wif-tokenapp-service-1" {

  name     = "wif-tokenapp-service-1"
  location = var.region
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
      containers {
        image = "northamerica-northeast1-docker.pkg.dev/fourth-walker-437420-f1/ashish-repo/tokenapp:1.0.0"
        ports {
          container_port = 8080
        }
        env {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.env
        }
      }
      service_account = "cloud-run-sa@${var.project_id}.iam.gserviceaccount.com"
  }
  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST" 
  }
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, # Prevent recreation on image change
      template[0].containers[0].ports[0].container_port, # Prevent recreation on container port change
      traffic # Prevent recreation when updating traffic splitting
    ]
  }
}

#Token app Service in Toronto
resource "google_cloud_run_v2_service" "wif-tokenapp-service-2" {

  name     = "wif-tokenapp-service-2"
  location = var.region_dr
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
      containers {
        image = "northamerica-northeast1-docker.pkg.dev/fourth-walker-437420-f1/ashish-repo/tokenapp:1.0.0"
        ports {
          container_port = 8080
        }
        env {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.env
        }
      }
      service_account = "cloud-run-sa@${var.project_id}.iam.gserviceaccount.com"
  }
  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST" 
  }
  lifecycle {
    ignore_changes = [ 
      template[0].containers[0].image, # Prevent recreation on image change
      template[0].containers[0].ports[0].container_port, # Prevent recreation on container port change
      traffic # Prevent recreation when updating traffic splitting
    ]
  }
}

resource "google_cloud_run_service_iam_member" "noauth-1" {
  project = google_cloud_run_v2_service.wif-tokenapp-service-1.project
  location = google_cloud_run_v2_service.wif-tokenapp-service-1.location
  service  = google_cloud_run_v2_service.wif-tokenapp-service-1.name
  role     = "roles/run.invoker"
  member  = "allUsers" 
}

resource "google_cloud_run_service_iam_member" "noauth-2" {

  project = google_cloud_run_v2_service.wif-tokenapp-service-2.project
  location = google_cloud_run_v2_service.wif-tokenapp-service-2.location
  service  = google_cloud_run_v2_service.wif-tokenapp-service-2.name
  role     = "roles/run.invoker"
  member  = "allUsers" 
}
