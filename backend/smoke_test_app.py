"""
Teste minimo de risco para a Fase 1 (ver CLAUDE.md, secao "Nova frente").

Pergunta a responder: TaskManager.start() do RuFaS (que usa
multiprocessing.Pool internamente) funciona quando chamado dentro de uma
BackgroundTask do FastAPI (que roda em thread de worker, nao na thread
principal)?

Este arquivo e descartavel — existe so para essa validacao, roda a task
SIMULATION_SINGLE_RUN da PoC (input/task_manager_metadata_poc_sim.json,
usa o animal_population ja gerado pela PoC em 2026-08-21) e nao faz parte
da API final.

Uso:
    cd /Users/leandro/projetoRuFaS/RuFaS
    source venv/bin/activate
    uvicorn backend.smoke_test_app:app --app-dir /Users/leandro/projetoRuFaS --reload
    (ou: PYTHONPATH=/Users/leandro/projetoRuFaS python -m uvicorn ...)

    curl -X POST http://127.0.0.1:8000/smoke-test/run
    curl http://127.0.0.1:8000/smoke-test/status
"""

import os
import time
import traceback
from pathlib import Path

from fastapi import BackgroundTasks, FastAPI

RUFAS_ROOT = Path("/Users/leandro/projetoRuFaS/RuFaS")
METADATA_PATH = Path("input/task_manager_metadata_poc_sim.json")

app = FastAPI(title="RuFaS smoke test")

status: dict = {"state": "idle", "started_at": None, "finished_at": None, "error": None}


def run_simulation() -> None:
    status["state"] = "running"
    status["started_at"] = time.time()
    original_cwd = Path.cwd()
    try:
        os.chdir(RUFAS_ROOT)
        from RUFAS.output_manager import LogVerbosity
        from RUFAS.task_manager import TaskManager

        task_manager = TaskManager()
        task_manager.start(
            metadata_path=METADATA_PATH,
            verbosity=LogVerbosity.ERRORS,
            exclude_info_maps=False,
            output_directory=Path("output/"),
            logs_directory=Path("output/logs"),
            clear_output_directory=False,
            produce_graphics=True,
            suppress_log_files=False,
            metadata_depth_limit=None,
        )
        status["state"] = "done"
    except Exception as e:
        status["state"] = "failed"
        status["error"] = f"{e}\n{traceback.format_exc()}"
    finally:
        os.chdir(original_cwd)
        status["finished_at"] = time.time()


@app.post("/smoke-test/run")
def trigger(background_tasks: BackgroundTasks) -> dict:
    if status["state"] == "running":
        return {"message": "ja esta rodando", "status": status}
    status.update({"state": "queued", "started_at": None, "finished_at": None, "error": None})
    background_tasks.add_task(run_simulation)
    return {"message": "disparado", "status": status}


@app.get("/smoke-test/status")
def get_status() -> dict:
    return status
