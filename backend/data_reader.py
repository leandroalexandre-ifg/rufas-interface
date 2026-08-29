"""Leitura eficiente do CSV de resultado de uma simulacao, com cache em
memoria por mtime do arquivo — mesma ideia de dashboard/data_loader.py,
sem as partes amarradas ao Streamlit (st.cache_data, barra de progresso).

Cache simples, sem limite de tamanho nem expiracao (aceitavel para uso
local de um unico desenvolvedor nesta fase; ver limitacoes da Fase 1 no
CLAUDE.md sobre estado em memoria)."""

import math
from pathlib import Path

import pandas as pd

_columns_cache: dict[str, tuple[float, list[str]]] = {}
_data_cache: dict[tuple[str, tuple[str, ...]], tuple[float, pd.DataFrame]] = {}


def read_columns(path: str) -> list[str]:
    mtime = Path(path).stat().st_mtime
    cached = _columns_cache.get(path)
    if cached is not None and cached[0] == mtime:
        return cached[1]
    header = pd.read_csv(path, nrows=0, encoding="utf-8")
    columns = list(header.columns)
    _columns_cache[path] = (mtime, columns)
    return columns


def read_data(path: str, columns: list[str]) -> pd.DataFrame:
    mtime = Path(path).stat().st_mtime
    key = (path, tuple(sorted(columns)))
    cached = _data_cache.get(key)
    if cached is not None and cached[0] == mtime:
        return cached[1]
    # low_memory=False: mesma razao do dashboard, evita IndexError do parser
    # C do pandas ao ler colunas esparsas com repr de objeto Python via usecols.
    df = pd.read_csv(path, usecols=list(columns), encoding="utf-8", low_memory=False)
    _data_cache[key] = (mtime, df)
    return df


def json_safe_values(series: pd.Series) -> list:
    """Converte NaN para None — JSON estrito (ex.: o parser do Flutter/Dart)
    rejeita o token literal NaN que json.dumps produziria por padrao."""
    values = series.tolist()
    return [None if isinstance(v, float) and math.isnan(v) else v for v in values]
