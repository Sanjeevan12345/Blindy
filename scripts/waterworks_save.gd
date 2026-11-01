extends RefCounted
const VERSION := 1
const PATH := "user://waterworks.json"
static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if int(data.get("version",0))!=VERSION or data.get("level",0)!=3: return false
	if not data.get("checkpoint",0) is float and not data.get("checkpoint",0) is int: return false
	if int(data.checkpoint)<1 or int(data.checkpoint)>14: return false
	if float(data.checkpoint)!=int(data.checkpoint): return false
	if not data.get("complete") is bool or data.get("cargo")!=true: return false
	if not data.get("heading") is float and not data.get("heading") is int: return false
	if not is_finite(float(data.heading)): return false
	if not data.get("flags") is Dictionary: return false
	for key in ["training","battery","pump_a","lock","pump_b","light_1","light_2","basin","exit"]:
		if not data.flags.get(key) is bool: return false
	if data.flags.pump_a and not data.flags.battery: return false
	if data.flags.pump_b and not data.flags.lock: return false
	if data.flags.basin and not (data.flags.pump_a and data.flags.pump_b): return false
	if int(data.checkpoint)>=13 and not data.flags.basin: return false
	return true
static func parse_file(path: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path))==OK else null
static func read_slot(path: String=PATH) -> Dictionary:
	for candidate in [path,path+".bak"]:
		if FileAccess.file_exists(candidate):
			var parser := JSON.new()
			var result := parser.parse(FileAccess.get_file_as_string(candidate))
			var data=parser.data if result==OK else null
			if valid(data): return data
	return {}
static func write_slot(data: Dictionary,path: String=PATH) -> Error:
	if not valid(data): return ERR_INVALID_DATA
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if not valid(parse_file(path+".tmp")): return ERR_FILE_CORRUPT
	# Only rotate a verified current save; a valid backup survives corruption.
	if FileAccess.file_exists(path) and valid(parse_file(path)):
		var copied := DirAccess.copy_absolute(path,path+".bak")
		if copied!=OK: return copied
	return DirAccess.rename_absolute(path+".tmp",path)
