# Funcionalidades — RuFaS Interface do Produtor

Descrição detalhada de cada funcionalidade: o que faz, como funciona por dentro, e como frontend e backend se conectam. Organizado pelo fluxo do usuário.

---

## 1. Cadastro de fazenda

**O que o usuário vê:** um formulário em três seções (Rebanho, Produção, Propriedade) com poucos campos em linguagem de fazenda.

**Campos** (os que a prova de conceito validou como suficientes):

| Campo | Alimenta no RuFaS | Observação |
|-------|-------------------|------------|
| Vacas em lactação | `cow_num` | inteiro > 0 |
| Bezerras | `calf_num` | inteiro ≥ 0 |
| Produção de leite típica | `annual_milk_yield` | float > 0 — **alvo de calibração, não garantia** |
| Tamanho da propriedade | `field_size_1`, `field_size_2` (2 campos) | float > 0 cada |
| Município / localização | `fips_county_code` | inteiro > 0 — ver gap do clima |

São exatamente estes 6 campos (`FarmInputRequest` em `backend/app.py`) — não há campo de raça nem de vacas secas nesta fase.

**Validação** (`form_validators.dart`): obrigatoriedade, tipo (inteiro/decimal, aceitando vírgula ou ponto), e faixa. Mensagens em português claro, centralizadas.

**Por dentro:** ao enviar, o app faz `POST /simulations` com os campos; o backend responde na hora com um `simulation_id` e dispara a simulação em background. O app retorna à lista, onde a nova fazenda aparece com estado "na fila".

> **Gap do clima:** hoje não há gerador de clima a partir da localização — o RuFaS usa um arquivo de clima selecionado. Traduzir "município" → arquivo de clima é trabalho de backend ainda pendente. O campo existe na interface; a tradução completa virá depois.

---

## 2. Tradução (backend, Etapa 2)

**O que faz:** converte os poucos campos do produtor na árvore de arquivos JSON/CSV que o RuFaS exige.

**Como funciona — substituição sobre o `freestall`:** parte dos arquivos do cenário de exemplo `freestall` (que já funcionam) e troca apenas os valores que descrevem a fazenda. A árvore referencia arquivos por caminho (nunca conteúdo embutido), então trocar um arquivo-folha não afeta os demais. A maior parte da árvore são constantes científicas (equações NRC/NASEM, coeficientes de emissão, parâmetros agronômicos) que permanecem intocadas.

**Isolamento:** cada execução usa um `simulation_id` no nome dos arquivos, evitando colisão entre simulações.

**Arquivo:** `backend/farm_translation.py`.

---

## 3. Execução da simulação (backend, Etapa 3)

**O que faz:** roda o RuFaS com a entrada gerada, em dois passos.

1. **`HERD_INITIALIZATION`** — gera a população animal individual a partir de `cow_num`/`calf_num` (com `save_animals: true`), escrevendo um `animal_population.json`.
2. **Simulação principal** — roda apontando para a população recém-gerada, produzindo o CSV de resultado.

**Assíncrono:** roda em background (BackgroundTask do FastAPI). O `multiprocessing` interno do RuFaS foi validado nesse contexto (Fase 1).

**Estados** expostos via API e traduzidos no app:

| Estado (API) | Exibição (app) |
|--------------|----------------|
| `queued` | na fila |
| `running_herd_init` | gerando rebanho |
| `running_simulation` | simulando |
| `done` | concluída |
| `failed` | falhou |

**Arquivo:** `backend/simulation_runner.py`.

---

## 4. Acompanhamento (frontend, Tela de status)

**O que faz:** acompanha uma simulação em andamento por polling.

- Consulta `GET /simulations/{id}` a cada ~5 segundos.
- Exibe o estado em linguagem de fazenda, com spinner e aviso de espera longa ("pode levar cerca de 10 minutos; você pode sair desta tela").
- **Para o polling** quando a simulação termina (`done`/`failed`) e quando o usuário sai da tela — não consulta indefinidamente.
- Erros de rede passageiros não cancelam o polling: mantêm o último estado e tentam de novo.
- **Falha:** mensagem sem jargão; detalhes técnicos (traceback) disponíveis atrás de um expansor "Detalhes técnicos".

**Arquivos:** `flutter_app/lib/screens/simulation_status_screen.dart`, `flutter_app/lib/core/simulation_states.dart`.

---

## 5. Filtragem de resultados (Tela de resultados, Parte A)

**O que faz:** reduz as ~3.322 colunas do resultado ao subconjunto de interesse — mesma lógica do dashboard original, exposta via API.

