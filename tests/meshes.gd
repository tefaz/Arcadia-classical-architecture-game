extends RefCounted

static func vertex_key(v: Vector3) -> String:
	return "%d:%d:%d" % [roundi(v.x*10000),roundi(v.y*10000),roundi(v.z*10000)]

static func triangles(mesh: Mesh) -> Array:
	var result: Array = []
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in range(vertices.size()): indices.append(i)
		for i in range(0,indices.size(),3):
			result.append({"v":[vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]],"n":[normals[indices[i]],normals[indices[i+1]],normals[indices[i+2]]]})
	return result

static func audit(mesh: Mesh) -> Dictionary:
	var winding := true
	var finite := true
	var degenerate := false
	var edges := {}
	var directions := {}
	var volume := 0.0
	for triangle in triangles(mesh):
		var v: Array = triangle.v
		var n: Array = triangle.n
		var cross: Vector3 = (v[1]-v[0]).cross(v[2]-v[0])
		degenerate = degenerate or cross.length_squared() < 1e-12
		winding = winding and cross.dot(n[0]+n[1]+n[2]) < 0
		volume += v[0].dot(v[1].cross(v[2]))
		for i in range(3):
			finite = finite and v[i].is_finite() and n[i].is_finite() and absf(n[i].length()-1) < 0.001
			var a := vertex_key(v[i])
			var b := vertex_key(v[(i+1)%3])
			var key := a+"|"+b if a < b else b+"|"+a
			edges[key] = edges.get(key,0)+1
			directions[key] = directions.get(key,0)+(1 if a < b else -1)
	var closed := true
	for key in edges:
		closed = closed and edges[key] == 2 and directions[key] == 0
	return {"winding":winding,"finite":finite,"degenerate":degenerate,"closed":closed,"volume":volume}

static func front_hit(parts: Array, start: Vector3, end: Vector3) -> Variant:
	var nearest: Variant = null
	var distance := INF
	for part in parts:
		if not part.has("mesh"): continue
		for triangle in triangles(part.mesh):
			var a: Vector3 = part.transform*triangle.v[0]
			var b: Vector3 = part.transform*triangle.v[1]
			var c: Vector3 = part.transform*triangle.v[2]
			var outward := -(b-a).cross(c-a)
			if outward.dot(end-start) >= 0: continue
			var hit: Variant = Geometry3D.segment_intersects_triangle(start,end,a,b,c)
			if hit != null and start.distance_squared_to(hit) < distance:
				nearest = hit
				distance = start.distance_squared_to(hit)
	return nearest

static func run(check: Callable) -> void:
	var cache := {}
	for definition in BuildCatalogue.PIECES+BuildCatalogue.LEGACY_PIECES:
		var valid_normals := true
		var valid_winding := true
		var closed := true
		var volume := true
		var clean := true
		for part in ClassicalGeometry.get_recipe(definition.id):
			if not part.has("mesh"): continue
			var mesh: Mesh = part.mesh
			if not cache.has(mesh.get_instance_id()):
				cache[mesh.get_instance_id()] = audit(mesh)
			var report: Dictionary = cache[mesh.get_instance_id()]
			valid_normals = valid_normals and report.finite
			valid_winding = valid_winding and report.winding
			closed = closed and report.closed
			volume = volume and report.volume < 0
			clean = clean and not report.degenerate
		check.call(valid_normals,definition.id+": all mesh vertices and unit normals are finite")
		check.call(valid_winding,definition.id+": every visible face has correct clockwise winding")
		check.call(closed,definition.id+": every solid surface closes with opposite edge directions")
		check.call(volume,definition.id+": closed mesh orientation points outward")
		check.call(clean,definition.id+": no degenerate triangles remain")
	for kind in BuildCatalogue.MITRE_KINDS:
		var closed := true
		for left in [-1,0,1]:
			for right in [-1,0,1]:
				for part in ClassicalGeometry.get_recipe(kind,left,right):
					if not part.has("mesh"): continue
					var mesh: Mesh = part.mesh
					if not cache.has(mesh.get_instance_id()): cache[mesh.get_instance_id()] = audit(mesh)
					var report: Dictionary = cache[mesh.get_instance_id()]
					closed = closed and report.closed and report.winding and report.volume < 0
		check.call(closed,kind+": all straight and corner variants remain closed and correctly oriented")
	var urn := ClassicalGeometry.get_recipe("urn")
	var bowl: Variant = front_hit(urn,Vector3(0.04,2,0.03),Vector3(0.04,0.3,0.03))
	check.call(bowl != null and absf(bowl.y-0.61) < 0.01,"Urn opening has a visible hollow bowl floor")
	check.call(front_hit(urn,Vector3(0,0.8,2),Vector3(0,0.8,0)) != null,"Urn exterior is visible from outside")
	var arch := ClassicalGeometry.get_recipe("arch")
	check.call(front_hit(arch,Vector3(0,2.7,0),Vector3(0,3.8,0)) != null,"Arch underside is visible from inside the doorway")
	check.call(front_hit(arch,Vector3(0,1,-2),Vector3(0,1,2)) == null,"Arch keeps its intentional open passage")
	var roof := [ClassicalGeometry.get_recipe("roof")[0]]
	check.call(front_hit(roof,Vector3(0.9,2,0.1),Vector3(0.9,0.1,0.1)) != null,"Roof slope is visible from above")
