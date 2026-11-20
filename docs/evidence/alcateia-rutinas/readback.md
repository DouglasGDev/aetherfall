# Rodada alcateia (dossiê 10) — o que foi lido, com o log de cada número

Motor Godot 4.7.2-stable (`ed1daf0bf`), binário `.tools/Godot_v4.7.2-stable_win64.exe`, md5
`2afa3142b68f7758755dc6015c54cbd8` conferido nesta sessão. `.tools/` está no `.gitignore`, então
**nenhum destes logs existe num clone recém-baixado** — os arquivos abaixo são a cópia publicada.

Árvore atual: `src` = `c36ab6cd2380b3dc7d584b7b4ebbd009ec445b5a`, `tests` =
`03f8da29fce069ce25dac5ddad4fe49ce7bbb3e8`. São **os mesmos hashes de `c42250c`**, a ponta de
código da perna: o merge da `main` (`265aad4`) e os três commits de documentos depois dele não
tocaram uma linha de `src/` nem de `tests/` (`git diff --stat eb6ec8d..HEAD -- src tests` fecha em
4 arquivos, `+1 171 / -11`, todos já presentes em `c42250c`). Então o runner de **150 checagens**
medido em `c42250c` vale byte a byte para esta árvore, sem re-corrida. As seções 1 a 5 abaixo são
**árvore de trabalho** — nenhuma corrida ali foi feita em clone. O clone limpo rodou depois, na
ponta desta branch, e está na **seção 6**.

Base da branch: `eb6ec8d` (runner `119 checagens` / 24 cenários, suíte `237`).
`git merge-base main HEAD` = `4ac5838`.

## 1. A escada de contagem, com o log de cada degrau

Nenhum exit code foi gravado nestes logs — o contrato lido é a última linha (`N checagens M
falhas T s` no runner, `== N checagens M falhas T s de teste ==` na suíte) e a contagem de
`SCRIPT ERROR`, que é **0 nos 30 arquivos** (os 28 da escada mais os dois do clone, §6).

| degrau | commit | runner (cenário / checagens) | log do runner | suíte | log da suíte |
| --- | --- | --- | --- | --- | --- |
| WIP preservado (6e670c3 + 57 linhas não commitadas) | — | 25 cenários, `130 / 0` | `backup-runner-1.log`, `backup-runner-2.log` | `237 → 239` | `backup-suite.log` (`239/0/36,2 s`) |
| matilha injetada | `6e670c3` | idem ao WIP acima | idem | `239/0` | idem |
| ronda por setor | `79882d2` | 26 cenários, `135 / 0` | `ronda-runner-1.log` | `239/0/36,9 s` | `ronda-suite.log` |
| cerco por assentos | `8e334e3` | 27 cenários, `140 / 1` → `140 / 0` → `140 / 0` | `cerco-runner-1/2/3.log` | `239/0/37,4 s` | `cerco-suite.log` |
| mordida escalonada | `89df566` | 28 cenários, `142 / 3` → `142 / 2` → `142 / 2` → `142 / 2` → `142 / 1` → `142 / 0` | `ataque-runner-1..6.log` | `239/0/35,8 s` | `ataque-suite.log` |
| confiança publicada | `4888818` | 28 cenários, `143 / 0` | `confianca-runner-1.log` | `239/0/45,1 s` | `confianca-suite.log` |
| contágio do medo | `2e4ff65` | 29 cenários, `146 / 0` → `146 / 1` → `146 / 0` | `contagio-runner-1/2/3.log` | `239/0/45,1 s` | `contagio-suite.log` |
| amortecimento por confiança | `c42250c` | **30** cenários, `150 / 0` → `150 / 1` → `150 / 0` | `amortecimento-runner-1/2/3.log` | `239/0/40,1 s` | `amortecimento-suite.log` |
| pós-merge e pós-documentos | `265aad4`…`cb96493` | não re-rodado — `src`/`tests` idênticos a `c42250c` | — | `239/0/41,3 s` | `pos-merge-suite.log` |

