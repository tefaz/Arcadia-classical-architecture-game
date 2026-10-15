extends RefCounted

## Map the logical gable bays onto the outer corners of their supporting beam run.
const LIP := 0.16
const EPS := 0.005

static func transform_for(kind: String, frame: Transform3D, pieces: Array, connections: Dictionary = {}) -> Transform3D:
	if kind == "finial":
		for peer in pieces:
			if peer.kind not in BuildCatalogue.RAKE_KINDS: continue
			if peer.kind != "pediment_crown": continue
			var peak: Vector3 = peer.transform*Vector3(0,1.2,0)
			if peak.distance_to(frame.origin) < EPS:
				var fitted_peak: Vector3 = peer.transform*(transform_for(peer.kind,peer.transform,pieces,connections)*Vector3(0,1.2,0))
				return Transform3D(Basis.IDENTITY,frame.basis.inverse()*(fitted_peak-peak+Vector3.UP*LIP))
		return Transform3D.IDENTITY
	if kind not in BuildCatalogue.PEDIMENT_KINDS: return Transform3D.IDENTITY
	var inverse := frame.affine_inverse()
	var supports: Array = []
	for peer in pieces:
		if peer.kind != "entablature" or absf(peer.basis.x.dot(frame.basis.x)) < 0.9999: continue
		var local: Vector3 = inverse*peer.position
		if absf(local.z) > EPS or local.y+0.75 > EPS or local.y < -25: continue
		supports.append({"piece":peer,"x":local.x,"y":local.y,"low":local.x-peer.span_length/2,"high":local.x+peer.span_length/2})
	# Start at the nearest supporting course below this module, then follow its run.
	var seed := -1
	for i in range(supports.size()):
		var entry: Dictionary = supports[i]
		if entry.low > 2+EPS or entry.high < -2-EPS: continue
		if seed < 0 or entry.y > supports[seed].y: seed = i
	if seed < 0: return Transform3D.IDENTITY
	var low: float = supports[seed].low
	var high: float = supports[seed].high
	var level: float = supports[seed].y
	var run: Array = []
	var expanded := true
	while expanded:
		expanded = false
		for entry in supports:
			if entry in run or absf(entry.y-level) > EPS or entry.low > high+EPS or entry.high < low-EPS: continue
			run.append(entry)
			low = minf(low,entry.low)
			high = maxf(high,entry.high)
			expanded = true
	if low > -2+EPS or high < 2-EPS: return Transform3D.IDENTITY
	if connections.is_empty(): connections = CornerJoints.index_pieces(pieces)
	var outside_low := low
	var outside_high := high
	for entry in run:
		var peer: BuildPiece = entry.piece
		var joints := CornerJoints.describe(peer.kind,peer.transform,connections,peer.uid,peer.span_length)
		for part in ClassicalGeometry.get_recipe(peer.kind,int(joints.left),int(joints.right),peer.span_length):
			if not part.has("mesh"): continue
			var bounds: AABB = inverse*peer.transform*part.transform*part.mesh.get_aabb()
			outside_low = minf(outside_low,bounds.position.x)
			outside_high = maxf(outside_high,bounds.end.x)
	var scale_x := (outside_high-outside_low)/(high-low)
	var offset := outside_low-low*scale_x
	return Transform3D(Basis.from_scale(Vector3(scale_x,1,1)),Vector3(offset,0,0))

static func recipe(kind: String, frame: Transform3D, pieces: Array, original: Array, connections: Dictionary = {}) -> Array:
	return apply(original,transform_for(kind,frame,pieces,connections))

static func apply(original: Array, fitting: Transform3D) -> Array:
	if fitting.is_equal_approx(Transform3D.IDENTITY): return original
	var result: Array = []
	for part in original:
		var fitted: Dictionary = part.duplicate()
		fitted.transform = fitting*part.transform
		if part.has("shape") and not fitting.basis.is_equal_approx(Basis.IDENTITY):
			# Bake the horizontal fit into colliders instead of nonuniform node scaling.
			var collider: Dictionary = fitted.duplicate()
			collider.erase("mesh")
			collider.shape = part.shape.duplicate()
			if collider.shape is BoxShape3D:
				collider.shape.size.x *= fitting.basis.x.x
			elif collider.shape is ConvexPolygonShape3D:
				var points: PackedVector3Array = collider.shape.points
				for i in range(points.size()): points[i].x *= fitting.basis.x.x
				collider.shape.points = points
			collider.transform = Transform3D(part.transform.basis,fitted.transform.origin)
			result.append(collider)
			fitted.erase("shape")
		if fitted.has("mesh") or fitted.has("shape"): result.append(fitted)
	return result
