# Board de Pedidos / Carrinhos — contexto do projeto

App local estilo Trello pra acompanhar pedidos e carrinhos abandonados de uma
loja de calçados. Alimentado por planilha `.xlsx` exportada da plataforma,
carregada pelo próprio usuário no navegador. Roda como **mini-app local**
(servidorzinho + navegador) ou, como fallback, direto em `file://`.

_Última atualização: 2026-07-02._

## Arquivos (tudo na mesma pasta)
- `index.html` — o app inteiro (HTML + CSS + JS inline). É o que abre no navegador.
- `xlsx.full.min.js` — biblioteca SheetJS que lê o `.xlsx`. **Precisa** estar junto do HTML.
- `Board.bat` — launcher do cliente (Windows): sobe o `server.ps1` e abre o navegador.
- `server.ps1` — servidor local em PowerShell puro (sem instalar nada). Serve os arquivos
  e persiste o estado em `banco.json`. É o que o **cliente (Windows)** usa.
- `server.py` — servidor gêmeo em Python (mesmos endpoints). Usado no **desenvolvimento/teste**
  (Linux/Mac). Não vai pro cliente.
- `LEIA-ME.txt` — instruções pro cliente.
- `banco.json` — estado persistido (criado sozinho). **Gitignored** (contém PII).
- `nulla-pedidos-*.xlsx` / `nulla-carrinhos-*.xlsx` — planilhas exemplo (gitignored, PII).

## Como usar
- **Cliente (Windows):** duplo-clique no `Board.bat` → 1x o aviso do SmartScreen
  (*Mais informações → Executar assim mesmo*) → abre o navegador em `http://localhost:8791`.
  Manter a janelinha do servidor aberta enquanto usa.
- **Fallback `file://`:** dá pra abrir o `index.html` com 2 cliques também; nesse modo
  não há servidor e o estado cai no `localStorage`.
- **Atualizar planilha** → escolher board (📦 Pedidos / 🛒 Carrinhos) → selecionar o `.xlsx`.
  - O seletor de board usa `<label for="file">` (nativo) — `input.click()` programático
    NÃO abre o diálogo de forma confiável em `file://`. Não voltar pra `.click()`.

## Persistência (importante)
- `USE_SERVER = location.protocol é http(s)`. Se aberto via servidor, o estado é salvo
  no `banco.json` (auto-save via `POST /api/state`, debounce 200ms) e carregado no boot
  (`GET /api/state`). Se aberto em `file://`, cai no `localStorage` (chave `boardPedidos_v1`).
  O `localStorage` também é usado como cache/fallback sempre.
- Boot é **assíncrono**: `bootState()` decide a fonte (servidor ou local) e só então `render()`.
- Endpoints do servidor (iguais no `.ps1` e no `.py`): `GET/POST /api/state` ↔ `banco.json`;
  o resto é arquivo estático.

## Como a coisa funciona (arquitetura no `index.html`)
- **Boards** em `BOARDS`:
  - `pedidos` (**Comprou** · Em reclamação · Pós vendas · Cancelados) — Comprou e Transporte
    foram **fundidas** numa coluna só.
  - `carrinhos` (Carrinhos · Fup 1 · Fup 2 · Ultimato · Pós vendas).
- **Cores por etapa** em `COLORS`. Modal e cards herdam a cor da coluna.
- **Mapa de campos por board** em `BOARD_FIELDS` (as planilhas têm nomes de coluna diferentes):
  - `pedidos`: id/`numero_pedido`, `cliente`, `cliente_telefone`, `cliente_email`,
    `cliente_document`, `data`, `produto`, `quantidade`, `status`.
  - `carrinhos`: `id`, `nome_cliente`, `telefone_cliente`, `email_cliente`, (sem document),
    `criado_em` (data), `produtos` (**vários itens separados por vírgula**), (sem quantidade),
    `tentativas_recuperação` (status).
- **1 card = 1 registro**: `importWorkbook()` agrupa por `id`. Em pedidos há 1 linha por
  produto (viram a lista de itens, com quantidade). Em carrinhos é 1 linha por carrinho e o
  campo `produtos` é splitado por vírgula.
- **De-para status → coluna** em `BOARD_STATUS_MAP[board]`; fallback `BOARD_DEFAULT_COL[board]`.
  - Pedidos: `Em transporte→comprou`, `Pagamento aprovado→comprou`,
    `Cancelado→reclamacao`, `Aguardando pagamento→comprou`.
  - Carrinhos (usa `tentativas_recuperação` = "n/4"): `0/4→carrinhos`, `1/4→fup1`,
    `2/4→fup2`, `3/4→ultimato`, `4/4→ultimato`. Na planilha exemplo cai 8/2/12/187/0
    (Ultimato domina — a base vem "no fim do funil").
