"""Lógica de filtragem de colunas por módulo, palavra-chave e regex."""

import re

import pandas as pd

TIME_COLUMN_PREFIX = "RufasTime."
DEFAULT_CATEGORICAL_THRESHOLD = 10

# Segmento da variável (após o último ponto, sem a unidade) que indica
# identificador/booleano/índice de dia redundante — nunca é uma medição
# contínua, então nem entra como opção de gráfico. Sufixo exato "_day"
# (não "contém day") para não pegar medições legítimas como "days_in_milk".
_NAME_EXCLUDE_PATTERN = re.compile(r"(^|_)id$|^is_|^has_|_day$")

CANDIDATE_KEYWORDS = [
    "milk", "methane", "nitrogen", "population", "manure", "feed",
    "emission", "energy", "crop", "water", "weather", "lactation",
    "breed", "calf", "heifer", "cow", "dry", "event", "purchase",
    "ration", "replacement", "storage",
]


def get_module(column_name: str) -> str:
    """Primeiro segmento do nome da coluna (antes do primeiro ponto)."""
    return column_name.split(".", 1)[0]


def list_modules(columns: list[str]) -> list[str]:
    return sorted({get_module(c) for c in columns})


def list_available_keywords(columns: list[str]) -> list[str]:
    """Só oferece palavras-chave que de fato aparecem em algum nome de coluna."""
    lower_columns = [c.lower() for c in columns]
    return [
        kw for kw in CANDIDATE_KEYWORDS
        if any(kw in col for col in lower_columns)
    ]


def is_time_column(column_name: str) -> bool:
    return column_name.startswith(TIME_COLUMN_PREFIX)


def variable_segment(column_name: str) -> str:
    """Último segmento do nome (após o último ponto), sem a unidade."""
    last = column_name.rsplit(".", 1)[-1]
    return re.sub(r"\s*\([^)]*\)\s*$", "", last).strip()


def short_label(column_name: str) -> str:
    """Último segmento do nome, COM a unidade — para título/eixo do gráfico."""
    return column_name.rsplit(".", 1)[-1].strip()


def is_name_excluded(column_name: str) -> bool:
    """Nomes de identificador/booleano/índice de dia (ex.: cow_id, is_milking,
    harvest_day) — nunca fazem sentido como série temporal."""
    if is_time_column(column_name):
        return False
    return bool(_NAME_EXCLUDE_PATTERN.search(variable_segment(column_name).lower()))


def classify_column(
    column_name: str, series: pd.Series, categorical_threshold: int = DEFAULT_CATEGORICAL_THRESHOLD
) -> str:
    """Classifica uma coluna já carregada para a seleção de gráficos.

    Retorna um destes rótulos:
    - "time": eixo de tempo, não é uma opção de gráfico em si.
    - "excluded_name": nome indica id/booleano/dia — nunca plotável.
    - "excluded_type": não é numérica (texto, objeto, booleano) — não plotável.
    - "no_data": numérica mas sem nenhum valor no arquivo — nada para plotar.
    - "categorical": numérica com poucos valores distintos — plotável, mas
      sinalizada como possivelmente categórica; a decisão fica com o usuário.
    - "plottable": medição contínua normal.
    """
    if is_time_column(column_name):
        return "time"
    if is_name_excluded(column_name):
        return "excluded_name"
    if not pd.api.types.is_numeric_dtype(series) or pd.api.types.is_bool_dtype(series):
        return "excluded_type"

    non_null = series.dropna()
    if non_null.empty:
        return "no_data"
    if non_null.nunique() <= categorical_threshold:
        return "categorical"
    return "plottable"


def build_regex(modules: list[str], keywords: list[str]) -> str:
    """Combina módulos (âncora no início) e palavras-chave (em qualquer lugar)
    via AND: se ambos os filtros estiverem preenchidos, a coluna precisa
    casar os dois. Se nenhum estiver preenchido, casa tudo.
    """
    parts = []
    if modules:
        alternatives = "|".join(re.escape(m) for m in modules)
        parts.append(rf"(?=^(?:{alternatives})\.)")
    if keywords:
        alternatives = "|".join(re.escape(k) for k in keywords)
        parts.append(rf"(?=.*(?:{alternatives}))")

    if not parts:
        return ".*"
    return "".join(parts)


def select_columns(columns: list[str], pattern: str) -> list[str]:
    """Aplica o regex às colunas, sempre incluindo as colunas de tempo."""
    try:
        compiled = re.compile(pattern, re.IGNORECASE)
    except re.error:
        compiled = re.compile(re.escape(pattern), re.IGNORECASE)

    selected = [
        c for c in columns
        if is_time_column(c) or compiled.search(c)
    ]
    # garante que as colunas de tempo apareçam mesmo se não vierem primeiro
    time_cols = [c for c in columns if is_time_column(c) and c not in selected]
    return time_cols + selected
