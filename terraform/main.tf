resource "google_cloudbuild_trigger" "test" {
     provider = google-beta
     project = "divine-energy-253221"
     name = "Terraform-Trigger"
     description = "A trigger to push to any branch"
    # trigger_template {
    #   branch_name = "np"
    #   repo_name = "ashish210290/terraform-gcp"
    # }
    github {
      name = "terraform-gcp"
      owner = "ashish210290"
      pull_request {
        branch = "^main$"
      }
    }
    filename = "cloud-build/tf-apply-project.yaml"
    substitutions = {
      _TF_COMMAND = "plan"
      _TF_OPTION = "-auto-approve"
      _VAR_FILES = "pr.tfvars"
      _TF_EXTRA_OPTION = "-lock=false"
    }
    included_files = ["terraform/**"]
}