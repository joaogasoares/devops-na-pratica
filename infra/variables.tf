variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos"
  type        = string
  default     = "devops-na-pratica"
}

variable "environment" {
  description = "Ambiente (dev, staging ou prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser dev, staging ou prod."
  }
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas (uma por zona de disponibilidade)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "Tipo da instância EC2 da aplicação"
  type        = string
  default     = "t3.small"
}

variable "app_port" {
  description = "Porta em que a API escuta"
  type        = number
  default     = 8000
}

variable "admin_cidr" {
  description = "CIDR autorizado a acessar Grafana (3000) e Prometheus (9090). Use o seu IP/32"
  type        = string
  default     = "127.0.0.1/32"
}

variable "github_repository" {
  description = "Repositório no formato usuario/repositorio, autorizado a fazer deploy via OIDC"
  type        = string
  default     = "SEU-USUARIO/devops-na-pratica"
}

variable "create_github_oidc_provider" {
  description = "Cria o provedor OIDC do GitHub (use false se ele já existir na conta AWS)"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "E-mail que recebe os alarmes do CloudWatch (vazio = sem assinatura)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 14
}
