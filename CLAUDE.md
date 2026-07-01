# Board de Pedidos / Carrinhos — contexto do projeto

App local estilo Trello (1 arquivo HTML) pra acompanhar pedidos e carrinhos
abandonados de uma loja de calçados. Alimentado por planilha `.xlsx` exportada
da plataforma, carregada pelo próprio usuário no navegador.

_Última atualização: 2026-07-01._

## Arquivos (tudo na mesma pasta)
- `index.html` — o app inteiro (HTML + CSS + JS inline). É o que o usuário abre.
- `xlsx.full.min.js` — biblioteca SheetJS que lê o `.xlsx`. **Precisa** estar junto do HTML.
- `nulla-pedidos-*.xlsx` — planilha exemplo de PEDIDOS usada no desenvolvimento.

## Como usar (usuário final)
1. Abrir `index.html` com 2 cliques (roda em `file://`, sem servidor).
2. **Atualizar planilha** → escolher board (📦 Pedidos / 🛒 Carrinhos) → selecionar o `.xlsx`.
   - O seletor de board usa `<label for="file">` (nativo) — importante: `input.click()`
     programático NÃO abre o diálogo de forma confiável em `file://`. Não voltar pra `.click()`.
3. Cards e alterações ficam salvos no `localStorage` (chave `boardPedidos_v1`), por
   navegador/máquina. Reabrir carrega sozinho; "Atualizar" só é usado quando a planilha muda.

## Como a coisa funciona (arquitetura no `index.html`)
- **Boards** em `BOARDS`: `pedidos` (Transporte · Em reclamação · Comprou · Pós vendas)
  e `carrinhos` (Carrinhos · Fup 1 · Fup 2 · Ultimato · Pós vendas).
- **Cores por etapa** em `COLORS`. Modal e cards herdam a cor da coluna.
- **1 card = 1 pedido**: `importWorkbook()` agrupa linhas da planilha por `id`
  (fallback `numero_pedido`); produtos do pedido viram a lista de itens. Campos usados:
  `cliente`, `cliente_telefone`, `data`, `produto`, `quantidade`, `status`.
- **De-para status → coluna** em `BOARD_STATUS_MAP[board]`; fallback `BOARD_DEFAULT_COL[board]`.
  - Pedidos: `Em transporte→transporte`, `Pagamento aprovado→comprou`,
    `Cancelado→reclamacao`, `Aguardando pagamento→comprou`.
  - Carrinhos: **`{}` (provisório)** → tudo cai em `carrinhos`. **A DEFINIR** (ver abaixo).
- **Estado** (`state`, salvo em `localStorage`), tudo isolado por board:
  `sheets[board]` (base da planilha), `moves[board]` (moves manuais),
  `edits[board]` (edições manuais por cima da planilha), `deleted[board]`
  (cards da planilha excluídos à mão), `manual` (cards criados à mão, guardam o board),
  `updated[board]`, `sort` (`newest`/`oldest`).
- **Planilha = fonte de verdade da existência**: ao reimportar, `importWorkbook()`
  reconcilia — pedido que sumiu some; moves/edits/deleted de ids inexistentes são podados;
  moves/edits/exclusões manuais de ids que continuam são preservados.
- **Ordenação** por data da compra (`parseData`/`sortCards`), botão no topo, persistida.
- **Migração**: `loadState()` converte o formato antigo de board única (`state.sheet`) pro
  novo multi-board. Não remover tão cedo.

## Status atual — FEITO ✅
- Pedidos: import, de-para, agrupamento por pedido, colunas, cards (nome → abre produtos/
  telefone/WhatsApp/data), adicionar/editar/mover (drag)/excluir, reconciliação.
- Carrinhos: board pronta; import cai tudo em "Carrinhos" (de-para pendente).
- Coluna "Pós vendas" nas 2 boards (manual). Seletor de board na importação. Ordenação.
- Persistência localStorage. Visual (tema camurça/espresso). 27 testes automatizados passando.

## PRÓXIMA ETAPA — planilha de Carrinhos abandonados 🔜
Quando o usuário mandar a **planilha exemplo de carrinhos**:
1. Inspecionar as colunas dela (nomes dos campos podem diferir da de pedidos —
   ex.: talvez não tenha `status`, ou o campo de nome/telefone/data tenha outro nome).
2. Definir o **de-para** em `BOARD_STATUS_MAP.carrinhos`: mapear o que existe na planilha
   pras colunas `carrinhos` / `fup1` / `fup2` / `ultimato`. Se não houver campo de etapa,
   manter default `carrinhos` e o usuário move à mão.
3. Se os nomes dos campos forem diferentes, generalizar a leitura em `importWorkbook()`
   (hoje os nomes de coluna estão fixos: `cliente`, `cliente_telefone`, `data`, `produto`…).
   Considerar um mapa de campos por board.
4. Reconfirmar a chave de agrupamento (`id`/`numero_pedido`) pra planilha de carrinhos.
5. Testar import em Carrinhos e o isolamento em relação a Pedidos.

## Testar durante o desenvolvimento
- Playwright não abre `file://`. Pra testar: `python3 -m http.server 8791` na pasta e
  abrir `http://127.0.0.1:8791/index.html`. O código é idêntico ao uso em `file://`.
- O usuário usa por duplo-clique (`file://`) — sempre validar que o fluxo de upload
  funciona nesse modo (por isso o `<label>`).

## Preferências do usuário
- Respostas curtas (1–2 frases). Ele testa no próprio navegador e dá o retorno.
- Interações em texto, sem menu clicável (evitar a ferramenta de perguntas com opções).
