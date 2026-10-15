class_name CornerJoints
extends RefCounted

## Joins are derived from matching centre-line endpoints, never persisted as fragile links.
const EPSILON := 0.005

static func point_key(point: Vector3) -> String:
	return "%d:%d:%d" % [roundi(point.x*100),roundi(point.y*100),roundi(point.z*100)]

static func end_point(transform_value: Transform3D, end: int, length: float = BuildCatalogue.BAY) -> Vector3:
	return transform_value * Vector3(end*length/2,0,0)

static func index_pieces(pieces: Array) -> Dictionary:
	var index := {}
	for piece in pieces:
		if piece.kind in BuildCatalogue.RAKE_KINDS or piece.kind in BuildCatalogue.ROOF_KINDS or piece.kind == "pediment":
			for socket in piece.world_sockets():
				if socket.family != "pediment_rake" and not socket.family.begins_with("roof_gable_"): continue
				var key := point_key(socket.position)
				if not index.has(key): index[key] = []
				index[key].append({"piece":piece,"end":0,"point":socket.position,"normal":socket.normal,"family":socket.family,"slope":socket.get("slope",Vector3.ZERO)})
		if piece.kind not in BuildCatalogue.MITRE_KINDS:
			continue
		for end in [-1,1]:
			var point := end_point(piece.transform,end,piece.span_length)
			var key := point_key(point)
			if not index.has(key):
				index[key] = []
			index[key].append({"piece":piece,"end":end,"point":point})
	return index

static func describe(kind: String, transform_value: Transform3D, index: Dictionary, ignore_uid: int = 0, length: float = BuildCatalogue.BAY) -> Dictionary:
	var result := {"left":0,"right":0,"partners":[],"conflict":false}
	if kind in BuildCatalogue.RAKE_KINDS or kind == "pediment":
		# Placing a gable trims matching existing roof ends on commit. Ignore
		# only those fitted partners during the pre-commit collision query.
		for socket in BuildCatalogue.sockets(kind):
			if not socket.family.begins_with("roof_gable_"): continue
			var point: Vector3 = transform_value*socket.position
			for entry in index.get(point_key(point),[]):
				if entry.piece.kind not in BuildCatalogue.ROOF_KINDS or entry.piece.uid == ignore_uid: continue
				if not BuildCatalogue.sockets_match(entry,socket,transform_value.basis) or entry.point.distance_to(point) > EPSILON: continue
				if entry.normal.dot(transform_value.basis*socket.normal) > -0.95: continue
				if entry.piece not in result.partners: result.partners.append(entry.piece)
	if kind in BuildCatalogue.ROOF_KINDS:
		for socket in BuildCatalogue.sockets(kind):
			if not socket.family.begins_with("roof_gable_"): continue
			var point: Vector3 = transform_value*socket.position
			for entry in index.get(point_key(point),[]):
				if entry.piece.uid == ignore_uid or entry.piece.kind not in ["pediment_left","pediment_right","pediment_crown","pediment"]: continue
				if not BuildCatalogue.sockets_match(entry,socket,transform_value.basis) or entry.point.distance_to(point) > EPSILON: continue
				if entry.normal.dot(transform_value.basis*socket.normal) > -0.95: continue
				result["left" if socket.position.z < 0 else "right"] = 1
		return result
	if kind in BuildCatalogue.RAKE_KINDS:
		for socket in BuildCatalogue.sockets(kind):
			if socket.family != "pediment_rake": continue
			var point: Vector3 = transform_value*socket.position
			for entry in index.get(point_key(point),[]):
				if entry.piece.uid == ignore_uid or entry.piece.kind not in BuildCatalogue.RAKE_KINDS: continue
				if entry.get("family","") != "pediment_rake": continue
				if entry.point.distance_to(point) > EPSILON or entry.normal.dot(transform_value.basis*socket.normal) > -0.95: continue
				result["left" if socket.position.x < 0 else "right"] = 1
		return result
	if kind not in BuildCatalogue.MITRE_KINDS:
		return result
	for end in [-1,1]:
		var point := end_point(transform_value,end,length)
		var candidates: Array = index.get(point_key(point),[])
		var matches: Array = []
		for entry in candidates:
			var other: BuildPiece = entry.piece
			if other.uid == ignore_uid or BuildCatalogue.join_profile(other.kind) != BuildCatalogue.join_profile(kind) or entry.point.distance_to(point) > EPSILON:
				continue
			if absf(transform_value.basis.x.dot(other.basis.x)) > 0.001:
				continue
			matches.append(entry)
		if matches.size() > 1:
			result.conflict = true # A T junction needs a different profile, not two mitres.
			continue
		if matches.is_empty():
			continue
		var match_entry: Dictionary = matches[0]
		var peer: BuildPiece = match_entry.piece
		# Do not take a corner that already belongs to another perpendicular run.
		for existing in candidates:
			var occupant: BuildPiece = existing.piece
			if occupant.uid == peer.uid or occupant.uid == ignore_uid or BuildCatalogue.join_profile(occupant.kind) != BuildCatalogue.join_profile(kind):
				continue
			if existing.point.distance_to(point) <= EPSILON and absf(peer.basis.x.dot(occupant.basis.x)) < 0.001:
				result.conflict = true
		var away: Vector3 = peer.basis.x * -int(match_entry.end)
		var turn := 1 if transform_value.basis.z.dot(away) > 0 else -1
		result["left" if end < 0 else "right"] = turn
		if peer not in result.partners:
			result.partners.append(peer)
	return result
