# Projeto: Dashboard de Resultados do RuFaS

## Contexto
Camada de visualização sobre o modelo RuFaS (Ruminant Farm Systems), um
modelo de simulação de fazenda leiteira em Python, open-source.

Este é o **primeiro marco** de um projeto maior. O objetivo geral (futuro) é
uma interface gráfica que permita a pesquisadores e técnicos da pecuária
leiteira usar o RuFaS sem linha de comando. Este marco cobre apenas a
**visualização dos resultados** — não roda o modelo nem gera entradas.

## Escopo deste marco (o que construir AGORA)
Uma aplicação web (rodando local ou publicada no Hugging Face Spaces)
que:
1. Lê um arquivo CSV de RESULTADO já existente do RuFaS (gerado por uma
   simulação anterior).
2. Exibe os dados num dashboard navegável.
3. Permite FILTRAR quais variáveis são exibidas.

## O que este marco NÃO faz (não construir ainda)
- Não executa o modelo RuFaS (nada de chamar `python main.py`).
- Não gera arquivos de entrada.
- Não faz "match" de planilhas do usuário.
Esses são marcos futuros. Manter o escopo enxuto.

## Vocabulário importante (evitar confusão)
- No RuFaS, "entrada" = os arquivos de configuração da fazenda (json/csv).
- No RuFaS, "saída" = o CSV de resultados da simulação.
- O arquivo que este dashboard lê é uma **SAÍDA** do RuFaS (o resultado),
  ainda que seja a **entrada** do nosso dashboard.

## Estrutura do CSV de resultado do RuFaS (fatos verificados)
- É MUITO largo: o número de colunas VARIA por filtro/simulação — não é uma
  constante do modelo. Um CSV real inspecionado (filtro `csv_all_variables.txt`,
  regex `.*`, saída completa) tinha **3.322 colunas**. Não assumir um número
  fixo; sempre descobrir o número real lendo o cabeçalho do arquivo carregado.
- É longo: no arquivo real inspecionado, 255.918 linhas de dados (~260.000,
  registros diários ao longo de anos de simulação) — ordem de grandeza
  confirmada.
- Tamanho em disco pode chegar a ~1GB (o arquivo real tinha 873MB).
- O arquivo é gerado numa ÚNICA escrita no fim da simulação
  (`OutputManager._dict_to_file_csv`, via `pandas.concat` + `to_csv`), não
  incrementalmente linha a linha.
- **CUIDADO com quebras de linha embutidas**: colunas de eventos por animal
  (ex.: `AnimalModuleReporter._record_animal_events.*`) guardam reprs de
  objetos Python com `\n` literais dentro do campo. O CSV resultante é válido
  (RFC4180, campo entre aspas), mas isso quebra qualquer parsing ingênuo por
  linha física (`split(",")` por `\n`) — usar sempre um parser CSV de verdade
  (pandas / módulo `csv`), nunca contagem de linhas físicas para inferir
  registros.
- Muitas células ficam vazias: nem toda variável é reportada em todo
  registro (esparsidade real do modelo, não é erro de leitura).
- A primeira linha/coluna pode conter um "DISCLAIMER" (no arquivo real, o
  cabeçalho da 1ª coluna se chama `DISCLAIMER` e a 1ª linha de dados traz o
  texto do aviso).
- Os nomes das colunas seguem uma hierarquia com pontos:
  `ClasseDoModulo.metodo_gerador.nome_da_variavel (unidade)`
  Exemplo real:
  `AnimalModuleReporter.report_animal_population_statistics.population_number_of_lactating_cows (animals)`
- Essa hierarquia é a chave da filtragem: o primeiro segmento é o MÓDULO
  (AnimalModuleReporter, etc.), e há palavras-chave temáticas no nome
  (milk, methane, nitrogen, population...).
- Há colunas de tempo prontas para eixo X dos gráficos: `RufasTime.day`,
  `RufasTime.year`, `RufasTime.calendar_year`, `RufasTime.simulation_day`.

## Como a filtragem deve funcionar
O RuFaS nativamente filtra a saída por REGEX sobre os nomes das variáveis
(arquivos em output/output_filters/, cada linha um padrão como `.*milk.*`).
O dashboard deve espelhar essa lógica, oferecendo DOIS modos:
1. Filtro amigável: menus por módulo (o 1º segmento do nome) e por
   palavra-chave temática (milk, methane, nitrogen, population...).
2. Filtro por padrão de texto (regex simples) — mostrando ao usuário o
   padrão gerado pelo modo amigável, para transparência.
O usuário seleciona um subconjunto das colunas (podem ser milhares,
número exato varia por arquivo) e o dashboard exibe só essas, com gráficos
apropriados.

## Stack decidida
**Streamlit + pandas.** Decidido na 1ª sessão (2026-08-06). Motivo: setup
mínimo, roda local, já usa o pandas que está no ambiente do RuFaS.
A UI definitiva em React (mencionada como possibilidade futura) fica para
um marco posterior, quando o escopo crescer além de visualização.

## Plataforma de deploy e repositórios (revisado em 2026-08-07, à noite)
**Streamlit Community Cloud voltou a ser usado**, a partir do mesmo
repositório do GitHub (`dashboard/`) — decisão revertida na mesma data,
depois que a agregação semanal (ver seção própria abaixo) resolveu o
motivo original do abandono: o CSV completo (~900MB) estourava o limite
de memória do plano gratuito do Streamlit Cloud; o CSV agregado (~12MB)
não. O CSV agregado (`data/freestall_resultado_semanal.csv`) foi incluído
diretamente no repositório do GitHub, em git normal (sem LFS — o arquivo
é pequeno o bastante), e `app.py` carrega automaticamente ao abrir.
Hugging Face Spaces continua existindo em paralelo (repositório separado
`hf-space/`, com o CSV completo via LFS) — não foi desativado, os dois
convivem por enquanto.

