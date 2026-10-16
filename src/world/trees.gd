extends RefCounted
## Deterministic Mediterranean tree meshes, shared by the perimeter instances.
## Foliage uses opaque geometry, avoiding stacked transparent leaf overdraw.

const SPECIES := ["cypress","olive","pine"]
const VARIANTS := 3
const CLEAR_HALF_EXTENT := 70.0
const TREES_PER_SIDE := 28
static var _recipes: Dictionary = {}
static var _bark: ShaderMaterial
static var _foliage: ShaderMaterial
static var _linear_colors := RenderingServer.get_current_rendering_method() != "gl_compatibility"

static func recipe(species: String, variant: int) -> Dictionary:
	var key := "%s:%d" % [species,variant]
	if _recipes.has(key): return _recipes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 6319+SPECIES.find(species)*1009+variant*137
	var wood := SurfaceTool.new()
	var crown := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	match species:
		"cypress": _cypress(wood,crown,rng)
		"olive": _olive(wood,crown,rng)
		"pine": _pine(wood,crown,rng)
	wood.index()
	crown.index()
	var trunk_mesh := wood.commit()
	var leaf_mesh := crown.commit()
	_recipes[key] = {"wood":trunk_mesh,"foliage":leaf_mesh,"bounds":trunk_mesh.get_aabb().merge(leaf_mesh.get_aabb())}
	return _recipes[key]

static func materials() -> Array[Material]:
	if _bark == null:
		_bark = ShaderMaterial.new()
		_bark.shader = preload("res://src/world/bark.gdshader")
		_foliage = ShaderMaterial.new()
		_foliage.shader = preload("res://src/world/foliage.gdshader")
	return [_bark,_foliage]

static func perimeter_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 159
	var protected := Rect2(Vector2.ONE*-CLEAR_HALF_EXTENT,Vector2.ONE*CLEAR_HALF_EXTENT*2)
	for side in range(4):
		for slot in range(TREES_PER_SIDE):
			var species: String = SPECIES[rng.randi_range(0,2)]
			var variant := rng.randi_range(0,VARIANTS-1)
			var size := rng.randf_range(0.85,1.3)
			var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size)
			var along := lerpf(-96,96,(slot+0.5)/TREES_PER_SIDE)+rng.randf_range(-1.6,1.6)
			var outward := rng.randf_range(79,94)
			var pos := Vector3(along,0,outward) if side%2 == 0 else Vector3(outward,0,along)
			if side >= 2: pos *= -1
			var transform_value := Transform3D(basis,pos)
			var bounds: AABB = transform_value*recipe(species,variant).bounds
			# Validate complete rotated/scaled crowns, including the breeze margin.
			var footprint := Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(0.2)
			if protected.intersects(footprint): continue
			result.append({"species":species,"variant":variant,"transform":transform_value,"side":side,"tint":rng.randf_range(0.88,1.08)})
	return result

static func populate(parent: Node3D, height_at: Callable) -> void:
	var grove := Node3D.new()
	grove.name = "PerimeterTrees"
	parent.add_child(grove)
	var groups := {}
	for record in perimeter_layout():
		var frame: Transform3D = record.transform
		frame.origin.y = planting_height(frame,height_at)
		record.transform = frame
		var key := "%d:%s:%d" % [record.side,record.species,record.variant]
		if not groups.has(key): groups[key] = []
		groups[key].append(record)
	var mats := materials()
	for key in groups:
		var records: Array = groups[key]
		var model := recipe(records[0].species,records[0].variant)
		for part in ["wood","foliage"]:
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.use_colors = true
			batch.mesh = model[part]
			batch.instance_count = records.size()
			for i in range(records.size()):
				batch.set_instance_transform(i,records[i].transform)
				var tint: float = records[i].tint
				batch.set_instance_color(i,Color(tint,tint,tint,1))
			var node := MultiMeshInstance3D.new()
			node.name = key.replace(":","_")+"_"+part
			node.multimesh = batch
			node.material_override = mats[0 if part == "wood" else 1]
			# The shader's small leaf movement must stay inside the culling bounds.
			node.extra_cull_margin = 0.2
			grove.add_child(node)

