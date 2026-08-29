# Requisitos — RuFaS Interface do Produtor

Este documento registra os requisitos funcionais e não-funcionais do sistema, além do escopo e das restrições. Serve de referência para desenvolvimento, validação e planejamento das próximas fases.

## Objetivo do sistema

Permitir que produtores rurais e técnicos (extensionistas, zootecnistas) — sem conhecimento técnico de computação — descrevam uma fazenda leiteira, executem uma simulação no modelo RuFaS e explorem os resultados, através de uma interface amigável que encapsula toda a complexidade do modelo.

## Atores

- **Produtor rural:** usuário-alvo principal. Descreve a fazenda em linguagem de fazenda; não conhece o RuFaS nem termos técnicos.
- **Técnico / extensionista / zootecnista:** usuário intermediário; pode conhecer o vocabulário do domínio, mas não a implementação do modelo.
- **Desenvolvedor / pesquisador:** mantém e evolui o sistema; tem acesso ao código e aos detalhes técnicos.

---

## Requisitos funcionais

Numerados como RF-n. Estado: ✅ implementado · ⬜ a construir.

### Cadastro e simulação de fazenda

- **RF-01** ✅ O sistema deve permitir cadastrar uma fazenda informando poucos campos em linguagem de fazenda: número de vacas em lactação, número de bezerras, produção de leite anual desejada, tamanho da propriedade (dois campos/talhões) e código do condado (localização/clima).
- **RF-02** ✅ O sistema deve validar os campos do formulário com mensagens claras e não-técnicas (obrigatoriedade, tipo, faixa), aceitando formato decimal brasileiro (vírgula ou ponto).
- **RF-03** ✅ O sistema deve traduzir os dados informados na estrutura de entrada que o RuFaS exige, sem intervenção do usuário.
- **RF-04** ✅ O sistema deve executar a simulação do RuFaS a partir dos dados cadastrados, nos bastidores.
- **RF-05** ✅ A execução deve ser assíncrona: o cadastro retorna imediatamente e a simulação prossegue em segundo plano.

### Acompanhamento

- **RF-06** ✅ O sistema deve permitir acompanhar o progresso da simulação, exibindo o estado em linguagem de fazenda ("na fila", "gerando rebanho", "simulando", "concluída").
- **RF-07** ✅ O sistema deve tratar os três desfechos — sucesso, falha e espera longa — com mensagens claras; em caso de falha, sem expor jargão técnico ao produtor (detalhes técnicos disponíveis de forma separada).
- **RF-08** ✅ O sistema deve listar as simulações/fazendas, com seu estado atual.

### Resultados

- **RF-09** ✅ O sistema deve permitir filtrar as variáveis do resultado por módulo e palavra-chave, mostrando a contagem de colunas selecionadas dinamicamente.
- **RF-10** ✅ O sistema deve oferecer, como recurso avançado, um padrão de busca (regex) editável, sem expô-lo como caminho principal.
- **RF-11** ✅ O sistema deve classificar as variáveis (plotável, categórica, não-plotável) e visualizar as plotáveis como gráfico de série temporal.
- **RF-12** ✅ O sistema deve tratar com clareza a seleção de variáveis não-plotáveis, sem gráfico quebrado ou vazio.
- **RF-13** ✅ O sistema deve permitir baixar o resultado completo da simulação (CSV).

### Multiplataforma

- **RF-14** ✅ O app deve funcionar em navegador (web) e Android a partir da mesma base de código.
- **RF-15** ⬜ O app deve funcionar em macOS e iOS (pendente: toolchain Xcode).

### Assistente (Fase 4)

- **RF-16** ⬜ O sistema deve permitir consultar os resultados da simulação em linguagem natural, por um assistente conversacional, referente à fazenda selecionada.

### Múltiplas fazendas (previsto no design)

- **RF-17** ⬜ O sistema deve permitir gerenciar várias fazendas por usuário, com seleção de uma fazenda ativa à qual o assistente e os resultados se referem.
> Nota: a rota de listagem (RF-08) é a base para isto; o gerenciamento completo de múltiplas fazendas com fazenda ativa é do design do app, ainda a implementar plenamente.

---

## Requisitos não-funcionais

- **RNF-01 — Usabilidade:** a interface deve ser compreensível por usuário sem familiaridade com tecnologia — linguagem de fazenda, elementos grandes, contraste alto, sem jargão. Público principal em celular.
- **RNF-02 — Encapsulamento:** o usuário nunca deve ver arquivos, JSON, unidades técnicas ou termos do modelo. Toda complexidade fica no backend.
- **RNF-03 — Responsividade da interface:** operações longas (simulação) não podem travar o app; feedback de progresso é obrigatório.
- **RNF-04 — Consistência multiplataforma:** o comportamento deve ser equivalente entre web e Android (validação em ambas a cada tela é prática do projeto).
- **RNF-05 — Legibilidade dos dados:** volumes grandes (CSV de ~900 MB) não podem ser enviados crus ao cliente; o backend filtra e reduz (downsampling) antes.
- **RNF-06 — Manutenibilidade:** tema visual e validações centralizados em fonte única; lógica de filtragem compartilhada de forma coerente.
- **RNF-07 — Reprodutibilidade:** a execução do RuFaS registra a semente e a configuração, permitindo regenerar resultados.
- **RNF-08 — Identidade visual:** Material 3 com paleta associada à pecuária leiteira (verdes, âmbar), transmitindo confiança.

---

## Escopo

### Dentro do escopo (fase atual)
- Cadastro de fazenda, execução da simulação, acompanhamento, filtragem e visualização dos resultados.
- Web e Android.
- Execução local (máquina de desenvolvimento).

### Fora do escopo (fase atual)
- Deploy / hospedagem / acesso remoto.
- Autenticação e multiusuário real.
- Assistente conversacional (Fase 4).
- Persistência estruturada de várias fazendas (parcial; ver RF-17).
- macOS/iOS validados.

---

## Restrições

- **RES-01:** o sistema depende do RuFaS instalado e funcional no ambiente; não o substitui nem o modifica.
- **RES-02:** cada simulação gera ~1 GB de saída e leva ~10 minutos; o design assume execução serializada (uma por vez) na fase atual.
- **RES-03:** `annual_milk_yield` é um alvo de calibração, não uma garantia de saída — a interface não deve prometer que o resultado igualará o valor informado.
- **RES-04:** a capacidade de curral não escala automaticamente com o rebanho (gap conhecido); rebanhos muito grandes podem produzir resultados afetados por superlotação.
- **RES-05:** o ambiente de execução atual é local; requisitos de rede, segurança e escala de produção não se aplicam nesta fase.

---

## Rastreabilidade (requisito → onde vive)

| Requisito | Camada / componente principal |
|-----------|-------------------------------|
| RF-01, RF-02 | Frontend — `new_farm_screen.dart`, `form_validators.dart` |
| RF-03 | Backend — `farm_translation.py` |
| RF-04, RF-05 | Backend — `simulation_runner.py`, `app.py` (background) |
| RF-06, RF-07 | Frontend — `simulation_status_screen.dart`, `simulation_states.dart` |
| RF-08 | Backend — `GET /simulations` · Frontend — `farm_list_screen.dart` |
| RF-09..RF-13 | Backend — endpoints de colunas/filtro/chart-data · Frontend — `results_screen.dart`, `chart_screen.dart` |
| RF-14 | Frontend — `api_client.dart` (resolução por plataforma) |
