"""Leitura eficiente do CSV de resultado do RuFaS.

O arquivo pode ter milhares de colunas e ~1GB, então nunca carregamos tudo:
primeiro lemos só o cabeçalho para montar os filtros, depois carregamos
apenas as colunas selecionadas pelo usuário.
"""

import os
import tempfile

import pandas as pd
import streamlit as st


_SAVE_CHUNK_SIZE = 4 * 1024 * 1024  # 4MB

_PROGRESS_BAR_HTML = """
<div style="margin: 0.4rem 0 1rem 0;">
  <div style="font-weight:600; margin-bottom:6px;">{label}</div>
  <div style="background:#dde3ea; border-radius:8px; height:30px; width:100%; overflow:hidden;">
    <div style="background:#1565C0; height:100%; width:{pct}%;
                display:flex; align-items:center; justify-content:flex-end;
                color:white; font-weight:700; font-size:0.85rem; padding-right:10px;
                white-space:nowrap; transition:width 0.15s linear;">
      {pct}%
    </div>
  </div>
</div>
"""


def _render_progress(placeholder, fraction: float, written: int, total: int) -> None:
    pct = int(min(fraction, 1.0) * 100)
    label = f"Salvando arquivo enviado... {written / 1e6:.0f} / {total / 1e6:.0f} MB"
    placeholder.markdown(_PROGRESS_BAR_HTML.format(label=label, pct=pct), unsafe_allow_html=True)


@st.cache_resource(show_spinner=False)
def save_uploaded_file(uploaded_file) -> str:
    """Salva o arquivo enviado via st.file_uploader em disco e retorna o
    caminho. Cacheado pelo próprio uploaded_file (Streamlit já sabe hashear
    esse tipo), então um novo upload gera um novo arquivo.

    Escreve em blocos (em vez de tudo de uma vez) para mostrar uma barra de
    progresso customizada (azul, com destaque — a st.progress nativa é fina
    demais e usa a cor do tema). Só aparece na primeira vez (cache miss); em
    reruns com o mesmo arquivo, o cache pula direto pro resultado."""
    suffix = os.path.splitext(uploaded_file.name)[1] or ".csv"
    fd, path = tempfile.mkstemp(prefix="rufas_upload_", suffix=suffix)
    total_size = uploaded_file.size or 0
    written = 0
    uploaded_file.seek(0)
    placeholder = st.empty()
    _render_progress(placeholder, 0.0, 0, total_size)
    try:
        with os.fdopen(fd, "wb") as f:
            while True:
                chunk = uploaded_file.read(_SAVE_CHUNK_SIZE)
                if not chunk:
                    break
                f.write(chunk)
                written += len(chunk)
                fraction = written / total_size if total_size else 1.0
                _render_progress(placeholder, fraction, written, total_size)
    finally:
        placeholder.empty()
    return path


@st.cache_data(show_spinner=False)
def get_columns(path: str, _mtime: float) -> list[str]:
    header = pd.read_csv(path, nrows=0, encoding="utf-8")
    return list(header.columns)


@st.cache_data(show_spinner=False)
def load_data(path: str, _mtime: float, columns: tuple[str, ...]) -> pd.DataFrame:
    # low_memory=False evita um IndexError do parser C do pandas 3.0.5 ao ler,
    # via usecols, colunas esparsas cujo valor é um repr de objeto Python
    # complexo (ex.: avg_essential_amino_acid_requirement).
    return pd.read_csv(path, usecols=list(columns), encoding="utf-8", low_memory=False)


def read_columns(path: str) -> list[str]:
    return get_columns(path, os.path.getmtime(path))


def read_data(path: str, columns: list[str]) -> pd.DataFrame:
    return load_data(path, os.path.getmtime(path), tuple(columns))