O runner tem dois censos internos que aparecem em todas as corridas: `censo de testes completos
N/N` (cenários) e `censo de checagens N/N` (checagens), e o teto declarado em código é
`EXPECTED_CHECKS` ([tests/aether_reactions_test.gd:20](../../../tests/aether_reactions_test.gd#L20)),
que saiu de **119** em `eb6ec8d` (lá linha 17) para **150**.

## 2. As vermelhas, e o que cada uma decidiu

Nenhuma das falhas abaixo é de ambiente: todas têm `SCRIPT ERROR` 0 e a checagem nomeia a premissa.

- `cerco-runner-1.log` → `FALHA cercar_espacamento_segue_os_participantes | fugindo=1 restantes=1
  angulos=[0.0] espacamento=2.0944`. O assento era sorteado sobre `_pack.size() + 1`, isto é, sobre
  quem *existe*, não sobre quem *caa*. Um vizinho em `flee` continuava ocupando cadeira na roda,
  então o espaçoçamento (`2,0944` = `TAU/3`) não batia com um único caçador de fato. Verde em
  `cerco-runner-2.log` com `n` lido de `_hunt_pack_size()`.
- `ataque-runner-1.log` → três falhas: `ataque_mordidas_nunca_no_mesmo_tick | mordidas=0`,
  `ataque_escalonamento_funcao_do_clock_tick | fases_normal={ }` e `nenhum estouro de subtree no
  budget | trips_matilha=10`. `mordidas=0` com `candidatos_no_primeiro_tick=4` é o estado antes da
  peça: quatro lobos em alcance e nenhum morde, porque o `SubtreeGuard` estourava (`trips=10`) e a
  folha de mordida não era alcançada. As cinco corridas seguintes (`2`→`5`) acompanham o
  escalonamento nascente (`fases={0:0, 1:1, 2:2, 3:3}` em `ataque-runner-5.log`, ainda com uma
  falha de entrada defasada) até `142 / 0` em `ataque-runner-6.log`.
- `confianca-base-runner.log` → `FALHA leitura_barata_com_as_quatro_chaves | chaves=identity,pos,
  intent,hp_ratio  lobo0<-[1 2] lobo1<-[0 2] lobo2<-[0 1] lobo3<-[]`. É a premissa do commit
  seguinte declarada antes do código: a leitura tinha **quatro** chaves e nenhum vizinho trazia
  confiança, então `amansar` não tinha o que ler.
- `contagio-runner-2.log` → `FALHA nenhum estouro de subtree no budget | trips_matilha=1`.
- `amortecimento-runner-2.log` → `FALHA nenhum estouro de subtree no budget | trips_solo=1`. As
  duas são o guard de 400 µs do BT batendo em corrida com a matilha inteira viva; verdes na
  amostra seguinte em ambas as pernas, e o budget continua declarado como não-gate (§4).

## 3. O censo da sessão real — e o furo #16

`pos-merge-suite.log:23-24`, as duas checagens que a perna acrescentou à suíte:

```
  [PASS] provedor de matilha montado pela sessao real lobo0(0 viz) lobo1(0 viz) lobo2(1 viz) lobo3(1 viz) lobo4(0 viz)
  [PASS] alcateia existe na sessao real         pares=10  esperado=10  maior_matilha_lida=1 lobos_vivos=5
```

`pares=10 = 5·4/2` é o número de **comparações** `i<j` que a passada da sessão avalia
(`_pack_pairs`, [src/main.gd:306](../../../src/main.gd#L306)), não o de pares coesos; a segunda
metade da checagem exige `maior_matilha_lida >= 1`, e ela devolve exatamente **1**. Ou seja: no vale
real com os cinco lares espalhados, `PACK_COHESION_RADIUS = 24 m` nunca entregou dois vizinhos a um
lobo. Cerco, contágio e ronda por setor estão provados em fixture de quatro lobos colocados a
distância uns dos outros, e **não** na sessão real. Está registrado como furo #16 no status e é
trabalho da perna 14.

## 4. µs: declarados não-gate (regra I do furo #15)

Nenhuma banda absoluta de µs serve de gate, e nesta perna não há chão pareado: as corridas abaixo
são da árvore de trabalho, com a máquina em uso pelo dono, e a contagem de passos do cenário de
matilha **mudou** ao longo da perna. Não se comparem estes números entre si como custo.

| log | cenário estreito (2 770 passos) `sim_step` total / pico | BT soma / pico / trips | passos de matilha (sessão real) passos · total · pico |
| --- | --- | --- | --- |
| `backup-runner-1.log` (WIP) | 384 450 µs / 828 µs (2 769 passos) | 15 746 / 128 / 0 | 22 · 34 127 µs · 8 062 µs |
| `ronda-runner-1.log` | 377 663 / 679 | 15 403 / 202 / 0 | 23 · 36 037 · 7 933 |
| `cerco-runner-3.log` | 381 762 / 817 | 15 598 / 191 / 0 | 37 · 52 943 · 8 536 |
| `ataque-runner-6.log` | 397 776 / 810 | 16 295 / 209 / 0 | 58 · 78 394 · 8 182 |
| `contagio-runner-3.log` | 569 904 / 1 624 | 24 065 / 239 / 0 | 80 · 164 774 · 12 870 |
| `amortecimento-runner-3.log` | 556 861 / 2 008 | 23 219 / 203 / 0 | 122 · 265 610 · 12 971 |

O que se pode dizer do que está escrito nos arquivos, sem correr nada: o cenário estreito roda os
mesmos 2 770 passos em todos os braços, e o `sim_step` integral saiu de ~378–405 kµs (ronda/cerco)
para ~557–570 kµs (contágio/amortecimento) na mesma janela de trabalho. Duas leituras possíveis —
a leitura da matilha mais o contágio custam ~45 %, ou a janela estava carregada — e esta perna
**não** tem chão pareado para separá-las. É débito declarado, não conclusão.

## 5. O que estes logs não fecham

- Nenhum gate de fase. O custo de BT continua medido só pelo `SubtreeGuard`, que cronometra a
  árvore e não a percepção nem a utilidade.
- Clone limpo com `--import` frio **rodou**, mas só na ponta desta branch (`188490b`) e não nos
  degraus intermediários: ver §6. O que estava proibido — publicar 239 como número de clone — caiu;
  o número do clone é **239 / 0 / 38,6 s**, exit 0.
- `maior_matilha_lida=1` (furo #16) e a ausência de chão pareado (§4) são os dois buracos reais
  desta perna.
- O log de ruído de saída tem agora **quatro** famílias nesta branch: `ronda-suite.log` dá **24**
  ObjectDB + **8** resources, `cerco-suite.log` dá **16/6**, os seis seguintes (`ataque`,
  `confianca`, `contagio`, `amortecimento`, `pos-merge`, `clone-gate-suite`) dão **12/6** e
  `backup-suite.log` dá **8/4** — este último já registrado no status como a exceção antiga da
  amostra. Não há par de árvores com `src` e `tests` idênticos dando números diferentes aqui (as
  duas árvores iguais desta perna, `c42250c` e `HEAD`, dão a mesma 12/6, e o clone limpo da ponta —
  mesmo `src`, mesmo `tests`, cache frio — dá a mesma 12/6), e nenhum log tem `--verbose`, então a
  contagem fica registrada sem atribuição.

## 6. O clone limpo da ponta, com `--import` frio

Comando e revisão, na ordem exata em que rodaram (caminhos literais desta máquina):

```sh
git clone --no-hardlinks C:/Aetherfall C:/Aetherfall/.tools/leg10-gate
git -C C:/Aetherfall/.tools/leg10-gate checkout 188490b
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/Aetherfall/.tools/leg10-gate --import
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/Aetherfall/.tools/leg10-gate tests/smoke_test.tscn
```

O clone saiu **sem `.godot/`** (conferido antes do `--import`: o diretório não existia), então a
importação foi fria de verdade.

| passo | resultado | log |
| --- | --- | --- |
| `--import` frio | exit **0**, com `[ DONE ] loading_editor_layout` no fim e zero `SCRIPT ERROR` | `clone-gate-import.log` |
| suíte no clone | **239 checagens / 0 falhas / 38,6 s**, exit **0**, zero `SCRIPT ERROR`, ruído de saída **12** ObjectDB + **6** resources | `clone-gate-suite.log` |

Os 38,6 s comparam-se com os 41,3 s da árvore de trabalho (`pos-merge-suite.log`) e caem dentro da
faixa dos degraus anteriores (35,8 a 45,1 s), que é o comportamento de sempre nesta máquina; a
corrida não foi paralela com outra carga. O que o número decide é a contagem e o exit code, não o
tempo: 239/0/exit 0 valia para `src` + `tests` byte a byte idênticos aos de `c42250c`, e o clone
confere isso por execução em vez de só por hash de árvore.

Não confere, e continua faltando: o gate de nenhuma fase fecha com isto (mandato 4), e o merge na
`main` ainda precisa da suíte re-rodada na árvore mergida — outra revisão, outro número.
