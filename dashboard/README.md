# Dashboard de Resultados do RuFaS

Dashboard local/web para explorar resultados de simulações do
[RuFaS](https://rufas.org) (Ruminant Farm Systems) sem precisar mexer em
código ou linha de comando.

Este é o **primeiro marco** de um projeto maior — cobre só a **visualização**
de um CSV de resultado já gerado por uma simulação anterior. Não roda o
modelo RuFaS, não gera arquivos de entrada e não faz "match" de planilhas.

## O que o dashboard faz

1. **Carregamento automático** do CSV agregado incluído no próprio
   repositório (`data/freestall_resultado_semanal.csv`) — abre já com dados,
   sem precisar enviar nada. Se esse arquivo não estiver presente (ex.:
   clone sem o `data/`), cai automaticamente no **upload manual**
   (arrastar e soltar ou selecionar o arquivo — suporta até 1GB).
2. **Filtro** das variáveis a exibir, de duas formas complementares:
   - **Amigável**: menus de módulo (`AnimalModuleReporter`, `FieldDataReporter`,
     etc.) e palavra-chave temática (milk, methane, population...).
   - **Regex**: o padrão gerado pelo filtro amigável aparece num campo de
     texto editável — o mesmo mecanismo que o RuFaS usa nativamente em
     `output/output_filters/`.
3. **Tabela** navegável com as colunas selecionadas.
4. **Gráficos** de série temporal (eixo X = dia de simulação) para até 3
   variáveis por vez, escolhidas manualmente num seletor — nada é plotado
   automaticamente. Variáveis que não fazem sentido como série temporal
   (identificadores, booleanos, texto) ficam de fora do seletor de gráfico,
   mas continuam visíveis na tabela; variáveis numéricas de baixa
   cardinalidade aparecem marcadas como "possivelmente categórica" em vez
   de serem escondidas.

## Agregação semanal (redução de tamanho)

O CSV de resultado bruto do RuFaS chega perto de 1GB — grande demais para
o limite de memória do plano gratuito do Streamlit Community Cloud.
`scripts/aggregate_weekly.py` converte um CSV de resolução **diária**
(centenas de milhares de linhas) para resolução **semanal** (algumas
centenas de linhas), mantendo **todas** as colunas originais — só reduz
linhas, nunca remove variáveis. No arquivo real testado: 915MB → ~12MB.

```bash
python scripts/aggregate_weekly.py <entrada.csv> <saida.csv>
```

Detalhes de como a agregação funciona por grupo de colunas (médias,
constantes, reconstrução de datas a partir de metadados no nome da
coluna, validada contra o código-fonte do RuFaS) estão documentados no
topo do próprio script e em `CLAUDE.md` do repositório principal.
`data/freestall_resultado_semanal.csv`, incluído neste repositório, é a
saída desse script — é o que o dashboard carrega automaticamente (ver
seção anterior).

## Como rodar localmente

```bash
cd dashboard
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```

Abre em `http://localhost:8501`.

## Formato esperado do CSV

O arquivo de entrada é uma **saída** do RuFaS (o resultado da simulação).
Pode ser tanto o CSV original em resolução **diária** (tipicamente milhares
de colunas e centenas de milhares de linhas, ~1GB) quanto um CSV agregado
em resolução **semanal** gerado por `scripts/aggregate_weekly.py` (mesmas
colunas, poucas centenas de linhas, ~12MB) — o dashboard lida com os dois
da mesma forma. Nomes de coluna seguem o padrão
`Módulo.método.variável (unidade)`, por exemplo:

```
AnimalModuleReporter.report_animal_population_statistics.population_number_of_lactating_cows (animals)
```

Muitas células ficam vazias — nem toda variável é reportada em todo
registro, o que é esperado (esparsidade real do modelo, não erro).

## Deploy (Streamlit Community Cloud)

Publicado em <https://rufas-dashboard.streamlit.app/> a partir deste
repositório (`leandroalexandre-ifg/rufas`, main file path
`dashboard/app.py`) — qualquer push em `main` republica automaticamente.

A fonte de dados é o CSV agregado incluído no próprio repositório
(`data/freestall_resultado_semanal.csv`, ~12MB, git normal, sem LFS) —
carrega sozinho ao abrir, sem depender de upload nem de download externo.

Esse é o segundo desenho de carregamento tentado — o primeiro (upload
manual como única fonte) veio depois de descartar carregamento automático
via link do Google Drive: o download de um CSV real (~900MB) derrubava o
app publicado (limite de memória/tempo do plano gratuito), enquanto o
mesmo arquivo via upload sempre funcionou. A agregação semanal (seção
acima) resolveu o problema de origem — reduzindo o CSV a ~12MB, ele passou
a caber com folga no limite de memória, permitindo voltar a um
carregamento automático (agora embutido no repositório, sem depender de
rede). Detalhes da investigação original estão no `CLAUDE.md` do
repositório principal.

Configuração relevante em `.streamlit/config.toml`: `maxUploadSize = 1024`
(o padrão do Streamlit é ~200MB) — ainda usada pelo upload manual de
fallback, para CSVs diários maiores que o agregado incluído.

## Estrutura do projeto

```
dashboard/
├── app.py                      # Entrypoint Streamlit — fluxo da interface
├── data_loader.py               # Leitura eficiente do CSV (upload, cabeçalho, colunas selecionadas)
├── filters.py                    # Lógica de filtro (módulo/palavra-chave/regex) e classificação de variáveis
├── scripts/
│   └── aggregate_weekly.py    # Gera o CSV agregado (diário -> semanal) a partir de uma saída do RuFaS
├── data/
│   └── freestall_resultado_semanal.csv  # CSV agregado, carregado automaticamente pelo app
├── requirements.txt
└── .streamlit/
    └── config.toml            # maxUploadSize
```

## Limitações conhecidas

- O CSV incluído no repositório é **resolução semanal** (médias/valores
  representativos por semana), não diária — trade-off deliberado para
  caber no limite de memória do Streamlit Community Cloud. Para explorar a
  granularidade diária completa, use upload manual com o CSV original (o
  app volta ao upload automaticamente se remover o CSV agregado de
  `data/`).
- Upload de arquivos grandes (fallback) depende da velocidade de upload da
  internet de quem está usando o app — isso é inerente ao Streamlit
  Community Cloud e não tem correção possível no código.
- Sem persistência entre reinícios do app: cada reinício do processo no
  Streamlit Cloud limpa o cache; o CSV agregado recarrega automaticamente
  (está no repositório), mas um CSV enviado por upload precisa ser
  reenviado.
