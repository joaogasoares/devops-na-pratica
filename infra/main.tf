locals {
  name          = "${var.project_name}-${var.environment}"
  log_group     = "/${var.project_name}/${var.environment}/app"
  app_dir       = "/opt/${var.project_name}"
  ssm_param_key = "/${var.project_name}/${var.environment}"
}

# ---------------------------------------------------------------
# Registro de imagens (ECR)
# ---------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  #checkov:skip=CKV_AWS_136:Criptografia AES256 padrão da AWS; KMS dedicado (custo) fica como melhoria futura
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Mantém apenas as 20 imagens mais recentes (controle de custo)
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter as 20 imagens mais recentes"

      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }

      action = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------
# Bucket com os artefatos de deploy (compose, scripts, configs)
# ---------------------------------------------------------------
resource "aws_s3_bucket" "deploy" { # NOSONAR(S6258): log de acesso dispensado, ver justificativa CKV_AWS_18
  #checkov:skip=CKV_AWS_18:Bucket interno só de artefatos de deploy; acessos já auditados pelo CloudTrail
  #checkov:skip=CKV_AWS_144:Artefatos são reproduzíveis a partir do Git; replicação entre regiões desnecessária
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) habilitado; KMS dedicado fica como melhoria futura
  #checkov:skip=CKV2_AWS_62:Nenhum processo depende de notificações de eventos deste bucket
  bucket_prefix = "${local.name}-deploy-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "deploy" {
  bucket                  = aws_s3_bucket.deploy.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Recusa qualquer acesso ao bucket que não use HTTPS (TLS)
resource "aws_s3_bucket_policy" "deploy_https_only" {
  bucket = aws_s3_bucket.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.deploy.arn, "${aws_s3_bucket.deploy.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.deploy]
}

resource "aws_s3_bucket_versioning" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Remove releases antigas e versões não correntes após 30 dias
resource "aws_s3_bucket_lifecycle_configuration" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  rule {
    id     = "expirar-releases-antigas"
    status = "Enabled"

    filter {
      prefix = "releases/"
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abortar-uploads-incompletos"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------
# Segredos (gestão de configuração segura: nada sensível no código)
# ---------------------------------------------------------------
resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  #checkov:skip=CKV_AWS_337:Usa a chave gerenciada aws/ssm; KMS dedicado fica como melhoria futura
  name        = "${local.ssm_param_key}/grafana-admin-password"
  description = "Senha do usuário admin do Grafana"
  type        = "SecureString"
  value       = random_password.grafana_admin.result
}

# ---------------------------------------------------------------
# Security Group: sem SSH. Administração via AWS SSM Session Manager
# ---------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${local.name}-sg"
  description = "Acesso a API de Tarefas e ao monitoramento"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "API HTTP"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana (somente administradores)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Prometheus (somente administradores)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # Saída apenas HTTPS: ECR, S3, SSM, CloudWatch, Docker Hub e pacotes do SO
  egress {
    description = "Saida HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ---------------------------------------------------------------
# Servidor da aplicação: Docker + Docker Compose; o deploy é feito pelo pipeline
# ---------------------------------------------------------------
resource "aws_instance" "app" { # NOSONAR(S6329): IP público intencional, a API é servida direto da EC2; portas restritas no security group
  #checkov:skip=CKV_AWS_126:Monitoramento básico (5 min) + Prometheus na própria instância; detalhado gera custo extra
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  ebs_optimized          = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 20
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_dir = local.app_dir
  })

  tags = { Name = "${local.name}-app" }
}
