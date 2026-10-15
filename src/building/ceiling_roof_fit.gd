extends RefCounted

const EPS := 0.00001

static func plane_for(frame: Transform3D, kind: String, roof_frame: Transform3D) -> Variant:
	if kind not in BuildCatalogue.ROOF_KINDS: return null
	var relative := frame.affine_inverse()*roof_frame
	if maxf(absf(relative.basis.x.x),absf(relative.basis.x.z)) < 0.9999 or absf(relative.origin.y) > 0.005: return null
	var size := BuildCatalogue.piece_size(kind)
	var left := BuildCatalogue.roof_profile(kind) in ["left","left_half"]
	var eave: Vector3 = relative*Vector3(-size.x/2 if left else size.x/2,0,0)
	var axis := 0 if absf(relative.basis.x.x) > 0.9 else 2
	var depth_axis := 2 if axis == 0 else 0
	if absf(absf(eave[axis])-2) > 0.75 or absf(relative.origin[depth_axis]) >= 4-EPS: return null
	var rise_direction := relative.basis.x*(1 if left else -1)
	if eave[axis]*rise_direction[axis] > -1.0: return null
	var normal := relative.basis*Vector3(-0.6 if left else 0.6,1,0)
	var distance := size.y/2+normal.dot(relative.origin)
	return Plane(normal.normalized(),distance/normal.length())

