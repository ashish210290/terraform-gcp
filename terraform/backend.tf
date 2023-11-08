terraform {
  required_version = "1.4.6"
  backend "gcs" {
    bucket = "divine-energy-253221"
    prefix = "terraform/pr"
  }
}