static func planting_height(frame: Transform3D, height_at: Callable) -> float:
	var base := Vector2(frame.origin.x,frame.origin.z)
	var lowest := float(height_at.call(base))
	# Bury the root flare into the downhill side as well as the trunk centre.
	var radius := frame.basis.get_scale().x*1.2
	for i in range(8):
		var offset := Vector2(cos(i*TAU/8),sin(i*TAU/8))*radius
		lowest = minf(lowest,float(height_at.call(base+offset)))
	return lowest-0.18

static func _vertex(surface: SurfaceTool, point: Vector3, normal: Vector3, color: Color) -> void:
	surface.set_normal(normal.normalized())
	surface.set_color(color)
	surface.add_vertex(point)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	if _linear_colors: color = color.srgb_to_linear()
	# Godot's front faces use clockwise winding.
	if (b-a).cross(c-a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	# Keep stylized leaf normals safely on the face's visible hemisphere, even
	# after vertex positions are quantized to the mesh's 32-bit buffers.
	normal = (normal.normalized()-(b-a).cross(c-a).normalized()*0.12).normalized()
	for point in [a,b,c]: _vertex(surface,point,normal,color)

static func _branch(surface: SurfaceTool, points: Array[Vector3], radii: Array[float], color: Color, phase: float = 0.0) -> void:
	const SIDES := 9
	var curved_points: Array[Vector3] = []
	var curved_radii: Array[float] = []
	for j in range(points.size()-1):
		for step in range(3):
			var t := step/3.0
			curved_points.append(points[j].cubic_interpolate(points[j+1],points[maxi(0,j-1)],points[mini(points.size()-1,j+2)],t))
			curved_radii.append(lerpf(radii[j],radii[j+1],t))
	curved_points.append(points[-1])
	curved_radii.append(radii[-1])
	points = curved_points
	radii = curved_radii
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var previous_axis := Vector3.ZERO
	for j in range(points.size()):
		var tangent := (points[mini(j+1,points.size()-1)]-points[maxi(j-1,0)]).normalized()
		var axis := tangent.cross(Vector3.FORWARD if absf(tangent.y) > 0.9 else Vector3.UP).normalized() if j == 0 else (previous_axis-tangent*previous_axis.dot(tangent)).normalized()
		previous_axis = axis
		var other := tangent.cross(axis).normalized()
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for i in range(SIDES):
			var angle := TAU*i/SIDES
			var normal := axis*cos(angle)+other*sin(angle)
			var furrow := 1.0+0.12*sin(angle*4+phase+j*0.65)
			ring.append(points[j]+normal*radii[j]*furrow)
			ring_normals.append(normal)
		rings.append(ring)
		normals.append(ring_normals)
	for j in range(points.size()-1):
		for i in range(SIDES):
			var k := (i+1)%SIDES
			var tint := color.darkened(0.12+0.1*sin(i*2.6+phase))
			for indices in [[Vector2i(j,i),Vector2i(j+1,k),Vector2i(j+1,i)],[Vector2i(j,i),Vector2i(j,k),Vector2i(j+1,k)]]:
				var a: Vector3 = rings[indices[0].x][indices[0].y]
				var b: Vector3 = rings[indices[1].x][indices[1].y]
				var c: Vector3 = rings[indices[2].x][indices[2].y]
				var normal_sum := Vector3.ZERO
				for index in indices: normal_sum += normals[index.x][index.y]
				if (b-a).cross(c-a).dot(normal_sum) > 0:
					indices.reverse()
				var linear_tint := tint.srgb_to_linear() if _linear_colors else tint
				for index in indices:
					_vertex(surface,rings[index.x][index.y],normals[index.x][index.y],linear_tint)
	for end in [0,points.size()-1]:
		var outward := (points[0]-points[1]).normalized() if end == 0 else (points[-1]-points[-2]).normalized()
		for i in range(SIDES): _triangle(surface,points[end],rings[end][i],rings[end][(i+1)%SIDES],outward,color)

static func _roots(surface: SurfaceTool, radius: float, color: Color, rng: RandomNumberGenerator) -> void:
	for i in range(5):
		var direction := Vector3(cos(i*TAU/5),0,sin(i*TAU/5))
		_branch(surface,[Vector3(0,0.55,0),direction*radius+Vector3(0,0.12,0),direction*radius*1.7+Vector3(0,-0.12,0)],[radius*0.3,radius*0.2,0.025],color,rng.randf()*TAU)

static func _leaf(surface: SurfaceTool, centre: Vector3, direction: Vector3, length_value: float, width: float, color: Color, rng: RandomNumberGenerator, outward: Vector3) -> void:
	var axis := direction.normalized()
	var across := axis.cross(Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))).normalized()
	if across.length_squared() < 0.5: across = axis.cross(Vector3.RIGHT).normalized()
	var n := across.cross(axis).normalized()
	var base := centre-axis*length_value*0.5
	var tip := centre+axis*length_value*0.5
	var left := centre+across*width
	var right := centre-across*width
	var ridge := centre+n*width*0.28
	# Rounded canopy normals keep thin leaves from looking like shiny confetti.
	var normal := (n+outward*1.8).normalized()
	for pair in [[base,left],[left,tip],[tip,right],[right,base]]:
		_triangle(surface,pair[0],pair[1],ridge,normal,color)

