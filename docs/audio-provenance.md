# Proveniência do som

O som do jogo está em `assets/audio/` e obedece a um contrato próprio: **CC0, cópia byte a byte,
sem reencode.** Cada arquivo daqui é idêntico ao arquivo que saiu do pacote de origem — o SHA-256
de `assets/audio/<pasta>/<arquivo>` é o mesmo SHA que se obtém extraindo o zip da fonte, o que
deixa a conferência mecânica:

```sh
# na raiz do repositório; sai com código 0 se cada arquivo conferir
sha256sum -c docs/audio-sha256.txt
```

Nada foi cortado, normalizado, remixado nem convertido: reencode mudaria o hash e a promessa de
origem deixaria de ser verificável. Ganho, afinação e cadência se aplicam em runtime, nos nós de
áudio — o arquivo em disco permanece o que o autor publicou.

## Pacotes de origem

| Pacote | Autor | Onde | Licença (evidência lida) | SHA-256 do que baixamos | Tamanho | Arquivos usados |
|---|---|---|---|---|---|---|
| Impact Sounds 1.0 (Kenney) | Kenney Vleugels | [kenney.nl/assets/impact-sounds](https://kenney.nl/assets/impact-sounds) | `License.txt` dentro do próprio zip: "License: (Creative Commons Zero, CC0)"; a página diz "Creative Commons CC0" | `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8` | 800.850 B | 33 |
| RPG Audio (Kenney) | Kenney Vleugels | [kenney.nl/assets/rpg-audio](https://kenney.nl/assets/rpg-audio) | `License.txt` dentro do zip: "License (Creative Commons Zero, CC0)"; a página diz "Creative Commons CC0" | `6dbeaf8544da958d8f2adcb4a4a4b76c1ade34a05f8ab9edccd327da7375f38b` | 964.837 B | 1 |
| 80 CC0 creature SFX | rubberduck | [opengameart.org/content/80-cc0-creature-sfx](https://opengameart.org/content/80-cc0-creature-sfx) | campo "License(s): CC0" da página, apontando `creativecommons.org/publicdomain/zero/1.0/` | `5d4002eea42f278e76543bb36e8ddd2cb978588a13271984191d8228f5d26768` | 1.885.648 B | 6 |
| 5 Hit Sounds + Dying | TinyWorlds | [opengameart.org/content/5-hit-sounds-dying](https://opengameart.org/content/5-hit-sounds-dying) | campo "License(s): CC0" da página | `fb345dac7eb9d8898a7aa48ac17f5852f9365e151821a74f6e156cfb86bb96fa` | 121.342 B | 4 |
| Swishes Sound Pack | artisticdude | [opengameart.org/content/swishes-sound-pack](https://opengameart.org/content/swishes-sound-pack) | campo "License(s): CC0" da página | `7980215241b739a787dcf26f660ce510bb237900968789395a86911619795693` | 385.150 B | 2 |
| 40 CC0 water / splash / slime SFX | rubberduck | [opengameart.org/content/40-cc0-water-splash-slime-sfx](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | campo "License(s): CC0" da página | `7cd39abb49d4362a37ba18dc0e454c7dc1d08029d4e5b683149046bc237b2eba` | 2.259.262 B | 3 |
| Ambient Bird Sounds | isaiah658 | [opengameart.org/content/ambient-bird-sounds](https://opengameart.org/content/ambient-bird-sounds) | campo "License(s): CC0" da página; a página ainda diz "Credit to isaiah658 is not needed but is appreciated" | `359e4e3f9da9d75aac64cede511c7e3ef8b461f9d9f8c230f8f80e44c4b3e35f` | 544.669 B | 1 |
| wind whoosh loop | sketchman3 | [opengameart.org/content/wind-whoosh-loop](https://opengameart.org/content/wind-whoosh-loop) | campo "License(s): CC0" da página | `0cfdbd3f21ed449689a9024264edf267d0037a6495813a7010827672ec191dac` | 251.584 B | 1 |

Os dois pacotes da Kenney saíram do próprio kenney.nl (`/assets/impact-sounds`, `/assets/rpg-audio`)
e a licença foi conferida no `License.txt` que viaja dentro do zip. Os outros cinco vieram das
páginas do OpenGameArt listadas acima; em cada uma o campo `License(s)` declarado pelo autor é CC0
e aponta `creativecommons.org/publicdomain/zero/1.0/`. Do `RPG Audio` há duas fontes em circulação —
o zip oficial e uma cópia no OpenGameArt — e os arquivos conferem byte a byte entre as duas
(`chop`, `metalClick`, `knifeSlice`, `cloth1`, `bookPlace1`, `footstep00`, `dropLeather`); por isso
a linha cita a página oficial.

O áudio do Veloren **não** está aqui, e não é esquecimento: o repositório deles tem 645 arquivos
de áudio sob um único `LICENSE` GPL-3.0. A decisão e o número estão em
[AGENTS.md](../AGENTS.md), regra 8.

## Arquivo por arquivo

Duração, taxa, nível médio e pico foram medidos com `ffmpeg`/`ffprobe` 9.0 nos próprios arquivos
deste repositório. `médio` e `pico` estão em dBFS e dão o ponto de partida do mixer. O SHA-256
completo de cada linha está em [audio-sha256.txt](audio-sha256.txt).

| Arquivo | De onde vem | Codec | Hz | canais | dur (s) | médio (dB) | pico (dB) | bytes |
|---|---|---|---|---|---|---|---|---|
| `break_glass_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactGlass_heavy_000.ogg` | vorbis | 44100 | 2 | 0.24 | -22.4 | -1.1 | 7.403 |
| `break_glass_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactGlass_heavy_001.ogg` | vorbis | 44100 | 2 | 0.43 | -25.3 | -1.0 | 8.946 |
| `break_soft_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactPunch_heavy_000.ogg` | vorbis | 44100 | 2 | 0.65 | -18.0 | -1.0 | 11.617 |
| `break_soft_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactPunch_heavy_001.ogg` | vorbis | 44100 | 2 | 0.54 | -17.5 | -1.2 | 10.861 |
| `break_stone_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactPlate_heavy_000.ogg` | vorbis | 44100 | 2 | 0.49 | -22.6 | -1.0 | 10.032 |
| `break_stone_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactPlate_heavy_001.ogg` | vorbis | 44100 | 2 | 0.35 | -17.4 | -0.9 | 8.713 |
| `break_wood_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactWood_heavy_000.ogg` | vorbis | 44100 | 2 | 0.31 | -19.6 | -0.9 | 6.233 |
| `break_wood_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactWood_heavy_001.ogg` | vorbis | 44100 | 2 | 0.31 | -19.7 | -0.9 | 6.239 |
| `dig_glass_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactGlass_light_000.ogg` | vorbis | 44100 | 2 | 0.21 | -21.8 | -1.6 | 6.526 |
| `dig_glass_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactGlass_light_001.ogg` | vorbis | 44100 | 2 | 0.21 | -21.3 | -0.9 | 6.544 |
| `dig_soft_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactSoft_medium_000.ogg` | vorbis | 44100 | 2 | 0.12 | -14.2 | -1.0 | 5.351 |
| `dig_soft_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactSoft_medium_001.ogg` | vorbis | 44100 | 2 | 0.18 | -14.8 | -0.9 | 5.506 |
| `dig_stone_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactMining_000.ogg` | vorbis | 44100 | 2 | 0.94 | -20.6 | -1.1 | 12.035 |
| `dig_stone_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactMining_001.ogg` | vorbis | 44100 | 2 | 0.87 | -21.1 | -1.0 | 11.481 |
| `dig_wood_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactWood_light_000.ogg` | vorbis | 44100 | 2 | 0.27 | -22.3 | -1.1 | 6.343 |
| `dig_wood_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactWood_light_001.ogg` | vorbis | 44100 | 2 | 0.27 | -24.0 | -0.9 | 6.373 |
| `hit_flesh_1.ogg` | 5 Hit Sounds + Dying / `hit1.ogg` | vorbis | 44100 | 2 | 0.42 | -21.0 | -2.8 | 12.280 |
| `hit_flesh_2.ogg` | 5 Hit Sounds + Dying / `hit2.ogg` | vorbis | 44100 | 2 | 0.39 | -25.0 | -8.4 | 12.604 |
| `hit_flesh_3.ogg` | 5 Hit Sounds + Dying / `hit3.ogg` | vorbis | 44100 | 2 | 0.48 | -25.1 | -8.9 | 13.979 |
| `place_1.ogg` | Impact Sounds 1.0 (Kenney) / `impactGeneric_light_000.ogg` | vorbis | 44100 | 2 | 0.14 | -21.0 | -1.2 | 5.827 |
| `place_2.ogg` | Impact Sounds 1.0 (Kenney) / `impactGeneric_light_001.ogg` | vorbis | 44100 | 2 | 0.12 | -20.0 | -1.0 | 5.636 |
| `player_die.ogg` | 5 Hit Sounds + Dying / `die1.ogg` | vorbis | 44100 | 2 | 0.68 | -16.5 | -1.0 | 19.212 |
| `splash_1.ogg` | 40 CC0 water / splash / slime SFX / `splash_01.ogg` | vorbis | 48000 | 2 | 1.38 | -33.9 | -0.3 | 64.822 |
| `splash_2.ogg` | 40 CC0 water / splash / slime SFX / `splash_02.ogg` | vorbis | 48000 | 2 | 0.72 | -28.6 | -1.9 | 37.895 |
| `step_dirt_1.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_carpet_000.ogg` | vorbis | 44100 | 2 | 0.14 | -23.7 | -1.1 | 6.353 |
| `step_dirt_2.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_carpet_001.ogg` | vorbis | 44100 | 2 | 0.14 | -19.6 | -1.1 | 6.411 |
| `step_dirt_3.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_carpet_003.ogg` | vorbis | 44100 | 2 | 0.14 | -22.9 | -1.1 | 6.301 |
| `step_grass_1.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_grass_000.ogg` | vorbis | 44100 | 2 | 0.78 | -29.9 | -1.1 | 8.290 |
| `step_grass_2.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_grass_001.ogg` | vorbis | 44100 | 2 | 0.67 | -28.8 | -1.2 | 8.313 |
| `step_grass_3.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_grass_002.ogg` | vorbis | 44100 | 2 | 0.69 | -29.5 | -1.1 | 8.278 |
| `step_snow_1.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_snow_000.ogg` | vorbis | 44100 | 2 | 0.37 | -22.3 | -0.9 | 7.880 |
| `step_snow_2.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_snow_001.ogg` | vorbis | 44100 | 2 | 0.37 | -18.7 | -1.0 | 7.794 |
| `step_snow_3.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_snow_002.ogg` | vorbis | 44100 | 2 | 0.37 | -18.8 | -1.0 | 7.694 |
| `step_stone_1.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_concrete_000.ogg` | vorbis | 44100 | 2 | 0.11 | -20.9 | -0.9 | 5.808 |
| `step_stone_2.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_concrete_001.ogg` | vorbis | 44100 | 2 | 0.11 | -22.4 | -1.2 | 6.308 |
| `step_stone_3.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_concrete_002.ogg` | vorbis | 44100 | 2 | 0.11 | -22.7 | -1.0 | 6.255 |
| `step_wood_1.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_wood_000.ogg` | vorbis | 44100 | 2 | 0.25 | -21.2 | -0.9 | 5.949 |
| `step_wood_2.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_wood_001.ogg` | vorbis | 44100 | 2 | 0.25 | -20.0 | -1.0 | 5.929 |
| `step_wood_3.ogg` | Impact Sounds 1.0 (Kenney) / `footstep_wood_002.ogg` | vorbis | 44100 | 2 | 0.25 | -19.4 | -0.9 | 5.895 |
| `swing_1.wav` | Swishes Sound Pack / `swish-1.wav` | pcm_s24le | 44100 | 2 | 0.13 | -15.0 | -0.1 | 34.138 |
| `swing_2.wav` | Swishes Sound Pack / `swish-5.wav` | pcm_s24le | 44100 | 2 | 0.13 | -13.9 | -0.1 | 34.414 |
| `ui_click.ogg` | RPG Audio (Kenney) / `metalClick.ogg` | vorbis | 48000 | 2 | 0.45 | -34.3 | -6.9 | 13.615 |
| `wolf_bark_1.ogg` | 80 CC0 creature SFX / `barking_01.ogg` | vorbis | 48000 | 2 | 0.40 | -18.6 | -0.7 | 17.341 |
| `wolf_die.ogg` | 80 CC0 creature SFX / `hurt_05.ogg` | vorbis | 48000 | 2 | 0.45 | -17.4 | -2.4 | 19.383 |
| `wolf_howl.ogg` | 80 CC0 creature SFX / `howl.ogg` | vorbis | 48000 | 2 | 0.72 | -15.9 | -2.4 | 25.641 |
| `wolf_hurt_1.ogg` | 80 CC0 creature SFX / `hurt_01.ogg` | vorbis | 48000 | 2 | 0.49 | -21.6 | -2.3 | 24.174 |
| `wolf_hurt_2.ogg` | 80 CC0 creature SFX / `hurt_02.ogg` | vorbis | 48000 | 2 | 0.48 | -15.7 | -1.0 | 21.608 |
| `wolf_roar.ogg` | 80 CC0 creature SFX / `roar_01.ogg` | vorbis | 48000 | 2 | 0.37 | -21.5 | -10.7 | 15.863 |
| `amb_birds.ogg` | Ambient Bird Sounds / `birds-isaiah658.ogg` | vorbis | 48000 | 2 | 30.69 | -30.8 | -6.2 | 544.669 |
| `amb_water.ogg` | 40 CC0 water / splash / slime SFX / `loop_water_02.ogg` | vorbis | 48000 | 2 | 7.01 | -29.1 | -13.8 | 269.372 |
| `amb_wind.ogg` | wind whoosh loop / `wind%20woosh%20loop.ogg` | vorbis | 48000 | 2 | 5.96 | -30.3 | -17.3 | 251.584 |

Total: **51 arquivos, 1.677.718 bytes (1.60 MiB)**.

## O que a medição dos arquivos já decidiu

- `footstep_carpet_001.ogg` e `footstep_carpet_002.ogg` do pacote Impact **são o mesmo arquivo**
  byte a byte, e `003`/`004` também. O pacote tem três passos de "terra" distintos, não cinco.
  `step_dirt_3` veio do `carpet_003` por isso: a variação é real, não um arquivo repetido com
  nome novo. Conferido por SHA-256 na árvore inteira: 51 arquivos, zero duplicados.
- Os níveis dão o trabalho do mixer sem achismo: `dig_soft_1` está em **-14,2 dB** médios e
  `ui_click` em **-34,3 dB** — 20 dB de diferença entre dois sons que tocam na mesma cena. Se
  os dois tocarem com ganho 1, um dos dois está errado, e o número diz qual.
- `step_grass` (-29,9 dB médio) é ~9 dB mais baixo que `step_stone` (-20,9) dentro do mesmo
  pacote: grama precisa de ganho próprio, senão o passo desaparece quando o jogador sai da pedra.
- Os três leitos de ambiência chegaram da fonte com `loop=false` na importação. Em
  `amb_birds.ogg.import`, `amb_wind.ogg.import` e `amb_water.ogg.import` o parâmetro está
  `loop=true` hoje, e o valor foi lido no resource carregado pelo Godot 4.7.2 headless, não
  presumido. Os outros 48 arquivos continuam `loop=false`: são golpes e passos, não camadas.
- `swing_1.wav` e `swing_2.wav` são PCM 24 bits e importam e carregam sem erro no Godot 4.7.2
  headless — conferido antes de fechar a lista.

## O que roda em cima desses arquivos

Nenhum byte dos arquivos muda em runtime. O que se aplica em runtime é ganho,
cadência e roteamento, no [src/audio/audio_director.gd](../src/audio/audio_director.gd)
(`AudioDirector`, 619 linhas), que o [src/main.gd:190-194](../src/main.gd#L190-L194)
cria por último no `_ready` — "último a entrar e o primeiro a ser ouvido".

**Barramentos.** `default_bus_layout.tres` (carregado por
[project.godot:15](../project.godot#L15)) define `Master`, `SFX`, `Ambience`, `UI`. O
diretor monta 12 `AudioStreamPlayer3D` no `SFX` (alcance 64 m), um `AudioStreamPlayer`
no `UI` e dois no `Ambience` para o crossfade das camas.

**Ganho.** O número vem da tabela acima, não de ouvido: `assets/audio/levels.json` guarda
o nível médio medido de cada arquivo e `gain_db()` devolve
`clamp(-20,0 − medido, ±14,0)` dB. Dos 51 arquivos, um só encosta no teto — `ui_click`
a -34,3 dB pediria +14,3 e recebe +14,0, ficando 0,3 dB abaixo do alvo. As três camas
levam ainda -12 dB de recuo, porque uma ambiência normalizada no alvo dos SFX brigaria
com cada passo. As 27 famílias jogáveis são **derivadas** do `levels.json` (`family_of()`
corta o sufixo `_N`), então arquivo sem nível medido não toca e nível medido sem arquivo
faz a suíte falhar.

**Cadência.** Passo é por distância percorrida, não por frame: 1,9 m por passo
(1,4 m nadando), ignorando velocidade abaixo de 0,4 m/s e qualquer salto de corpo maior
que 10 m — respawn não pode virar rajada de passos. A lavra emite um tick a cada 0,3 s
lendo a barra de progresso real do jogador, e trocar de alvo reinicia o intervalo. A
cama ambiental é reavaliada 1×/s com 98 leituras de bloco (7×7 na camada do corpo e na
de baixo, limiar de 6 blocos de água ou neve) e troca com crossfade de 0,7 s. Latido só
de lobo em `hunt` a até 14 m, com cooldown de 3 s por corpo sorteado entre 0,7× e 1,4×;
uivo tem cooldown global de 18 s, para não virar coro. A voz livre é escolhida pela
**duração** do arquivo no relógio de parede (`_busy`), não por `playing`: o flag só vira
`false` no próximo tick de mix depois do fim. Não é um truque do headless — medido em
[dummy-progress.log](evidence/audio/dummy-progress.log), com o driver `Dummy`, a posição
avança e um SFX não-looping termina sozinho.

**O diretor não manda no mundo.** Ele escuta seis sinais do jogador
(`block_broken`, `block_placed`, `attacked`, `damaged`, `died`, `panel_changed`, em
[audio_director.gd:149-154](../src/audio/audio_director.gd#L149-L154)) e três de
cada lobo (`bit_player`, `wounded`, `died`, conectados em
[audio_director.gd:159-161](../src/audio/audio_director.gd#L159-L161), chamada por
[main.gd:392-393](../src/main.gd#L392-L393)); não escreve voxel, não imprime no Éter e
sorteja variante numa RNG própria, semente 20261118. Medido em headless
([tests/audio_test.gd](../tests/audio_test.gd)): nove eventos disparados não mexem no
hash autoritativo do tick (`98313688c61a → 98313688c61a`), nem no `_rng.state` de cada
lobo, nem no `_population_rng.state`. O transitório por corpo (posição anterior,
acumulador de passo, água, cooldown) é chaveado por `wolf.identity` e limpo no load
([main.gd:1073](../src/main.gd#L1073)) — nunca vira save.

**Custo.** 743 µs uma vez no boot (montagem das vozes e leitura dos níveis), ~3 µs por
frame de física em `update_audio`, ~100 µs por avaliação de ambiência (1×/s) e ~0,66 ms
por evento — dos quais 467 µs são o `stop()+play()` do próprio motor; o `load()` de um
arquivo já em cache custa 2,7 µs e o sorteio da variante, 2,0 µs. Nada disso entra nos
50 ms do tick de 20 Hz, e o primeiro toque de cada arquivo sai mais caro (1,63 ms) porque
a decodificação ainda não aconteceu. Corridas e contagens em
[melhorias-status.md](melhorias-status.md), notas de medição do som.

## O que o headless não pode provar, e a sonda que prova

Headless roda com o driver `Dummy`: `playing` vira `true` e o que sai do mixer é silêncio.
A posição de playback **não** fica congelada — essa frase estava errada aqui e foi desfeita
por medida: em [dummy-progress.log](evidence/audio/dummy-progress.log), um `step_grass_1` de
0,778 s avança até `playing=false` e a cama ao lado marca 1,395 s no mesmo relógio, em 200
frames. O que o headless não prova continua sendo a entrega ao aparelho. Então a suíte prova
tabelas, ganhos, cadência e consumidores — não audibilidade. Para isso existe
[tests/audio_live_probe.tscn](../tests/audio_live_probe.tscn), que instancia a sessão
real **em janela** e mede o pico dos barramentos durante 6 s sem nenhum input disparado
(quem anda é a matilha):

```sh
godot --path . tests/audio_live_probe.tscn
```

A corrida que fecha esta seção (Godot 4.7.2, WASAPI, Radeon RX 9060 XT): 13 toques na
janela — `step_grass` 6, `step_snow` 6, `splash` 1 —, cama `amb_birds`, pico medido
**-7,4 dB no Master**, -9,9 dB no SFX, -7,4 dB no Ambience, e a sonda sai com código 0.

Duas coisas que a própria sonda ensinou, e que valem como diagnóstico:

- O medidor de pico **não** distingue driver real de `Dummy`: uma corrida da mesma árvore
  que caiu em Dummy marcou -12,7 dB no SFX. Por isso a checagem `driver != "Dummy"` vem
  primeiro, e só ela prova o caminho até o dispositivo.
- O Godot pode não conseguir abrir o endpoint do Windows (`WASAPI: init_output_device
  error`, `drivers/wasapi/audio_driver_wasapi.cpp:275`) e aí ele avisa e cai no `Dummy` — jogo mudo com
  o código inteiro certo. Aconteceu na corrida do meio destas três, com o serviço de áudio
  rodando e oito dispositivos de som listados; a corrida seguinte abriu WASAPI de novo. Se
  o som sumir, a primeira linha da sonda diz de quem é a culpa.

## Como os arquivos foram obtidos

1. Páginas oficiais (Kenney) e do OpenGameArt lidas com `curl`; em cada uma a licença foi
   conferida antes de baixar qualquer byte.
2. Zip baixado, SHA-256 gravado na tabela acima, extraído para uma pasta fora do repositório.
3. Seleção copiada com o nome do jogo, sem tocar no conteúdo.
4. Cada arquivo do repositório foi comparado por SHA-256 com a árvore extraída: se algum não
   batesse byte a byte com a origem declarada na sua linha, o gerador desta tabela abortava.
   Ele não abortou.
5. `godot --headless --path . --import` e uma sonda de carregamento confirmam que os 51
   arquivos importam e carregam em runtime; a corrida está registrada em
   [melhorias-status.md](melhorias-status.md), notas de medição do som.

