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
var cover_rect := Rect2(-2,-2,4,4)

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
		var point: Vector3 = socket.position
		if kind in preload("res://src/building/wall_cover.gd").KINDS:
			var size := BuildCatalogue.piece_size(kind)
			point.x = cover_rect.position.x+(point.x+size.x/2)*cover_rect.size.x/size.x
			point.z = cover_rect.position.y+(point.z+size.z/2)*cover_rect.size.y/size.z
		transformed.position = global_transform * point
		transformed.normal = global_basis * socket.normal
		if socket.has("slope"): transformed.slope = global_basis*socket.slope
		result.append(transformed)
	return result
