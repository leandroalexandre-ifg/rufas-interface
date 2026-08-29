"""Agrega um CSV de resultado do RuFaS de resolução diária para semanal.

O QUE FAZ
---------
Lê um CSV de resultado do RuFaS (ex.: freestall_resultado.csv, ~900MB,
3.322 colunas, 255.918 linhas) e gera uma versão muito menor (~12MB,
366 linhas — uma por semana da simulação), mantendo TODAS as colunas
originais. Decisão registrada em CLAUDE.md ("Redução de tamanho via
agregação temporal").

Por que 366 linhas e não ~36.560 (255.918 / 7): as 255.918 linhas do
arquivo NÃO são um dia por linha. O CSV é montado por
`OutputManager._dict_to_file_csv` colando (pandas.concat) ~50 tabelas de
"reporters" diferentes lado a lado, cada uma com sua própria contagem de
linhas. A simulação em si cobre só 2.556 dias (~366 semanas). Rodar este
script sobre um CSV de resultado diferente pode produzir uma contagem de
semanas diferente (depende da duração da simulação), mas a lógica de
agregação é a mesma.

COMO A AGREGAÇÃO FUNCIONA (por grupo de colunas)
-------------------------------------------------
Colunas são agrupadas pelo padrão de células preenchidas (quais linhas têm
valor) — colunas com o mesmo padrão vieram do mesmo "reporter" e comungam
a mesma base de tempo. Cada grupo é tratado de um jeito:

- Grupo A (colunas alinhadas por posição com RufasTime.simulation_day,
  a maioria das variáveis diárias de campo/fazenda): semana = dia // 7,
  média (numéricas) ou moda (texto/categórico) por semana.
- Grupo B (dados de ordenha, ~100 linhas/dia, tem seu próprio
  simulation_day em toda linha): mesmo tratamento, usando o campo de dia
  próprio do grupo.
- Grupo C (outros "reporters" de evento com campo de dia próprio, ex.
  falha de ração, colheita, estoque): mesmo tratamento, um campo de dia
  por subgrupo.
- Grupo D (colunas com valor único em toda a simulação, ex. seed
  aleatória, parâmetros de curva de lactação): valor repetido em todas as
  semanas — EXCETO as colunas de log de eventos por animal
  (`AnimalModuleReporter._record_animal_events.*`, reprs de texto
  gigantes com o dia embutido no nome, ex. "..._day_2556"): essas são um
  dump único de fim de simulação, não um dado recorrente — colocadas só
  na semana real daquele dia, vazias nas demais (evita inflar o arquivo
  ~366x com texto repetido).
- Grupo E1 (variáveis diárias de cultura por instância de plantio, nome
  contém "planted=DDD,YYYY" — DDD=dia juliano, YYYY=ano civil): a
  simulação NÃO alinha essas colunas por posição com RufasTime (cada
  instância de cultura recomeça sua própria contagem do zero no
  plantio). Reconstrução validada contra o código-fonte do RuFaS
  (RUFAS/biophysical/field/manager/field_data_reporter.py e
  RUFAS/biophysical/field/crop/crop.py): posição 0 da lista = dia do
  plantio, cada posição seguinte = +1 dia corrido, sem lacunas (só o dia
  de remoção final da cultura não é gravado). dia_simulação = (data do
  plantio − 1/jan do ano-base da simulação) + posição_na_lista.
- Grupo E2 (variáveis de estoque de silo/feno/grão por lote, nome contém
  "stored_date=YYYY-MM-DD"): diferente do E1 — validado contra
  RUFAS/biophysical/feed_storage/storage.py e simulation_engine.py.
  Posição 0 = dia do armazenamento (stored_date). As posições seguintes
  NÃO são +1 dia: seguem um cronograma global de processamento de
  degradação a cada exatamente 30 dias (compartilhado por todos os
  estoques, começando no dia 0 da simulação — GRAIN_CROPS/
  HIGH_MOISTURE_CROPS ganham um ponto extra em +1 dia por perda de
  processamento no recebimento).
- Colunas sem grupo reconhecido (sem RufasTime alinhado, sem campo de dia
  próprio, sem padrão "planted="/"stored_date=" e sem valor único):
  mantidas no arquivo (nenhuma coluna é removida), mas vazias em todas as
  semanas — não há como posicioná-las no calendário com confiança sem
  investigar o código-fonte daquele "reporter" especificamente.

Duas colunas novas são adicionadas para referência: `week_index` (0, 1,
2, ...) e `week_start_date` (data civil do início daquela semana). As
3.322 colunas originais continuam todas presentes.

COMO RODAR
----------
    cd dashboard
    source .venv/bin/activate
    python scripts/aggregate_weekly.py <caminho_csv_entrada> <caminho_csv_saida>

Exemplo:
    python scripts/aggregate_weekly.py \\
        ../hf-space/data/freestall_resultado.csv \\
        ../hf-space/data/freestall_resultado_semanal.csv

Requer bastante RAM (o script carrega o CSV inteiro na memória — testado
com um arquivo de 915MB/24GB de RAM disponível, uso de pico bem abaixo
do total). Não sobrescreve nada automaticamente: o CSV de saída fica
apenas em disco, cabe a quem rodar decidir se/quando versionar ou
publicar.
"""