**Fluxo:**
1. `GET /simulations/{id}/columns` → módulos e palavras-chave disponíveis (lê só o cabeçalho do CSV, barato mesmo em ~900 MB).
2. O usuário seleciona módulos e palavras-chave por **chips** (caminho principal; regex não exposto por padrão).
3. Cada seleção dispara `POST /simulations/{id}/filters/preview` → contagem de colunas selecionadas ("N colunas selecionadas"), sem carregar dados (só aplica o regex ao cabeçalho).
4. **Avançado:** um padrão regex editável, escondido por padrão; editá-lo desativa os chips e vice-versa, de forma coerente.

**Colunas de tempo** (`RufasTime.*`) são sempre incluídas automaticamente.

**Arquivo:** `flutter_app/lib/screens/results_screen.dart`.

---

## 6. Visualização em gráfico (Tela de resultados, Parte B)

**O que faz:** plota as variáveis escolhidas como séries temporais.

**Fluxo:**
1. `GET /simulations/{id}/chart-data?columns=...` → o backend carrega só as colunas pedidas (`usecols`), escolhe o eixo de tempo (preferência por `simulation_day`), aplica **downsampling** (limite de pontos, ex. 3000) e devolve as séries prontas, com a **classificação** de cada coluna.
2. O app desenha um `LineChart` (`fl_chart`) por variável.

**Formato da resposta** (chave para o frontend; conferido linha a linha contra `get_chart_data` em `backend/app.py`):
```json
{
  "time_column": "RufasTime.simulation_day",
  "time_column_label": "dia de simulação",
  "time": [ ... ],
  "total_points": 2556,
  "sampled_points": 200,
  "series": {
    "daily_milk_production": { "classification": "plottable", "values": [ ... ] },
    "herd_milk_fat_percent": { "classification": "categorical", "values": [ ... ] },
    "cow_id": { "classification": "excluded_type", "values": [ ... ] }
  }
}
```
`total_points` é o tamanho real da série pedida (linhas onde pelo menos uma das colunas solicitadas tem dado — não o tamanho do CSV inteiro, que é dominado pelo reporter mais longo). `sampled_points` é quanto sobrou após o downsampling. Toda coluna em `series` sempre traz `values` (mesmo `excluded_type`/`no_data`) — a classificação é que decide se o app desenha o gráfico ou mostra a mensagem informativa.

**Tratamento por classificação:**
- `plottable` / `categorical` → gráfico de linha (categórica pode aparecer como linha quase constante, com aviso de "poucas variações").
- `excluded_*` / `no_data` / `time` → card informativo, **sem gráfico quebrado**.

**Detalhe técnico (Fase 3):** valores "constantes" com ruído de ponto flutuante geravam intervalo de eixo ~10⁻¹⁵, travando o cálculo de grade do `fl_chart`. Corrigido com um **epsilon** (intervalo mínimo) nos eixos X e Y.

**Arquivo:** `flutter_app/lib/screens/chart_screen.dart` (o card de cada gráfico, `_ChartCard`, é uma classe privada nesse mesmo arquivo — não há um widget separado em `widgets/`).

---

## 7. Download do resultado completo

**O que faz:** permite baixar o CSV completo da simulação (para quem quer os dados brutos, já que a tabela crua não é exposta no app — inadequada para tela pequena).

`GET /simulations/{id}/download` — serve o arquivo com suporte a range request (206 Partial Content), validado na Fase 1.

---

## 8. Identidade visual (Material 3)

**O que faz:** aplica um tema consistente às 4 telas.

- `ColorScheme.fromSeed` a partir do verde `#2E7D32`; secundária verde-claro `#A5D6A7`; acento âmbar `#F9A825`.
- Estilos de card, botão, campo, chip, checkbox e snackbar centralizados.
- Cores de estado com significado: verde (concluída), âmbar (em andamento), cinza (na fila), vermelho (falha).
- Centralizado em `app_theme.dart` — mudar o visual do app inteiro se faz num arquivo.

---

## Endpoints da API — referência rápida

| Método | Rota | Entrada | Saída |
|--------|------|---------|-------|
| `POST` | `/simulations` | campos da fazenda (JSON) | `simulation_id`, estado inicial |
| `GET` | `/simulations` | — | lista de simulações |
| `GET` | `/simulations/{id}` | — | estado atual (polling) |
| `GET` | `/simulations/{id}/result` | — | metadados do resultado |
| `GET` | `/simulations/{id}/download` | — | CSV completo (range) |
| `GET` | `/simulations/{id}/columns` | — | colunas, módulos, palavras-chave |
| `POST` | `/simulations/{id}/filters/preview` | módulos, palavras-chave, pattern? | pattern, colunas selecionadas, contagem |
| `GET` | `/simulations/{id}/chart-data` | columns, max_points | séries + classificação + eixo de tempo |

Assinaturas conferidas linha a linha contra as rotas reais em `backend/app.py`. A documentação interativa viva está em `http://localhost:8000/docs` (Swagger).