static func regions_for(frame: Transform3D, pieces: Array, ignore_uid: int = 0, connections: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for peer in pieces:
		if peer.uid == ignore_uid and ignore_uid != 0: continue
		var plane: Variant = plane_for(frame,peer.kind,peer.transform)
		if plane == null: continue
		var relative: Transform3D = frame.affine_inverse()*peer.transform
		var axis := 2 if absf(relative.basis.x.x) > 0.9 else 0
		var joints := {"left":peer.join_left,"right":peer.join_right} if connections.is_empty() else CornerJoints.describe(peer.kind,peer.transform,connections,peer.uid,peer.span_length)
		var a: Vector3 = relative*Vector3(0,0,-2+(0.35 if joints.left != 0 else 0.0))
		var b: Vector3 = relative*Vector3(0,0,2-(0.35 if joints.right != 0 else 0.0))
		var low := maxf(-2,minf(a[axis],b[axis]))
		var high := minf(2,maxf(a[axis],b[axis]))
		if high-low <= EPS: continue
		# Merge coplanar neighbouring bays instead of splitting every ordinary slab.
		var merged := true
		while merged:
			merged = false
			for i in range(result.size()-1,-1,-1):
				var region: Dictionary = result[i]
				if region.axis != axis or not region.plane.is_equal_approx(plane) or region.low > high+EPS or region.high < low-EPS: continue
				low = minf(low,region.low)
				high = maxf(high,region.high)
				result.remove_at(i)
				merged = true
		result.append({"plane":plane,"axis":axis,"low":low,"high":high})
	return result

static func clip(parts: Array, regions: Array[Dictionary]) -> Array:
	if regions.is_empty(): return parts
	var result: Array = []
	for part in parts:
		var size: Vector3 = part.mesh.size if part.has("mesh") else part.shape.size
		var centre: Vector3 = part.transform.origin
		var cuts := {0:[centre.x-size.x/2,centre.x+size.x/2],2:[centre.z-size.z/2,centre.z+size.z/2]}
		var relevant: Array[Dictionary] = []
		for region in regions:
			var plane: Plane = region.plane
			if plane.distance_to(centre)+plane.normal.abs().dot(size/2) <= EPS: continue
			var axis: int = region.axis
			if region.high <= cuts[axis][0]+EPS or region.low >= cuts[axis][1]-EPS: continue
			relevant.append(region)
			for edge in [region.low,region.high]:
				if edge > centre[axis]-size[axis]/2+EPS and edge < centre[axis]+size[axis]/2-EPS and not cuts[axis].any(func(value): return absf(value-edge) < EPS): cuts[axis].append(edge)
		if relevant.is_empty():
			result.append(part)
			continue
		cuts[0].sort()
		cuts[2].sort()
		for x in range(cuts[0].size()-1):
			for z in range(cuts[2].size()-1):
				var split_size := Vector3(cuts[0][x+1]-cuts[0][x],size.y,cuts[2][z+1]-cuts[2][z])
				var split_centre := Vector3((cuts[0][x+1]+cuts[0][x])/2,centre.y,(cuts[2][z+1]+cuts[2][z])/2)
				var planes: Array[Plane] = []
				for region in relevant:
					if split_centre[region.axis] > region.low-EPS and split_centre[region.axis] < region.high+EPS: planes.append(region.plane)
				var split: Dictionary = part.duplicate()
				split.transform = Transform3D(Basis.IDENTITY,split_centre)
				if split.has("mesh"):
					split.mesh = BoxMesh.new()
					split.mesh.size = split_size
				if split.has("shape"):
					split.shape = BoxShape3D.new()
					split.shape.size = split_size
				result.append_array(clip_planes([split],planes))
	return result

static func clip_planes(parts: Array, planes: Array[Plane]) -> Array:
	if planes.is_empty(): return parts
	var result: Array = []
	for part in parts:
		var size: Vector3 = part.mesh.size if part.has("mesh") else part.shape.size
		var centre: Vector3 = part.transform.origin
		var active: Array[Plane] = []
		var removed := false
		for plane in planes:
			var radius: float = plane.normal.abs().dot(size/2)
			var distance := plane.distance_to(centre)
			if distance-radius >= -EPS:
				removed = true
				break
			if distance+radius > EPS: active.append(plane)
		if removed: continue
		if active.is_empty():
			result.append(part)
			continue
		var faces: Array = []
		for axis in range(3):
			for side in [-1,1]:
				var normal := Vector3.ZERO
				normal[axis] = side
				var u := (axis+1)%3
				var v := (axis+2)%3
				var points: Array[Vector3] = []
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					var point := centre+normal*size/2
					point[u] += corner.x*size[u]/2
					point[v] += corner.y*size[v]/2
					points.append(point)
				faces.append({"points":points,"normal":normal})
		for plane in active: faces = clip_faces(faces,plane)
		var output := {"transform":Transform3D.IDENTITY}
		if part.has("mesh"):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for face in faces:
				for i in range(1,face.points.size()-1):
					ClassicalGeometry._triangle(surface,[face.points[0],face.points[i],face.points[i+1]],[face.normal,face.normal,face.normal])
			output.mesh = surface.commit()
		if part.has("shape"):
			var vertices := PackedVector3Array()
			for face in faces:
				for point in face.points: vertices.append(point)
			var shape := ConvexPolygonShape3D.new()
			shape.points = vertices
			output.shape = shape
		result.append(output)
	return result

static func clip_faces(faces: Array, plane: Plane) -> Array:
	var result: Array = []
	var cap: Array[Vector3] = []
	for face in faces:
		var clipped: Array[Vector3] = []
		var points: Array = face.points
		for i in range(points.size()):
			var a: Vector3 = points[i]
			var b: Vector3 = points[(i+1)%points.size()]
			var da := plane.distance_to(a)
			var db := plane.distance_to(b)
			if da <= EPS: append_unique(clipped,a)
			if (da < -EPS and db > EPS) or (da > EPS and db < -EPS): append_unique(clipped,a.lerp(b,da/(da-db)))
		for point in clipped:
			if absf(plane.distance_to(point)) <= EPS: append_unique(cap,point)
		if clipped.size() >= 3: result.append({"points":clipped,"normal":face.normal})
	if cap.size() >= 3:
		var centre := Vector3.ZERO
		for point in cap: centre += point
		centre /= cap.size()
		var u := plane.normal.cross(Vector3.UP).normalized()
		if u.is_zero_approx(): u = Vector3.RIGHT
		var v := plane.normal.cross(u)
		cap.sort_custom(func(a: Vector3,b: Vector3): return atan2((a-centre).dot(v),(a-centre).dot(u)) < atan2((b-centre).dot(v),(b-centre).dot(u)))
		result.append({"points":cap,"normal":plane.normal})
	return result

static func append_unique(points: Array[Vector3], point: Vector3) -> void:
	if not points.any(func(existing: Vector3): return existing.distance_squared_to(point) < EPS*EPS): points.append(point)
