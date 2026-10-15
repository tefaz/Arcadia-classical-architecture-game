class_name SnapSolver
extends RefCounted

## Candidate generation is pure math; the builder chooses the nearest candidate that fits.
const SNAP_RADIUS := 1.7
const WallPerimeter := preload("res://src/building/wall_perimeter.gd")
const ColumnLayout := preload("res://src/building/column_layout.gd")

static func solve(kind: String, angle: float, hit: Dictionary, pieces: Array, grid: bool, sockets_enabled: bool, elevation: float, anchor: int = 0, connections: Dictionary = {}, length: float = 0) -> Dictionary:
	return candidates(kind,angle,hit,pieces,grid,sockets_enabled,elevation,anchor,connections,length)[0]

static func candidates(kind: String, angle: float, hit: Dictionary, pieces: Array, grid: bool, sockets_enabled: bool, elevation: float, anchor: int = 0, connections: Dictionary = {}, length: float = 0) -> Array[Dictionary]:
	var point: Vector3 = hit.position
	var span := length if length > 0 else BuildCatalogue.BAY
	var size := BuildCatalogue.piece_size(kind,span)
	var basis := Basis(Vector3.UP,angle)
	var pos := point
	var support := (basis.x.abs()*size.x + basis.z.abs()*size.z)/2
	var surface: BuildPiece = hit.collider as BuildPiece
	if kind == "flat_roof" and surface != null and sockets_enabled and grid and is_zero_approx(elevation):
		var infill := ceiling_infill(basis,hit,pieces)
		if not infill.is_empty(): return infill
	# A completed roof obscures the beam top. Its room-facing side can still
	# seat a ceiling at the eave, but only when a matching roof fit exists.
	if kind == "flat_roof" and surface != null and surface.kind == "entablature" and sockets_enabled and is_zero_approx(elevation) and absf(hit.normal.dot(surface.basis.z)) > 0.9:
		var upper: Dictionary = hit.duplicate()
		upper.position = Vector3(point.x,surface.position.y+0.75,point.z)
		upper.normal = Vector3.UP
		var eave_candidates: Array[Dictionary] = []
		for candidate in candidates(kind,angle,upper,pieces,grid,sockets_enabled,elevation,anchor,connections,length):
			if not candidate.snapped or (candidate.position-point).dot(hit.normal) < 0.1: continue
			if preload("res://src/building/ceiling_roof_fit.gd").regions_for(Transform3D(basis,candidate.position),pieces).is_empty(): continue
			candidate.label = "Ceiling beneath roof · R turns / T cycles anchors"
			eave_candidates.append(candidate)
		if not eave_candidates.is_empty(): return eave_candidates
	if absf(hit.normal.y) < 0.6:
		pos += hit.normal * support.dot(hit.normal.abs())
		pos.y = surface.position.y if surface else 0.0
	elif hit.normal.y < -0.6:
		pos.y -= size.y
	if kind == "flat_roof" and absf(hit.normal.y) > 0.6:
		var anchors := BuildCatalogue.sockets(kind).filter(func(socket): return socket.family == "stack" and socket.normal.y < -0.5)
		pos -= basis*anchors[posmod(anchor,anchors.size())].position
	if grid:
		# Follow the aimed building's origin and rotation, including off-grid old worlds.
		var frame := surface.global_transform if surface else Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)
		var grid_anchor := -basis.x*span/2 if kind in BuildCatalogue.MITRE_KINDS else Vector3.ZERO
		var local := frame.affine_inverse()*(pos+grid_anchor)
		local.x = snappedf(local.x,BuildCatalogue.GRID)
		local.z = snappedf(local.z,BuildCatalogue.GRID)
		pos = frame*local-grid_anchor
		# Rounding must not move a solid back through the aimed face.
		if absf(hit.normal.y) < 0.6:
			pos += hit.normal*maxf(0,support.dot(hit.normal.abs())-(pos-point).dot(hit.normal))
	var fallback := {"position":pos+Vector3.UP*elevation,"length":span,"snapped":false,"target":null,"socket":Vector3.ZERO,"label":("Surface grid · 0.5 m" if surface else "Grid · 0.5 m") if grid else "Free placement","score":INF}
	var result: Array[Dictionary] = []
	if grid and sockets_enabled and is_zero_approx(elevation):
		var perimeter := WallPerimeter.solve(kind,basis,hit,pieces,anchor,length)
		if not perimeter.is_empty(): return [perimeter]
		var layout := ColumnLayout.solve(kind,hit,pieces)
		if not layout.is_empty(): return [layout]
	if not sockets_enabled or not is_zero_approx(elevation) or surface == null: return [fallback]
	if kind in BuildCatalogue.DOME_KINDS and surface.kind in BuildCatalogue.MITRE_KINDS and hit.normal.y > 0.6 and anchor == 0:
		var dome := dome_on_run(kind,basis,surface,pieces)
		if not dome.is_empty(): return [dome]
	if kind == "steps" and surface.kind in BuildCatalogue.FOUNDATION_KINDS and absf(hit.normal.y) < 0.1:
		var stairs := landing_stairs(surface,point,hit.normal)
		# A blocked entrance must remain at the aimed landing, rather than
		# falling back to a short stair that cannot reach the platform.
		if not stairs.is_empty(): return stairs
	var selected_sockets := BuildCatalogue.sockets(kind,span)
	var underside: bool = hit.normal.y < -0.6
	var bottoms: Array[Dictionary] = []
	for input in selected_sockets:
		if input.family == "stack" and (input.normal.y > 0.5 if underside else input.normal.y < -0.5):
			bottoms.append(input)
	var bottom: Dictionary = bottoms[posmod(anchor,bottoms.size())]
	# Standard entablatures start at a support rather than straddling its centre.
	if kind == "entablature" and surface.kind in ColumnLayout.KINDS and not underside and anchor == 0:
		bottom = bottoms[1]
	if kind in BuildCatalogue.DOME_KINDS and surface.kind in BuildCatalogue.WALL_KINDS+["arch","entablature","cornice"] and not underside and anchor == 0:
		bottom = bottoms[1]
	if connections.is_empty(): connections = CornerJoints.index_pieces(pieces)
	var seen := {}
	var outputs := surface.world_sockets()
	if kind == "flat_roof" and (surface.kind in BuildCatalogue.MITRE_KINDS or surface.kind == "arch") and hit.normal.y > 0.6:
		var surface_height := BuildCatalogue.piece_size(surface.kind,surface.span_length).y
		for end in [-1,1]:
			outputs.append(BuildCatalogue.socket(surface.transform*Vector3(end*surface.span_length/2,surface_height,0),Vector3.UP))
	for output in outputs:
		if kind in BuildCatalogue.ROOF_KINDS and surface.kind in BuildCatalogue.ROOF_KINDS and hit.normal.y > 0.6 and output.family == "stack": continue
		var roof_edge: bool = kind in BuildCatalogue.ROOF_KINDS and surface.kind in BuildCatalogue.ROOF_KINDS and hit.normal.y > 0.6 and output.family in ["roof_rake","roof_run"]
		if not socket_matches_face(output,hit.normal) and not roof_edge: continue
		if output.has("accepts") and kind not in output.accepts: continue
		var distance: float = output.position.distance_squared_to(point)
		var radius := 0.85 if surface.kind in BuildCatalogue.FOUNDATION_KINDS and output.family == "stack" else SNAP_RADIUS
		if surface.kind in BuildCatalogue.FOUNDATION_KINDS and kind in BuildCatalogue.FOUNDATION_KINDS and output.family == "floor":
			# An upper side hit on a tall podium should still find its base-aligned bay.
			radius = maxf(radius,BuildCatalogue.piece_size(surface.kind).y+0.1)
		if distance > radius*radius: continue
		for input in selected_sockets:
			if input.family == "stack" and input != bottom: continue
			if not BuildCatalogue.sockets_match(output,input,basis): continue
			var alignment: float = output.normal.dot(basis*input.normal)
			var corner: bool = output.family == "span" and BuildCatalogue.join_profile(kind) == BuildCatalogue.join_profile(surface.kind) and kind in BuildCatalogue.MITRE_KINDS and absf(alignment) < 0.001
			if not corner and alignment > -0.95: continue
			if corner:
				var end_x: float = bottom.position.x if not is_zero_approx(bottom.position.x) else -span/2
				if not is_equal_approx(input.position.x,end_x): continue
			var candidate: Vector3 = output.position-basis*input.position
			var fitted := span
			# Preserve the attached end and stop at the next matching endpoint.
			if length == 0 and kind in BuildCatalogue.MITRE_KINDS and absf(input.position.x) > 0.001:
				fitted = fitting_length(kind,candidate,basis,int(signf(input.position.x)),surface,connections,span,pieces)
				candidate += basis.x*signf(input.position.x)*(span-fitted)/2
			if corner and CornerJoints.describe(kind,Transform3D(basis,candidate),connections,0,fitted).conflict: continue
			var duplicate := false
			for other in pieces:
				if other.kind == kind and is_equal_approx(other.span_length,fitted) and other.position.distance_squared_to(candidate) < 0.0001 and absf(angle_difference(other.rotation.y,angle)) < 0.01:
					duplicate = true
					break
			if duplicate: continue
			var key := CornerJoints.point_key(candidate)+":%.2f" % fitted
			if seen.has(key): continue
			seen[key] = true
			var anchor_label := ""
			if corner or (bottoms.size() > 1 and input.family == "stack"):
				anchor_label = " · "+("centre" if input.position.is_zero_approx() else ("left end" if input.position.x < 0 else "right end"))
			var label: String = ("Mitred corner · " if corner else "Component snap · ")+BuildCatalogue.get_piece(surface.kind).name+anchor_label
			if output.family == "pediment_rake": label = "Continuous pediment slope"
			if output.family == "sculpture": label = "Sculpture recess · R turns figure"
			if output.family == "roof_rake": label = "Continuous roof pitch"
			if output.family == "roof_run": label = "Roof depth bay · 4 m"
			if output.family.begins_with("roof_gable_"): label = "Roof fits pediment profile"
			if kind in BuildCatalogue.DOME_KINDS and input.family == "stack": label = "Dome support · R turns / T cycles anchors"
			if kind == "flat_roof": label = "Flat cover · "+BuildCatalogue.cover_anchor_label(anchor)+" · T cycles anchors"
			if kind == "entablature" and surface.kind in ColumnLayout.KINDS: label = "Column-to-column beam · %.1f m · R turns / T reverses" % fitted
			if fitted < span-0.001: label += " · Fitted %s m" % String.num(fitted,2)
			result.append({"position":candidate,"length":fitted,"snapped":true,"target":surface,"socket":output.position,"label":label,"score":distance+candidate.distance_squared_to(point+hit.normal*0.15)*0.01})
	result.sort_custom(func(a: Dictionary,b: Dictionary): return a.score < b.score)
	result.append(fallback)
	return result

