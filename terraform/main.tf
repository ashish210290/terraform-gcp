# Create Trigger for terraform plan ##

provider "google-beta" {
  project = var.project_id
  
}
resource "google_cloudbuild_trigger" "test" {
     provider = google-beta
     project = "divine-energy-253221"
     name = "Terraform-plan-${var.env}"
     description = "A trigger to push to any branch"

    github {
      name = "terraform-gcp"
      owner = "ashish210290"
      push {
        branch = "^main$"
      }
    }
    filename = "cloud-build/tf-plan-project.yaml"
    substitutions = {
      _BACKEND_CONFIG_PREFIX: "terraform/${var.env}"
      _TF_COMMAND = "plan"
      _TF_OPTION = "-auto-approve"
      _VAR_FILES = "../tfvars/pr.tfvars"
      _TF_EXTRA_OPTION = "-lock=false"
    }
    approval_config {
      approval_required = false
    }
    included_files = ["terraform/**"]
}


# Create Trigger for terraform apply, approval required ##


resource "google_cloudbuild_trigger" "trigger-apply" {
     provider = google-beta
     project = "divine-energy-253221"
     name = "Terraform-apply-${var.env}"
     description = "A trigger to apply terraform on git push to main"

    github {
      name = "terraform-gcp"
      owner = "ashish210290"
      push {
        branch = "^${var.data_platform_ops_br}$"
      }
    }
    filename = "cloud-build/tf-apply-project.yaml"
    substitutions = {
      _BACKEND_CONFIG_PREFIX: "terraform/${var.env}"
      _TF_COMMAND = "apply"
      _TF_OPTION = "-auto-approve"
      _VAR_FILES = "../tfvars/pr.tfvars"
      _TF_EXTRA_OPTION = "-lock=false"
    }
    approval_config {
      approval_required = true
    }
    included_files = ["terraform/**"]
}

resource "google_monitoring_alert_policy" "test_alert_policy_name" {
  
  project = "divine-energy-253221"
  display_name = "My Alert Policy"
  combiner     = "OR"

  conditions {
    display_name = "test condition - metrics missing"
    condition_absent {
      filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration = "300s"

      trigger {
        count = 1
      }
      
      aggregations {
        alignment_period = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  enabled = true
  notification_channels = ["projects/divine-energy-253221/notificationChannels/16399540197443471345"]
}

resource "google_monitoring_alert_policy" "Alert-Policy-1" {
    display_name = "My Alert POlicy 1"
    combiner = "OR"
    conditions {
      display_name = "Test Conditions 1"
      condition_threshold {
      filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration = "60s"
      comparison = "COMPARISION_GT"
      aggregations {
        alignment_period = "60s"
        per_series_aligner = "ALING_RATE"
      }
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
      }     
    }
    user_labels = {
      foo = "bar"
    }
}