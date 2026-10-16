class_name ColumnLayout
extends RefCounted

## Column centres share the standard beam bay, in the supporting platform's frame.
const KINDS := ["doric_column","ionic_column","corinthian_column"]
const GUIDE_RADIUS := 12.0

static func rect_of(piece: BuildPiece, frame: Transform3D) -> Rect2:
	var size := BuildCatalogue.piece_size(piece.kind)
	var rect := piece.cover_rect
	var bounds := (frame.affine_inverse()*piece.transform)*AABB(Vector3(rect.position.x,0,rect.position.y),Vector3(rect.size.x,size.y,rect.size.y))
	return Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))

static func on_platform(point: Vector3, rectangles: Array[Rect2], frame: Transform3D) -> bool:
	var local := frame.affine_inverse()*point
	for rect in rectangles:
		if rect.grow(0.005).has_point(Vector2(local.x,local.z)): return true
	return false

static func platform(surface: BuildPiece, pieces: Array) -> Array[Rect2]:
	var frame := surface.transform
	var top := surface.position.y+BuildCatalogue.piece_size(surface.kind).y
	var pending: Array[Rect2] = []
	for piece in pieces:
		if piece == surface or piece.kind not in BuildCatalogue.FOUNDATION_KINDS: continue
		if absf(piece.position.y+BuildCatalogue.piece_size(piece.kind).y-top) > 0.005: continue
		# Foundations in this layout can be quarter-turned, but not skewed.
		var alignment := absf(frame.basis.x.dot(piece.basis.x))
		if alignment > 0.001 and alignment < 0.999: continue
		if piece.position.distance_to(surface.position) > GUIDE_RADIUS*2: continue
		pending.append(rect_of(piece,frame))
	var connected: Array[Rect2] = [rect_of(surface,frame)]
	var index := 0
	while index < connected.size():
		var current := connected[index]
		for i in range(pending.size()-1,-1,-1):
			var other := pending[i]
			var overlap := current.end.min(other.end)-current.position.max(other.position)
			if overlap.x >= -0.005 and overlap.y >= -0.005 and maxf(overlap.x,overlap.y) > 0.005:
				connected.append(other)
				pending.remove_at(i)
		index += 1
	return connected

static func solve(kind: String, hit: Dictionary, pieces: Array) -> Dictionary:
	var surface := hit.collider as BuildPiece
	if kind not in KINDS or surface == null or surface.kind not in BuildCatalogue.FOUNDATION_KINDS or hit.normal.y < 0.95: return {}
	var frame := surface.transform
	var size := BuildCatalogue.piece_size(surface.kind)
	var top := surface.position.y+size.y
	var rectangles := platform(surface,pieces)
	var origin := frame*Vector3(-size.x/2+2 if size.x >= 4 else 0,size.y,-size.z/2+2 if size.z >= 4 else 0)
	var nearest := INF
	for piece in pieces:
		if piece.kind not in KINDS or absf(piece.position.y-top) > 0.005: continue
		if not is_equal_approx(BuildCatalogue.piece_size(piece.kind).y,BuildCatalogue.piece_size(kind).y): continue
		if not on_platform(piece.position,rectangles,frame): continue
		var distance: float = piece.position.distance_squared_to(hit.position)
		if distance < nearest:
			nearest = distance
			origin = piece.position
	var local: Vector3 = frame.basis.inverse()*(hit.position-origin)
	var x := roundi(local.x/BuildCatalogue.BAY)
	var z := roundi(local.z/BuildCatalogue.BAY)
	var source_rect := rect_of(surface,frame).grow(0.005)
	var candidate := Vector3.ZERO
	var best := INF
	# Keep snapping on the aimed foundation, including an offset legacy layout.
	for ix in range(x-1,x+2):
		for iz in range(z-1,z+2):
			var point := origin+frame.basis*Vector3(ix*BuildCatalogue.BAY,0,iz*BuildCatalogue.BAY)
			var in_frame: Vector3 = frame.affine_inverse()*point
			if not source_rect.has_point(Vector2(in_frame.x,in_frame.z)): continue
			var distance: float = point.distance_squared_to(hit.position)
			if distance < best:
				best = distance
				candidate = point
	if is_inf(best): return {}
	var guides: Array[Vector3] = []
	for ix in range(x-3,x+4):
		for iz in range(z-3,z+4):
			var point := origin+frame.basis*Vector3(ix*BuildCatalogue.BAY,0,iz*BuildCatalogue.BAY)
			if on_platform(point,rectangles,frame): guides.append(point)
	var lines: Array[Vector3] = []
	for point in guides:
		for direction in [frame.basis.x,frame.basis.z]:
			var other: Vector3 = point+direction*BuildCatalogue.BAY
			if not on_platform((point+other)/2,rectangles,frame): continue
			if guides.any(func(peer): return peer.is_equal_approx(other)):
				lines.append_array([point,other])
	return {"position":candidate,"length":BuildCatalogue.BAY,"snapped":true,"target":surface,"socket":candidate,"label":"Column layout · 4 m centres","score":0.0,"guide_points":guides,"guide_lines":lines,"guide_basis":frame.basis}
