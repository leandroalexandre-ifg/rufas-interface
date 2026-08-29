"""Dashboard de visualização de resultados do RuFaS (marco 1).

Lê um CSV de resultado já gerado pelo RuFaS e permite filtrar e explorar
as variáveis. Não executa o modelo nem gera arquivos de entrada.
"""

import os
from pathlib import Path

import plotly.express as px
import streamlit as st

from data_loader import read_columns, read_data, save_uploaded_file
from filters import (
    build_regex,
    classify_column,
    is_time_column,
    list_available_keywords,
    list_modules,
    select_columns,
    short_label,
)

MAX_POINTS_PER_CHART = 3000
MAX_VARIABLES_TO_PLOT = 3
CHART_HEIGHT = 400

# CSV incluído no próprio repositório (resolução semanal, ~12MB — cabe em
# git normal, sem LFS) — carregado automaticamente ao abrir, sem depender
# de upload. Caminho resolvido a partir deste arquivo, não do diretório de
# trabalho, pra funcionar igual local ou publicado.
LOCAL_CSV_PATH = Path(__file__).parent / "data" / "freestall_resultado_semanal.csv"

st.set_page_config(page_title="Resultados do RuFaS", layout="wide")
st.title("Dashboard de Resultados do RuFaS")

if st.button("Limpar cache"):
    save_uploaded_file.clear()
    st.session_state.pop("loaded_columns", None)
    st.rerun()

path = None
if LOCAL_CSV_PATH.is_file():
    path = str(LOCAL_CSV_PATH)
    st.caption(f"Usando o CSV incluído no repositório: {LOCAL_CSV_PATH.name}")
else:
    st.subheader("Envie o CSV de resultado do RuFaS")
    uploaded_file = st.file_uploader("Arquivo CSV de resultado da simulação", type=["csv", "txt"])

    if uploaded_file is None:
        st.info("Envie um arquivo CSV de resultado do RuFaS acima para começar.")
        st.stop()

    try:
        path = save_uploaded_file(uploaded_file)
        st.caption(f"Arquivo enviado: {uploaded_file.name}")
    except Exception as exc:
        st.error(f"Não foi possível processar o arquivo enviado: {exc}")
        st.stop()

if not os.path.isfile(path):
    st.error(f"Arquivo não encontrado após o carregamento: {path}")
    st.stop()

try:
    with st.spinner("Lendo cabeçalho do arquivo..."):
        columns = read_columns(path)
except Exception as exc:
    st.error(f"Não foi possível ler o arquivo como CSV: {exc}")
    st.stop()

st.caption(f"{len(columns)} colunas encontradas no arquivo.")

st.subheader("Filtro amigável")
col1, col2 = st.columns(2)
with col1:
    selected_modules = st.multiselect("Módulo", options=list_modules(columns))
with col2:
    selected_keywords = st.multiselect("Palavra-chave", options=list_available_keywords(columns))

default_pattern = build_regex(selected_modules, selected_keywords)

st.subheader("Padrão de filtro (regex)")
pattern = st.text_input(
    "Editável — o mesmo mecanismo usado pelos filtros nativos do RuFaS "
    "(output/output_filters/)",
    value=default_pattern,
)

selected_columns = select_columns(columns, pattern)
st.caption(
    f"{len(selected_columns)} colunas selecionadas "
    "(colunas de tempo são sempre incluídas)."
)

if st.button("Carregar dados", type="primary"):
    st.session_state["loaded_columns"] = selected_columns

# Usamos session_state (não o retorno direto de st.button) porque qualquer
# interação com os widgets abaixo (ex.: o seletor de variáveis do gráfico)
# causa um novo rerun do script, e nesse rerun st.button volta a ser False —
# sem isso, a tabela e o gráfico desapareceriam a cada clique no seletor.
if "loaded_columns" not in st.session_state:
    st.stop()

try:
    with st.spinner("Carregando dados selecionados..."):
        df = read_data(path, st.session_state["loaded_columns"])
except Exception as exc:
    st.error(f"Erro ao carregar os dados: {exc}")
    st.stop()

st.subheader("Tabela de dados")
st.dataframe(df, use_container_width=True)

time_col = next((c for c in df.columns if is_time_column(c) and "simulation_day" in c), None)
if time_col is None:
    time_col = next((c for c in df.columns if is_time_column(c)), None)
time_axis_label = "dia de simulação" if time_col and "simulation_day" in time_col else (
    short_label(time_col) if time_col else None
)

st.subheader("Gráfico")

if time_col is None:
    st.info("Nenhuma coluna de tempo (RufasTime.*) encontrada para o eixo X dos gráficos.")
    st.stop()

classifications = {c: classify_column(c, df[c]) for c in df.columns if not is_time_column(c)}
plot_options = [c for c, label in classifications.items() if label in ("plottable", "categorical")]
plot_options.sort()


def _format_option(column: str) -> str:
    suffix = " · possivelmente categórica" if classifications[column] == "categorical" else ""
    return short_label(column) + suffix


if not plot_options:
    st.info("Nenhuma variável numérica adequada para gráfico nas colunas selecionadas.")
    st.stop()

selected_vars = st.multiselect(
    f"Escolha até {MAX_VARIABLES_TO_PLOT} variáveis para plotar",
    options=plot_options,
    format_func=_format_option,
    max_selections=MAX_VARIABLES_TO_PLOT,
    default=[],
)

if not selected_vars:
    st.caption("Nenhuma variável selecionada ainda — escolha acima para ver o gráfico.")
    st.stop()

chart_df = df
if len(df) > MAX_POINTS_PER_CHART:
    step = len(df) // MAX_POINTS_PER_CHART
    chart_df = df.iloc[::step]
    st.caption(
        f"Amostrado para exibição: 1 a cada {step} registros "
        f"({len(chart_df)} pontos plotados de {len(df)})."
    )

for column in selected_vars:
    st.caption(f"Nome completo: `{column}`")
    try:
        fig = px.line(chart_df, x=time_col, y=column, height=CHART_HEIGHT)
        fig.update_layout(
            title=short_label(column),
            xaxis_title=time_axis_label,
            yaxis_title=short_label(column),
            margin=dict(t=40, b=20),
        )
        st.plotly_chart(fig, use_container_width=True)
    except Exception:
        st.warning(f"Não foi possível gerar o gráfico para {short_label(column)}.")
