class_name BuildPiece
extends StaticBody3D

var uid := 0
var kind := "foundation"
var stone := 0
var span_length := BuildCatalogue.BAY
var stair_rise := BuildCatalogue.STAIR_RISE
var join_left := 0
var join_right := 0
var visual_bounds := AABB()
var pediment_fit := Transform3D.IDENTITY
var ceiling_regions: Array[Dictionary] = []
var ceiling_rects: Array[Rect2] = [Rect2(-2,-2,4,4)]

func serialize() -> Dictionary:
	var record := {"uid": uid, "kind": kind, "stone": stone, "position": [position.x, position.y, position.z], "rotation": rotation.y}

	if kind in BuildCatalogue.MITRE_KINDS and not is_equal_approx(span_length,BuildCatalogue.BAY):
		record["length"] = span_length
	if kind == "steps" and not is_equal_approx(stair_rise,BuildCatalogue.STAIR_RISE):
		record["rise"] = stair_rise
	return record

func world_sockets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for socket in BuildCatalogue.sockets(kind,span_length,stair_rise):
		var transformed: Dictionary = socket.duplicate()
		transformed.position = global_transform * socket.position
		transformed.normal = global_basis * socket.normal
		if socket.has("slope"): transformed.slope = global_basis*socket.slope
		result.append(transformed)
	return result
