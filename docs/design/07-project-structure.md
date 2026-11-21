# 07 — Estrutura de pastas do projeto

O projeto Godot fica **na raiz do repositório** (`project.godot` em `res://`): evita o
anti-padrão de `game/` aninhado (CI, export presets e paths de recurso ficam mais
simples) e separa por convenção de nome o que é código, dado, arte e nativo.

## Convenções `[DECIDED]`

| Regra | Detalhe |
|---|---|
| Pastas e arquivos | `snake_case`, ASCII puro, sem espaço, sem maiúscula (evita divergência NTFS/ext4/APFS e quebra de `ResourceUID` em merge) |
| Classes | `PascalCase` via `class_name`, uma por arquivo, arquivo = nome da classe em snake (`mind_server.gd` → `class_name MindServer`) |
| Interfaces/modais | prefixo `i_` para "contrato" (`i_voxel_backend.gd`), `*_types.gd` para enums/structs compartilhados de um sistema |
| Extensões | `.gd` código · `.tscn` cena · `.tres` recurso · `.gdshader` · `.gdextension` nativo · `.gdc/.scn` só em build |
| Sufixos semânticos | `*_system.gd` (roda no SimClock) · `*_service.gd` (autoload, API) · `*_store.gd` (dados + persistência) · `*_job.gd` (trabalho em thread) · `*_schema.gd` (validação) |
| Cenas de mundo | prefixo de domínio: `site_village_*.tscn`, `dungeon_*.tscn`, `mob_wolf_*.tscn`, `ui_*.tscn`, `fx_*.tscn` |
| Um sistema, uma pasta, com `README.md` | cada pasta de `src/*/` tem um README curto: o que é, o que **não** faz, quem chama (mantido derivado do código) |
| `addons/` só para terceiros | nossa 1ª-party vive em `src/` e `native/`; `addons/` é apenas deps de engine, cada um com licença registrada em `THIRD_PARTY_LICENSES.md` |
| `data/` sem lógica | só `.tres`/`.json`/`.csv` de definição; qualquer `.gd` dentro de `data/` é bug de arquitetura |

## Recorte real — hash e journal

