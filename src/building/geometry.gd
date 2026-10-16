class_name ClassicalGeometry
extends RefCounted

## Geometry recipes cache shared meshes. Gameplay only knows catalogue IDs and sockets.
static var recipes: Dictionary = {}
static var joined_recipes: Dictionary = {}
static var materials: Array[Material] = []
static var tile_material: StandardMaterial3D
static var ghost_material: StandardMaterial3D
static var blocked_material: StandardMaterial3D

static func setup_materials() -> void:
	if not materials.is_empty():
		return
	for i in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://src/building/stone.gdshader")
		mat.set_shader_parameter("stone_color", BuildCatalogue.MATERIAL_COLORS[i])
		mat.set_shader_parameter("marble", 1.0 if i == 1 else 0.0)
		materials.append(mat)
	tile_material = StandardMaterial3D.new()
	tile_material.albedo_color = Color("a95435")
	tile_material.roughness = 0.9
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.albedo_color = Color(0.38, 0.88, 0.79, 0.38)
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blocked_material = ghost_material.duplicate()
	blocked_material.albedo_color = Color(1.0, 0.39, 0.30, 0.4)

static func create(id: String, stone: int = 0, preview: bool = false, length: float = BuildCatalogue.BAY, stair_rise: float = BuildCatalogue.STAIR_RISE) -> BuildPiece:
	setup_materials()
	var root := BuildPiece.new()
	root.kind = id
	root.stone = stone
	root.span_length = length
	root.stair_rise = stair_rise
	var size := BuildCatalogue.piece_size(id,length,stair_rise)
	root.cover_rect = Rect2(Vector2(-size.x/2,-size.z/2),Vector2(size.x,size.z))
	root.collision_layer = 0 if preview else 2
	root.collision_mask = 0
	configure(root,0,0,preview)
	return root

static func configure(root: BuildPiece, left: int, right: int, preview: bool = false) -> void:
	root.join_left = left
	root.join_right = right
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var bounds_set := false
	var parts := preload("res://src/building/ceiling_fit.gd").recipe(root.ceiling_rects,root.ceiling_regions) if root.kind == "flat_roof" else get_recipe(root.kind,left,right,root.span_length,root.stair_rise)
	if root.kind in BuildCatalogue.FOUNDATION_KINDS:
		parts = preload("res://src/building/wall_cover.gd").foundation_recipe(root.kind,root.cover_rect)
	parts = preload("res://src/building/pediment_fit.gd").apply(parts,root.pediment_fit)
	for part in parts:
		if part.has("mesh"):
			var instance := MeshInstance3D.new()
			instance.mesh = part.mesh
			instance.transform = part.transform
			instance.material_override = ghost_material if preview else (tile_material if part.get("tile", false) else materials[root.stone])
			if preview:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(instance)
			var bounds: AABB = part.transform * instance.mesh.get_aabb()
			root.visual_bounds = root.visual_bounds.merge(bounds) if bounds_set else bounds
			bounds_set = true
		if part.has("shape") and not preview:
			var collider := CollisionShape3D.new()
			collider.shape = part.shape
			collider.transform = part.transform
			root.add_child(collider)

static func get_recipe(id: String, left: int = 0, right: int = 0, length: float = BuildCatalogue.BAY, stair_rise: float = BuildCatalogue.STAIR_RISE) -> Array:
	if id not in BuildCatalogue.MITRE_KINDS: length = BuildCatalogue.BAY
	var recipe_key := id if is_equal_approx(length,BuildCatalogue.BAY) else "%s:%.2f" % [id,length]
	if id == "steps": recipe_key = "steps:%.5f" % stair_rise
	if not recipes.has(recipe_key):
		recipes[recipe_key] = recipe(id,length,stair_rise)
	if (left == 0 and right == 0) or (id not in BuildCatalogue.MITRE_KINDS and id not in BuildCatalogue.RAKE_KINDS and id not in BuildCatalogue.ROOF_KINDS):
		return recipes[recipe_key]
	var key := "%s:%d:%d" % [recipe_key,left,right]
	if not joined_recipes.has(key):
		if id in BuildCatalogue.ROOF_KINDS:
			joined_recipes[key] = preload("res://src/building/roof_geometry.gd").recipe(id,left != 0,right != 0)
		elif id in BuildCatalogue.RAKE_KINDS:
			var parts: Array = []
			modular_pediment(parts,id,left != 0,right != 0)
			joined_recipes[key] = parts
		else:
			joined_recipes[key] = _mitre_recipe(id,recipes[recipe_key],left,right,length)
	return joined_recipes[key]

