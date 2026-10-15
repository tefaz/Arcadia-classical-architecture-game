class_name WorldStore
extends RefCounted

const VERSION := 1
const SAVE_PATH := "user://sanctuary.json"
const MAX_PIECES := 4000
var error := ""

func save_world(pieces: Array, player: Dictionary, preferences: Dictionary, path: String = SAVE_PATH) -> bool:
	error = ""
	var document := {"version": VERSION, "name": "The Builder's Sanctuary", "saved_at": Time.get_datetime_string_from_system(), "pieces": pieces, "player": player, "preferences": preferences}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Could not write save file. Check available space and permissions."
		return false
	file.store_string(JSON.stringify(document, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if result != OK:
		error = "Could not finish saving the world."
	return result == OK

func load_world(path: String = SAVE_PATH) -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path):
		error = "No saved sanctuary yet. Build something and press F5."
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.length() > 8_000_000:
		error = "This save is too large."
		return {}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		error = "This save is damaged. Your current world is unchanged."
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or parsed.get("version") != VERSION or not parsed.get("pieces") is Array:
		error = "This save is damaged or belongs to another version. Your current world is unchanged."
		return {}
	if parsed.pieces.size() > MAX_PIECES:
		error = "This save exceeds the prototype's building limit."
		return {}
	var seen := {}
	for record in parsed.pieces:
		if not valid_piece(record) or seen.has(int(record.uid)):
			error = "Invalid component data in save. Your current world is unchanged."
			return {}
		seen[int(record.uid)] = true
	if not parsed.get("player", {}) is Dictionary or not parsed.get("preferences", {}) is Dictionary:
		error = "Invalid world settings in save."
		return {}
	return parsed

static func valid_vector(value: Variant, limit: float = 80) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)) or absf(float(number)) > limit:
			return false
	return true

static func valid_piece(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	if not record.get("kind") is String or BuildCatalogue.get_piece(record.kind).is_empty():
		return false
	if not record.get("uid") is float and not record.get("uid") is int:
		return false
	if record.uid <= 0 or float(record.uid) != floorf(float(record.uid)):
		return false
	if not record.get("stone") is float and not record.get("stone") is int:
		return false
	if record.stone < 0 or record.stone >= BuildCatalogue.MATERIALS.size() or float(record.stone) != floorf(float(record.stone)):
		return false
	if not valid_vector(record.get("position")):
		return false
	if record.has("length"):
		var length: Variant = record.length
		if record.kind not in BuildCatalogue.MITRE_KINDS or not (length is float or length is int): return false
		if not is_finite(float(length)) or length < BuildCatalogue.MIN_SPAN or length > BuildCatalogue.MAX_SPAN: return false
		if not BuildCatalogue.valid_span(record.kind,float(length)): return false
	if record.has("rise"):
		var rise: Variant = record.rise
		if record.kind != "steps" or not (rise is float or rise is int): return false
		if not is_finite(float(rise)) or rise < BuildCatalogue.STAIR_RISER or rise > 40: return false
	var angle: Variant = record.get("rotation")
	return (angle is float or angle is int) and is_finite(float(angle)) and absf(float(angle)) < 1000
