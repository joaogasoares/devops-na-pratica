# ---------- Estágio 1: instala as dependências ----------
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- Estágio 2: imagem final enxuta ----------
FROM python:3.12-slim

ARG APP_VERSION=dev
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION}

LABEL org.opencontainers.image.title="devops-na-pratica" \
      org.opencontainers.image.version="${APP_VERSION}"

WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/ ./app/

# Executa sem privilégios de root (DevSecOps)
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# O Docker marca o container como "unhealthy" se /health parar de responder
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health', timeout=2).status == 200 else 1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
