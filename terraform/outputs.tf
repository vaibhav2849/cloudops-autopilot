output "dashboard_url" { value="http://${aws_instance.demo.public_ip}:5000" }
output "instance_id" { value=aws_instance.demo.id }
output "ecr_repository_url" { value=aws_ecr_repository.dashboard.repository_url }
output "remediator_lambda" { value=aws_lambda_function.remediator.function_name }
output "github_actions_role_arn" { value=var.github_repo=="" ? "Set github_repo to create role" : aws_iam_role.github_actions[0].arn }
