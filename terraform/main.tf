data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state="available" }
data "aws_ssm_parameter" "al2023" { name="/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }

locals { name="cloudops-autopilot" }

resource "aws_vpc" "main" {
  cidr_block="10.30.0.0/16"
  enable_dns_support=true
  enable_dns_hostnames=true
}
resource "aws_subnet" "public" {
  vpc_id=aws_vpc.main.id
  cidr_block="10.30.1.0/24"
  availability_zone=data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch=true
}
resource "aws_internet_gateway" "main" { vpc_id=aws_vpc.main.id }
resource "aws_route_table" "public" {
  vpc_id=aws_vpc.main.id
  route { cidr_block="0.0.0.0/0" gateway_id=aws_internet_gateway.main.id }
}
resource "aws_route_table_association" "public" {
  subnet_id=aws_subnet.public.id
  route_table_id=aws_route_table.public.id
}
resource "aws_security_group" "dashboard" {
  name="${local.name}-dashboard"
  vpc_id=aws_vpc.main.id
  ingress { from_port=5000 to_port=5000 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  egress { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
}
resource "aws_ecr_repository" "dashboard" {
  name=local.name
  image_tag_mutability="MUTABLE"
  image_scanning_configuration { scan_on_push=true }
}
resource "aws_cloudwatch_log_group" "lambda" {
  name="/aws/lambda/${local.name}-remediator"
  retention_in_days=7
}

resource "aws_iam_role" "lambda" {
  name="${local.name}-lambda-role"
  assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="lambda.amazonaws.com"},Action="sts:AssumeRole"}]})
}
resource "aws_iam_role_policy" "lambda" {
  role=aws_iam_role.lambda.id
  policy=jsonencode({
    Version="2012-10-17",
    Statement=[
      {Effect="Allow",Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],Resource="${aws_cloudwatch_log_group.lambda.arn}:*"},
      {Effect="Allow",Action=["ec2:DescribeInstances","ec2:StartInstances"],Resource="*"}
    ]
  })
}
data "archive_file" "lambda" {
  type="zip"
  source_file="${path.module}/../lambda/remediator.py"
  output_path="${path.module}/remediator.zip"
}
resource "aws_lambda_function" "remediator" {
  function_name="${local.name}-remediator"
  role=aws_iam_role.lambda.arn
  handler="remediator.lambda_handler"
  runtime="python3.12"
  filename=data.archive_file.lambda.output_path
  source_code_hash=data.archive_file.lambda.output_base64sha256
  timeout=30
  environment { variables={AUTO_TAG_KEY="AutoRemediate"} }
}

resource "aws_iam_role" "ec2" {
  name="${local.name}-ec2-role"
  assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="ec2.amazonaws.com"},Action="sts:AssumeRole"}]})
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role=aws_iam_role.ec2.name
  policy_arn="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ec2" {
  name="${local.name}-profile"
  role=aws_iam_role.ec2.name
}
resource "aws_instance" "demo" {
  ami=data.aws_ssm_parameter.al2023.value
  instance_type=var.instance_type
  subnet_id=aws_subnet.public.id
  vpc_security_group_ids=[aws_security_group.dashboard.id]
  iam_instance_profile=aws_iam_instance_profile.ec2.name
  user_data=<<-USERDATA
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  USERDATA
  tags={Name="${local.name}-demo",AutoRemediate="true"}
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name="${local.name}-high-cpu"
  comparison_operator="GreaterThanThreshold"
  evaluation_periods=2
  metric_name="CPUUtilization"
  namespace="AWS/EC2"
  period=60
  statistic="Average"
  threshold=80
  dimensions={InstanceId=aws_instance.demo.id}
}

resource "aws_cloudwatch_event_rule" "stopped" {
  name="${local.name}-stopped-instance"
  event_pattern=jsonencode({source=["aws.ec2"],"detail-type"=["EC2 Instance State-change Notification"],detail={state=["stopped"]}})
}
resource "aws_cloudwatch_event_target" "remediator" {
  rule=aws_cloudwatch_event_rule.stopped.name
  arn=aws_lambda_function.remediator.arn
}
resource "aws_lambda_permission" "eventbridge" {
  statement_id="AllowExecutionFromEventBridge"
  action="lambda:InvokeFunction"
  function_name=aws_lambda_function.remediator.function_name
  principal="events.amazonaws.com"
  source_arn=aws_cloudwatch_event_rule.stopped.arn
}

resource "aws_iam_role" "github_actions" {
  count=var.github_repo=="" ? 0 : 1
  name="${local.name}-github-actions"
  assume_role_policy=jsonencode({
    Version="2012-10-17",
    Statement=[{Effect="Allow",Principal={Federated="arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"},Action="sts:AssumeRoleWithWebIdentity",Condition={StringEquals={"token.actions.githubusercontent.com:aud"="sts.amazonaws.com"},StringLike={"token.actions.githubusercontent.com:sub"="repo:${var.github_repo}:ref:refs/heads/main"}}}]
  })
}
resource "aws_iam_role_policy" "github_actions" {
  count=var.github_repo=="" ? 0 : 1
  role=aws_iam_role.github_actions[0].id
  policy=jsonencode({
    Version="2012-10-17",
    Statement=[
      {Effect="Allow",Action=["ecr:GetAuthorizationToken"],Resource="*"},
      {Effect="Allow",Action=["ecr:BatchCheckLayerAvailability","ecr:CompleteLayerUpload","ecr:InitiateLayerUpload","ecr:PutImage","ecr:UploadLayerPart"],Resource=aws_ecr_repository.dashboard.arn}
    ]
  })
}
