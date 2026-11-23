# Leitura de retorno — os stdout do cavar viram evidência versionada (dossiê 12, fecho (h))

Branch `feat/bicho-cavando-12`, aberta da `main` em
**`dcbcbe823e6202750803cbfb3e84420553fc8185`** (o registro do pouso da evidência 07c) com ponta de código
**`d80ac207e9c33021944752ab9535e723c95b8bbc`**. Esta pasta **não mede nada novo**: ela arquiva os stdout que a
seção **"Rodada Cavar 12"** de [`docs/melhorias-status.md`](../../melhorias-status.md) publica e que até aqui
viviam em diretório gitignored — **cinco** corridas no clone limpo de `d80ac20` (sob
`.qoder/clones/clean-12h/`, com `--import` frio) e **cinco** na árvore de trabalho da ponta, mais as réguas
re-corridas nesta árvore — três comandos, quatro saídas, porque a do furo #30 pareia duas versões da mesma
régua sobre o corpus pineado. O débito é de instrumento, não de código: o ciclo de trabalho do
[AGENTS.md](../../../AGENTS.md), item 6, diz que número publicado é número medido nesta revisão, e um log que
só existe numa máquina não é conferível por quem clona o repositório.

Nenhuma linha de `src/` nem de `tests/` foi tocada por este fecho: `git diff --name-only d80ac20 -- src tests`
devolve **vazio** (0 arquivos). As árvores pineadas abaixo são as da ponta de código, e é por identidade de
árvore — não por herança de prosa — que o contrato medido aqui vale para a ponta desta branch.

## 1. O que está nesta pasta

| Arquivo | O que é |
| --- | --- |
| `clone_import.log` | o `--import` frio do clone limpo de `d80ac20` (exit 0, `[ DONE ] loading_editor_layout`, 0 `SCRIPT ERROR`, 0 linhas começadas por `ERROR`) |
| `clone_suite.log` | a suíte completa no clone — `== 255 checagens  0 falhas  48.0 s de teste ==` (rodapé na linha 357) |
| `clone_runner_reactions.log` | o runner de reações no clone — `283 checagens 0 falhas 33.194 s`, com os dois rodapés de colheita |
| `clone_runner_rng.log` | o runner de RNG no clone — `27 checagens 0 falhas 2.668 s` |
| `clone_runner_journal.log` | o runner do journal no clone — `128 checagens 0 falhas 7/7 testes concluidos 5.645 s` |
| `head_runner_run1.log` | o runner de reações na árvore de trabalho, primeira das duas corridas serializadas — `283 / 0 / 32.776 s` |
| `head_runner_run2.log` | a segunda — `283 / 0 / 32.782 s` |
| `head_suite.log` | a suíte na árvore de trabalho — `255 / 0 / 48.0 s` |
| `head_runner_rng.log` | o RNG na árvore de trabalho — `27 / 0 / 2.668 s` |
| `head_runner_journal.log` | o journal na árvore de trabalho — `128 / 0 / 5.672 s` |
| `ruler_doc_anchors.log` | saída de `python tools/check_doc_anchors.py` nesta árvore — `38 arquivos · 2 924 ponteiros · 209 rótulos · 2 939 links · casos objetivos: 0` |
| `ruler_doc_anchors_com_semm_secao.log` | a mesma régua sobre o mesmo corpus com e sem a seção "Rodada Cavar 12" — `2 924 · 209 · 2 939` contra `2 900 · 205 · 2 898`, os dois com `casos objetivos: 0`; é a testemunha do delta **+24 ponteiros, +4 rótulos, +41 links** |
| `ruler_plan_cites.log` | saída de `python .tools/verify_plan_cites.py …` nesta árvore — `2 720 citações`, `34` arquivos inexistentes, `fora do arquivo: 0` |
| `ruler_plan_ids.log` | saída de `python .tools/verify_plan_ids.py docs/planos/12-bicho-cavando-voxel.md` — `105` identificadores, `5` ausentes (todos SHA) |
| `furo30_regua_pareada_d80ac20.log` | as duas réguas sobre o corpus pineado em `d80ac20`: isenção larga `2 855` ponteiros, apertada `2 878`, **os mesmos `107` casos objetivos nos dois lados** — a testemunha do furo #30 |
| `artifacts.sha256` | SHA-256 de cada arquivo acima (menos ele próprio); confere com `sha256sum -c artifacts.sha256` |

Os dez stdout de corrida e as cinco saídas de régua são **stdout+stderr literais** de cada execução, sem
recorte: a linha citada no status está na linha que o status diz, e o rodapé é o rodapé real do processo.

## 2. A revisão pineada e as árvores