static func _clip_footprint(points: PackedVector2Array, normal: Vector2, distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var da := normal.dot(a)-distance
		var db := normal.dot(b)-distance
		if da <= 0.00001:
			result.append(a)
		if (da < -0.00001 and db > 0.00001) or (da > 0.00001 and db < -0.00001):
			result.append(a.lerp(b,da/(da-db)))
	return result

static func _prism(points: PackedVector2Array, low: float, high: float) -> Dictionary:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	var vertices := PackedVector3Array()
	for p in points:
		vertices.append(Vector3(p.x,low,p.y))
		vertices.append(Vector3(p.x,high,p.y))
	for top in [false,true]:
		for i in range(0,indices.size(),3):
			for k in ([0,1,2] if top else [2,1,0]):
				var p := points[indices[i+k]]
				surface.set_normal(Vector3.UP if top else Vector3.DOWN)
				surface.add_vertex(Vector3(p.x,high if top else low,p.y))
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()
		for v in [Vector3(a.x,low,a.y),Vector3(b.x,high,b.y),Vector3(a.x,high,a.y),Vector3(a.x,low,a.y),Vector3(b.x,low,b.y),Vector3(b.x,high,b.y)]:
			surface.set_normal(normal)
			surface.add_vertex(v)
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	return {"mesh":surface.commit(),"shape":shape,"transform":Transform3D.IDENTITY}

static func _mitre_recipe(id: String, original: Array, left: int, right: int, length: float = BuildCatalogue.BAY) -> Array:
	var result: Array = []
	var parts: Array = original.duplicate()
	# Continue the dentil rhythm along the extended outside of the mouldings.
	if id in ["entablature","cornice"]:
		for sign_value in [-1,1]:
			if (left if sign_value < 0 else right) == 0:
				continue
			for step in range(3):
				var x: float = sign_value * (length/2+0.115+step*0.235)
				if id == "entablature":
					for z in [-0.55,0.55]:
						box(parts,Vector3(0.1,0.11,0.15),Vector3(x,0.455,z),false)
				else:
					box(parts,Vector3(0.11,0.1,0.75),Vector3(x,0.15,0),false)
	for part in parts:
		# Window rake mouldings are rotated boxes inside the wall bay. Their
		# transform must survive; baking them as axis-aligned prisms makes
		# the two diagonal mouldings turn into vertical strips at corners.
		if not part.transform.basis.is_equal_approx(Basis.IDENTITY):
			result.append(part)
			continue
		var box_mesh: BoxMesh = part.get("mesh") as BoxMesh
		var box_shape: BoxShape3D = part.get("shape") as BoxShape3D
		if not box_mesh and not box_shape:
			result.append(part)
			continue
		var size: Vector3 = box_mesh.size if box_mesh else box_shape.size
		var pos: Vector3 = part.transform.origin
		var min_x := pos.x-size.x/2
		var max_x := pos.x+size.x/2
		# Replace paired balustrade end posts with two halves of one square corner post.
		if id == "balustrade" and is_equal_approx(size.y,0.85) and size.x < 0.5:
			var end := -1 if pos.x < 0 else 1
			if (left if end < 0 else right) != 0:
				pos.x = end*length/2
				size.x = size.z
				min_x = pos.x-size.x/2
				max_x = pos.x+size.x/2
		else:
			var extension := absf(pos.z)+size.z/2
			if left != 0 and min_x <= -length/2+0.03:
				min_x = minf(min_x,-length/2-extension)
			if right != 0 and max_x >= length/2-0.03:
				max_x = maxf(max_x,length/2+extension)
		var points := PackedVector2Array([Vector2(min_x,pos.z-size.z/2),Vector2(max_x,pos.z-size.z/2),Vector2(max_x,pos.z+size.z/2),Vector2(min_x,pos.z+size.z/2)])
		if left != 0:
			points = _clip_footprint(points,Vector2(-1,left),length/2)
		if right != 0:
			points = _clip_footprint(points,Vector2(1,right),length/2)
		if points.size() < 3:
			continue
		var baked := _prism(points,pos.y-size.y/2,pos.y+size.y/2)
		if not box_mesh:
			baked.erase("mesh")
		if not box_shape:
			baked.erase("shape")
		result.append(baked)
	return result

static func set_preview_valid(root: Node3D, valid: bool) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			child.material_override = ghost_material if valid else blocked_material

static func box(parts: Array, size: Vector3, pos: Vector3, collision: bool = true, tile: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := {"mesh": mesh, "transform": Transform3D(Basis.IDENTITY, pos), "tile": tile}
	if collision:
		var shape := BoxShape3D.new()
		shape.size = size
		part.shape = shape
	parts.append(part)

static func cylinder(parts: Array, bottom: float, top: float, height: float, pos: Vector3, collision: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 32
	var part := {"mesh": mesh, "transform": Transform3D(Basis.IDENTITY, pos)}
	if collision:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(bottom, top)
		shape.height = height
		part.shape = shape
	parts.append(part)

static func beam(parts: Array, start: Vector3, end: Vector3, width: float, depth: float, tile: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, start.distance_to(end), depth)
	var direction := (end - start).normalized()
	var axis := Vector3.UP.cross(direction)
	var basis := Basis.IDENTITY
	if axis.length() > 0.001:
		basis = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1, 1)))
	parts.append({"mesh": mesh, "transform": Transform3D(basis, (start + end) / 2), "tile": tile})

