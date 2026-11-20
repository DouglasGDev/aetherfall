# 09 — Bioma como código, cor do pelo e fundo de Éter por bioma

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20 ( [`AGENTS.md`,
"Escopo autorizado agora"](../../AGENTS.md) — extensão de 2026-11-20). Este dossiê é o **primeiro**
da série 09 → 10 → 11 → 12 porque a cor do filhote (11) e o background de Éter lido pela alcateia
(10) perguntam "de que bioma" antes de qualquer coisa.

## 1. Premissa nomeada

**Um bioma só existe como código se ele decidir algo que o jogador vê ou o lobo sente.**
Forma falsificável, em headless: dois lobos colocados em colunas de neve e de areia têm de sair com
material de pelo **diferente**, e o mesmo par `(seed, x, z)` tem de devolver o mesmo identificador
de bioma em duas instâncias de `WorldGen`. Se a cor não muda entre biomas, a tabela é enfeite; se o
identificador muda entre duas instâncias com a mesma semente, ele não é função do mundo.

Segunda premissa, e ela trava o escopo: **derivar bioma não pode alterar o terreno.** A geração é
determinística ([world_gen.gd:2](../../src/world/world_gen.gd#L2), `GEN_VERSION = 4` em
[:6](../../src/world/world_gen.gd#L6)) e o hash por tick do journal recebe as dimensões do mundo
([tick_journal.gd:16-44](../../src/persistence/tick_journal.gd#L16-L44)). Uma projeção de bioma que
mexer em byte de bloco muda o hash de revisões antigas e reabre o dossiê 01.

## 2. Estado real do código (lido, não medido)

- **A palavra não existe em `src/`.** `grep -i "bioma|biome"` no repositório devolve 12 ocorrências
  em 7 arquivos — [`AGENTS.md`](../../AGENTS.md) 1, [`README.md`](../../README.md) 1 e as 10 em
  [`docs/design/06`](../design/06-godot-architecture.md) (2), [`07`](../design/07-project-structure.md)
  (5), [`04`](../design/04-local-ai-architecture.md) (1), [`08`](../design/08-roadmap-risks-licensing.md)
  (1). Em `src/` e `tests/`: **zero**. O diretório prometido `src/.../world/biome/` com
  `biome_table.gd`, `climate.gd`, `soil.gd`, `rivers.gd` (`docs/design/07-project-structure.md:99`)
  não existe, assim como `biomes/*.tres` (`docs/design/07-project-structure.md:263`).
  `[TARGET]`.
- **O que existe é uma regra, não um estado.**
  [`surface_block(x, z, h)`](../../src/world/world_gen.gd#L100-L111) escolhe o bloco de topo por
  três condições: `h <= SEA_LEVEL + 1` → `SAND`; `h >= 52` → `SNOW` abaixo de 57, `STONE` acima;
  depois `_temp < -0.35` → `SNOW`, `_moist < -0.30` → `SAND`, senão `GRASS`. Os dois ruídos vêm de
  [`_moist`](../../src/world/world_gen.gd#L33) (semente `p_seed + 3`, frequência 0,0045,
  [:45](../../src/world/world_gen.gd#L45)) e
  [`_temp`](../../src/world/world_gen.gd#L34) (semente `p_seed + 4`, frequência 0,0030,
  [:46](../../src/world/world_gen.gd#L46)). `SEA_LEVEL` é 26
  ([voxel_config.gd:13](../../src/world/voxel_config.gd#L13)). O resultado **não é guardado**:
  depois de `generate_chunk` ([world_gen.gd:114-137](../../src/world/world_gen.gd#L114-L137))
  escrever os blocos, ninguém sabe de que regra cada coluna veio — só de que bloco ela é feita.
- **O pelo é uma linha só, e é compartilhada.**
  [`_build_visual()`](../../src/entities/wolf.gd#L885) cria um `StandardMaterial3D` por lobo
  ([:889](../../src/entities/wolf.gd#L889)) e pinta todos com
  `Color(0.40, 0.36, 0.31)` ([:890](../../src/entities/wolf.gd#L890)); as caixas do corpo usam essa
  material de [:892](../../src/entities/wolf.gd#L892) até [:917](../../src/entities/wolf.gd#L917).
  Não há cor por semente, por bioma nem por indivíduo.
- **O Éter não sabe onde está.** `setup` aloca `_cur`/`_nxt` de
  `COUNT * _per_channel` ([aether_field.gd:42-54](../../src/world/aether_field.gd#L42-L54)) e as
  três tabelas por canal são constantes
  ([:9-17](../../src/world/aether_field.gd#L9-L17)). Os imprints existentes passam valor fixo por
  evento: `WORK 0,42`/`0,20` no jogador
  ([main.gd:356-361](../../src/main.gd#L356-L361)), `FEAR 0,4` no spawn
  ([:211](../../src/main.gd#L211)), `BLOOD 1,3` + `FEAR 1,0` no cadáver
  ([:400-401](../../src/main.gd#L400-L401)). Uma coluna de gelo e uma de savana imprimem o mesmo
  número.
- **Onde o bioma seria lido, hoje:** `setup` do lobo recebe `p_spawn` e sorteia `_rng` com a semente
  do mundo ([wolf.gd:166-182](../../src/entities/wolf.gd#L166-L182), `:121`) — o ponto natural de
  perguntar "que bioma é este?" uma vez por lobo, sem cadência. A sessão já sorteia o
  `home` num raio de 16–46 ([main.gd:199-215](../../src/main.gd#L199-L215), via
  [`_random_ground_point`](../../src/main.gd#L240-L254)).

## 3. O que a peça exige

1. **`biome_of(x, z, h) -> int` em `WorldGen`** — função pura das mesmas duas ruídos e da altura que
   `surface_block` já usa, com a **mesma** ordem de condições (água/praias primeiro, altitude,
   depois frio e seca). Enumeração fechada e pequena: `FROZEN`, `ARID`, `TEMPERATE`, `WETLAND` —
   quatro, porque é o que as duas ruídos + altura distinguem hoje sem criar dado novo.
   `surface_block` passa a **consultar** `biome_of` em vez de repetir as comparações, então a regra
   fica uma vez só (mandato: generalizar no segundo chamador — aqui o chamador extra já existe).
   Propriedade exigida: **nenhum byte de bloco muda**; `surface_height`
   ([world_gen.gd:71-85](../../src/world/world_gen.gd#L71-L85)) e `generate_chunk` ficam intactos.
2. **Cor do pelo derivada do bioma do `home`**, escolhida em `setup` e aplicada em `_build_visual`
   no lugar da linha [:890](../../src/entities/wolf.gd#L890). Tabela de quatro cores na própria
   classe do lobo (não em `.tres`: um consumidor só, e o padrão da casa é dado no código até haver
   motivo para dado em arquivo — [`AGENTS.md`](../../AGENTS.md), anti-bloat).
3. **Fundo de Éter por bioma como viés de imprint, não como semeadura de grade.** O imprint sabe a
   célula; `biome_of` sabe responder por ela. Cada fonte ganha um multiplicador por bioma (neve
   segura mais FEAR, areia mais WORK) aplicado em
   [`imprint`](../../src/world/aether_field.gd#L87) pelo **chamador**, não dentro do campo: o campo
   continua sem saber de mundo, e `diffuse_and_decay`
   ([:117+](../../src/world/aether_field.gd#L117)) não ganha leitura de voxel — ela custaria uma
   consulta por célula por passada, 4×/s.
4. **Nada de `biome_table.gd`, `climate.gd`, `soil.gd`, `rivers.gd`, sites ou `.tres`** — são a
   estrutura prometida de P2 (design/07) e precisam de um segundo comprador antes de existir.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Às vezes: `biome_of` é consultada uma vez por lobo no
  `setup` (5 chamadas por sessão) e por imprint (o `_on_acted` já roda em evento do jogador, e a
  lavra é limitada pelo `hardness` de `player.gd:636-647`). **Nenhuma** chamada entra em
  `_physics_process` nem dentro de `diffuse_and_decay`.
- **Quantas entidades são alcançadas?** 5 lobos hoje; 4 biomas; os ~13 sítios de imprint que já
  existem (`grep imprint` em `src/` devolve 12 linhas). Custo por chamada: duas amostras de ruído
  2D — as mesmas que `surface_block` já faz na geração, coluna por coluna, 64 chunks.
- **Aloco no caminho quente?** Não: assinatura `-> int`, sem Array, sem Dictionary novo. O material
  de pelo já é um por lobo ([wolf.gd:889](../../src/entities/wolf.gd#L889)) — mudar a cor não muda
  o número de recursos nem de draw calls.
- **Como sei que ficou melhor?** Não é "melhor", é "existe": as checagens do §5. E o custo que
  aparece é o de sempre — o rodapé de colheita de `sim_step` do runner de reações
  ([aether_reactions_test.gd:178-194](../../tests/aether_reactions_test.gd#L178-L194)) tem de sair
  na banda das oito árvores medidas (361 464–375 216 µs em 2 768 passos,
  [nota da rodada](../melhorias-status.md)); se sair, o imprint com bioma não custou nada.

## 5. Gate em headless

Comandos que já existem, sem nada novo de infraestrutura:

```sh
godot --headless --path . --import          # só no clone ainda não importado
godot --headless --path . --check-only --script src/world/world_gen.gd
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/aether_reactions_test.gd
```

Checagens novas, com o número que decide cada uma impresso:

1. **`bioma_deterministico`** — duas instâncias de `WorldGen` com `setup(20261116)` devolvem o
   mesmo `biome_of` para uma grade amostrada (ex.: 16 × 16 colunas). Imprime a contagem de células
   divergentes: tem de ser **0**.
2. **`bioma_nao_altera_terreno`** — as 16 colunas de relevo do mundo gerado (a mesma comparação que
   a suíte já faz em [`smoke_test.gd`](../../tests/smoke_test.gd)) e a assinatura de blocos de
   topo de uma grade fixa ficam **idênticas** à revisão anterior. Essa checagem é a prova da
   premissa §1.2, e é a única que pode fechar o lote.
3. **`cor_do_pelo_vem_do_bioma`** — dois lobos com `home` em biomas diferentes saem com
   `albedo_color` diferente; dois lobos no mesmo bioma saem com a **mesma** cor. Imprime as cores
   em hex e o bioma de cada um.
4. **`imprint_bioma_tem_mesma_ordem`** — a mesma fonte no mesmo lugar, com e sem viés, preserva a
   ordem de grandeza (nenhum canal satura em `MAX_VALUE 4,0`,
   [aether_field.gd:17](../../src/world/aether_field.gd#L17)) e o valor médio por canal do cenário
   estreito não sai da banda medida.

`EXPECTED_CHECKS` ([aether_reactions_test.gd:19](../../tests/aether_reactions_test.gd#L19), hoje
**109**) e a contagem da suíte (hoje **236 / 0 falhas**, pin [`README.md`](../../README.md)) sobem
com o lote e são re-medidos no clone limpo antes de qualquer número ir para o texto.

## 6. O que NÃO fazer

- Não guardar bioma por chunk nem por coluna como dado novo do mundo: é estado que ninguém pediu e
  o save ([save_manager.gd](../../src/persistence/save_manager.gd)) passa a ter de migrar.
  Projeção lida, não gravada.
- Não mexer em `GEN_VERSION` ([:6](../../src/world/world_gen.gd#L6)) nem em `FORMAT_VERSION` do
  journal ([tick_journal.gd:16-44](../../src/persistence/tick_journal.gd#L16-L44)) — este lote não
  muda nem terreno nem a projeção do hash. Mudar é reabrir o dossiê 01.
- Não dar cor aleatória por lobo: o pedido é **por bioma**, e aleatoriedade sem semente do mundo
  quebraria o que `setup` já garante ([:175](../../src/entities/wolf.gd#L175)).
- Não colocar o viés dentro de `AetherField`: o campo hoje não conhece voxel nenhum, e essa
  fronteira é o que mantém a difusão barata.
- Não prometer "bioma deserto" na galeria sem re-bake: as capturas são cena própria
  (`.tools/shot_gallery.tscn`, [README](../../README.md)) e o texto delas é `[MEASURED]` de um
  frame, não deste lote.

## 7. Commits atômicos

Um assunto, uma corrida: (a) `biome_of` + `surface_block` consultando, com a checagem 2 vermelha
antes e verde depois; (b) cor do pelo, com as checagens 3; (c) viés de imprint, com a 4; (d) status
+ `README.md` re-pinados com o número do clone limpo. Branch `feat/bioma-e-cor-de-pelo-09`, base
`main`, merge `--no-ff`.

## 8. Citações deste arquivo

Toda linha acima foi lida nesta revisão (`main` = `9f5256b`). Se o lote crescer o arquivo citado,
a âncora envelhece junto — regra e precedente no status, furo #13 (rótulo de citação e âncora da
URL envelhecem separados, e nada no repositório confere os dois).
