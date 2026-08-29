"""
API FastAPI das Fases 1 e 2 (ver CLAUDE.md, secao "Nova frente" >
"Arquitetura escolhida"). Fase 1: recebe os campos de uma fazenda, roda o
fluxo de traducao + execucao do RuFaS (herd init -> simulacao) validado
pela PoC, e disponibiliza o CSV de resultado. Fase 2: expoe a mesma logica
de filtragem do dashboard Streamlit (backend/filters.py, copia de
dashboard/filters.py) para o app consumir sem carregar o CSV inteiro.

Limitacoes conhecidas desta fase (ver CLAUDE.md para detalhes e motivo):
- Uma simulacao por vez (fila serializada em memoria, sem fila externa).
- Sem Docker, sem autenticacao — uso local apenas.
- Arquivos gerados por simulacao (input/output com prefixo farm_<id>) nao
  sao limpos automaticamente (prioridade a resolver ao robustecer o backend).

Uso:
    cd /Users/leandro/projetoRuFaS/RuFaS
    source venv/bin/activate
    PYTHONPATH=/Users/leandro/projetoRuFaS uvicorn backend.app:app --reload
"""

import queue
import threading
import time
import uuid
from dataclasses import asdict

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from backend import data_reader
from backend import farm_translation as ft
from backend import filters as flt
from backend import simulation_runner

app = FastAPI(title="RuFaS Farm API", version="0.1.0")

# CORS liberado para desenvolvimento local do app Flutter (web + desktop/
# mobile). Sem autenticacao nesta fase, entao nao ha credenciais/cookies
# envolvidos — origem "*" e aceitavel apenas porque tudo roda local.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class FarmInputRequest(BaseModel):
    cow_num: int = Field(gt=0, description="Numero de vacas em lactacao")
    calf_num: int = Field(ge=0, description="Numero de bezerras")
    annual_milk_yield: float = Field(gt=0, description="Meta de producao de leite anual (kg/ano)")
    field_size_1: float = Field(gt=0, description="Tamanho do campo 1 (acres)")
    field_size_2: float = Field(gt=0, description="Tamanho do campo 2 (acres)")
    fips_county_code: int = Field(gt=0, description="Codigo FIPS do condado (define clima/regiao)")


# Estado em memoria — nao persiste entre reinicios do processo (aceitavel
# na Fase 1, ver limitacoes no CLAUDE.md).
JOBS: dict[str, dict] = {}

# Fila serializada: um worker unico consome job_queue e roda uma simulacao
# de cada vez, mesmo que varias requisicoes cheguem simultaneamente. Isso
# evita duas instancias de TaskManager (cada uma com seu proprio
# multiprocessing.Pool) competindo por CPU/memoria ao mesmo tempo.
job_queue: queue.Queue[str] = queue.Queue()


def _worker_loop() -> None:
    while True:
        simulation_id = job_queue.get()
        job = JOBS[simulation_id]
        simulation_runner.run_full_simulation(simulation_id, job["farm"], job)
        job_queue.task_done()


threading.Thread(target=_worker_loop, daemon=True).start()


def _get_job(simulation_id: str) -> dict:
    job = JOBS.get(simulation_id)
    if job is None:
        raise HTTPException(status_code=404, detail="simulation_id desconhecido")
    return job


def _require_result_csv(simulation_id: str) -> str:
    job = _get_job(simulation_id)
    if job["state"] != "done" or not job["csv_path"]:
        raise HTTPException(status_code=409, detail=f"Simulacao ainda nao concluida (estado atual: {job['state']})")
    return job["csv_path"]


@app.get("/simulations")
def list_simulations() -> list[dict]:
    """Historico de simulacoes (mais recente primeiro) — o app usa isso pra
    listar fazendas com 'ver resultados'."""
    jobs = sorted(JOBS.items(), key=lambda item: item[1]["created_at"], reverse=True)
    return [
        {
            "simulation_id": sid,
            "state": job["state"],
            "created_at": job["created_at"],
            "farm": asdict(job["farm"]),
        }
        for sid, job in jobs
    ]


@app.post("/simulations", status_code=202)
def create_simulation(farm_input: FarmInputRequest) -> dict:
    simulation_id = uuid.uuid4().hex[:12]
    JOBS[simulation_id] = {
        "state": "queued",
        "farm": ft.FarmInput(**farm_input.model_dump()),
        "created_at": time.time(),
        "csv_path": None,
        "csv_size_bytes": None,
        "error": None,
    }
    job_queue.put(simulation_id)
    return {"simulation_id": simulation_id, "state": "queued", "queue_position": job_queue.qsize()}


