locals {
  name = "cloudops-autopilot"
}

resource "terraform_data" "project" {
  input = {
    name      = local.name
    project   = "CloudOps AutoPilot"
    managedBy = "Terraform"
  }
}