- **Emoji por etapa (só Pedidos)** em `PEDIDO_STATUS`: 🚚 Em transporte · 🛍️ Comprou
  (Pagamento aprovado) · ⏳ Aguardando pagamento. Aparece no nome do card e no campo
  "Etapa" do modal. Depende do `status` cru guardado no card (pedido já importado antes
  desta feature só ganha emoji após reimportar).
- **Cards "novos"** (`state.novos[board]`): no import, ids que não existiam na planilha
  anterior sobem pro topo da coluna e ganham fundo tingido (`.card.novo`, cor da coluna
  clara). 1ª importação não marca ninguém. Recalculado a cada import.
- **Dedup de cancelados** (só pedidos): se o cliente virou comprador (pedido em
  `Em transporte`/`Pagamento aprovado`), os `Cancelado` dele vão pra coluna `Cancelados`
  (em vez de `Em reclamação`). Identidade por CPF (`cliente_document`) → telefone → e-mail.
  `SUCCESS_STATUSES`/`CANCELLED_STATUS`. Exemplo: 22 vão pra `Cancelados`, 15 ficam em
  `Em reclamação`. **`Aguardando pagamento` NÃO conta como comprador.**
- **Estado** (`state`), isolado por board: `sheets[board]` (base da planilha, com `status`),
  `moves[board]`, `edits[board]`, `deleted[board]`, `novos[board]`, `manual` (cards à mão),
  `updated[board]`, `sort`.
- **Planilha = fonte de verdade da existência**: ao reimportar, `importWorkbook()` reconcilia —
  registro que sumiu some; moves/edits/deleted de ids inexistentes são podados; os de ids que
  continuam são preservados. **Cards manuais nunca são tocados pelo import.**
- **Resolução de coluna** (`cardsForBoard`): `move manual → status da planilha → default`.
  Ou seja: card que você **não** moveu segue a última atualização da planilha; card que você
  moveu à mão fica onde você pôs (o novo status é ignorado). Regra "status mudou → planilha
  vence" foi discutida mas **não** implementada.
- **Scroll preservado**: `renderBoard()` salva/restaura o scroll das colunas + página antes de
  reconstruir (editar/mover/excluir não joga mais o scroll pro topo).
- **Busca** (`searchQuery` + `norm()`): campo no header filtra os cards das colunas por nome
  (sem acento/caixa); as contagens acompanham; limpa ao trocar de board. Estado transitório (não salvo).
- **Mover card por nome** (`openMover`/`doMover`): botão "⇄ Mover card pra cá" por coluna (à parte
  do "➕"). Acha o card por nome (exato → parcial; datalist com autocomplete). Se já estiver naquela
  coluna, **avisa e não mostra o confirm**; senão pede "Você tem certeza…" antes de mover. Nome não
  encontrado/ambíguo → avisa. Tudo em `index.html` (as 2 features não mexem em outro arquivo).
- **Ordenação** por data (`parseData`/`sortCards`), botão no topo, persistida. Novos vêm antes.
- **Migração** (`normalizeState`): formato antigo de board única (`state.sheet`) → multi-board;
  e coluna `transporte` (extinta) → `comprou` em sheets/moves/manual. Não remover tão cedo.

## Status atual — FEITO ✅
- Pedidos e Carrinhos: import com mapa de campos, de-para, colunas, cards, add/editar/mover/
  excluir, reconciliação, isolamento entre boards.
- Persistência via servidor (`banco.json`) + fallback `localStorage`. Launcher Windows.
- Fusão Comprou/Transporte + emoji de etapa. Cards novos destacados. Scroll preservado.
- Busca por nome nas colunas. Mover card por nome (botão por coluna, com confirmação).
- Visual tema camurça/espresso.

## Pontas soltas / decisões abertas
- **Validar o `Board.bat`/`server.ps1` num Windows real** — só foi testado o app + persistência
  via `server.py` (gêmeo). Falta 1 run em Windows (porta, SmartScreen).
- **Export/Import banco (.json)** — discutido como backup portátil; **não** implementado.
- **Regra move manual × última atualização** — indefinida (ver "Resolução de coluna").

## Testar durante o desenvolvimento
- Playwright não abre `file://`. Suba `python3 server.py --no-browser` na pasta (mesmos
  endpoints do PowerShell) e abra `http://127.0.0.1:8791/index.html` no Playwright.
- Não há suíte de testes commitada; validação é manual via Playwright (import/persistência/
  render), lendo `banco.json` do disco pra conferir o que foi salvo.
- Sempre limpar `banco.json` e o `localStorage` entre testes (o `state` em memória **não** é
  limpo por `localStorage.clear()` — recarregar a página ou zerar as sub-chaves).

## Preferências do usuário
- Respostas curtas (1–2 frases). Ele testa no próprio navegador e dá o retorno.
- Interações em texto, sem menu clicável (evitar a ferramenta de perguntas com opções).