static func _spray(surface: SurfaceTool, centre: Vector3, radii: Vector3, count: int, palette: Color, leaf_length: float, rng: RandomNumberGenerator, narrow: bool = false) -> void:
	for i in range(count):
		var direction := Vector3(rng.randfn(),rng.randfn(),rng.randfn()).normalized()
		var offset := direction*pow(rng.randf(),0.3333)*radii
		var tint := palette.lightened(rng.randf_range(0,0.17)) if direction.y > 0 else palette.darkened(rng.randf_range(0.02,0.2))
		var leaf_axis := (direction+Vector3(0,0.55,0)).normalized() if narrow else Vector3(rng.randf_range(-1,1),rng.randf_range(-0.45,0.55),rng.randf_range(-1,1)).normalized()
		_leaf(surface,centre+offset,leaf_axis,leaf_length*rng.randf_range(0.7,1.25),leaf_length*(0.11 if narrow else 0.21),tint,rng,direction)

static func _cypress(wood: SurfaceTool, crown: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(9.5,12.5)
	var lean := Vector3(rng.randf_range(-0.25,0.25),0,rng.randf_range(-0.25,0.25))
	var bark_color := Color("746450")
	_roots(wood,0.38,bark_color,rng)
	_branch(wood,[Vector3.ZERO,Vector3(0.05,height*0.32,0)+lean*0.2,Vector3(0,height*0.7,0)+lean*0.6,Vector3.UP*height+lean],[0.28,0.2,0.11,0.015],bark_color)
	# Many staggered ascending branchlets create the columnar silhouette.
	for level in range(23):
		var t := float(level)/23
		var y := lerpf(1.4,height-0.25,t)
		var spread := (0.42+0.85*sin(t*PI))*pow(1.0-t,0.35)
		for arm in range(4):
			var angle := arm*TAU/4+level*2.4+rng.randf_range(-0.3,0.3)
			var direction := Vector3(cos(angle),0,sin(angle))
			var start := Vector3.UP*y+lean*t
			var end := start+direction*spread+Vector3.UP*rng.randf_range(0.3,0.8)
			_branch(wood,[start,start.lerp(end,0.55)-Vector3.UP*0.14,end],[0.055*(1-t)+0.01,0.025,0.005],bark_color,angle)
			_spray(crown,end,Vector3(spread*0.52,0.7,spread*0.52),52,Color("344c31"),0.52,rng,true)
	_spray(crown,Vector3.UP*(height-0.2)+lean,Vector3(0.25,0.65,0.25),75,Color("47603b"),0.38,rng,true)

static func _olive(wood: SurfaceTool, crown: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var bark_color := Color("807562")
	var lean := Vector3(rng.randf_range(-0.3,0.3),0,rng.randf_range(-0.3,0.3))
	_roots(wood,0.65,bark_color,rng)
	_branch(wood,[Vector3.ZERO,Vector3(0.12,0.8,-0.1),Vector3(-0.14,1.65,0.1),Vector3(0.08,2.5,0)+lean],[0.48,0.38,0.31,0.23],bark_color,0.5)
	for arm in range(6):
		var angle := arm*TAU/6+rng.randf_range(-0.3,0.3)
		var direction := Vector3(cos(angle),0,sin(angle))
		var start := Vector3(0.05,1.7+arm*0.14,0)+lean
		var elbow := direction*rng.randf_range(1.1,1.6)+Vector3(0,3.0+rng.randf()*0.5,0)
		var end := direction*rng.randf_range(2.0,2.9)+Vector3(0,rng.randf_range(3.8,4.9),0)
		_branch(wood,[start,elbow,end],[0.23,0.13,0.045],bark_color,angle)
		for twig in range(7):
			var fork_angle := angle+(twig-3)*0.38
			var radial := Vector3(cos(fork_angle),0,sin(fork_angle))
			var tip := end+radial*rng.randf_range(0.25,1.05)+Vector3(0,rng.randf_range(-0.1,0.8),0)
			_branch(wood,[elbow.lerp(end,0.35+twig*0.1),end.lerp(tip,0.55)+Vector3.UP*0.1,tip],[0.045,0.023,0.006],bark_color,fork_angle)
			_spray(crown,tip,Vector3(0.75,0.62,0.75),105,Color("718365"),0.36,rng)
	# An airy, irregular centre connects the branch-end sprays without a solid ball.
	for i in range(8):
		_spray(crown,Vector3(rng.randf_range(-1.2,1.2),rng.randf_range(4.1,5.2),rng.randf_range(-1.2,1.2)),Vector3(0.8,0.65,0.8),90,Color("708365"),0.34,rng)

static func _pine(wood: SurfaceTool, crown: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(8.0,10.0)
	var bark_color := Color("825d44")
	var lean := Vector3(rng.randf_range(-0.5,0.5),0,rng.randf_range(-0.4,0.4))
	_roots(wood,0.65,bark_color,rng)
	_branch(wood,[Vector3.ZERO,Vector3(-0.12,height*0.35,0.1),Vector3.UP*height*0.65+lean*0.65,Vector3.UP*(height-0.5)+lean],[0.42,0.32,0.23,0.08],bark_color)
	for arm in range(9):
		var angle := arm*TAU/9+rng.randf_range(-0.24,0.24)
		var direction := Vector3(cos(angle),0,sin(angle))
		var start := Vector3.UP*(height*0.58+arm*0.12)+lean*0.6
		var elbow := direction*rng.randf_range(1.3,1.9)+Vector3.UP*(height-1.5)+lean
		var end := direction*rng.randf_range(2.6,3.7)+Vector3.UP*(height-0.25+rng.randf()*0.6)+lean
		_branch(wood,[start,elbow,end],[0.19,0.12,0.045],bark_color,angle)
		for twig in range(5):
			var fork_angle := angle+(twig-2)*0.43
			var tip := end+Vector3(cos(fork_angle),rng.randf_range(0.1,0.5),sin(fork_angle))*rng.randf_range(0.5,1.15)
			_branch(wood,[elbow.lerp(end,0.6+twig*0.07),end.lerp(tip,0.55),tip],[0.06,0.028,0.006],bark_color,fork_angle)
			_spray(crown,tip,Vector3(1.0,0.65,1.0),115,Color("3f603d"),0.65,rng,true)
	for i in range(12):
		var angle := i*TAU/12
		var pos := Vector3(cos(angle)*1.5,height+0.25+rng.randf()*0.4,sin(angle)*1.5)+lean
		_spray(crown,pos,Vector3(1.1,0.65,1.1),120,Color("4c6b40"),0.65,rng,true)