static func _triangle(surface: SurfaceTool, vertices: Array, normals: Array) -> void:
	var cross: Vector3 = (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])
	if cross.length_squared() < 1e-12:
		return
	# Godot front faces are clockwise: their geometric cross points opposite the normal.
	var order := [0,2,1] if cross.dot(normals[0]+normals[1]+normals[2]) > 0 else [0,1,2]
	for i in order:
		surface.set_normal(normals[i])
		surface.add_vertex(vertices[i])

static func _flute_factor(angle: float, fluted: bool) -> float:
	return 1.0-0.0325*(1.0+cos(angle*24)) if fluted else 1.0

static func _lathe_vertex(point: Vector2, angle: float, fluted: bool) -> Vector3:
	var radius := point.x*_flute_factor(angle,fluted)
	return Vector3(cos(angle)*radius,point.y,sin(angle)*radius)

static func _lathe_normal(delta: Vector2, angle: float, fluted: bool) -> Vector3:
	var factor := _flute_factor(angle,fluted)
	var derivative := 0.78*sin(angle*24) if fluted else 0.0
	var radial := Vector3(cos(angle),0,sin(angle))
	var tangent := Vector3(-sin(angle),0,cos(angle))
	# This also gives correct inward normals for a descending bowl interior.
	return (delta.y*(radial*factor-tangent*derivative)+Vector3.UP*(-delta.x*factor*factor)).normalized()

static func lathe(parts: Array, profile: Array, pos: Vector3 = Vector3.ZERO, fluted: bool = false, segments: int = 40) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		var a: Vector2 = profile[ring]
		var b: Vector2 = profile[ring + 1]
		for j in range(segments):
			var t0 := TAU * float(j) / segments
			var t1 := TAU * float(j + 1) / segments
			var v0 := _lathe_vertex(a,t0,fluted)
			var v1 := _lathe_vertex(b,t0,fluted)
			var v2 := _lathe_vertex(b,t1,fluted)
			var v3 := _lathe_vertex(a,t1,fluted)
			var n0 := _lathe_normal(b-a,t0,fluted)
			var n1 := _lathe_normal(b-a,t1,fluted)
			_triangle(surface,[v0,v1,v2],[n0,n0,n1])
			_triangle(surface,[v0,v2,v3],[n0,n1,n1])
	for end in [0,profile.size()-1]:
		var point: Vector2 = profile[end]
		if point.x <= 0:
			continue
		var normal := Vector3.DOWN if end == 0 else Vector3.UP
		for j in range(segments):
			_triangle(surface,[Vector3(0,point.y,0),_lathe_vertex(point,TAU*j/segments,fluted),_lathe_vertex(point,TAU*(j+1)/segments,fluted)],[normal,normal,normal])
	parts.append({"mesh": surface.commit(), "transform": Transform3D(Basis.IDENTITY, pos)})