| Arquivo existente | Responsabilidade neste bloco |
|---|---|
| [src/main.gd](../../src/main.gd) (787 linhas) | dona da instância do journal; grava após incrementar o tick, dentro do cronômetro ([253-259](../../src/main.gd#L253-L259)); expõe diagnóstico ([708-719](../../src/main.gd#L708-L719)) e `state_hash()` ([772-775](../../src/main.gd#L772-L775)) |
| [src/persistence/tick_journal.gd](../../src/persistence/tick_journal.gd) | `TickJournal`: SHA256 da projeção mínima e JSONL `[tick,hash]` sob demanda, em arquivo novo por corrida; não é replay |
| [src/world/aether_field.gd](../../src/world/aether_field.gd) (234 linhas) | `state_bytes()` copia todos os bytes de `_cur` Float32, sem o corte usado no save ([232-234](../../src/world/aether_field.gd#L232-L234)) |

Contrato e limites em [AGENTS.md](../../AGENTS.md); gates continuam abertos em
[§08](08-roadmap-risks-licensing.md). A árvore e os autoloads abaixo são **alvos de
organização**, não inventário do código atual nem autorização para criá-los. Em particular,
`core/sim/tick_journal.gd` é localização alvo; o arquivo real está em `src/persistence/`.

## Árvore `[TARGET]`

```text
Aetherfall/
├─ project.godot
├─ .gitignore                      # .godot/, bin/, saves/, models/, native/build/, *.tmp
├─ LICENSE.md                      # MIT (código)
├─ LICENSE-ASSETS.md               # CC-BY-SA 4.0 (assets)
├─ THIRD_PARTY_LICENSES.md         # gerado: voxel tools, llama.cpp, sqlite, GUT, fontes, modelos
├─ README.md                       # pitch, como rodar, como contribuir, status do projeto
├─ AGENTS.md                       # existe hoje: contrato de trabalho (princípios, escopo, medição)
├─ CONTRIBUTING.md  CHANGELOG.md  VERSION
│
├─ .github/
│  ├─ workflows/
│  │  ├─ ci.yml                    # lint + import check + unit + data validation
│  │  ├─ sim-tests.yml             # 20 lobos × 10 000 ticks, hash por sistema
│  │  ├─ replay-tests.yml          # golden journals (Crônica) → regressão determinística
│  │  ├─ coop-tests.yml            # headless server + 2 clientes, late-join, migração
│  │  ├─ gdextension-build.yml     # C++ p/ windows-x86_64, linux-x86_64, macos-universal
│  │  ├─ license-audit.yml         # GPL/AGPL/CC-BY-NC não permitida; modelos fora do repo
│  │  └─ release.yml               # export + assinar + publicar (itch/Steam) por tag
│  ├─ ISSUE_TEMPLATE/  PULL_REQUEST_TEMPLATE.md  CODEOWNERS  dependabot.yml
│
├─ docs/
│  ├─ design/                      # este conjunto (visão, inovações, loops, bosses)
│  ├─ engine/                      # derivado do código: sistemas, APIs, SimClock, ordens de tick
│  ├─ ai/                          # contratos de mente, BT de referência, tuning de utility, eval do oráculo
│  ├─ world/                       # biomas, sites, espécies, facções, economia, ecologia (planilhas canônicas)
│  ├─ net/                         # protocolo, codec, limites de rate, migration
│  ├─ art/                         # style bible, atlas de voxels, paleta do Éter, regras de FX
│  ├─ writing/                     # tom, glossário de termos, templates de fala, ética do LLM local
│  ├─ modding/                     # superfície de API, sandbox de mods, exemplos
│  ├─ adr/                         # arquitetura: 0001-sem-csharp.md, 0002-simclock-20hz.md, ...
│  └─ ops/                         # build por plataforma, telemetria local, política de saves
│
├─ addons/                         # SOMENTE terceiros
│  ├─ voxel/                       # Voxel Tools (MIT)
│  ├─ db/                          # plugin SQLite (MIT)
│  ├─ gut/                         # framework de testes (MIT)
│  └─ atlas_importer/              # fatia de atlas de voxels, importador de spritesheet
│
├─ src/                            # 100% GDScript de jogo (nada de asset binário aqui)
│  │
│  ├─ core/                        # ── Núcleo, sem conhecimento de gameplay
│  │  ├─ README.md
│  │  ├─ boot/                     #   game_boot.gd, boot_chain.gd, crash_guard.gd, safemode.gd
│  │  ├─ autoloads/                #   SERVICES-singletons (lista canônica abaixo)
│  │  ├─ sim/                      #   sim_world.gd, entity_store.gd, sim_clock.gd, tick_journal.gd,
│  │  │                            #   component_types.gd, archetype.gd, query_mask.gd, systems/
│  │  ├─ events/                   #   event_bus.gd, typed event structs (deed, imprint, mind_cmd)
│  │  ├─ rng/                      #   seeded_streams.gd (splitmix64/sfc64), per_system_seed.gd
│  │  ├─ time/                     #   world_calendar.gd, day_night.gd, sleep_advance.gd
│  │  ├─ registry/                 #   content_registry.gd, tags.gd (CollectionService), ids.gd
│  │  ├─ settings/                 #   settings_service.gd, schema, defaults, hardware_profiles.gd
│  │  └─ i18n/                     #   locale_service.gd, speaker.gd (concordância gênero/número PT-EN)
│  │
│  ├─ world/                       # ── Mundo: terreno, Éter, geração, simulação lenta
│  │  ├─ README.md
│  │  ├─ chunks/                   #   chunk_store.gd, voxel_backend/ (i_voxel_backend.gd,
│  │  │                            #     backend_voxel_tools.gd, block_shapes.gd, block_registry.tres),
│  │  │                            #     edit_journal.gd, dirty_regions.gd, lod_streamer.gd,
│  │  │                            #     voxel_query.gd (raycast/DLOS), destructible.gd
│  │  ├─ generation/               #   world_gen.gd, gen_params.tres, gen_version.gd,
│  │  │  ├─ noise/                 #     domain_warper.gd, ridged.gd, bilinear_up.gd
│  │  │  ├─ biome/                 #     biome_table.gd, climate.gd, soil.gd, rivers.gd
│  │  │  ├─ site/                  #     site_planner.gd, village_layout.gd, dungeon_layout.gd,
│  │  │  │                         #     ruin_layout.gd, graph_navigator.gd, road_builder.gd
│  │  │  ├─ structure/             #     structure_assembler.gd, piece_library.tres, height_utils.gd
│  │  │  ├─ flora/                 #     flora_scatter.gd, foliage_instancer.gd, growth_model.gd
│  │  │  ├─ fauna/                 #     spawn_table.gd, population_seed.gd, herd_placement.gd
│  │  │  └─ loot/                  #     chest_tables.gd, resource_density.gd
│  │  ├─ aether/                   #   aether_field.gd, channels.gd, imprint_system.gd,
│  │  │                            #   diffuse_job.gd, decay_table.tres, scar_tissue.gd (imunidade),
│  │  │                            #   aether_sense_api.gd, aether_viz.gd (FX de leitura)
│  │  ├─ nav/                      #   climb_graph.gd (nodes escaláveis estilo Veloren, em C++),
│  │  │                            #   voxel_astar.gd, influence_map.gd, corridor_cache.gd,
│  │  │                            #   reachability_check.gd (gate de geração)
│  │  ├─ ecology/                  #   population.gd, predation.gd, migration.gd, forage.gd,
│  │  │                            #   fire_system.gd, water_flow.gd, seasons.gd, traits_evolution.gd
│  │  ├─ slow_sim/                 #   loom.gd (Trama), faction_sim.gd, village_economy.gd,
│  │  │                            #   work_orders.gd, build_requests.gd, rumor_spread.gd,
│  │  │                            #   travel_jobs.gd, catch_up.gd (offline), macro_step.gd
│  │  ├─ weather/                  #   weather_sim.gd, front_map.gd, audio_ambience_link.gd
│  │  ├─ sites/                    #   site_instance.gd, ownership.gd, maintenance.gd, poaching.gd
│  │  └─ scenes/                   #   world_root.tscn, region_streamer.tscn, sky.tscn,
│  │                               #   site_village_*.tscn, dungeon_*.tscn, ruins_*.tscn
│  │
│  ├─ ai/                          # ── IA local (§04): nenhuma cena de jogo aqui, só lógica + dados
│  │  ├─ README.md
│  │  ├─ runtime/                  #   mind_server.gd (autoload), mind_store.gd, hot_set.gd,
│  │  │                            #   budget_governor.gd, tick_phases.gd, mind_lod.gd
│  │  ├─ mind/                     #   mind.gd, personality.gd, drives.gd, goal_stack.gd,
│  │  │                            #   wants.gd, mood.gd, attention.gd, energy.gd
│  │  ├─ memory/                   #   episodic_buffer.gd, beliefs.gd, belief_verifier.gd (grounding),
│  │  │                            #   consolidation_job.gd, semantic_index.gd (embeddings),
│  │  │                            #   recall.gd, forgetting_curve.tres, rumor_state.gd
│  │  ├─ behavior/                 #   bt/ (bt_node.gd, sequence.gd, selector.gd, parallel.gd,
│  │  │  │                         #     decorators/: inverter, cooldown, timeout, sub_tree_guard,
│  │  │  │                         #     memory_gate.gd)  leaves/: action_leaf.gd, condition_leaf.gd
│  │  │  ├─ blackboard.gd
│  │  │  └─ trees/                 #     *.tres: bt_wolf_hunt, bt_villager_day, bt_guard_patrol,
│  │  │                            #       bt_bandit_ambush, bt_boss_thornking, bt_companion_dissent
│  │  ├─ utility/                  #   response_curve.gd, consideration.gd, action_evaluator.gd,
│  │  │                            #   scorer.gd, hysteresis.gd, taskset.tres, curves/*.tres
│  │  ├─ perception/               #   sight.gd, hearing.gd, aether_sense.gd, social_sense.gd,
│  │  │                            #   threat_map.gd, awareness.gd, recognition.gd (rosto→crença)
│  │  ├─ action/                   #   intents.gd, action_registry.gd, locomotion.gd, combat_actions.gd,
│  │  │                            #   social_actions.gd, work_actions.gd, flee.gd, fetch.gd, build.gd
│  │  ├─ group/                    #   squad.gd, roles.gd, flanking.gd, formation.tres,
│  │  │                            #   herd_flocking.gd, chain_of_command.gd, orders.gd
│  │  ├─ adaptation/               #   style_fingerprint.gd, tactic_bank.gd (bandit),
│  │  │                            #   counter_profile.gd, immunity_profile.gd, director.gd,
│  │  │                            #   fairness_governor.gd, tension_model.gd
│  │  ├─ social/                   #   relations.gd, grudges.gd, reputation.gd, trust.gd,
│  │  │                            #   council.gd (quórum de opiniões p/ co-op), consent.gd,
│  │  │                            #   dialogue_state.gd, testimony.gd
│  │  ├─ llm/                      #   oracle_service.gd, prompt_compiler.gd, context_builder.gd,
│  │  │                            #   schemas/*.gd (validação), grammars/*.gbnf, oracle_cache.gd,
│  │  │                            #   embedding_service.gd, model_pack.gd, model_fetcher.gd,
│  │  │                            #   degraded_templater.gd (IA reduzida), oracle_health.gd
│  │  └─ tools/                    #   minds_inspector.tscn, bt_debugger.gd, budget_overlay.gd,
│  │                               #   memory_dump.gd, director_reason.gd, oracle_trace.gd
│  │
│  ├─ entities/                    # ── Entidades: cena + regra de alto nível
│  │  ├─ README.md
│  │  ├─ common/                   #   body.gd, health.gd, inventory.gd, equipment.gd, damageable.gd,
│  │  │                            #   carrying.gd, states (on_fire, poisoned, frightened),
│  │  │                            #   interactable.gd, loot.gd, naming.gd, visual_agent.gd (pool)
│  │  ├─ player/                   #   player.gd, controllers/: first_person.tscn, third_person.tscn,
│  │  │                            #     camera_rig.gd (gated per-mode), input_gutter.gd
│  │  │                            #   weaver.gd (magia), interaction.gd, party.gd, local_prediction.gd
│  │  ├─ mobs/                     #   mob.gd, archetypes/ (beast, pack, herd, vermin, construct,
│  │  │  └─ species/               #     drake, elemental), espécies como .tres + cena fina:
│  │  │                            #     mob_wolf.tres/.tscn, mob_deer, mob_bandit, mob_golem...
│  │  ├─ npc/                      #   npc.gd, roles/ (villager, guard, merchant, elder, priest,
│  │  │                            #     scout, smith, refugee), schedule.gd, home.gd, job.gd
│  │  ├─ companion/                #   companion.gd, dissent.gd, testimony_hook.gd, camp.gd
│  │  ├─ boss/                     #   boss.gd, boss_memory.gd, preparation.gd, envoys.gd,
│  │  │                            #     encounters/*.tres (perfis dos 6 chefes de referência)
│  │  └─ objects/                  #   prop_*, container, door, chest, campfire, forge, loom,
│  │                               #   banner, trap, projectile_gd, arrow, dropped_item
│  │
│  ├─ gameplay/                    # ── Sistemas de regra (todos rodam no SimClock)
│  │  ├─ README.md
│  │  ├─ combat/                   #   damage_pipeline.gd, material_matrix.tres, hitstop.gd, armor,
│  │  │                            #   block/parry/dodge, status_effects.gd, archery.gd, siege.gd
│  │  ├─ crafting/                 #   recipes.tres, stations.gd, quality.gd, tools.gd, upgrades,
│  │  │                            #   knowledge_gates.gd (receita vem de Gnose, não de nível)
│  │  ├─ magic/                    #   weaving.gd, sigil_compiler.gd (nós→assinatura), quanta.gd,
│  │  │                            #   backlash.gd, immune_response.gd, true_names.gd
│  │  ├─ economy/                  #   market.gd, supply_chain.gd, prices.gd, wages.gd, taxes,
│  │  │                            #   info_market.gd (vender dados do ledger!)
│  │  ├─ quests/                   #   commitment_reader.gd (lê ledger -> ofertas), journal.gd,
│  │  │                            #   conditions.gd (consultas), failure.gd, generator.gd
│  │  ├─ progression/              #   axes.gd (Soma/Vínculo/Gnose/Domínio/Ressonância),
│  │  │                            #   thresholds.gd (disjunção de rotas), death_debts.gd
│  │  ├─ events/                   #   event_director_api.gd, raids.gd, migrations.gd, festivals.gd,
│  │  │                            #   law_changes.gd, emergent_registry.gd
│  │  ├─ building/                 #   claims.gd, blueprints.gd, player_voxel_edit.gd, upkeep.gd,
│  │  │                            #   siege_work.gd (as mesmas portas usadas pela facção)
│  │  └─ survival/                 #   needs.gd (descanso, fome, frio), shelter.gd, light.gd
│  │
│  ├─ net/                         # ── Multiplayer 1-4 + dedicado
│  │  ├─ README.md
│  │  ├─ session/                  #   session_service.gd, host.gd, join.gd, lobby.tscn,
│  │  │                            #   invite_code.gd, peer_state.gd, host_migration.gd
│  │  ├─ replication/              #   net_registry.gd, delta_codec.gd, interest.gd, priority.gd,
│  │  │                            #   snapshot.gd, interpolation.gd, prediction.gd, authority.gd
│  │  ├─ protocol/                 #   messages.gd, msg_schema/*.gd, version.gd, rate_limiter.gd,
│  │  │                            #   validation.gd (motivos estruturados de recusa)
│  │  ├─ transport/                #   enet_bridge.gd, bouncer_client.gd (NAT introdução),
│  │  │                            #   relay_policy.gd, steam_transport.gd (opcional)
│  │  ├─ server/                   #   dedicated.tscn, console_commands.gd, admin.gd, config_file.gd
│  │  └─ attribution/              #   actor_set.gd (ordem/execução/empréstemo/testemunha),
│  │                                #   co_op_causality.gd
│  │
│  ├─ persistence/                 # ── Saves, journal, migração, verificação
│  │  ├─ save_manager.gd, save_slot.gd, atomic_write.gd, chunk_codec.gd, aether_codec.gd,
│  │  ├─ ledger_db.gd, mind_db.gd, chronicle_db.gd, embeddings_db.gd, journal_store.gd,
│  │  ├─ migrations/  (0001_init.gd, 0002_rumor_credibility.gd, ...)
│  │  ├─ fsck.gd, invariant_checks.gd, export_import.gd (backup de mundo), cloud_stub.gd (off)
│  │
│  ├─ ui/                          # ── Interface (§ style bible em docs/art)
│  │  ├─ hud/                      #   hud.tscn, vitals.gd, compass_ether.gd (vestígios), targets,
│  │  │                            #     log_echo.gd, prompts, notices (consequências em tempo real)
│  │  ├─ menus/                    #   main_menu.tscn, settings (incl. AI pack, IA reduzida),
│  │  │                            #     world_create.tscn, save_slots, co-op lobby, credits
│  │  ├─ screens/                  #   chronicle_scrubber.tscn (I8), faction_map.tscn, mind_dialogue.tscn,
│  │  │                            #     inventory, crafting, codex (conhecimento), court (leis/dívidas)
│  │  ├─ controls/                 #   reutilizáveis: item_slot, ether_bar, curve_graph, portrait,
│  │  │                            #     testimony_row, deed_row, slider_x
│  │  ├─ overlays/                 #   debug_overlay.gd, budget_overlay.gd, oracle_overlay.gd
│  │  ├─ theme/                    #   af_theme.tres, fonts/, styles/, sounds de UI
│  │  └─ navigation/               #   focus_map.gd (gamepad/teclado), tooltip_service.gd,
│  │                                 #     a11y.gd (redimensionável, daltônico, legendas)
│  │
│  ├─ rendering/                   # ── Visual: shaders e efeitos (sem lógica de regra)
│  │  ├─ shaders/                  #   ether_trace.gdshader, voxel_atlas.gdshader, dissolve_deed,
│  │  │                            #     dissolvers, heat_haze, mind_glow, time_lapse_overlay
│  │  ├─ materials/                #   mat_*.tres por família de bloco
│  │  ├─ lighting/                 #   sun.gd, ether_emissive.gd, night_grade.tres
│  │  ├─ fx/                       #   fx_hitstop, fx_impact_*, fx_memory_write (partícula de
│  │  │                            #     gravação), screen_shake.gd, blood_to_ether.gd
│  │  └─ atmosphere/               #   fog_height, weather_post, sky presets
│  │
│  ├─ audio/                       #   audio_bus_setup.tres, ambience_by_biome.gd, music_layered.gd
│  │                                #   (score adaptativo: camadas por tensão do Diretor),
│  │                                #   sfx_by_material.gd, speech_tips.gd (placeholder de voz local)
│  │
│  ├─ input/                       #   actions.gd (mapeamento), rebinder.gd, conflict_check.gd,
│  │                                #   deadzone.gd, touch_layout.gd, haptics.gd
│  │
│  ├─ analytics/                   #   LOCAL-ONLY: style_telemetry.gd, session_recorder.gd,
│  │                                #   budget_log.gd  — nada de rede; toggle no settings
│  │
│  ├─ mod/                         #   af_api.gd (API pública estável), hooks.gd, sandbox.gd
│  │                                #   (política: mods não tocam ledger sem versão), example_mod/
│  │
│  ├─ tools/                       # ── Ferramentas de design (cenas normais, reusáveis por mods)
│  │  ├─ gen_preview/              #   af_gen_preview.tscn: mapa de biomas/sites, seeds, diffs
│  │  ├─ balance_editor/           #   af_balance_editor.tscn: curvas de utility, loot, receitas
│  │  ├─ pregen/                   #   af_pregen.gd (headless: gera/regenera regiões)
│  │  ├─ bench/                    #   af_bench.gd: cenários + hash por tick + relatório
│  │  ├─ asset_pipeline/           #   atlas slicer, voxel block importer, palette check
│  │  └─ chronicle_cli.gd          #   consulta/exports de Crônica sem abrir o jogo
│  │
│  ├─ data/                        # ── Definições como Resource (sem .gd aqui)
│  │  ├─ blocks/                   #   block_*.tres, block_shapes/, materials_atlas.tres
│  │  ├─ biomes/                   #   biome_*.tres, climate_tables.tres
│  │  ├─ species/                  #   species_*.tres (corpo, dieta, BT ref, tactic set, herd)
│  │  ├─ factions/                 #   faction_*.tres, goals, valores, obras permitidas
│  │  ├─ items/                    #   item_*.tres, tools, weapons, armor, materials
│  │  ├─ recipes/                  #   recipe_*.tres, stations.tres
│  │  ├─ quests/                   #   não-escritas: apenas templates de consulta do ledger
│  │  ├─ bosses/                   #   boss_*.tres, preparations, concessions, true names
│  │  ├─ knowledge/                #   gnose: receitas-lock, names, fraquezas (o que a Crônica pode ensinar)
│  │  ├─ dialogue/                 #   intents.tres, templates de fallback (IA reduzida), tom
│  │  ├─ balance/                  #   damage_curves.tres, cost_curves.tres, budgets.tres
│  │  └─ l10n/                     #   af.csv -> pt.csv/en.csv, fake_out_of_length.csv
│  │
│  └─ util/                        # ── Utilitários genéricos, sem estado de jogo
│     ├─ math/                     #   fixed32.gd, interpolation.gd, easing.gd, geo_voxel.gd,
│     │                            #     bit_packing.gd, color_ether.gd, noise_wrappers.gd
│     ├─ data/                     #   packed_pool.gd, free_list.gd, ring_buffer.gd, cache_lru.gd,
│     │                            #     int_int_map.gd, sorted_query.gd
│     ├─ logging/                  #   af_log.gd (níveis, categorias, captação p/ Crônica),
│     │                            #     perf_trace.gd, tick_stats.gd
│     ├─ io/                       #   path_policy.gd (user:// vs res://), zstd_helper.gd, jsonx.gd
│     ├─ testing/                  #   assertions_invariants.gd, determinism_check.gd, fake_clock.gd
│     └─ debug/                    #   gizmos.gd, dev_menu.tscn, cheat_service.gd (gateado)
│
├─ assets/                         # ── Binários de arte/áudio (CC-BY-SA), nunca referenciados
│  │                               #    por caminho hardcoded: sempre via content_registry
│  ├─ art/voxel_atlas/             #   atlas_01.png/.import, paleta.tres
│  ├─ art/models/                  #   mobs/, npcs/, props/, rigs/ (glTF .glb)
│  ├─ art/ui/                      #   ícones, retratos, cursors, logos
│  ├─ art/fonts/                   #   fontes + licenças (OFL) por arquivo
│  ├─ audio/sfx/  audio/music/  audio/ambience/
│  ├─ shaders/                     #   só .gdshader binário-dependente? (código fica em src/rendering)
│  └─ placeholders/                #   removidos antes de cada release (CI barra)
│
├─ native/                         # ── C++ GDExtension (um módulo por responsabilidade)
│  ├─ af_voxel/                    #   codec/LOD/meshing extra se o backend precisar, block shapes
│  │  ├─ src/  include/  af_voxel.gdextension  SConstruct  tests/
│  ├─ af_aether/                   #   difusão, decaimento, consultas espaciais (SIMD)
│  ├─ af_nav/                      #   climb graph, A* voxel, influence maps
│  ├─ af_store/                    #   zstd, journal append, sqlite wrappers, hashes
│  ├─ af_mind/                     #   llama.cpp: loader, slots, grammar decode, embeddings
│  │  ├─ third_party/llama.cpp/    #     submódulo MIT (licença registrada)
│  │  └─ model_policy.cpp          #     n_gpu_layers, reasoning off, escolha de device Vulkan
│  ├─ af_sim/                      #   componentes quentes do SimWorld (queries, swept AABB)
│  └─ build/                       #   gitignored — .dll/.so/.dylib produzidos por plataforma
│
├─ models/                         # gitignored — GGUF baixados por ModelPackFetcher
│  ├─ mind-small/                  #   LICENSE.txt + MODEL_CARD.md + sha256
│  └─ mind-voice/                  #   idem
│
├─ saves/                          # gitignored — layout em §06.7
├─ config/                         #   defaults/, keybinds/, hardware_profiles/*.tres
├─ export/                         #   export_presets.cfg, icons/, template checksums
├─ bin/                            # gitignored — builds por plataforma
│
└─ tests/                          # ── Testes executáveis por CI (headless)
   ├─ unit/                        #   gdscript unit (GUT), por sistema
   ├─ sim/                         #   determinismo: N espécies × M ticks, hash por sistema/tick
   ├─ replay/                      #   golden journals da Crônica -> regressão de estado
   ├─ invariants/                  #   regras do ledger, verificação de crenças, budget governor
   ├─ coop/                        #   2 clientes: late-join, atribuição, migração de host
   ├─ data/                        #   validação de schema de .tres, referências cruzadas, curvas
   ├─ world/                       #   conectividade de sites, densidade de loot, gerações seeds
   └─ ai_eval/                     #   oráculo: grounding de ids, % fora de schema, custo/tempo
```

## Autoloads canônicos `[TARGET]` (ordem importa)

```
GameBoot        src/core/boot/game_boot.gd          # detecta hw, safemode, crash guard
Settings        src/core/settings/settings_service.gd
SimClock        src/core/sim/sim_clock.gd           # dono do tick autoritativo
Events          src/core/events/event_bus.gd
ContentRegistry src/core/registry/content_registry.gd  # ids de blocks/species/factions
WorldRegistry   src/world/chunks/chunk_store.gd     # voxel + regiões + dirty
Aether          src/world/aether/aether_field.gd    # campo de memória espacial
Loom            src/world/slow_sim/loom.gd          # Trama: facções/economia/ecologia/rumores
Minds           src/ai/runtime/mind_server.gd       # BT+utility+memória+LOD+budget
Oracle          src/ai/llm/oracle_service.gd        # LLM local opcional (fila, cache, degrade)
Ledger          src/persistence/ledger_db.gd        # Ecos + Crônica
Net             src/net/session/session_service.gd
Saves           src/persistence/save_manager.gd
Audio           src/audio/audio_service.gd
Debug           src/util/debug/dev_menu.gd          # só em builds de debug
```

Nada dessa lista é autoload hoje — `project.godot` não tem seção `[autoload]`. O som que
existe é outra linha: `src/audio/audio_director.gd`, um nó filho da sessão
(`src/main.gd`), consumidor dos sinais do mundo com as 27 famílias derivadas de
`assets/audio/levels.json` ([procedência e medição](../audio-provenance.md)).
`audio_service.gd` continua `[TARGET]`.

**Regra de ouro de dependência:** `core → util`; `world/gameplay/entities → core`;
`ai → core, world (leitura), gameplay (intents)`; `net → tudo (autoridade)`, **mas**
nada em `core/world/ai` pode `preload` de `ui/` ou `net/` — UI e rede são **consumidores
de eventos**, nunca produtores de estado. Essa aresta proibida é o que mantém o
`--headless` funcionando e o dedicado idêntico ao host de um jogador.