@app.get("/simulations/{simulation_id}")
def get_simulation_status(simulation_id: str) -> dict:
    job = _get_job(simulation_id)
    return {
        "simulation_id": simulation_id,
        "state": job["state"],
        "created_at": job["created_at"],
        "error": job["error"],
    }


@app.get("/simulations/{simulation_id}/result")
def get_simulation_result(simulation_id: str) -> dict:
    _require_result_csv(simulation_id)
    job = JOBS[simulation_id]
    return {
        "simulation_id": simulation_id,
        "csv_size_bytes": job["csv_size_bytes"],
        "download_url": f"/simulations/{simulation_id}/download",
    }


@app.get("/simulations/{simulation_id}/download")
def download_simulation_csv(simulation_id: str) -> FileResponse:
    csv_path = _require_result_csv(simulation_id)
    return FileResponse(csv_path, media_type="text/csv", filename=f"farm_{simulation_id}_resultado.csv")


class FilterPreviewRequest(BaseModel):
    modules: list[str] = []
    keywords: list[str] = []
    pattern: str | None = None


@app.get("/simulations/{simulation_id}/columns")
def get_simulation_columns(simulation_id: str) -> dict:
    csv_path = _require_result_csv(simulation_id)
    columns = data_reader.read_columns(csv_path)
    return {
        "columns": columns,
        "modules": flt.list_modules(columns),
        "keywords_available": flt.list_available_keywords(columns),
    }


@app.post("/simulations/{simulation_id}/filters/preview")
def preview_filter(simulation_id: str, request: FilterPreviewRequest) -> dict:
    csv_path = _require_result_csv(simulation_id)
    columns = data_reader.read_columns(csv_path)
    pattern = request.pattern if request.pattern is not None else flt.build_regex(request.modules, request.keywords)
    selected_columns = flt.select_columns(columns, pattern)
    return {"pattern": pattern, "selected_columns": selected_columns, "count": len(selected_columns)}


@app.get("/simulations/{simulation_id}/chart-data")
def get_chart_data(
    simulation_id: str,
    columns: str = Query(..., description="Nomes de coluna separados por virgula"),
    max_points: int = Query(3000, ge=1, le=50000),
) -> dict:
    csv_path = _require_result_csv(simulation_id)
    requested_columns = [c.strip() for c in columns.split(",") if c.strip()]
    if not requested_columns:
        raise HTTPException(status_code=400, detail="informe ao menos uma coluna em 'columns'")

    all_columns = data_reader.read_columns(csv_path)
    unknown_columns = [c for c in requested_columns if c not in all_columns]
    if unknown_columns:
        raise HTTPException(status_code=400, detail=f"colunas desconhecidas: {unknown_columns}")

    time_column = next((c for c in all_columns if flt.is_time_column(c) and "simulation_day" in c), None)
    if time_column is None:
        time_column = next((c for c in all_columns if flt.is_time_column(c)), None)
    if time_column is None:
        raise HTTPException(status_code=409, detail="nenhuma coluna RufasTime.* encontrada para eixo de tempo")
    # Mesma regra do dashboard (dashboard/app.py): rotulo amigavel pronto
    # pro app nao precisar traduzir o nome tecnico da coluna.
    time_column_label = "dia de simulação" if "simulation_day" in time_column else flt.short_label(time_column)

    load_columns = list(dict.fromkeys([time_column] + requested_columns))
    df = data_reader.read_data(csv_path, load_columns)

    # Reporters diferentes tem contagens de linha diferentes e sao colados
    # lado a lado (ver CLAUDE.md, "Achado tecnico sobre o CSV de saida") —
    # amostrar sobre len(df) inteiro (dominado pelo reporter com mais
    # linhas) descartaria quase toda a serie de colunas de reporters mais
    # esparsos. Por isso filtramos para as linhas onde pelo menos uma
    # coluna pedida tem dado antes de amostrar.
    rows_with_data = df[df[requested_columns].notna().any(axis=1)]

    total_points = len(rows_with_data)
    step = max(1, total_points // max_points) if total_points else 1
    sampled = rows_with_data.iloc[::step]

    series = {}
    for column in requested_columns:
        series[column] = {
            "classification": flt.classify_column(column, df[column]),
            "values": data_reader.json_safe_values(sampled[column]),
        }

    return {
        "time_column": time_column,
        "time_column_label": time_column_label,
        "time": data_reader.json_safe_values(sampled[time_column]),
        "total_points": total_points,
        "sampled_points": len(sampled),
        "series": series,
    }
