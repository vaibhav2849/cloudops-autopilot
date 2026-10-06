data "aws_caller_identity" "current" {}

locals {
  name = "cloudops-autopilot"
}

# ---------------------------------------------------------
# Terraform-managed project metadata
# ---------------------------------------------------------

resource "terraform_data" "project" {
  input = {
    name      = local.name
    project   = "CloudOps-AutoPilot"
    managedBy = "Terraform"
    account   = data.aws_caller_identity.current.account_id
  }
}