static func polygon(parts: Array, points: PackedVector2Array, depth: float, pos: Vector3, tile: bool = false, collision: bool = false) -> void:
	points = points.duplicate()
	var area := 0.0
	for i in range(points.size()):
		area += points[i].cross(points[(i+1)%points.size()])
	if area < 0:
		points.reverse()
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for front in [-1.0, 1.0]:
		for t in range(0, indices.size(), 3):
			var face: Array = []
			for k in range(3):
				var p: Vector2 = points[indices[t + k]]
				face.append(Vector3(p.x,p.y,front*depth/2))
			var normal := Vector3(0,0,front)
			_triangle(mesh,face,[normal,normal,normal])
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var normal := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		var v0 := Vector3(a.x,a.y,-depth/2)
		var v1 := Vector3(b.x,b.y,-depth/2)
		var v2 := Vector3(b.x,b.y,depth/2)
		var v3 := Vector3(a.x,a.y,depth/2)
		_triangle(mesh,[v0,v1,v2],[normal,normal,normal])
		_triangle(mesh,[v0,v2,v3],[normal,normal,normal])
	var part := {"mesh": mesh.commit(), "transform": Transform3D(Basis.IDENTITY, pos), "tile": tile}
	if collision:
		var shape := ConvexPolygonShape3D.new()
		var vertices := PackedVector3Array()
		for p in points:
			vertices.append(Vector3(p.x, p.y, -depth / 2))
			vertices.append(Vector3(p.x, p.y, depth / 2))
		shape.points = vertices
		part.shape = shape
	parts.append(part)

static func base(parts: Array, y: float = 0) -> void:
	box(parts, Vector3(1.4, 0.16, 1.4), Vector3(0, y + 0.08, 0))
	lathe(parts, [Vector2(0.0, 0.16), Vector2(0.59, 0.16), Vector2(0.62, 0.21), Vector2(0.58, 0.28), Vector2(0.48, 0.30), Vector2(0.46, 0.36), Vector2(0.53, 0.39), Vector2(0.53, 0.45), Vector2(0.44, 0.5)], Vector3(0, y, 0))
	cylinder(parts, 0.58, 0.45, 0.34, Vector3(0, y + 0.33, 0), true)

static func shaft(parts: Array, y: float = 0) -> void:
	lathe(parts, [Vector2(0.44, 0), Vector2(0.455, 0.12), Vector2(0.455, 0.7), Vector2(0.43, 1.7), Vector2(0.395, 2.85), Vector2(0.4, 3)], Vector3(0, y, 0), true, 192)
	var shape := CylinderShape3D.new()
	shape.radius = 0.44
	shape.height = 3
	parts.append({"shape": shape, "transform": Transform3D(Basis.IDENTITY, Vector3(0, y + 1.5, 0))})

static func capital(parts: Array, style: String, y: float = 0) -> void:
	if style == "corinthian":
		preload("res://src/building/corinthian_geometry.gd").append_to(parts,y)
		return
	preload("res://src/building/classical_capitals.gd").append_to(parts,style,y)

static func pediment_rake(parts: Array, a: Vector2, b: Vector2, continued: bool = false) -> void:
	# Vertical-cut ends meet exactly when modules continue four metres along and 2.4 up.
	var slope := (b.y-a.y)/(b.x-a.x)
	for layer in [{"drop":0.0,"height":0.12,"depth":0.7},{"drop":0.12,"height":0.08,"depth":0.54}]:
		var points := PackedVector2Array([Vector2(a.x,a.y-layer.drop-layer.height),Vector2(b.x,b.y-layer.drop-layer.height),Vector2(b.x,b.y-layer.drop),Vector2(a.x,a.y-layer.drop)])
		var clipped := _clip_footprint(points,Vector2(0,-1),0)
		polygon(parts,clipped,layer.depth,Vector3.ZERO,false,true)
		if continued:
			# Restore the small moulding wedge at internal seams. It is trim,
			# like the dentils: backing blocks beneath it retain their solid volume.
			var completion := _clip_footprint(points,Vector2(0,1),0)
			if completion.size() >= 3: polygon(parts,completion,layer.depth,Vector3.ZERO,false,false)
	var lip := preload("res://src/building/pediment_fit.gd").LIP
	polygon(parts,PackedVector2Array([a,b,b+Vector2(0,lip),a+Vector2(0,lip)]),0.7,Vector3.ZERO,false,false)
	var count := maxi(1,roundi((b.x-a.x)/0.25))
	for i in range(count):
		var x := lerpf(a.x,b.x,(i+0.5)/count)
		var y := a.y+(x-a.x)*slope-0.25
		if y > 0.07 or continued:
			box(parts,Vector3(0.10,0.10,0.46),Vector3(x,y,0),false)

