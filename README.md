# DevOps na Prática — Fase 1: Configuração e Automação Inicial

API REST de gerenciamento de tarefas (To-Do) usada como base para aplicar práticas de DevOps:
integração contínua com GitHub Actions, testes automatizados e infraestrutura como código com Terraform.

## Estrutura

```
app/                  # Código da API (Python + FastAPI)
tests/                # Testes automatizados (pytest)
.github/workflows/    # Pipeline de CI (GitHub Actions)
infra/                # Infraestrutura como Código (Terraform / AWS)
Dockerfile            # Imagem da aplicação
```

## Rodando localmente

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload        # http://localhost:8000/docs
```

## Testes e qualidade

```bash
ruff check . && ruff format --check .
pytest --cov=app --cov-fail-under=80
```

## Pipeline de CI

A cada `push` em `main`/`develop` e a cada Pull Request para `main`, o workflow `.github/workflows/ci.yml` executa:

1. **Lint** — `ruff check` e `ruff format --check`
2. **Testes** — `pytest` com cobertura mínima de 80%, em Python 3.11 e 3.12
3. **Docker** — build da imagem e smoke test do endpoint `/health`
4. **Terraform** — `fmt -check`, `init` e `validate` do código de infraestrutura

## Infraestrutura (Terraform)

Recursos provisionados na AWS: VPC, 2 subnets públicas, Internet Gateway, tabela de rotas,
Security Group, repositório ECR, IAM Role/Instance Profile e instância EC2 que executa a API em Docker.

```bash
cd infra
terraform init
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
terraform destroy -var-file=environments/dev.tfvars   # para evitar custos
```
