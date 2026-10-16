extends RefCounted

## Keep logical four-metre bays; cut only the slab where an edge meets a gable.
const GABLES := ["pediment","pediment_left","pediment_right","pediment_crown","pediment_backing","pediment_base"]
const EPS := 0.0001
static var recipes: Dictionary = {}

static var bounds_cache: Dictionary = {}

static func local_bounds(kind: String) -> AABB:
	if bounds_cache.has(kind): return bounds_cache[kind]
	var bounds := AABB()
	var started := false
	for part in ClassicalGeometry.get_recipe(kind):
		if not part.has("mesh"): continue
		var box: AABB = part.transform*part.mesh.get_aabb()
		bounds = bounds.merge(box) if started else box
		started = true
	bounds_cache[kind] = bounds
	return bounds

static func cut_for(frame: Transform3D, gable_kind: String, gable_frame: Transform3D, pieces: Array = [], fitted: Variant = null) -> Rect2:
	if gable_kind not in GABLES: return Rect2()
	var relative := frame.affine_inverse()*gable_frame
	# Reject unrelated planes before inspecting geometry or following supporting beams.
	if maxf(absf(relative.basis.x.x),absf(relative.basis.x.z)) < 0.9999: return Rect2()
	var normal := Vector2(relative.basis.z.x,relative.basis.z.z).abs()
	var centre := Vector2(relative.origin.x,relative.origin.z)
	var axis := 0 if normal.x > 0.9 else 1
	if absf(absf(centre[axis])-2.0) > 0.75: return Rect2()
	var original := local_bounds(gable_kind)
	if relative.origin.y+original.end.y <= EPS or relative.origin.y+original.position.y >= 0.2-EPS: return Rect2()
	# Committed pieces already know their fit. Planned gables calculate it only when needed.
	var fitting: Transform3D = fitted if fitted != null else preload("res://src/building/pediment_fit.gd").transform_for(gable_kind,gable_frame,pieces)
	var bounds: AABB = (relative*fitting)*original
	var cut := Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
	# Cut through to the outside edge, avoiding a detached sliver in the front recess.
	var far_edge := cut.end
	if centre[axis] > 0:
		far_edge[axis] = maxf(far_edge[axis],2.0)
	else:
		cut.position[axis] = minf(cut.position[axis],-2.0)
	cut.end = far_edge
	var overlap := cut.intersection(Rect2(-2,-2,4,4))
	if not overlap.has_area(): return Rect2()
	return cut

static func rectangles(frame: Transform3D, pieces: Array, ignore_uid: int = 0, refit: bool = false) -> Array[Rect2]:
	var result: Array[Rect2] = [preload("res://src/building/wall_cover.gd").rectangle("flat_roof",frame,pieces)]
	for peer in pieces:
		if peer.uid == ignore_uid and ignore_uid != 0: continue
		var cut := cut_for(frame,peer.kind,peer.transform,pieces,null if refit else peer.pediment_fit)
		if not cut.has_area(): continue
		var remaining: Array[Rect2] = []
		for rect in result:
			var overlap := rect.intersection(cut)
			if not overlap.has_area():
				remaining.append(rect)
				continue
			# Disjoint strips preserve the rest of partially covered edge bays.
			for strip in [Rect2(rect.position,Vector2(overlap.position.x-rect.position.x,rect.size.y)),Rect2(Vector2(overlap.end.x,rect.position.y),Vector2(rect.end.x-overlap.end.x,rect.size.y)),Rect2(Vector2(overlap.position.x,rect.position.y),Vector2(overlap.size.x,overlap.position.y-rect.position.y)),Rect2(Vector2(overlap.position.x,overlap.end.y),Vector2(overlap.size.x,rect.end.y-overlap.end.y))]:
				if strip.size.x > EPS and strip.size.y > EPS: remaining.append(strip)
		result = remaining
	return result

static func key(rects: Array[Rect2]) -> String:
	var result := ""
	for rect in rects:
		result += "%.4f,%.4f,%.4f,%.4f;" % [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	return result

static func recipe(rects: Array[Rect2], regions: Array[Dictionary] = []) -> Array:
	var signature := key(rects)
	for region in regions: signature += "r:%.5f,%.5f,%.5f,%.5f,%d,%.5f,%.5f;" % [region.plane.normal.x,region.plane.normal.y,region.plane.normal.z,region.plane.d,region.axis,region.low,region.high]
	if recipes.has(signature): return recipes[signature]
	var parts: Array = []
	for rect in rects:
		var centre := rect.get_center()
		ClassicalGeometry.box(parts,Vector3(rect.size.x,0.18,rect.size.y),Vector3(centre.x,0.09,centre.y),false)
		var slab := BoxShape3D.new()
		slab.size = Vector3(rect.size.x,0.2,rect.size.y)
		parts.append({"shape":slab,"transform":Transform3D(Basis.IDENTITY,Vector3(centre.x,0.1,centre.y))})
		for x in range(floori((rect.position.x+2)/2),ceili((rect.end.x+2)/2)):
			for z in range(floori((rect.position.y+2)/2),ceili((rect.end.y+2)/2)):
				var tile := rect.intersection(Rect2(Vector2(x*2-1.992,z*2-1.992),Vector2.ONE*1.984))
				if tile.size.x <= EPS or tile.size.y <= EPS: continue
				ClassicalGeometry.box(parts,Vector3(tile.size.x,0.02,tile.size.y),Vector3(tile.get_center().x,0.19,tile.get_center().y),false)
	parts = preload("res://src/building/ceiling_roof_fit.gd").clip(parts,regions)
	# Free placement can produce many distinct cuts; bound the shared preview cache.
	if recipes.size() >= 128: recipes.erase(recipes.keys()[0])
	recipes[signature] = parts
	return parts
