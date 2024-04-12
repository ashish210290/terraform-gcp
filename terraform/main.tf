# Create Trigger for terraform plan ##

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
      approval_required = true
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


resource "google_monitoring_notification_channel" "name" {

  project = var.project_id
  display_name = var.display_name
  description = var.description
  type = var.type
}

resource "google_monitoring_alert_policy" "alert_policy" {
  display_name = "My Alert Policy"
  combiner     = "OR"
  conditions {
    display_name = "test condition"
    condition_prometheus_query_language {
      query      = "compute_googleapis_com:instance_cpu_usage_time > 0"
      duration   = "60s"
      evaluation_interval = "60s"
      alert_rule  = "AlwaysOn"
      rule_group  = "a test"
    }
  }

  alert_strategy {
    auto_close  = "1800s"
  }
}

resource "google_logging_metric" "nifi_log_metric" {
  provider = google-beta
  project = "divine-energy-253221"

  name = "nifi-too-mny-files"
  description = "Detect too many files"
  filter = "labels.\"log.file.name\"=\"nifi-app.log\" AND \"Initiating checkpoint of FlowFile Repository\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type = "INT64"
  }

}