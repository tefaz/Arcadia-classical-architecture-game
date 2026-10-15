extends RefCounted

const MAX_COPIES := 32
const MAX_PREVIEW_PIECES := 256
static var spans: Dictionary = {}

static func span(kind: String, length: float = BuildCatalogue.BAY, stair_rise: float = BuildCatalogue.STAIR_RISE) -> Vector3:
	var key := "%s:%.2f:%.5f" % [kind,length,stair_rise]
	if spans.has(key): return spans[key]
	var logical := BuildCatalogue.piece_size(kind,length,stair_rise)
	var bounds := AABB()
	var initialized := false
	for part in ClassicalGeometry.get_recipe(kind,0,0,length,stair_rise):
		if not part.has("mesh"): continue
		var extent: AABB = part.transform*part.mesh.get_aabb()
		bounds = bounds.merge(extent) if initialized else extent
		initialized = true
	var size := logical.max(bounds.size)
	if kind in BuildCatalogue.FOUNDATION_KINDS:
		size = logical
	elif kind in BuildCatalogue.MITRE_KINDS:
		size.x = logical.x # Preserve the four-metre centre-line bays.
	elif kind == "roof" or kind in BuildCatalogue.ROOF_KINDS:
		size.x = logical.x
		size.z = logical.z
	spans[key] = size
	return size

static func step(kind: String, basis: Basis, look_direction: Vector3, length: float = BuildCatalogue.BAY, stair_rise: float = BuildCatalogue.STAIR_RISE) -> Vector3:
	return step_size(span(kind,length,stair_rise),basis,look_direction)

static func step_size(size: Vector3, basis: Basis, look_direction: Vector3) -> Vector3:
	var local := basis.inverse()*look_direction
	var axis := Vector3.ZERO
	if absf(local.y) > maxf(absf(local.x),absf(local.z)):
		axis.y = signf(local.y)
	elif absf(local.x) >= absf(local.z):
		axis.x = signf(local.x)
	else:
		axis.z = signf(local.z)
	return basis*(axis*size)

static func module_bounds(piece: BuildPiece, frame: Transform3D) -> AABB:
	var size := BuildCatalogue.piece_size(piece.kind,piece.span_length,piece.stair_rise)
	return (frame.affine_inverse()*piece.transform)*AABB(Vector3(-size.x/2,0,-size.z/2),size)

static func selection_bounds(first: BuildPiece, last: BuildPiece) -> AABB:
	return module_bounds(first,first.transform).merge(module_bounds(last,first.transform))

static func select_between(first: BuildPiece, last: BuildPiece, pieces: Array) -> Array[BuildPiece]:
	# Clicking one component twice selects only it, even when another piece's
	# centre lies exactly on its boundary (for example a gable at a roof end).
	if first == last: return [first]
	var bounds := selection_bounds(first,last).grow(0.005)
	var inverse := first.transform.affine_inverse()
	var selected: Array[BuildPiece] = []
	# Keep the first endpoint first so that it remains the frame for repeat directions.
	selected.append(first)
	for piece in pieces:
		if piece == first: continue
		var centre: Vector3 = inverse*(piece.transform*Vector3(0,BuildCatalogue.piece_size(piece.kind,piece.span_length,piece.stair_rise).y/2,0))
		if piece == last or bounds.has_point(centre): selected.append(piece)
	return selected

static func group_bounds(selected: Array[BuildPiece]) -> AABB:
	var frame := selected[0].transform
	var inverse := frame.affine_inverse()
	var bounds := module_bounds(selected[0],frame)
	for piece in selected:
		bounds = bounds.merge(module_bounds(piece,frame))
		bounds = bounds.merge((inverse*piece.transform)*piece.visual_bounds)
	return bounds
