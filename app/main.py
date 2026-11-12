"""API de Tarefas (To-Do) - aplicação de exemplo do projeto DevOps na Prática."""

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

APP_VERSION = "1.0.0"

app = FastAPI(title="DevOps na Prática - API de Tarefas", version=APP_VERSION)


class TaskIn(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    done: bool = False


class Task(TaskIn):
    id: int


# Armazenamento em memória (suficiente para a Fase 1).
_tasks: dict[int, Task] = {}
_next_id = 1


def reset_storage() -> None:
    """Limpa o armazenamento; usado pelos testes automatizados."""
    global _next_id
    _tasks.clear()
    _next_id = 1


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "version": APP_VERSION}


@app.get("/tasks", response_model=list[Task])
def list_tasks() -> list[Task]:
    return list(_tasks.values())


@app.post("/tasks", response_model=Task, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskIn) -> Task:
    global _next_id
    task = Task(id=_next_id, **payload.model_dump())
    _tasks[task.id] = task
    _next_id += 1
    return task


@app.get("/tasks/{task_id}", response_model=Task)
def get_task(task_id: int) -> Task:
    if task_id not in _tasks:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada")
    return _tasks[task_id]


@app.put("/tasks/{task_id}", response_model=Task)
def update_task(task_id: int, payload: TaskIn) -> Task:
    if task_id not in _tasks:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada")
    task = Task(id=task_id, **payload.model_dump())
    _tasks[task_id] = task
    return task


@app.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: int) -> None:
    if _tasks.pop(task_id, None) is None:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada")
