import pytest
from fastapi.testclient import TestClient

from app.main import app, reset_storage

client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_storage():
    reset_storage()
    yield
    reset_storage()


def test_health_retorna_ok():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_lista_vazia_inicialmente():
    assert client.get("/tasks").json() == []


def test_cria_tarefa():
    resp = client.post("/tasks", json={"title": "Configurar CI"})
    assert resp.status_code == 201
    body = resp.json()
    assert body == {"id": 1, "title": "Configurar CI", "done": False}


def test_rejeita_titulo_vazio():
    resp = client.post("/tasks", json={"title": ""})
    assert resp.status_code == 422


def test_busca_tarefa_existente():
    client.post("/tasks", json={"title": "Escrever Terraform"})
    resp = client.get("/tasks/1")
    assert resp.status_code == 200
    assert resp.json()["title"] == "Escrever Terraform"


def test_busca_tarefa_inexistente_retorna_404():
    assert client.get("/tasks/99").status_code == 404


def test_atualiza_tarefa():
    client.post("/tasks", json={"title": "Criar testes"})
    resp = client.put("/tasks/1", json={"title": "Criar testes", "done": True})
    assert resp.status_code == 200
    assert resp.json()["done"] is True


def test_atualiza_tarefa_inexistente_retorna_404():
    resp = client.put("/tasks/42", json={"title": "x"})
    assert resp.status_code == 404


def test_remove_tarefa():
    client.post("/tasks", json={"title": "Temporária"})
    assert client.delete("/tasks/1").status_code == 204
    assert client.get("/tasks/1").status_code == 404


def test_remove_tarefa_inexistente_retorna_404():
    assert client.delete("/tasks/7").status_code == 404
