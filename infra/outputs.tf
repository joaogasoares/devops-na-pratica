output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "ecr_repository_url" {
  description = "URL do repositório ECR para push da imagem"
  value       = aws_ecr_repository.app.repository_url
}

output "app_public_ip" {
  description = "IP público da instância da aplicação"
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "Endereço do health check da API"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/health"
}