static func modular_pediment(parts: Array, id: String, left_joined: bool = false, right_joined: bool = false) -> void:
	if id == "pediment_base":
		box(parts,Vector3(4,0.08,0.56),Vector3(0,0.04,0))
		box(parts,Vector3(4,0.06,0.64),Vector3(0,0.11,0))
		box(parts,Vector3(4,0.04,0.7),Vector3(0,0.16,0))
		return
	if id == "pediment_backing":
		box(parts,Vector3(4,2.4,0.16),Vector3(0,1.2,-0.23))
		return
	var points := PackedVector2Array([Vector2(-2,0),Vector2(2,0)])
	if id == "pediment_crown":
		points.append(Vector2(0,1.2))
		pediment_rake(parts,Vector2(-2,0),Vector2(0,1.2),left_joined)
		pediment_rake(parts,Vector2(0,1.2),Vector2(2,0),right_joined)
	elif id == "pediment_left":
		points.append(Vector2(2,2.4))
		pediment_rake(parts,Vector2(-2,0),Vector2(2,2.4),left_joined)
	else:
		points.append(Vector2(-2,2.4))
		pediment_rake(parts,Vector2(-2,2.4),Vector2(2,0),right_joined)
	polygon(parts,points,0.16,Vector3(0,0,-0.23),false,true)