import argparse
import hashlib
import os
import re
from collections import defaultdict
from datetime import date, timedelta

import numpy as np
import pandas as pd

START_DATE = date(2013, 1, 1)
RUFASTIME_COL = "RufasTime.simulation_day (simulation day)"
MILK_DAY_COL = (
    "AnimalModuleReporter.report_milk.milk_data_at_milk_update.simulation_day (simulation day)"
)

GRAIN_CROPS = {"cereal_rye_grain", "corn_grain", "soybean_grain", "triticale_grain", "winter_wheat_grain"}
HIGH_MOISTURE_CROPS = {"corn_high_moisture"}
DEGRADATION_INTERVAL_DAYS = 30

PLANTED_RE = re.compile(r"planted=(\d+),(\d+)")
STORED_RE = re.compile(r"crop='([^']+)',stored_date=(\d{4}-\d{2}-\d{2})")
EVENT_DAY_RE = re.compile(r"_record_animal_events.*?_day_(\d+)\s*\(")


def is_day_like(colname: str) -> bool:
    """Detecta colunas cujo nome indica um campo de dia (aceita 'simulation_day' e
    'simulation day' com espaço — o RuFaS não é consistente nisso)."""
    seg = colname.rsplit(".", 1)[-1]
    seg_no_unit = re.sub(r"\s*\([^)]*\)\s*$", "", seg).strip().lower()
    seg_norm = seg_no_unit.replace(" ", "_")
    return bool(re.search(r"(^|_)day$|^sim_day$", seg_norm)) or "simulation_day" in seg_norm


def _aggregate_group(df: pd.DataFrame, cols: list[str], week_of_row: np.ndarray) -> dict[str, pd.Series]:
    """Agrega cada coluna do grupo por semana: média se numérica, moda caso contrário."""
    out = {}
    week_series = pd.Series(week_of_row)
    for c in cols:
        s = df[c].reset_index(drop=True)
        if pd.api.types.is_numeric_dtype(s) and not pd.api.types.is_bool_dtype(s):
            out[c] = s.groupby(week_series).mean()
        else:
            out[c] = s.groupby(week_series).agg(lambda x: x.mode().iloc[0] if not x.mode().empty else np.nan)
    return out


