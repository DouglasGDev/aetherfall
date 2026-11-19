class_name TickJournal
extends RefCounted

const FORMAT_VERSION: int = 1

var path: String = ""
var records: int = 0
var last_tick: int = -1
var last_hash: String = ""
var last_us: int = 0
var worst_us: int = 0
var total_us: int = 0
var _file: FileAccess = null


static func state_hash(tick: int, world: VoxelWorld, field: AetherField, roster: Array) -> String:
	var positions: Array = world.edits.keys()
	positions.sort()
	var edits: Array = []
	for pos: Vector3i in positions:
		edits.append([pos.x, pos.y, pos.z, int(world.edits[pos])])
	var living: Array[Wolf] = []
	for wolf: Wolf in roster:
		if wolf.alive:
			living.append(wolf)
	living.sort_custom(func(a: Wolf, b: Wolf) -> bool: return a.identity < b.identity)
	var minds: Array = []
	for wolf: Wolf in living:
		var keys: Array = wolf.mind.beliefs.keys()
		keys.sort()
		var beliefs: Array = []
		for key: String in keys:
			var belief: Dictionary = wolf.mind.beliefs[key]
			beliefs.append([key, float(belief["confidence"]), String(belief["source"])])
		minds.append([wolf.identity, wolf.mind.identity, wolf.mind.kind, wolf.intent, beliefs])
	var metadata: Array = [FORMAT_VERSION, world.gen.world_seed, WorldGen.GEN_VERSION, tick,
		[VoxelConfig.world_size_x(), VoxelConfig.CHUNK_SIZE_Y, VoxelConfig.world_size_z()],
		[field.cell, field.size_x, field.size_y, field.size_z, AetherField.Channel.COUNT],
		edits, minds]
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(metadata))
	digest.update(field.state_bytes())
	return digest.finish().hex_encode()


func start(file_path: String) -> Error:
	if active():
		return ERR_ALREADY_IN_USE
	if FileAccess.file_exists(file_path) or DirAccess.dir_exists_absolute(file_path):
		return ERR_ALREADY_EXISTS
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	if _file == null:
		return FileAccess.get_open_error()
	path = file_path
	records = 0
	last_tick = -1
	last_hash = ""
	last_us = 0
	worst_us = 0
	total_us = 0
	return OK


func active() -> bool:
	return _file != null


func record(tick: int, world: VoxelWorld, field: AetherField, roster: Array) -> Error:
	if not active():
		return ERR_UNCONFIGURED
	if tick < 0 or (records > 0 and tick != last_tick + 1):
		return ERR_INVALID_DATA
	var started := Time.get_ticks_usec()
	var checksum := state_hash(tick, world, field, roster)
	_file.store_line(JSON.stringify([tick, checksum]))
	_file.flush()
	var err := _file.get_error()
	if err != OK:
		return err
	last_tick = tick
	last_hash = checksum
	records += 1
	last_us = Time.get_ticks_usec() - started
	worst_us = maxi(worst_us, last_us)
	total_us += last_us
	return OK


func close() -> void:
	if _file != null:
		_file.close()
		_file = null


func diagnostics() -> Dictionary:
	return {"active": active(), "path": path, "records": records, "last_tick": last_tick,
		"last_hash": last_hash, "last_us": last_us, "worst_us": worst_us, "total_us": total_us}
