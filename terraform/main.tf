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
      _BACKEND_CONFIG_PREFIX: "terraform/pr"
      _TF_COMMAND = "plan"
      _TF_OPTION = "-auto-approve"
      _VAR_FILES = "../tfvars/pr.tfvars"
      _TF_EXTRA_OPTION = "-lock=false"
    }
    included_files = ["terraform/**"]
}