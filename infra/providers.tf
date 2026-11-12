terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Estado remoto (descomente após criar o bucket S3 e a tabela DynamoDB de lock)
  # backend "s3" {
  #   bucket         = "devops-na-pratica-tfstate"
  #   key            = "fase1/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "devops-na-pratica-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