static func dome_on_run(kind: String, basis: Basis, surface: BuildPiece, pieces: Array) -> Dictionary:
	if absf(basis.x.dot(surface.basis.x)) < 0.999: return {}
	var size := BuildCatalogue.piece_size(kind)
	var height := BuildCatalogue.piece_size(surface.kind,surface.span_length).y
	var low := -surface.span_length/2
	var high := surface.span_length/2
	var intervals: Array[Vector2] = []
	for peer in pieces:
		if peer == surface or BuildCatalogue.join_profile(peer.kind) != BuildCatalogue.join_profile(surface.kind): continue
		if absf(peer.basis.x.dot(surface.basis.x)) < 0.999: continue
		var local: Vector3 = surface.transform.affine_inverse()*peer.position
		if absf(local.y) > 0.005 or absf(local.z) > 0.005: continue
		intervals.append(Vector2(local.x-peer.span_length/2,local.x+peer.span_length/2))
	var extended := true
	while extended:
		extended = false
		for interval in intervals:
			if interval.x > high+0.005 or interval.y < low-0.005: continue
			if interval.x < low-0.005 or interval.y > high+0.005:
				low = minf(low,interval.x)
				high = maxf(high,interval.y)
				extended = true
	if not is_equal_approx(high-low,size.x): return {}
	var edge := surface.transform*Vector3((low+high)/2,height,0)
	return {"position":edge-basis*Vector3(0,0,size.z/2),"length":BuildCatalogue.BAY,"snapped":true,"target":surface,"socket":edge,"label":"Dome fits %.0f m support run · R turns side" % size.x,"score":0.0}

