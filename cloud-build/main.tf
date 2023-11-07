resource "google_cloudbuild_trigger" "tf-ashish-gcp-plan-trigger" {
     project = "divine-energy-253221"
     description = "A trigger to push to any branch"
    trigger_template {
      branch_name = ".*"
      repo_name = "ashish210290/terraform-gcp"
    }
    github {
      name = "ashish210290/terraform-gcp"
      owner = "ashish210290"
      push {
        branch = ".*"
      }
    }
    filename = "cloudbuild.yml"
    substitutions = {
      _TF_COMMAND = "plan"
      _TF_OPTION = "-auto-approve"
      _VAR_FILES = "pr.tfvars"
      _TF_EXTRA_OPTION = "-lock=false"
    }
    included_files = ["terraform/**"]
}