Texto original desta seção (mantido por contexto histórico — **não é
mais a decisão vigente**, ver acima): Hugging Face Spaces, não mais
Streamlit Community Cloud. Dois repositórios Git **separados e
independentes** (não dois remotes do mesmo working tree — ver motivo
abaixo):
- `github.com/leandroalexandre-ifg/rufas` — código-fonte, histórico de
  desenvolvimento. **Nunca contém o CSV.** Continua sendo o repo de
  referência para ler/editar o código.
- Repositório do Hugging Face Space (separado, pasta local `hf-space/` na
  máquina de desenvolvimento) — cópia do código + o CSV de exemplo
  versionado via **Git LFS**. É o que roda publicado.
- **Por que separados**: se o CSV (~900MB) fosse commitado num repositório
  que também tem remote no GitHub, um `git push` para o GitHub tentaria
  enviar esses ~900MB de LFS também — o GitHub LFS gratuito tem cota de
  1GB de armazenamento + 1GB/mês de banda, que um único arquivo desse
  tamanho já estoura. Manter os repositórios fisicamente separados evita
  esse acidente.

Streamlit Community Cloud tinha sido **desligado** (decisão explícita do
usuário, não só "descartado como opção") — motivo abaixo. **Reativado**
em 2026-08-07 à noite, ver "Plataforma de deploy" acima.

## Histórico de entrada de dados (por que chegamos no Hugging Face)
1. Caminho local fixo (1ª versão) → abandonado ao preparar deploy: sem
   acesso a disco do usuário quando publicado.
2. **Google Drive tentado e descartado**: carregamento automático via link
   do Drive + `gdown` (com fallback via `requests` e validação de
   conteúdo), mas em produção o download de um CSV real (~900MB) derrubava
   o app inteiro ("Oh no" do Streamlit) — mesmo arquivo, mesmo tamanho, o
   upload manual funcionava normalmente. Causa mais provável: limite de
   memória/tempo de execução do plano gratuito do Streamlit Community
   Cloud sendo estourado especificamente pelo processo de download (não é
   bug de código, nenhum try/except resolve).
   - Investigamos reduzir o CSV (remover colunas de id/booleano/texto) como
     mitigação, mas o tamanho do arquivo é dominado pelo número de linhas
     (~256 mil) distribuído quase uniformemente entre milhares de colunas —
     não há colunas "vilãs" concentrando peso, então essa redução só
     cortaria ~15% do arquivo, insuficiente. Análise completa em
     `notas/reduction_report_2026-08-07.txt` (na raiz do projeto, fora do
     dashboard — tem valor para entender a composição da saída do RuFaS
     independente da decisão de deploy). Se algum dia for reconsiderada
     redução de tamanho, o que funcionaria é por LINHAS (amostragem/
     agregação temporal), não por colunas.
3. **Upload manual** (`st.file_uploader`) — funcionou no Streamlit Cloud,
   mas dependia da velocidade de upload de cada usuário e precisava ser
   reenviado a cada reinício do processo.
4. **Migração para Hugging Face Spaces (atual)**: tier gratuito com 16GB
   de RAM (vs. ~1GB do Streamlit Cloud), resolvendo o limite de memória.
   O CSV vai embutido no próprio repositório do Space via Git LFS,
   eliminando upload pela rede. `app.py` resolve
   `Path(__file__).parent / "data" / "freestall_resultado.csv"`: se
   existir, carrega automaticamente ao abrir; senão, cai no
   `st.file_uploader` como alternativa (mantém o app utilizável mesmo sem
   o CSV embutido, ex. rodando local a partir do repo do GitHub).
- Configuração do Space: `README.md` na raiz do repo do Space precisa do
  cabeçalho YAML (`sdk: streamlit`, `sdk_version`, `python_version`,
  `app_file: app.py`) — é isso que o Hugging Face lê pra saber como rodar
  o app; sem ele, o Space não sobe.
- `maxUploadSize` continua em 1024MB em `.streamlit/config.toml` (o
  upload manual de fallback ainda precisa suportar arquivos grandes).

## Redução de tamanho via agregação temporal (implementado em 2026-08-07)
Retomando a nota em "Histórico de entrada de dados" (redução por LINHAS,
não por colunas): implementado. Script `dashboard/scripts/aggregate_weekly.py`
(versionado, documentado no topo do próprio arquivo) lê um CSV de resultado
do RuFaS em resolução diária e gera uma versão em resolução **semanal**,
mantendo TODAS as colunas originais (nenhuma removida) — só reduz linhas.
- Uso: `python scripts/aggregate_weekly.py <entrada.csv> <saida.csv>`.
- No arquivo real testado: 915MB/3.322 colunas/255.918 linhas →
  **11,85MB/3.324 colunas (as originais + `week_index` e
  `week_start_date`)/366 linhas**.
- **Achado importante**: 255.918 linhas não são 255.918 dias — a
  simulação cobre só 2.556 dias (~366 semanas). O CSV é montado por
  `pandas.concat` colando ~50 tabelas de "reporters" diferentes lado a
  lado, cada uma com sua própria contagem de linhas (ex.: dados de
  ordenha têm ~100 linhas/dia). Por isso o resultado agregado tem 366
  linhas (uma por semana da simulação), não ~36 mil (255.918 ÷ 7).
- A agregação trata as colunas em grupos diferentes conforme sua base de
  tempo real (nem todas alinham por posição com `RufasTime.simulation_day`
  — descoberta feita durante a implementação, validada linha a linha
  contra o CSV real e, para os casos não óbvios, contra o código-fonte do
  RuFaS). Detalhe completo de cada grupo (A a E2) está documentado no
  docstring do script — não duplicar aqui, manter uma fonte só.
