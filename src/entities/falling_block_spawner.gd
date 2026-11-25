class_name FallingBlockSpawner
## Dono das entidades de bloco em voo (dossie 17 §3.3, §7d). A fila decide QUEM cai; este
## objeto decide ONDE o grao mora enquanto cai, e e o unico lugar que poe um `FallingBlock`
## na arvore -- por isso o `diagnostics()` e o F3 leem `falling` daqui e nao de um contador
## solto no `main.gd`.
##
## Nada aqui varre o mundo atras de areia solta: a lista nasce vazia e so cresce pelo
## `convert` chamado pela fila. `clear` e o load quem chama, porque o disco guarda o mundo ja
## em repouso (dossie 17 §3.7) e estado de queda nao tem chave de save.

var world: VoxelWorld = null
var stage: Node3D = null
var falling: Array = []
var conversions: int = 0
var placed: int = 0
## Grao que chegou ao fim da queda sem coube em lugar nenhum. Contado, nao calado: a saida
## `SHATTER` do doc nao tem comprador (dossie 17 §6), entao o caminho existe como recusa com
## numero e nao como item no chao inventado.
var stranded: int = 0
var max_falling: int = 0


func setup(p_world: VoxelWorld, p_stage: Node3D) -> void:
	world = p_world
	stage = p_stage


func convert(cell: Vector3i, b: int) -> bool:
	conversions += 1
	# A origem sai do grid PELO REGISTRO: a areia nao esta mais aquela, e essa chave e a
	# primeira metade da dupla que `queda_move_a_celula` conta no diario.
	if not world.set_block(cell, BlockDefs.Block.AIR):
		return false
	var fb := FallingBlock.new()
	fb.name = "FallingBlock%d" % conversions
	fb.setup(world, cell, b)
	stage.add_child(fb)
	falling.append(fb)
	max_falling = maxi(max_falling, falling.size())
	return true


func step(dt: float) -> void:
	if falling.is_empty():
		return
	var i: int = 0
	while i < falling.size():
		var fb: FallingBlock = falling[i]
		if fb.fresh:
			# Nasceu no tick do `convert`: integra no proximo (dossie 17 §3.5), senao a
			# conversao e o primeiro passo de queda cairiam no mesmo cronometro.
			fb.fresh = false
			i += 1
			continue
		fb.sim_step(dt)
		if fb.done:
			if fb.stranded:
				stranded += 1
			else:
				placed += 1
			falling.remove_at(i)
			fb.queue_free()
			continue
		i += 1


func clear() -> void:
	for fb: FallingBlock in falling:
		fb.queue_free()
	falling.clear()


func stats() -> Dictionary:
	return {
		"falling": falling.size(), "conversions": conversions,
		"placed": placed, "stranded": stranded, "max_falling": max_falling,
	}
