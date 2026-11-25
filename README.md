# DevOps na Prática — API de Tarefas

API REST de gerenciamento de tarefas (To-Do), em Python/FastAPI, usada para aplicar o ciclo DevOps completo:
integração contínua, entrega contínua, containers, infraestrutura como código, monitoramento, logging e DevSecOps.

| Fase | Entregas |
|------|----------|
| **Fase 1** — Configuração e Automação Inicial | Repositório, pipeline de CI, testes automatizados, Terraform |
| **Fase 2** — Entrega Contínua, Monitoramento e Segurança | Pipeline de CD, Docker/Compose, scripts de deploy e rollback, Prometheus/Grafana, CloudWatch, SAST/DAST |

## Estrutura

```
app/                         # Código da API (FastAPI) + métricas Prometheus + logs JSON
tests/                       # Testes automatizados (pytest)
Dockerfile                   # Imagem multi-stage, usuário não-root, HEALTHCHECK
docker-compose.yml           # Ambiente local: API + Prometheus + Grafana
deploy/
  docker-compose.prod.yml    # Stack de produção (logs no CloudWatch)
  scripts/deploy.sh          # Deploy com smoke test e rollback automático
  scripts/rollback.sh        # Rollback manual para a versão anterior
  scripts/smoke_test.sh      # Verificação pós-deploy
  monitoring/                # prometheus.yml, alertas e dashboard do Grafana
infra/                       # Terraform: VPC, EC2, ECR, S3, IAM/OIDC, SSM, CloudWatch, SNS
.github/workflows/ci-cd.yml  # Pipeline CI/CD
.github/workflows/rollback.yml
.github/dependabot.yml       # Atualização automática de dependências
docs/fluxograma.md           # Fluxograma do fluxo DevOps (Mermaid)
```

## Rodando localmente

```bash
# Somente a API
pip install -r requirements-dev.txt
uvicorn app.main:app --reload            # http://localhost:8000/docs

# Stack completa em containers
docker compose up -d --build
# API: http://localhost:8000  |  Prometheus: http://localhost:9090  |  Grafana: http://localhost:3000 (admin / admin-local)
```

## Qualidade e segurança (executados no pipeline)

```bash
ruff check . && ruff format --check .                     # lint
pytest --cov=app --cov-fail-under=80                      # testes + cobertura
bandit -r app -ll                                         # SAST
pip-audit -r requirements.txt --strict                    # dependências vulneráveis
```

## Pipeline CI/CD (`.github/workflows/ci-cd.yml`)

```
lint ─┬─ testes (3.11/3.12) ─┐
      └─ segurança (Bandit, pip-audit) ─┤
terraform (fmt, validate, Checkov) ─────┴─ build ─► deploy (aprovação manual) ─► DAST (OWASP ZAP)
                                          │
                                          ├ docker build + Trivy
                                          ├ docker compose up + smoke test + Prometheus/Grafana
                                          └ push no ECR (somente main)
```

- **Pull Requests e branch `develop`:** executam toda a parte de CI.
- **Push na `main`:** além da CI, publica a imagem no ECR e entra no job de deploy, que aguarda aprovação
  manual no ambiente `production` (Entrega Contínua). Após aprovado: envia os artefatos para o S3, executa
  `deploy.sh` na EC2 via AWS SSM, faz smoke test pela internet e roda o OWASP ZAP.
- **Rollback:** automático no `deploy.sh` se o smoke test falhar, ou manual pela workflow **Rollback**.

## Ativando o deploy na AWS

1. Ajuste `infra/environments/prod.tfvars` (`github_repository`, `admin_cidr`, `alert_email`) e rode:
   ```bash
   cd infra
   terraform init
   terraform apply -var-file=environments/prod.tfvars
   ```
   Se a conta já tiver o provedor OIDC do GitHub, use `-var create_github_oidc_provider=false`.
2. No GitHub, em **Settings → Secrets and variables → Actions → Variables**, crie as variáveis com os
   outputs do Terraform:

   | Variável | Valor |
   |----------|-------|
   | `DEPLOY_ENABLED` | `true` |
   | `AWS_REGION` | `us-east-1` |
   | `AWS_ROLE_ARN` | output `github_actions_role_arn` |
   | `ECR_REPOSITORY_URL` | output `ecr_repository_url` |
   | `DEPLOY_BUCKET` | output `deploy_bucket` |
   | `EC2_INSTANCE_ID` | output `instance_id` |
   | `APP_URL` | output `app_url` |

3. Em **Settings → Environments**, crie o ambiente `production` e marque **Required reviewers**
   (você mesmo) para exigir aprovação antes de cada deploy.
4. Faça um push na `main` e acompanhe em **Actions**.

Nenhuma chave de acesso fica no GitHub: o pipeline assume uma role IAM via OIDC com permissões mínimas.
A senha do Grafana é gerada pelo Terraform e guardada no SSM Parameter Store.

> Para evitar custos, destrua o ambiente ao final: `terraform destroy -var-file=environments/prod.tfvars`.

## Monitoramento e logs

- **Métricas:** `/metrics` (Prometheus) — requisições por rota/status, latência (histograma), tarefas armazenadas.
- **Dashboard:** Grafana provisionado automaticamente ("API de Tarefas - Visão Geral").
- **Alertas Prometheus:** API fora do ar, taxa de erro 5xx > 5%, latência p95 > 500 ms.
- **Logs:** JSON estruturado no stdout, enviados ao CloudWatch Logs pelo driver `awslogs`.
- **Alarmes CloudWatch (SNS/e-mail):** CPU > 80%, falha de status check da EC2, erros 5xx da API.
