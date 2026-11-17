class_name SaveManager
## Persistencia atomica (docs/design/06.5): escreve .tmp e so depois renomeia. Um
## mundo com metade do arquivo gravado e pior que o mundo anterior inteiro.
##
## O save guarda a semente + o diario de edicoes, nunca o voxel em si: o gerador e
## deterministico, entao reconstruir e mais barato e a prova de versao (gen_version).

const SCHEMA: int = 1
const SAVE_DIR: String = "user://saves"
const SLOT_FILE: String = "world_%s.json"


static func slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(SLOT_FILE % slot)


static func tmp_path(slot: String) -> String:
	return slot_path(slot) + ".tmp"


static func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func write_slot(slot: String, data: Dictionary) -> Dictionary:
	var out := {"ok": false, "error": "", "bytes": 0, "ms": 0.0, "path": slot_path(slot)}
	var t0 := Time.get_ticks_usec()
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		out["error"] = "dir: %s" % error_string(err)
		return out
	var tmp := tmp_path(slot)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		out["error"] = "open: %s" % error_string(FileAccess.get_open_error())
		return out
	f.store_string(JSON.stringify(data, "  "))
	f.flush()
	var size := f.get_length()
	f.close()
	err = DirAccess.rename_absolute(tmp, slot_path(slot))
	if err != OK:
		out["error"] = "rename: %s" % error_string(err)
		DirAccess.remove_absolute(tmp)
		return out
	out["ok"] = true
	out["bytes"] = size
	out["ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	return out


static func read_slot(slot: String) -> Dictionary:
	var out := {"ok": false, "error": "", "data": {}, "ms": 0.0}
	if not has_slot(slot):
		out["error"] = "ausente"
		return out
	var t0 := Time.get_ticks_usec()
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		out["error"] = "open: %s" % error_string(FileAccess.get_open_error())
		return out
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		out["error"] = "json invalido"
		return out
	var d: Dictionary = parsed
	if int(d.get("schema", 0)) > SCHEMA:
		out["error"] = "schema %d mais novo que %d" % [int(d["schema"]), SCHEMA]
		return out
	out["ok"] = true
	out["data"] = d
	out["ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	return out