static func landing_stairs(surface: BuildPiece, point: Vector3, normal: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rise := surface.global_position.y+BuildCatalogue.piece_size(surface.kind).y
	if rise < BuildCatalogue.STAIR_RISER or rise > 40: return result
	var angle := atan2(normal.x,normal.z)
	var basis := Basis(Vector3.UP,angle)
	var size := BuildCatalogue.piece_size("steps",BuildCatalogue.BAY,rise)
	for output in surface.world_sockets():
		if output.family != "floor" or output.normal.dot(normal) < 0.95: continue
		var landing: Vector3 = output.position
		landing.y = rise
		var position := landing-basis*Vector3(0,rise,-size.z/2)
		result.append({"position":position,"angle":angle,"rise":rise,"length":BuildCatalogue.BAY,"snapped":true,"target":surface,"socket":landing,"label":"Stairs fit landing · %.2f m rise · %d steps" % [rise,BuildCatalogue.stair_count(rise)],"score":Vector2(landing.x-point.x,landing.z-point.z).length_squared()})
	result.sort_custom(func(a: Dictionary,b: Dictionary): return a.score < b.score)
	return result

static func socket_matches_face(output: Dictionary, normal: Vector3) -> bool:
	# The raycast face expresses placement intent, even when another socket is closer.
	if output.family == "sculpture":
		return output.normal.dot(normal) > 0.95
	if normal.y > 0.6:
		return output.family == "stack" and output.normal.y > 0.5
	if normal.y < -0.6:
		return output.family == "stack" and output.normal.y < -0.5
	# Perpendicular span sockets still allow mitred corners along a broad side face.
	return output.family != "stack" and absf(output.normal.y) < 0.5 and output.normal.dot(normal) >= -0.001

static func fitting_length(kind: String, centre: Vector3, basis: Basis, end: int, source: BuildPiece, connections: Dictionary, maximum: float, supports: Array = []) -> float:
	var fixed := centre+basis.x*end*maximum/2
	var direction := -basis.x*end
	var length := maximum
	for entries in connections.values():
		for entry in entries:
			var peer: BuildPiece = entry.piece
			if peer == source or BuildCatalogue.join_profile(peer.kind) != BuildCatalogue.join_profile(kind): continue
			var delta: Vector3 = entry.point-fixed
			var distance := delta.dot(direction)
			if distance < BuildCatalogue.MIN_SPAN-0.001 or distance >= length-0.001: continue
			if (delta-direction*distance).length() > CornerJoints.EPSILON: continue
			if direction.dot(peer.basis.x*int(entry.end)) > 0.001: continue
			if not BuildCatalogue.valid_span(kind,distance): continue
			length = snappedf(distance,0.01)
	# Column tops are layout endpoints too: a first beam can fit a narrow bay before its neighbors exist.
	for peer in supports:
		if peer == source or (BuildCatalogue.get_piece(peer.kind).group != "Columns" and peer.kind != "pedestal"): continue
		var top: Vector3 = peer.position+Vector3.UP*BuildCatalogue.piece_size(peer.kind).y
		var delta := top-fixed
		var distance := delta.dot(direction)
		if distance < BuildCatalogue.MIN_SPAN-0.001 or distance >= length-0.001: continue
		if (delta-direction*distance).length() > CornerJoints.EPSILON: continue
		if is_equal_approx(distance,snappedf(distance,BuildCatalogue.GRID)):
			length = snappedf(distance,BuildCatalogue.GRID)
	return length

static func ceiling_infill(basis: Basis, hit: Dictionary, pieces: Array) -> Array[Dictionary]:
	var surface: BuildPiece = hit.collider as BuildPiece
	if surface == null or (surface.kind != "entablature" and surface.kind not in BuildCatalogue.PEDIMENT_KINDS and surface.kind not in BuildCatalogue.ROOF_KINDS): return []
	var result: Array[Dictionary] = []
	var seen := {}
	var occupied := {}
	var ceiling: Array[BuildPiece] = []
	for peer in pieces:
		if peer.kind == "flat_roof":
			ceiling.append(peer)
			occupied[CornerJoints.point_key(peer.position)] = true
	for peer in ceiling:
		if maxf(absf(peer.basis.x.dot(basis.x)),absf(peer.basis.x.dot(basis.z))) < 0.9999: continue
		if surface.kind == "entablature" and absf(peer.position.y-surface.position.y-0.75) > 0.005: continue
		if hit.position.y-peer.position.y < -0.15 or hit.position.y-peer.position.y > 6: continue
		var local: Vector3 = peer.transform.affine_inverse()*hit.position
		if Vector2(local.x,local.z).length() > 9: continue
		var position: Vector3 = peer.transform*Vector3(snappedf(local.x,4),0,snappedf(local.z,4))
		if surface.kind == "entablature" and absf(hit.normal.y) < 0.6 and (position-hit.position).dot(hit.normal) < -0.005: continue
		var key := CornerJoints.point_key(position)
		if occupied.has(key) or seen.has(key): continue
		seen[key] = true
		result.append({"position":position,"length":BuildCatalogue.BAY,"snapped":true,"target":surface,"socket":hit.position,"label":"Ceiling infill · follows existing panels","score":position.distance_squared_to(hit.position)})
	result.sort_custom(func(a: Dictionary,b: Dictionary): return a.score < b.score)
	return result