| | |
| --- | --- |
| base da branch | **`dcbcbe823e6202750803cbfb3e84420553fc8185`** — `git rev-parse dcbcbe8:src` = `100af75ded6d50b6a26120be352cf72770f97e80`, `:tests` = `77fcb0510525a82d39bb799ff1376ff0fb6eb17b` (as mesmas duas árvores do pin `9b2c65a`, o pouso da 16) |
| ponta de código medida | **`d80ac207e9c33021944752ab9535e723c95b8bbc`** — `git rev-parse d80ac20:src` = `f77c1961bb8065ea5a78b24677a36c5840891c75`, `:tests` = `4855f0e85c883573bc374125b4b016ad1e775711`, **diferentes** das da base: a perna escreve código, então o pin é o commit medido, não um documento em cima dele |
| árvore deste fecho | `git diff --name-only d80ac20 -- src tests` **vazio** — o clone limpo de `d80ac20` cobre a ponta da branch por identidade de `src/` e `tests/` |
| engine | `Godot Engine v4.7.2.stable.official.ed1daf0bf` — a primeira linha de **todos** os dez stdout |
| semente | a da casa, `SEED := 20261116` |

## 3. O comando, serial, máquina livre

```sh
# clone limpo, sem .godot/
git clone <este repositório> clean-12h && cd clean-12h && git checkout d80ac20
godot --headless --path . --import
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . --script tests/simulation_rng_test.gd
godot --headless --path . --script tests/tick_journal_test.gd
# na árvore de trabalho desta branch, os mesmos quatro comandos, sem o --import

# as réguas, nesta árvore (`.tools/` é gitignored; os comandos estão literais no cabeçalho de cada log)
python tools/check_doc_anchors.py
python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md docs/engine/*.md docs/melhorias-status.md AGENTS.md README.md
python .tools/verify_plan_ids.py docs/planos/12-bicho-cavando-voxel.md
python .tools/_ruler_old.py --ref d80ac20 && python tools/check_doc_anchors.py --ref d80ac20   # o par do #30
```

Zero processo do engine e zero `llama-server` antes das duas séries; as cinco corridas de cada série rodam
uma de cada vez, porque medição de tempo é serial (contrato, "Comandos de medição").

## 4. As linhas que os logs sustentam

| Número publicado | Arquivo | Linha literal |
| --- | --- | --- |
| `283 checagens 0 falhas 33.194 s` | `clone_runner_reactions.log` | rodapé |
| `OK censo de checagens \| 283/283` | `clone_runner_reactions.log` | a linha do censo |
| passos e `sim_step` do cenário estreito | `clone_runner_reactions.log` | `CENARIO ESTREITO, NAO GATE P1: passos=10568 sim_step total=2169480 us pico=3979 us; BT last_us soma=55907 pico=245 trips=0` |
| passos e `sim_tick` da matilha | `clone_runner_reactions.log` | `PASSOS DE MATILHA (sessao real, difusao incluida), NAO GATE P1: passos=1341 sim_tick total=3098370 us pico=12329 us; BT last_us soma=53693 pico=136 trips=0` |
| colheita de malha (§4 do dossiê) | `head_runner_run1.log`, `head_runner_run2.log` | `COLHEITA DE MALHA SEM CAVAR (dossie 12 §4, estado atual), NAO GATE P1: boot chunks=64 …` |
| `255 / 0 / 48,0 s` | `clone_suite.log`, `head_suite.log` | `== 255 checagens  0 falhas  48.0 s de teste ==` |
| `27 / 0` | `clone_runner_rng.log`, `head_runner_rng.log` | `OK censo de checagens \| 27/27` |
| `128 / 0` com `7/7 testes concluidos` | `clone_runner_journal.log`, `head_runner_journal.log` | `128 checagens 0 falhas 7/7 testes concluidos …` |

Nenhum dos dez stdout tem `[FAIL]` nem `SCRIPT ERROR`. O pé do `clone_suite.log` e do `head_suite.log` traz o
par já debitado das pernas anteriores — `WARNING: 4 ObjectDB instances were leaked at exit` e
`ERROR: 2 resources still in use at exit` — com os mesmos `4` e `2` das testemunhas versionadas da 07c; a
atribuição continua aberta e nada aqui a mexe.

## 5. O que esta pasta não fecha

- Gate de fase fecha o dono do repositório (mandato 4). Nada aqui encerra P0 ou P1.
- `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não foram tocados por
  nenhuma das sete linhas da perna; uma corrida com lobos cavando ainda não reproduz os hashes publicados,
  porque o **mundo** mudou, não a projeção (dossiê 12 §6).
- As sete corridas dos commits (a)→(g) continuam em `.tools/perna12_*.log`, gitignored. Cada commit cita o
  seu próprio número e o número está na mensagem do commit; a pasta arquiva a série do fecho, não a série
  inteira da branch. Dono de qualquer re-arquivamento: a próxima perna que usar estes números.
- Os `.uid` de `tests/` continuam fora do git (#25, decisão do dono) e são os dois `??` que todo clone limpo
  mostra.
