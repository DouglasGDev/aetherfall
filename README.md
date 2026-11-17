# Aetherfall

RPG open-world em voxels, feito em **Godot 4.7** com **GDScript**, sob licença
**MIT**. O diferencial do projeto é a IA dos moradores do mundo rodar 100% na
máquina do jogador: comportamento de criaturas, personalidade e memória de NPCs,
facções e eventos nascem de simulação local, sem serviço de nuvem.

Este repositório contém o **slice P0/P1**: um mundo procedural jogável em 3D,
com mecânicas de quebra/colocação, combate, memória do mundo (campo de Éter) e
lobos guiados por Behavior Tree + Utilidade + memória. O design completo do jogo
está em [`docs/design/`](docs/design/).

## Rodando

Pré-requisito: Godot 4.7 (std ou .NET) — não há build step, não há dependências
externas.

```sh
godot --path .
```

Ou abra `project.godot` no editor e pressione **F5**. O primeiro boot gera o
mundo e malha os 64 chunks antes de entregar o controle ao jogador: ~1,1 s de
geração e ~4,7 s de malharia nesta máquina (medido; veja *Limites*).

## Controles

| Tecla | Ação |
| --- | --- |
| `W` `A` `S` `D` | mover |
| `Espaço` | pular |
| `Shift` | correr |
| `Ctrl` | agachar |
| Botão esquerdo | minerar bloco / atacar criatura |
| Botão direito | colocar bloco do slot selecionado |
| `1`–`7` | slot do hotbar |
| `V` | câmera em 1ª / 3ª pessoa |
| `B` | visão do Éter (mapa de calor dos canais) |
| `F3` | HUD de debug |
| `F2` | lista de bindagens |
| `F5` / `F9` | salvar / carregar o slot `alpha` |
| `Esc` | liberar o cursor |
| `R` | renascer (só com o jogador morto) |

## Teste headless

A suíte roda a sessão real (`src/main.tscn`) sem janela e só conta como prova o
que foi medido naquela execução:

```sh
godot --headless --path . tests/smoke_test.tscn
```

Sai com código `1` se qualquer checagem falhar. Resultado da última execução
nesta máquina: **106 checagens, 0 falhas, 29,0 s**. O que ela cobre:

- geração determinística (16 colunas de relevo e malha idênticas entre dois
  mundos criados com a mesma seed), face-culling exato (cubo 3×3×3 soma
  exatamente 108 triângulos; sem culling seriam 324) e winding dos triângulos
  na convenção de face frontal do Godot — com o índice em (0,1,2) o
  rasterizador descartava todas as faces de topo e o terreno aparecia
  transparente;
- relógio de simulação: 60 Hz de locomoção contra 20 Hz de lógica, teto de 5
  passos por frame, nenhum tick perdido durante o teste inteiro;
- mecânicas: mineração com o tempo igual à dureza do bloco, colocação por
  clique real do mouse passando pelo InputMap, recusa de colocar dentro do
  próprio corpo, troca de hotbar por tecla;
- IA: a mesma memória (`Mind`) muda a decisão do lobo entre os braços com e sem
  episódios gravados, e a fuga aparece depois de levar dano;
- campo de Éter: imprint, difusão para a célula vizinha e meia-vida por canal;
- HUD, morte e renascer, ciclo de vida dos lobos (cadáver, recolhimento e
  reposição de matilha);
- persistência: salvar → mutar o mundo → carregar devolve relevo, diário de
  edições, posição, vida, tick e a memória dos lobos.

## Estrutura

```
src/
  ai/            behavior tree, curvas de resposta, utilidade, mente do NPC
  core/          relógio de simulação (20 Hz)
  entities/      jogador, corpo voxel (colisão AABB-contra-voxel), lobo
  input/         registro de ações (sai para rebinder com persistência no P2)
  persistence/   save atômico (.tmp + rename), schema e diário de edições
  rendering/     visão do Éter
  ui/            HUD, debug, mensagens
  world/         mundo voxel, chunks, gerador, blocos, atlas, campo de Éter
  main.gd        composição do slice
tests/           smoke test headless
docs/design/     design completo (pitch, IA, progressão, arquitetura, roadmap)
```

## O que existe e o que é alvo de design

Implementado neste repositório: mundo voxel procedural (relevo com planície,
lago e praia de areia no nível do mar, monte nevado, árvores, blocos de pedra,
cavernas e túneis por ruído), malha com face-culling e oclusão ambiental por
vértice, texturas geradas em runtime (atlas 8×8), jogador em 1ª/3ª pessoa,
quebrar e colocar blocos, combate corpo a corpo, vida/dano/morte/renascer,
hotbar, HUD, 5 lobos com Behavior Tree + Utilidade + memória episódica e
confiança no jogador, campo de Éter com 3 canais (work, blood, fear) que difunde
e decai, relógio de simulação desacoplado, save/load atômico e a suíte headless
acima.

Ainda **alvo de design** (descrito em `docs/design/`, sem código aqui): NPCs de
aldeia com objetivos próprios, facções e evolução de assentamentos, progressão
não linear com bosses reimaginados, crafting, matchmaking e co-op 1–4, e o
rebinder com persistência de bindagens. Nada disso está pronto — o slice é o
P0/P1 do roadmap.

## Limites conhecidos (medidos nesta máquina)

- Boot: ~1,1 s de geração + ~4,7 s de malharia dos 64 chunks (230.932
  triângulos), com a janela congelada. Os ~16 s originais caíram para ~7,5 s
  quando as consultas de vizinhança do mesher passaram a ler uma cópia linear
  do mundo em vez do dicionário de chunks; a medição acima é do relevo atual
  (`GEN_VERSION` 3), que escava cavernas e portanto tem menos faces por chunk.
- Mundo fixo em 128×64×128 (8×8 chunks de 16×64×16), sem streaming de chunks.
- Uma criatura (lobo) e um NPC conceitual: a memória existe, mas não há
  aldeia nem facções.
- Single-player. O código separa o passo local do passo de simulação para
  permitir o dedicado, mas não há rede implementada.

## Licença

MIT — veja [`LICENSE`](LICENSE).
