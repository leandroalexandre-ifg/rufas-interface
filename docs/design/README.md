# Referências de design (Claude Design)

Fonte dos protótipos visuais explorados com o Claude Design, guardada aqui
como referência — não é código do app nem é executada pelo Flutter.

Cada `.dc.html` é um "Design Component": um arquivo autocontido, renderizado
pelo editor do Claude Design (não abre como HTML comum num navegador).
Para editar de verdade, use o link publicado — ele carrega o editor.

## Links publicados (versão editável, ao vivo)
- Logo: https://claude.ai/code/artifact/53c7c1a8-7389-499c-9ec6-ebd1c42c7e24
- Protótipo do app (mobile + desktop): https://claude.ai/code/artifact/87ab957d-939e-4fa2-9487-93594cd978ff

Esses links são privados (só quem tem acesso à conta que gerou vê); os
arquivos `.dc.html` abaixo são a única cópia dessa fonte versionada no git.

## `rufas-logo/`
Logo genérico do RuFaS, na direção visual descrita abaixo: lockup principal
(`Main.dc.html`), ícone isolado para uso como ícone de app (`IconMark.dc.html`)
e wordmark solto para espaços estreitos (`Wordmark.dc.html`).

## `rufas-app-prototype/`
Protótipo clicável (dados de amostra, sem chamada real à API) das 4 telas do
app Flutter: lista de fazendas, cadastro em wizard, status da simulação e
resultados/gráfico.
- `Main.dc.html` — versão mobile (telefone, com menu lateral em gaveta).
- `Desktop.dc.html` — versão desktop/browser (barra lateral fixa, grade de
  cards, layout de duas colunas em resultados e gráfico).

## Direção visual
Paleta e tipografia inspiradas num sistema de design de referência (Hartzler
Family Dairy, via refero.design) — não copiado literalmente (sem o nome, logo
ou fotos de produto da marca original), só a lógica de cores/tipografia/
composição: verde-floresta `#1B4D3E` como cor âncora, creme `#FAF7F0` de
fundo, amarelo-manteiga `#F4C15C` e teal `#4FB6A8` como acentos, tipografia
Work Sans bem forte (peso 900) nos títulos, botões e chips em pílula, sem
sombra/gradiente — bordas finas no lugar.

Essa identidade ainda não foi aplicada ao código do app (`flutter_app/`) —
os arquivos aqui são só a referência visual/exploração, pendente de decisão
sobre adotar (e implementar) esse novo visual.
