output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "ecr_repository_url" {
  description = "URL do repositório ECR (variável ECR_REPOSITORY_URL no GitHub)"
  value       = aws_ecr_repository.app.repository_url
}

output "deploy_bucket" {
  description = "Bucket dos artefatos de deploy (variável DEPLOY_BUCKET no GitHub)"
  value       = aws_s3_bucket.deploy.bucket
}

output "instance_id" {
  description = "ID da EC2 (variável EC2_INSTANCE_ID no GitHub)"
  value       = aws_instance.app.id
}

output "github_actions_role_arn" {
  description = "Role assumida pelo GitHub Actions via OIDC (variável AWS_ROLE_ARN no GitHub)"
  value       = aws_iam_role.github_actions.arn
}

output "app_url" {
  description = "URL pública da API (variável APP_URL no GitHub)"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

output "grafana_url" {
  description = "Dashboard Grafana (acesso restrito ao admin_cidr)"
  value       = "http://${aws_instance.app.public_ip}:3000"
}

output "log_group" {
  description = "Grupo de logs da aplicação no CloudWatch"
  value       = aws_cloudwatch_log_group.app.name
}

output "grafana_password_parameter" {
  description = "Parâmetro do SSM com a senha do Grafana"
  value       = aws_ssm_parameter.grafana_admin_password.name
}