static func recipe(id: String, length: float = BuildCatalogue.BAY, stair_rise: float = BuildCatalogue.STAIR_RISE) -> Array:
	var p: Array = []
	if id in BuildCatalogue.WINDOW_KINDS:
		return preload("res://src/building/window_geometry.gd").recipe(id,length)
	if id in BuildCatalogue.DOOR_KINDS:
		return preload("res://src/building/door_geometry.gd").recipe(length)
	if id in BuildCatalogue.DOME_KINDS:
		return preload("res://src/building/dome_geometry.gd").recipe(id)
	if id in BuildCatalogue.ROOF_KINDS:
		return preload("res://src/building/roof_geometry.gd").recipe(id)
	if id in BuildCatalogue.PEDIMENT_KINDS:
		modular_pediment(p,id)
		return p
	if id in BuildCatalogue.STATUE_KINDS:
		return preload("res://src/building/sculpture_geometry.gd").recipe(id)
	if id in BuildCatalogue.FOUNDATION_KINDS:
		return preload("res://src/building/foundation_geometry.gd").recipe(id)
	match id:
		"flat_roof":
			box(p,Vector3(4,0.18,4),Vector3(0,0.09,0),false)
			var slab := BoxShape3D.new()
			slab.size = Vector3(4,0.2,4)
			p.append({"shape":slab,"transform":Transform3D(Basis.IDENTITY,Vector3(0,0.1,0))})
			# Keep the underside and outer edges flush; only the upper joints recess.
			for x in [-1,1]:
				for z in [-1,1]:
					box(p,Vector3(1.984,0.02,1.984),Vector3(x,0.19,z),false)
		"steps":
			var count := BuildCatalogue.stair_count(stair_rise)
			var run := count*BuildCatalogue.STAIR_TREAD
			for j in range(count):
				var height := stair_rise*(j+1)/count
				box(p,Vector3(4,height,BuildCatalogue.STAIR_TREAD),Vector3(0,height/2,run/2-(j+0.5)*BuildCatalogue.STAIR_TREAD))
		"base": base(p)
		"shaft": shaft(p)
		"doric_capital", "ionic_capital", "corinthian_capital": capital(p, id.split("_")[0])
		"doric_column", "ionic_column", "corinthian_column":
			base(p)
			shaft(p, 0.5)
			capital(p, id.split("_")[0], 3.5)
		"entablature":
			box(p, Vector3(length, 0.18, 1.02), Vector3(0, 0.09, 0))
			box(p, Vector3(length, 0.08, 1.1), Vector3(0, 0.22, 0))
			box(p, Vector3(length, 0.22, 1.0), Vector3(0, 0.37, 0))
			box(p, Vector3(length, 0.09, 1.18), Vector3(0, 0.535, 0))
			box(p, Vector3(length, 0.17, 1.3), Vector3(0, 0.665, 0))
			for j in range(maxi(1,roundi(length/0.235))):
				for z in [-0.55, 0.55]:
					box(p, Vector3(0.1, 0.11, 0.15), Vector3(-length/2+(j+0.5)*length/maxi(1,roundi(length/0.235)), 0.455, z), false)
		"pediment":
			polygon(p, PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(0, 1.2)]), 0.5, Vector3.ZERO, false, true)
			box(p, Vector3(4.12, 0.12, 0.7), Vector3(0, 0.06, 0), false)
			for side in [-1, 1]:
				beam(p, Vector3(side * 2.02, 0.1, 0), Vector3(0, 1.24, 0), 0.13, 0.7)
				beam(p, Vector3(side * 1.75, 0.19, 0.28), Vector3(0, 1.16, 0.28), 0.035, 0.06)
		"wall":
			box(p, Vector3(length, 4.1, 0.32), Vector3(0, 2.05, 0))
			for j in range(8):
				var start := -length/2
				while start < length/2-0.001:
					var width := minf(0.5 if j%2 == 1 and is_equal_approx(start,-length/2) else 1.0,length/2-start)
					box(p,Vector3(width-0.025,0.47,0.37),Vector3(start+width/2,0.28+j*0.5,0),false)
					start += width
			box(p, Vector3(length, 0.15, 0.44), Vector3(0, 0.075, 0), false)
			box(p, Vector3(length, 0.14, 0.44), Vector3(0, 4.03, 0), false)
		"arch":
			for side in [-1, 1]:
				box(p, Vector3(0.6, 2, 0.6), Vector3(side * 1.7, 1, 0))
				box(p, Vector3(0.7, 0.12, 0.7), Vector3(side * 1.7, 0.06, 0), false)
				box(p, Vector3(0.7, 0.14, 0.7), Vector3(side * 1.7, 1.93, 0), false)
			for j in range(13):
				var a := PI * j / 13.0 + 0.007
				var b := PI * (j+1) / 13.0 - 0.007
				var outer := 2.04 if j == 6 else 2.0
				polygon(p, PackedVector2Array([Vector2(cos(a)*1.4, 2+sin(a)*1.4), Vector2(cos(a)*outer, 2+sin(a)*outer), Vector2(cos(b)*outer, 2+sin(b)*outer), Vector2(cos(b)*1.4, 2+sin(b)*1.4)]), 0.68 if j == 6 else 0.6, Vector3.ZERO, false, true)
			box(p, Vector3(4, 0.12, 0.7), Vector3(0, 4.04, 0), false)
		"roof":
			polygon(p, PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(0, 1.2)]), 4, Vector3.ZERO, true, true)
			for side in [-1, 1]:
				for row in range(11):
					var x: float = side * row * 0.2
					beam(p, Vector3(x, 1.24 - absf(x)*0.6, -2), Vector3(x, 1.24 - absf(x)*0.6, 2), 0.07, 0.04, true)
				for row in range(12):
					beam(p, Vector3(0, 1.23, -1.85 + row * 0.33), Vector3(side * 2, 0.03, -1.85 + row * 0.33), 0.025, 0.025, true)
		"cornice":
			box(p, Vector3(length, 0.13, 0.6), Vector3(0, 0.065, 0))
			# Recessed backing makes the dentil course continuous and aimable.
			box(p, Vector3(length, 0.05, 0.5), Vector3(0, 0.155, 0))
			box(p, Vector3(length, 0.12, 0.8), Vector3(0, 0.24, 0))
			for j in range(maxi(1,roundi(length/0.235))):
				box(p, Vector3(0.11, 0.1, 0.75), Vector3(-length/2+(j+0.5)*length/maxi(1,roundi(length/0.235)), 0.15, 0), false)
		"balustrade":
			box(p, Vector3(length, 0.15, 0.5), Vector3(0, 0.075, 0))
			box(p, Vector3(length, 0.15, 0.5), Vector3(0, 1.075, 0))
			var post_width := minf(0.35,length/2-0.025)
			for x in [-length/2+post_width/2+0.025, length/2-post_width/2-0.025]:
				box(p, Vector3(post_width, 0.85, 0.4), Vector3(x, 0.575, 0))
			var count := maxi(0,floori((length-0.8)/0.45))
			for j in range(count):
				lathe(p, [Vector2(0.12, 0), Vector2(0.12, 0.08), Vector2(0.075, 0.13), Vector2(0.075, 0.22), Vector2(0.16, 0.36), Vector2(0.16, 0.48), Vector2(0.09, 0.66), Vector2(0.08, 0.77), Vector2(0.13, 0.85)], Vector3((j-(count-1)/2.0)*0.45, 0.15, 0), false, 24)
			box(p, Vector3(maxf(0.1,length-0.6), 0.85, 0.24), Vector3(0, 0.575, 0), true)
			p.back().erase("mesh") # one inexpensive invisible collision rail
		"rectangular_pedestal":
			var cap := preload("res://src/building/capital_details.gd")
			p.append({"mesh":cap.plate([Vector3(1.56,0,0.76),Vector3(1.6,0.04,0.8),Vector3(1.6,0.12,0.8),Vector3(1.49,0.19,0.69),Vector3(1.45,0.23,0.65),Vector3(1.45,1.0,0.65),Vector3(1.49,1.04,0.69),Vector3(1.50,1.08,0.70),Vector3(1.6,1.13,0.8),Vector3(1.6,1.18,0.8),Vector3(1.58,1.2,0.78)]),"transform":Transform3D.IDENTITY})
			box(p,Vector3(3.2,0.19,1.6),Vector3(0,0.095,0))
			p.back().erase("mesh")
			box(p,Vector3(2.9,0.85,1.3),Vector3(0,0.615,0))
			p.back().erase("mesh")
			box(p,Vector3(3.2,0.16,1.6),Vector3(0,1.12,0))
			p.back().erase("mesh")
		"pedestal":
			box(p, Vector3(1.4, 0.15, 1.4), Vector3(0, 0.075, 0))
			box(p, Vector3(1.2, 0.12, 1.2), Vector3(0, 0.21, 0))
			box(p, Vector3(1.0, 0.65, 1.0), Vector3(0, 0.595, 0))
			box(p, Vector3(1.2, 0.08, 1.2), Vector3(0, 0.96, 0))
			box(p, Vector3(1.4, 0.1, 1.4), Vector3(0, 1.05, 0))
		"urn":
			box(p, Vector3(0.55, 0.1, 0.55), Vector3(0, 0.05, 0))
			lathe(p, [Vector2(0.22,0.1),Vector2(0.24,0.16),Vector2(0.12,0.26),Vector2(0.12,0.4),Vector2(0.22,0.48),Vector2(0.34,0.57),Vector2(0.4,0.75),Vector2(0.39,0.9),Vector2(0.28,1.05),Vector2(0.26,1.12),Vector2(0.37,1.18),Vector2(0.37,1.25),Vector2(0.28,1.25),Vector2(0.24,1.16),Vector2(0.24,1.05),Vector2(0.33,0.9),Vector2(0.33,0.72),Vector2(0.23,0.61),Vector2(0,0.61)], Vector3.ZERO, false, 48)
			cylinder(p, 0.36, 0.36, 1.05, Vector3(0, 0.7, 0), true)
			p.back().erase("mesh")
			for side in [-1, 1]:
				var last := Vector3(side*0.3, 0.54, 0)
				for j in range(1, 13):
					var angle := PI * j / 12
					var next := Vector3(side * (0.3 + sin(angle)*0.19), 0.54 + (1-cos(angle))*0.25, 0)
					beam(p, last, next, 0.055, 0.065)
					last = next
		"finial":
			box(p, Vector3(0.45, 0.13, 0.36), Vector3(0, 0.065, 0))
			for j in range(9):
				var angle := -1.1 + j * 0.275
				var start := Vector3(0, 0.15, 0)
				var end := start + Vector3(sin(angle)*0.48, cos(angle)*0.87, 0)
				beam(p, start, end, 0.1, 0.16)
			cylinder(p, 0.13, 0.06, 0.55, Vector3(0, 0.4, 0), true)
	return p