def aggregate_weekly(input_path: str, output_path: str) -> None:
    print(f"Lendo {input_path} ...")
    df = pd.read_csv(input_path, encoding="utf-8", low_memory=False)
    n_rows, n_cols = df.shape
    print(f"shape original: {df.shape}")

    notna = df.notna()

    # agrupa colunas pela assinatura exata de "quais linhas têm valor" -- colunas
    # do mesmo reporter compartilham a mesma assinatura
    sig_to_cols: dict[str, list[str]] = defaultdict(list)
    col_sig: dict[str, str] = {}
    for c in df.columns:
        h = hashlib.md5(notna[c].to_numpy().tobytes()).hexdigest()
        sig_to_cols[h].append(c)
        col_sig[c] = h

    rufastime_sig = col_sig[RUFASTIME_COL]
    milk_sig = col_sig[MILK_DAY_COL]

    max_sim_day = int(df[RUFASTIME_COL].max())
    n_weeks = max_sim_day // 7 + 1
    all_weeks = np.arange(n_weeks)
    print(f"simulação cobre {max_sim_day + 1} dias -> {n_weeks} semanas")

    weekly_data: dict[str, pd.Series] = {}
    handled_sigs: set[str] = set()

    # ---- grupo A: alinhado por posição com RufasTime ----
    bucket_a_cols = sig_to_cols[rufastime_sig]
    idx_a = notna[RUFASTIME_COL]
    week_a = (df.loc[idx_a, RUFASTIME_COL].astype(int).to_numpy()) // 7
    weekly_data.update(_aggregate_group(df.loc[idx_a], bucket_a_cols, week_a))
    handled_sigs.add(rufastime_sig)
    print(f"Grupo A: {len(bucket_a_cols)} colunas")

    # ---- grupo B: ordenha (campo de dia próprio em toda linha) ----
    bucket_b_cols = sig_to_cols[milk_sig]
    week_b = (df[MILK_DAY_COL].astype(int).to_numpy()) // 7
    weekly_data.update(_aggregate_group(df, bucket_b_cols, week_b))
    handled_sigs.add(milk_sig)
    print(f"Grupo B: {len(bucket_b_cols)} colunas")

    # ---- grupo C: outros reporters com campo de dia próprio no grupo ----
    bucket_c_count = 0
    for h, cols in sig_to_cols.items():
        if h in handled_sigs:
            continue
        day_cols = [c for c in cols if is_day_like(c)]
        if not day_cols:
            continue
        day_col = day_cols[0]
        idx = notna[day_col]
        if idx.sum() == 0 or not pd.api.types.is_numeric_dtype(df.loc[idx, day_col]):
            continue
        week_c = (df.loc[idx, day_col].astype(float).to_numpy() // 7).astype(int)
        weekly_data.update(_aggregate_group(df.loc[idx], cols, week_c))
        handled_sigs.add(h)
        bucket_c_count += len(cols)
    print(f"Grupo C: {bucket_c_count} colunas")

    # ---- grupo D: valor único -- broadcast, exceto dumps de evento por animal ----
    bucket_d_count = 0
    bucket_d_event_count = 0
    for h, cols in sig_to_cols.items():
        if h in handled_sigs:
            continue
        if notna[cols[0]].sum() != 1:
            continue
        for c in cols:
            val = df[c].dropna()
            if val.empty:
                continue
            m = EVENT_DAY_RE.search(c)
            if m:
                event_week = int(m.group(1)) // 7
                s = pd.Series(np.nan, index=all_weeks, dtype="object")
                s.loc[event_week] = val.iloc[0]
                weekly_data[c] = s
                bucket_d_event_count += 1
            else:
                weekly_data[c] = pd.Series(val.iloc[0], index=all_weeks)
        handled_sigs.add(h)
        bucket_d_count += len(cols)
    print(f"Grupo D: {bucket_d_count} colunas ({bucket_d_event_count} dumps de evento, não repetidas)")

    # ---- grupo E1: culturas via planted=DDD,YYYY ----
    bucket_e1_count = 0
    for h, cols in sig_to_cols.items():
        if h in handled_sigs:
            continue
        m = PLANTED_RE.search(cols[0])
        if not m:
            continue
        day_j, year_j = int(m.group(1)), int(m.group(2))
        planting_date = date(year_j, 1, 1) + timedelta(days=day_j - 1)
        planting_sim_day = (planting_date - START_DATE).days
        idx = notna[cols[0]]
        n = int(idx.sum())
        sim_days = np.array([planting_sim_day + p for p in range(n)])
        week_e1 = sim_days // 7
        weekly_data.update(_aggregate_group(df.loc[idx], cols, week_e1))
        handled_sigs.add(h)
        bucket_e1_count += len(cols)
    print(f"Grupo E1 (culturas, plantio): {bucket_e1_count} colunas")

    # ---- grupo E2: estoque via stored_date=YYYY-MM-DD (ciclo de degradação de 30 dias) ----
    bucket_e2_count = 0
    for h, cols in sig_to_cols.items():
        if h in handled_sigs:
            continue
        m = STORED_RE.search(cols[0])
        if not m:
            continue
        crop_name, stored_date_str = m.group(1), m.group(2)
        stored_day = (date.fromisoformat(stored_date_str) - START_DATE).days
        idx = notna[cols[0]]
        n = int(idx.sum())
        seq = [stored_day]
        if crop_name in GRAIN_CROPS or crop_name in HIGH_MOISTURE_CROPS:
            seq.append(stored_day + 1)
        d = 0
        while len(seq) < n and d <= max_sim_day:
            if d > seq[-1]:
                seq.append(d)
            d += DEGRADATION_INTERVAL_DAYS
        week_e2 = np.array(seq[:n]) // 7
        weekly_data.update(_aggregate_group(df.loc[idx], cols, week_e2))
        handled_sigs.add(h)
        bucket_e2_count += len(cols)
    print(f"Grupo E2 (estoque, degradação): {bucket_e2_count} colunas")

    # ---- restante: mantidas, vazias em todas as semanas ----
    leftover_count = 0
    for h, cols in sig_to_cols.items():
        if h in handled_sigs:
            continue
        for c in cols:
            weekly_data[c] = pd.Series(np.nan, index=all_weeks, dtype="float64")
        leftover_count += len(cols)
    print(f"Sem grupo reconhecido (mantidas, vazias): {leftover_count} colunas")

    total_handled = (
        len(bucket_a_cols) + len(bucket_b_cols) + bucket_c_count
        + bucket_d_count + bucket_e1_count + bucket_e2_count + leftover_count
    )
    assert total_handled == n_cols, f"cobertura incompleta: {total_handled} != {n_cols}"
    assert set(df.columns) == set(weekly_data.keys()), "alguma coluna original ficou de fora"

    print("Montando tabela final...")
    weekly_df = pd.concat(
        {c: weekly_data[c].reindex(all_weeks) for c in df.columns}, axis=1
    )
    weekly_df.insert(0, "week_index", all_weeks)
    weekly_df.insert(1, "week_start_date", [START_DATE + timedelta(days=int(w * 7)) for w in all_weeks])

    print(f"shape final: {weekly_df.shape}")
    weekly_df.to_csv(output_path, index=False)
    size_mb = os.path.getsize(output_path) / 1e6
    print(f"gravado em {output_path} ({size_mb:.2f} MB)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input_csv", help="CSV de resultado do RuFaS (resolução diária)")
    parser.add_argument("output_csv", help="Caminho do CSV agregado (resolução semanal) a gerar")
    args = parser.parse_args()
    aggregate_weekly(args.input_csv, args.output_csv)


if __name__ == "__main__":
    main()