- Colunas sem base de tempo identificável ficam presentes no CSV
  agregado, vazias em todas as semanas (nunca removidas).
- O CSV agregado ainda **não** foi commitado nem publicado no Hugging
  Face Space — decisão pendente do usuário após teste local.

## Princípios de projeto
- Performance: o CSV pode ter milhares de colunas × ~260 mil linhas e quase
  1GB em disco. Carregar de forma eficiente: ler apenas o cabeçalho primeiro
  (para popular os filtros), depois carregar só as colunas selecionadas
  (`pandas.read_csv(usecols=...)`), nunca o arquivo inteiro de uma vez.
  Sempre usar um parser CSV real (nunca split manual — ver nota sobre
  quebras de linha embutidas acima). Cachear leituras (`st.cache_data`).
  Considerar amostragem/agregação temporal para os gráficos se necessário.
- Nunca travar a UI: mostrar carregamento e exibir dados progressivamente.
- Contexto brasileiro na EXIBIÇÃO: rótulos e números legíveis; atenção a
  separador decimal se for reexportar.
- Mensagens claras em português para o usuário final.

## Comandos
- Setup do código (1ª vez): `cd dashboard && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`
- Rodar o dashboard localmente: `cd dashboard && source .venv/bin/activate && streamlit run app.py`
  (abre em http://localhost:8501)
- Repositório do Space (`hf-space/`, separado do `dashboard/` do GitHub —
  ver "Plataforma de deploy" acima): mesmo código de `dashboard/` +
  `data/freestall_resultado.csv` (via Git LFS) + `README.md` com cabeçalho
  YAML do HF. Alterações de lógica devem ser feitas em `dashboard/` (fonte
  de verdade) e replicadas manualmente para `hf-space/` antes de publicar.

## Convenções
- Nomes de código em inglês; textos de interface em português.
- Type hints no Python.
- Commits pequenos e frequentes; mensagens descritivas.

## Nova frente: interface produtor → RuFaS

### Objetivo geral
Construir uma interface amigável que conecta o produtor ao RuFaS,
escondendo a complexidade técnica do modelo. A visão completa tem 5
etapas:
1. **Entrada do produtor** — formulário em linguagem de fazenda (não
   técnica).
2. **Tradução** — converter as respostas do formulário para a árvore de
   arquivos que o RuFaS espera como entrada.
3. **Execução** — rodar o modelo RuFaS nos bastidores.
4. **Dashboard de resultados** — **JÁ IMPLEMENTADA**: é o dashboard de
   filtros descrito no restante deste documento.
5. **Assistente conversacional** — interface de chat sobre os resultados/
   processo.

As etapas 1, 2, 3 e 5 ainda serão construídas. Esta seção documenta essa
frente nova; o restante do CLAUDE.md (contexto, escopo, stack, etc.)
continua se referindo ao marco do dashboard de filtros (etapa 4).

### RuFaS agora é git submodule deste repositório (decidido em 2026-08-31)
Até aqui, `RuFaS/` era só um checkout local ignorado pelo git deste repo
(`/RuFaS/` no `.gitignore`) — o usuário pediu para que o código do RuFaS
passasse a fazer parte do repositório também, e não apenas existir como
uma dependência externa invisível pra quem clona o projeto.

Decisão: **git submodule**, não cópia direta do código nem `git subtree`.
Motivo: o checkout local tinha 11GB no disco e o histórico de commits do
projeto oficial sozinho já soma ~33 mil commits / 1,6GB — inviável de
duplicar dentro do histórico deste repo. O submodule guarda só uma
referência leve (URL do repo oficial + hash de um commit específico), sem
duplicar esse histórico; quem quiser o código de verdade roda
`git submodule update --init` (ou clona com `--recurse-submodules`).
Aponta pro repositório oficial (`github.com/RuminantFarmSystems/RuFaS`),
fixado no commit que já estava em uso localmente (branch `dev`).

Isso **não contradiz** a decisão de manter `hf-space/` fora deste repo
(ver "Plataforma de deploy e repositórios" abaixo) — aquele caso era
especificamente sobre não arriscar estourar a cota de Git LFS do GitHub
com o CSV de ~900MB versionado ali. Um submodule não copia nem envia
nenhum dado do RuFaS pra este repo — só a referência —, então não tem
esse risco.

Nenhum código do backend precisou mudar: `backend/farm_translation.py`
já apontava `RUFAS_ROOT` para o caminho absoluto `.../RuFaS`, que
continua sendo exatamente onde o submodule fica.

### Arquitetura escolhida (decidido em 2026-08-27)
**Flutter (app) + Python/FastAPI (backend/API)**, comunicando por API.
Tudo rodando local nesta fase (sem deploy). O app Flutter é o frontend
final para o produtor; o FastAPI expõe a lógica Python do RuFaS (PoC de
tradução+execução) e, depois, a lógica de filtragem hoje no dashboard
Streamlit.

Plano de 4 fases:
1. Transformar a PoC (etapas 2+3, hoje com valores fixos no código) numa
   API FastAPI: recebe os campos de uma fazenda numa requisição e devolve
   o resultado da simulação. **Fase atual.**
2. Migrar a lógica de filtragem do dashboard Streamlit (etapa 4, já
   implementada) para a API — endpoints que leem o CSV de saída e
   devolvem os dados filtrados.
3. Construir o app Flutter conectado à API (etapas 1 e 4 do ponto de
   vista do usuário: formulário de entrada + visualização de resultados).
4. Assistente conversacional (etapa 5), também via API.

### Estado atual
Começando pela **prova de conceito das etapas 2+3** (tradução e
execução), por serem o maior risco técnico do projeto todo.

Pergunta de viabilidade a responder: **é possível, a partir de poucos
campos em linguagem de fazenda, montar uma entrada válida que o RuFaS
aceita e roda?**

### Ambiente desta fase
Tudo roda localmente, no MacBook Pro M4 Pro do usuário (24GB RAM). Nesta
fase NÃO há preocupação com:
- hospedagem/deploy,
- tamanho do CSV de saída,
- agregação semanal,
- publicação web.

Usa-se o arquivo de saída completo em resolução diária, sem restrição de
tamanho. Essas preocupações (ver "Plataforma de deploy", "Redução de
tamanho via agregação temporal" acima) pertencem à frente do dashboard
(etapa 4) e não se aplicam aqui até que esta frente amadureça a ponto de
precisar de deploy.

### Hipótese de trabalho para a tradução (etapa 2) — A VALIDAR
Montar a entrada por **substituição**: partir dos arquivos do cenário
freestall que já funcionam (rodam com sucesso no RuFaS hoje) e trocar
apenas os poucos valores que descrevem uma fazenda diferente, mantendo o
restante como está. Para as partes pesadas — ex.: população animal —
aproveitar os **geradores nativos do RuFaS** em vez de montar esses dados
manualmente.
**Isto é uma hipótese, não uma certeza.** A prova de conceito das etapas
2+3 existe justamente para validá-la (ou refutá-la). Não assumir que vai
funcionar antes de checar contra o código/comportamento real do RuFaS.

O gerador nativo de população animal **não** é uma flag de linha de
comando (a menção original a `-I -s` estava desatualizada/incorreta —
essas flags hoje fazem outra coisa: `-i` exclui mapas de info, `-s`
suprime arquivos de log). O mecanismo real é uma **task**:
`TaskType.HERD_INITIALIZATION` (arquivo pronto de exemplo:
`input/data/tasks/herd_init_task.json`), rodada com `save_animals: true`
— ela simula o rebanho a partir de `cow_num`/`calf_num` (em
`animal.json → herd_information`) e escreve um `animal_population.json`
novo. A simulação principal (`SIMULATION_SINGLE_RUN`) usa por padrão o
arquivo estático já existente (`init_herd: false`), então basta apontar o
metadata dela para o arquivo recém-gerado.

**Lacuna conhecida (fora do escopo desta PoC)**: não existe gerador
nativo de **clima** a partir de localização/FIPS — hoje a escolha do CSV
de clima (`input/data/weather/`) é manual e desconectada do
`FIPS_county_code`. Para a interface futura (etapa 1/2 completas), será
preciso decidir como resolver isso (ex.: mapear região → CSV de clima
mais próximo, ou pedir upload). Registrado aqui para não ser esquecido,
não para ser resolvido agora.

### Resultado da PoC (2026-08-21) — HIPÓTESE VALIDADA
Executada localmente a partir do cenário freestall, editando 5 campos em
linguagem de fazenda (`cow_num`, `calf_num`, `annual_milk_yield`,
`field_size` ×2, `FIPS_county_code`), mantendo tudo o mais inalterado.
Arquivos `_poc` (config/animal/field/metadata/tasks) criados em
`RuFaS/input/`, sem sobrescrever os originais.
1. Task `HERD_INITIALIZATION` (`save_animals: true`) rodou sem erros
   (~6min) e gerou um novo reservatório de animais.
2. Simulação completa (`SIMULATION_SINGLE_RUN`, 7 anos, 2013–2019) rodou
   sem erros (~4min) a partir desse reservatório + arquivos `_poc`,
   produzindo um CSV de saída completo (927MB), no mesmo formato usado
   pelo dashboard.
3. Produção de leite anualizada na saída (~835.000 kg/ano) ficou na
   mesma ordem de grandeza e direção do `annual_milk_yield` informado
   (1.250.000 kg/ano), confirmando que o campo tem efeito real e
   coerente na simulação.

**Dois gaps descobertos pela PoC (a resolver na interface futura, não
nesta PoC):**
- **Capacidade de curral não escala com o rebanho.** `pen_information`
  (nº de baias por curral) é fixo nos arquivos freestall originais; ao
  aumentar `cow_num`/`calf_num` sem tocar nisso, currais ficaram
  superlotados (avisos "Pen is overstocked" no log, simulação não trava
  mas a superlotação provavelmente contribui para a produção de leite
  ficar abaixo do alvo). A interface futura precisará derivar a
  capacidade de curral a partir do rebanho informado, ou expor isso como
  campo adicional.
- **`annual_milk_yield` é um alvo de calibração da curva de lactação, não
  uma garantia de saída.** Ele pilota o ajuste dos parâmetros da curva de
  Wood (`lactation_curve.py`), mas o valor realmente produzido ao longo
  da simulação depende da dinâmica completa (períodos secos, estresse de
  superlotação, descarte, etc.) e pode ficar sensivelmente abaixo do
  informado — não é uma "trava" numérica. Importante para calibrar
  expectativa na comunicação com o produtor.

**Achado técnico sobre o CSV de saída, relevante para o dashboard
também**: colunas de reporters diferentes têm contagens de linha
diferentes e são coladas lado a lado (`pandas.concat`) — comparar/somar
colunas de reporters distintos linha-a-linha (ex. cruzar `RufasTime` com
uma coluna de outra tabela sem confirmar que vêm do mesmo reporter) pode
produzir números sem sentido, mesmo sem erro de leitura. Sempre confirmar
que as colunas comparadas pertencem à mesma tabela/reporter antes de
cruzar.

### Decisão tomada (2026-08-27): seguir para a arquitetura Flutter+FastAPI
Entre os dois caminhos que estavam em aberto (robustecer a PoC vs. ir para
o visual), a decisão foi seguir para a Fase 1 do plano de 4 fases (ver
"Arquitetura escolhida" acima): expor o fluxo da PoC como API. O gap do
curral (`pen_information`) fica **conscientemente ignorado por enquanto**
(ver "Limitações conhecidas da Fase 1" abaixo) — não foi resolvido, só
adiado.

### Fase 1: API FastAPI (implementação, 2026-08-27)
Antes de implementar, foi feito um teste de fumaça isolado (descartável,
não faz parte do código final) para validar o maior risco técnico: rodar
`TaskManager.start()` do RuFaS — que usa `multiprocessing.Pool`
internamente — dentro de uma `BackgroundTask` do FastAPI (que roda em
thread de worker, não na thread principal). **Resultado: funciona sem
conflito** — os workers de multiprocessing (`spawn`) sobem normalmente a
partir da thread, a task `SIMULATION_SINGLE_RUN` da PoC rodou por
completo (~4min) e produziu o CSV esperado. Não foi necessário partir
para a alternativa (processo separado via subprocess).

Implementado em `backend/` (raiz do projeto, novo diretório, roda na
mesma venv de `RuFaS/venv` — reaproveitada para evitar reinstalar
numpy/scipy/numba; `fastapi`/`uvicorn` foram adicionados a ela):
- `backend/farm_translation.py` — gera, por `simulation_id`, os arquivos
  de entrada (`animal`, `field_1`, `field_2`, `config`, `metadata`, as
  duas tasks) por substituição sobre o cenário freestall **original**
  (`example_freestall_*`, não os arquivos `_poc`), com os 5 campos da
  fazenda. Convenção de nomes: `farm_<simulation_id>_*` em
  `input/data/.../`.
- `backend/simulation_runner.py` — orquestra as duas chamadas a
  `TaskManager().start()` (herd init → descobre o `animal_population`
  gerado → aponta o metadata pra ele → simulação principal), atualizando
  um dict de status compartilhado a cada etapa.
- `backend/app.py` — FastAPI com `POST /simulations`,
  `GET /simulations/{id}`, `GET /simulations/{id}/result`,
  `GET /simulations/{id}/download`.

Rodar: `cd RuFaS && source venv/bin/activate && PYTHONPATH=<raiz do
projeto> uvicorn backend.app:app --reload`.

**Bug pego durante a validação manual (antes do teste end-to-end real)**:
os arquivos de task (`herd_init_task.json`, `example_freestall_task.json`)
têm a task real dentro de uma lista (`{"tasks": [{...}]}`), não são um
dict plano — a primeira versão do código escrevia os campos substituídos
(`metadata_file_path`, `output_prefix` etc.) no nível errado (fora da
lista), o que faria a task real continuar apontando pro metadata original
do freestall, silenciosamente ignorando os campos da fazenda. Pego com um
teste seco (gerar os arquivos sem rodar o RuFaS) antes de gastar ~10min
numa rodada real. Corrigido: os campos são escritos em `task["tasks"][0]`.

**Achado sobre onde a saída de cada task realmente cai (descoberto no
1º teste end-to-end real via API)**: o `output_directory`/`logs_directory`
passados para `TaskManager.start()` só controlam o log do próprio
`TaskManager` (arquivos "Task Manager_*", usados em caso de falha total).
Cada TASK individual tem seus próprios campos de diretório
(`csv_output_directory`, `json_output_directory`, `logs_directory`,
`report_directory`, `graphics_directory`, `filters_directory`), com
defaults fixos no schema do RuFaS
(`RUFAS/input/metadata/properties/tasks_properties.json`:
`output/CSVs/`, `output/JSONs/`, `output/logs/`, etc.) quando ausentes da
task JSON — **não** derivados do parâmetro passado a `start()`. Como
nossas tasks geradas não setam esses campos, CSVs e logs de todas as
simulações caem no mesmo `output/CSVs/` e `output/logs/` compartilhados,
diferenciados só pelo nome do arquivo (via `output_prefix`, que já é
único por `simulation_id` — sem risco de colisão, já que a Fase 1 roda
uma simulação por vez). Única exceção real isolada por diretório:
`output/farm_<simulation_id>/animals/`, porque `save_animals_directory`
é setado explicitamente por `farm_translation.write_herd_init_task`.
`find_result_csv()` busca em `output/CSVs/`, não em
`output/farm_<id>/CSVs/` (que não existe). Não foi feito nenhum esforço
adicional pra isolar CSVs/logs por diretório — a unicidade por nome de
arquivo já é suficiente para a Fase 1, e forçar isolamento por diretório
exigiria setar mais 5 campos por task sem ganho de correção.

### Limitações conhecidas da Fase 1 (decisão explícita do usuário)
- **Uma simulação por vez.** Fila serializada em memória
  (`queue.Queue` + uma thread worker única em `backend/app.py`) — mesmo
  que cheguem várias requisições `POST /simulations` ao mesmo tempo, elas
  rodam em sequência, nunca em paralelo. Motivo: cada simulação já usa
  `multiprocessing.Pool` internamente (4 workers); duas ao mesmo tempo
  competiriam por CPU/memória sem necessidade validada ainda. Sem fila
  externa (Celery/RQ) nesta fase.
- **Gap do curral (`pen_information`) continua ignorado.** Fazendas com
  `cow_num`/`calf_num` grandes podem gerar superlotação (ver achado da
  PoC acima) — não tratado nesta fase.
- **Sem Docker, sem autenticação.** Tudo local, um único usuário
  confiável (o desenvolvedor). CORS liberado (`allow_origins=["*"]`) para
  o Flutter (web + desktop/mobile) local conseguir chamar a API sem
  travar no desenvolvimento — aceitável só porque não há autenticação/
  credenciais envolvidas ainda.
- **Sem limpeza automática de arquivos por simulação — PRIORIDADE (elevado
  de pendência em 2026-08-27, após os 2 testes end-to-end reais da
  Fase 1).** Cada execução deixa para trás arquivos de entrada
  (`input/.../farm_<id>_*`) e saída — espalhada, não num único diretório
  por simulação (ver achado acima): `output/CSVs/farm_<id>_*` (o CSV
  completo, cada um ~900MB-1GB), `output/logs/farm_<id>_*`,
  `output/JSONs/`, `output/reports/`, `output/graphics/`, mais
  `output/farm_<id>/animals/` (essa sim isolada). O prefixo `farm_<id>_`
  é único e consistente em todos esses locais, o que já viabiliza uma
  rotina de limpeza por glob — **a rotina em si ainda não foi
  implementada**. Motivo da prioridade: só os 2 testes de validação da
  Fase 1 já geraram ~1,8GB (apagados manualmente em 2026-08-27); cada
  simulação real gera ~1GB, então o disco enche rápido sem alguma forma
  de limpeza (automática após um tempo, ou ao menos um endpoint/comando
  manual de limpeza). Tratar isso ao robustecer o backend (não faz parte
  do escopo da Fase 2, que é sobre filtragem).
- **Estado em memória.** O dict de jobs (`JOBS` em `backend/app.py`) não
  persiste — um restart do processo perde o histórico/status de
  simulações (o CSV já gerado em disco continua existindo, só o
  rastreamento via API se perde).

### Fase 2: filtragem via API (implementação, 2026-08-27)
Migra a lógica de filtragem do dashboard Streamlit (`dashboard/filters.py`
+ o fluxo em `dashboard/app.py`) para endpoints da API, para o app Flutter
consumir sem precisar carregar o CSV inteiro.

**Nota importante de escala**: o dashboard hoje serve por padrão o CSV
**semanal agregado** (~12MB, 366 linhas — ver seção de agregação temporal
acima). O backend da Fase 2 opera sobre o CSV que a Fase 1 realmente
produz: **completo, resolução diária** (~900MB-1GB, até ~258 mil linhas
por reporter). É o downsampling do `chart-data` (abaixo) que torna isso
viável para o app — sem ele, mandar a série inteira pela rede não faria
sentido.

Implementado:
- `backend/filters.py` — **cópia** de `dashboard/filters.py` (decisão do
  usuário: preferiu duplicar a importar via `sys.path`, porque o backend
  vai seguir caminho próprio e depender de `dashboard/` criaria
  acoplamento frágil). **São duas fontes a manter sincronizadas
  manualmente** — se a lógica de filtro/classificação mudar, replicar dos
  dois lados. Mesmo padrão já usado entre `dashboard/` e `hf-space/`.
- `backend/data_reader.py` — leitura do CSV com cache em memória por
  `mtime` do arquivo (mesma ideia de `dashboard/data_loader.py`, sem as
  partes amarradas ao Streamlit). Cache simples, sem limite de tamanho
  nem expiração.
- Novos endpoints em `backend/app.py`:
  - `GET /simulations` — lista todas as simulações (mais recente
    primeiro), para o app mostrar histórico de fazendas com "ver
    resultados".
  - `GET /simulations/{id}/columns` — lê só o cabeçalho do CSV; devolve
    todas as colunas, os módulos (`list_modules`) e as palavras-chave
    disponíveis (`list_available_keywords`).
  - `POST /simulations/{id}/filters/preview` — recebe módulos/palavras-
    chave (ou um regex direto), devolve o regex gerado e as colunas
    selecionadas — sem carregar dados, só o cabeçalho (equivalente ao
    `build_regex` + `select_columns` do dashboard).
  - `GET /simulations/{id}/chart-data?columns=...&max_points=N` — carrega
    só as colunas pedidas (`usecols`), classifica cada uma
    (`classify_column`: `plottable`/`categorical`/`excluded_name`/
    `excluded_type`/`no_data`/`time`) e devolve uma série já pronta pra
    plotar, com downsampling (ver bug abaixo).
- **Decisão explícita**: não existe rota de tabela crua/paginada. Quem
  quer os dados brutos usa `GET /simulations/{id}/download` (Fase 1). O
  app fica só com filtro + gráfico.

**Bug pego durante a validação manual (antes de fechar a Fase 2)**: a
primeira versão do `chart-data` fazia o downsampling (`iloc[::step]`)
sobre `len(df)` — o comprimento do CSV inteiro carregado, dominado pelo
reporter com mais linhas (ex.: eventos por ordenha, ~258 mil linhas).
Para uma coluna de um reporter mais esparso (ex.:
`daily_milk_production`, que só tem 2.556 linhas reais — uma por dia de
simulação — coladas ao lado de reporters bem mais longos, ver "Achado
técnico sobre o CSV de saída" na seção da PoC acima), isso descartava
quase toda a série: numa amostra de 3004 pontos, só 30 tinham valor
real. Corrigido filtrando para as linhas onde pelo menos uma das colunas
pedidas tem dado (`df[requested_columns].notna().any(axis=1)`) **antes**
de amostrar — `total_points` agora reflete o tamanho real da série
pedida (ex.: 2.556), não o tamanho do CSV inteiro. Achado com um teste
real via API contra um CSV de saída completo já existente em disco (não
foi preciso rodar uma simulação nova pra esse teste). Esse comportamento
(reporters com contagens de linha diferentes colados lado a lado) já
era conhecido — documentado na seção da PoC — mas esta foi a primeira
vez que se mostrou concretamente como um problema de usabilidade pro
app, não só uma ressalva teórica.

Testado (via servidor real com um JOB falso apontando pra um CSV de
saída completo já existente, sem gastar ~10min rodando simulação nova):
`GET /simulations`, `GET /simulations/{id}/columns` (3.338 colunas reais),
`POST /simulations/{id}/filters/preview` (filtro por módulo+palavra-chave
reduzindo pra 31 colunas), `GET /simulations/{id}/chart-data` (série
densa de 2.556 pontos reais, com classificação `plottable` e
`categorical` corretas), e os erros 404/400/409. `/result` e `/download`
(Fase 1) re-testados após o refactor (extraído `_require_result_csv`) —
sem regressão.

### Fase 3: app Flutter (implementação, 2026-08-27)
As 4 telas do app, consumindo a API das Fases 1 e 2, construídas e
validadas uma de cada vez (Web + Android) antes de passar pra próxima,
por pedido explícito do usuário — método que se provou valioso: pegou
bugs reais que só apareciam numa das duas plataformas.

- **Tela 1 — Lista de fazendas** (`lib/screens/farm_list_screen.dart`):
  `GET /simulations`, estados traduzidos pra linguagem de fazenda (chip
  `lib/widgets/simulation_state_chip.dart`, labels centralizados em
  `lib/core/simulation_states.dart`), estado vazio/erro, pull-to-refresh.
- **Tela 2 — Nova fazenda** (`lib/screens/new_farm_screen.dart`):
  formulário dos 5 campos, validação amigável em português (aceita
  vírgula ou ponto), `POST /simulations`, volta pra lista com snackbar de
  confirmação.
- **Tela 3 — Status da simulação** (`lib/screens/simulation_status_screen.dart`):
  polling de `GET /simulations/{id}` a cada 5s, para sozinho ao chegar em
  `done`/`failed` ou ao sair da tela (verificado observando a rede ao
  vivo, não só lendo o código). Falha mostra mensagem amigável com
  traceback técnico escondido atrás de "Detalhes técnicos".
- **Tela 4 — Resultados** (`lib/screens/results_screen.dart` +
  `lib/screens/chart_screen.dart`), em duas partes:
  - Parte A (filtro): chips de módulo/palavra-chave como caminho
    principal, regex escondido atrás de "Avançado", contagem dinâmica via
    `POST /filters/preview`.
  - Parte B (gráfico): escolha de até 3 variáveis, `GET /chart-data` por
    variável, `fl_chart`, classificação decide se desenha linha ou mostra
    mensagem de "não plotável".

**Bug real pego e corrigido (Parte B)**: variáveis "categóricas" de
verdade (ex.: teor de gordura do leite, sempre ~4.0) travavam o app —
reproduzido em Web **e** Android, não só concorrência (travava até com 1
variável sozinha). Causa: os valores tinham ruído de ponto flutuante
(`4.0` vs `4.000000000000001`), dando um intervalo de eixo Y positivo mas
infinitesimal (~10⁻¹⁵) que travava o cálculo de grade do `fl_chart`.
Corrigido comparando contra um epsilon (`1e-9`) em vez de `> 0` exato, no
eixo X e no Y. Diagnosticado descartando teoria por teoria (rede,
concorrência, memória do sistema) usando `adb logcat`/`uiautomator dump`
no Android — nesse ponto o Chrome DevTools Protocol desta sessão estava
instável (timeouts de captura de tela desconectados do estado real do
app, confirmado comparando com os logs do backend), então a validação
definitiva veio do Android, mecanismo independente.

Pacotes novos: `http` (chamadas REST), `fl_chart` (gráficos). Sem
gerenciamento de estado nem roteamento externo — `StatefulWidget` +
`Navigator` padrão bastam pro tamanho atual do app, decisão deliberada
por ser a primeira vez do usuário com Flutter.

## Identidade visual (Material 3), aplicada em 2026-08-29
Design visual aplicado às 4 telas do app Flutter — só camada visual,
**nenhuma lógica/funcionalidade foi alterada**. Tema centralizado em
`flutter_app/lib/core/app_theme.dart` (`AppTheme.light`, aplicado em
`main.dart` via `ThemeData`): `useMaterial3: true`, `ColorScheme.fromSeed`
a partir do verde `#2E7D32`, com primária/secundária/acento fixados na
paleta de fazenda decidida com o usuário — primária `#2E7D32` (AppBar,
FAB, botões), secundária `#A5D6A7` (apoio, ex. avatar dos itens da
lista), acento `#F9A825` (chips de filtro ativos na Tela 4, estado
"em andamento" na Tela 1), fundo off-white `#FAF9F4`, texto cinza-escuro
`#262B27`. O tema também define estilos globais de `Card` (cantos
arredondados, elevação leve), botões, campos de formulário
(`InputDecorationTheme`), chips e checkbox — todas as telas herdam daí,
sem cor/estilo hardcoded localmente (bordas explícitas de campo que
existiam nas Telas 2 e 4 foram removidas para o tema prevalecer).
Cores semânticas de status (`core/simulation_states.dart`) foram
realinhadas à paleta (verde para concluída, âmbar para em andamento,
cinza para na fila; vermelho de erro mantido só para falha, por ser
fora da paleta de marca mas necessário para o alerta semântico).
Validado rodando o app de verdade (não só lendo código) em Web e no
emulador Android, telas 1-4, incluindo um teste com CSV de saída real
já existente em disco (backend seedado com jobs falsos só para a
validação visual, descartado ao final — não faz parte do código do
projeto).

**Nota (2026-08-31): esta paleta foi substituída** — ver "Nova
identidade visual" mais abaixo. Seção mantida por contexto histórico.

## Reformula navegação: menu lateral + cadastro em wizard (2026-08-29)
Adaptação de um design de referência ("Cadastro Fazenda Wizard", Claude
Design): a Tela 1 virou shell + lista, com `widgets/app_drawer.dart`
(novo) — navegação lateral com marca, seletor de "fazenda ativa" (estado
só de UI, não existe no backend) e item "Minhas Fazendas" com contador.
A Tela 2 (`new_farm_screen.dart`, removido) virou
`screens/new_farm_wizard_screen.dart` (novo): wizard de 3 etapas
(Rebanho, Produção, Propriedade) + Revisão + Confirmação, usando só os 6
campos que `backend/app.py` aceita — campos do design sem equivalente no
backend (nome da fazenda, vacas secas, raça, busca de município por
nome) ficaram de fora, por decisão do usuário. Nenhum arquivo do
`backend/` foi alterado; `simulation_status_screen.dart`,
`results_screen.dart` e `chart_screen.dart` continuam intocados.
Testado de ponta a ponta (Web e Android, release) com uma simulação real
disparada no backend.

## Nova identidade visual "editorial de laticínio" (2026-08-31)
Reskin completo do `app_theme.dart`, substituindo a paleta Material 3
descrita acima — só camada visual, mesma regra de antes (nenhuma
lógica/funcionalidade alterada). Decisão tomada explorando referências
de estilo com o usuário via Claude Design — detalhes e os arquivos de
design (`.dc.html`) em `docs/design/README.md`.

Paleta nova: verde-floresta `#1B4D3E` primária (era `#2E7D32`),
verde-claro `#DCEAE1` de apoio (era `#A5D6A7`), dourado `#F4C15C` de
acento (era âmbar `#F9A825`), fundo creme `#FAF7F0` (era `#FAF9F4`),
texto `#26332C`. Tipografia trocada de padrão do sistema para **Work
Sans** via pacote `google_fonts` (nova dependência), peso alto (900) nos
títulos. Botões/chips/FAB viraram formato pílula (`StadiumBorder`); cards
perderam a sombra, ganharam borda fina no lugar.

`core/simulation_states.dart` foi corrigido nessa mudança: as cores de
estado tinham hex duplicado localmente (não referenciavam `AppColors`),
então continuariam com a paleta antiga mesmo depois do reskin do tema —
passaram a referenciar `AppColors.primaryGreen`/`AppColors.amber`.

Validado rodando o app de verdade no navegador (lista, menu lateral,
wizard de cadastro) com o backend real já rodando.

## Estado do marco (2026-08-29): Fases 1, 2 e 3 concluídas + identidade visual aplicada
Backend (API FastAPI sobre a PoC + filtragem, ver seções acima) e app
Flutter (4 telas, Web e Android) funcionando **de ponta a ponta,
localmente**, com identidade visual Material 3 aplicada (ver seção
acima): cadastrar fazenda → acompanhar simulação → filtrar resultado →
ver gráfico, com dados reais do RuFaS. **App funcional e com identidade
visual, pronto para demonstração (Web e Android).**

**Pendências conhecidas para retomar depois:**
- **macOS/iOS não validados**: Xcode incompleto na máquina (ver "Ambiente
  Flutter" na investigação da Fase 3) — adiado por decisão do usuário,
  não travou a Fase 3. O código Flutter em si não muda por causa disso.
- **Limitações da Fase 1** (ainda valem, não revisitadas nesta fase): fila
  serializada (uma simulação por vez), gap do curral (`pen_information`
  não escala com `cow_num`/`calf_num`), sem limpeza automática de
  arquivos por simulação (prioridade, ver seção própria acima).

**Próximo passo natural**: avançar para a Fase 4 do plano original
(assistente conversacional, ver "Arquitetura escolhida" no topo desta
seção).

## Estado do marco (2026-08-31): navegação em wizard, identidade nova, RuFaS como submodule
Atualização do estado acima (2026-08-29), que ficou desatualizado em
três pontos:

1. **Navegação**: Tela 1 tem menu lateral (`app_drawer.dart`) com
   "fazenda ativa"; Tela 2 é o wizard de 3 passos + revisão +
   confirmação, não mais um formulário único — ver "Reformula
   navegação" acima.
2. **Identidade visual**: paleta "editorial de laticínio" (verde-floresta
   + dourado + creme, Work Sans), não mais a paleta Material 3 original —
   ver "Nova identidade visual" acima.
3. **Bug corrigido no backend**: o venv do RuFaS tinha (tem) um
   `pip install` não-editável incompleto — falta o subpacote
   `RUFAS.biophysical` (limitação do `pyproject.toml` do RuFaS,
   `packages = ["RUFAS"]` sem subpacotes). Isso já causava
   `ModuleNotFoundError: No module named 'RUFAS.biophysical'`
   dependendo de como o `uvicorn` era iniciado (o truque de
   `os.chdir` + `PYTHONPATH` em `simulation_runner.py` só funcionava se
   o processo deixasse `sys.path` seguir o `cwd` dinamicamente — não é o
   caso ao rodar o script `uvicorn` do venv diretamente). Corrigido
   inserindo `RUFAS_ROOT` explicitamente no início do `sys.path` em
   `backend/simulation_runner.py`, independente de como o processo é
   iniciado.
4. **`RuFaS/` agora é git submodule** deste repositório (era só um
   checkout local ignorado pelo git) — ver "RuFaS agora é git submodule
   deste repositório" acima.

Nenhuma dessas mudanças alterou o fluxo funcional (cadastro → simulação
→ status → resultados → gráfico), que continua de ponta a ponta em Web e
Android. **Próximo passo natural continua sendo a Fase 4** (assistente
conversacional).
