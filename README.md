# CloudOps AutoPilot
Automated AWS infrastructure monitoring and auto-remediation platform.

Stack: AWS CloudWatch, EventBridge, Lambda, EC2, ECR, IAM, Terraform, Docker, Python Flask, Boto3, GitHub Actions.

Flow:
GitHub -> GitHub Actions -> Docker -> ECR -> deployment
AWS events -> EventBridge -> Lambda -> Boto3 -> controlled EC2 remediation -> CloudWatch Logs

Core features:
- Terraform Infrastructure as Code
- Dockerized Flask monitoring dashboard
- CloudWatch monitoring
- Event-driven Lambda remediation
- Boto3 based EC2 automation
- ECR container registry
- GitHub Actions CI/CD
- GitHub OIDC instead of permanent AWS keys
- Least-privilege IAM

Interview pitch:
"I built CloudOps AutoPilot to automate AWS infrastructure monitoring and remediation. Terraform provisions the cloud resources, CloudWatch and EventBridge detect infrastructure events, and Python Lambda uses Boto3 for controlled remediation. The monitoring dashboard is containerized with Docker and delivered through ECR and GitHub Actions."

Resume:
Built an AWS infrastructure monitoring and auto-remediation platform using Terraform, CloudWatch, EventBridge, Lambda and Boto3. Containerized a Flask monitoring dashboard with Docker and Amazon ECR, with GitHub Actions automating image delivery.
