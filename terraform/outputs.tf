output "project_name" {
  value = local.name
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "terraform_project_status" {
  value = "Infrastructure configuration validated and managed by Terraform"
}
