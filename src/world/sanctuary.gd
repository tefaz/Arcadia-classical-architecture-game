class_name SanctuaryWorld
extends Node3D

const DAY_LENGTH_SECONDS := 1200.0
const DEFAULT_DAY_PROGRESS := 0.2
const DAYLIGHT_UPDATE_INTERVAL := 0.1
const Lighting = preload("res://src/world/lighting.gd")
const Trees = preload("res://src/world/trees.gd")
const Grass = preload("res://src/world/grass.gd")
const TERRAIN_STEP := 2.0
const TERRAIN_CELLS := 128

var sun: DirectionalLight3D
var sky_fill: DirectionalLight3D
var sky_material: ShaderMaterial
var day_progress := DEFAULT_DAY_PROGRESS
var _daylight_update_elapsed := 0.0
var terrain: MeshInstance3D
var environment: Environment
var stone: StandardMaterial3D
var terrain_noise: FastNoiseLite
var grass: Grass

func _ready() -> void:
	_create_light()
	_create_landscape()
	_create_garden()
	grass = Grass.new()
	add_child(grass)
	grass.populate(ground_height_at)

static func material(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _create_light() -> void:
	environment = Environment.new()
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://src/world/daylight_sky.gdshader")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d0dbe1")
	environment.ambient_light_energy = 0.58
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("bdc9c5")
	environment.fog_density = 0.0018
	environment.fog_light_energy = 0.65
	environment.fog_sky_affect = 0.12
	var node := WorldEnvironment.new()
	node.environment = environment
	add_child(node)
	sun = DirectionalLight3D.new()
	# The sky shader draws the single sun independently of direct-light intensity.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.06
	add_child(sun)
	# A cool, gentle directional fill preserves relief on the side away from the sun.
	sky_fill = DirectionalLight3D.new()
	sky_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sky_fill.light_color = Color("c4dbed")
	sky_fill.light_energy = 0.16
	sky_fill.shadow_enabled = false
	add_child(sky_fill)
	Lighting.setup(environment,sun,sky_fill)
	if Lighting.is_forward_plus(): sky_material.set_shader_parameter("background_energy",0.7)
	_update_daylight()

func advance_daylight(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	var next_progress := day_progress+delta/DAY_LENGTH_SECONDS
	var wrapped := next_progress >= 1.0
	day_progress = fposmod(next_progress,1.0)
	_daylight_update_elapsed += delta
	# The slow-moving sun needs only ten visual updates a second. This also limits
	# radiance-map refreshes; a sunset wrap always updates the lighting immediately.
	if wrapped or _daylight_update_elapsed >= DAYLIGHT_UPDATE_INTERVAL:
		_daylight_update_elapsed = fmod(_daylight_update_elapsed,DAYLIGHT_UPDATE_INTERVAL)
		_update_daylight()

func restore_daylight(value: Variant) -> void:
	day_progress = DEFAULT_DAY_PROGRESS
	if (value is float or value is int) and is_finite(float(value)) and value >= 0 and value < 1:
		day_progress = float(value)
	_daylight_update_elapsed = 0
	_update_daylight()

func _update_daylight() -> void:
	# Cross the sky from east to west, reaching the sunset horizon before wrapping.
	var angle := lerpf(deg_to_rad(8),PI,day_progress)
	var direction := Vector3(cos(angle),sin(angle)*sin(PI/3),sin(angle)*cos(PI/3))
	sun.basis = Basis.looking_at(-direction,Vector3.UP)
	var warmth := 1.0-smoothstep(0.08,0.55,direction.y)
	sun.light_color = Color("ffe4ba").lerp(Color("f4a369"),warmth)
	sun.light_energy = lerpf(0.22,0.35,smoothstep(0,0.5,direction.y))
	# Forward+ uses linear HDR lighting; Compatibility needs its own lower energy.
	if Lighting.is_forward_plus(): sun.light_energy *= Lighting.DIRECT_ENERGY_SCALE
	else: sun.light_energy *= 0.8
	var fill_direction := Vector3(-direction.x,0.9,-direction.z).normalized()
	sky_fill.basis = Basis.looking_at(-fill_direction,Vector3.UP)
	environment.ambient_light_color = Color("a7b7c9").lerp(Color("cab194"),warmth*0.3)
	environment.fog_light_color = Color("a8b7c0").lerp(Color("c59e85"),warmth*0.6)
	sky_material.set_shader_parameter("sun_direction",sun.global_basis.z)
	sky_material.set_shader_parameter("sun_color",Color("fff8de").lerp(Color("ffc16f"),warmth))
	sky_material.set_shader_parameter("zenith_color",Color("567b9a").lerp(Color("657584"),warmth*0.55))
	sky_material.set_shader_parameter("horizon_color",Color("b8c4c9").lerp(Color("d8a27e"),warmth))

func set_shade_brightness(value: float) -> void:
	environment.ambient_light_energy = clampf(value,0.35,0.85)

func mesh_node(mesh: Mesh, mat: Material, pos: Vector3, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = scale_value
	add_child(node)
	return node

func _create_landscape() -> void:
	var ground_shader := ShaderMaterial.new()
	ground_shader.shader = load("res://src/world/ground.gdshader")
	var ground := PlaneMesh.new()
	ground.size = Vector2(160, 160)
	mesh_node(ground, ground_shader, Vector3.ZERO)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 1, 160)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.5
	body.add_child(collider)
	add_child(body)
	var sea := PlaneMesh.new()
	sea.size = Vector2(900, 900)
	mesh_node(sea, material(Color("758f91"), 0.5), Vector3(0, -2, 0))
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = 618
	terrain_noise.frequency = 0.022
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Shared, smoothly shaded vertices replace the coarse, faceted four-metre grid.
	for x in range(TERRAIN_CELLS+1):
		for z in range(TERRAIN_CELLS+1):
			var px := (x-TERRAIN_CELLS/2)*TERRAIN_STEP
			var pz := (z-TERRAIN_CELLS/2)*TERRAIN_STEP
			var normal := Vector3(_terrain_vertex_height(px-0.5,pz)-_terrain_vertex_height(px+0.5,pz),1.0,_terrain_vertex_height(px,pz-0.5)-_terrain_vertex_height(px,pz+0.5)).normalized()
			surface.set_normal(normal)
			surface.add_vertex(Vector3(px,_terrain_vertex_height(px,pz),pz))
	for x in range(TERRAIN_CELLS):
		for z in range(TERRAIN_CELLS):
			var first := x*(TERRAIN_CELLS+1)+z
			for offset in [0,TERRAIN_CELLS+2,1,0,TERRAIN_CELLS+1,TERRAIN_CELLS+2]:
				surface.add_index(first+offset)
	terrain = mesh_node(surface.commit(), ground_shader, Vector3.ZERO)
	var mountain := SphereMesh.new()
	mountain.radial_segments = 16
	mountain.rings = 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 921
	for i in range(18):
		var color := Color("869a91").lerp(Color("a8b5b0"), rng.randf()*0.4)
		mesh_node(mountain, material(color), Vector3(-190 + i*23, 5, -165 - rng.randf()*50), Vector3(36+rng.randf()*40, 35+rng.randf()*40, 32+rng.randf()*35))

func _create_garden() -> void:
	stone = material(Color("aea88d"))
	Trees.populate(self,terrain_height_at)
	var rng := RandomNumberGenerator.new()
	rng.seed = 159
	# Discreet corner markers leave the entire construction plot usable.
	for x in [-1.0, 25.0]:
		for z in [-14.0, 14.0]:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.35, 0.6, 0.35)
			mesh_node(mesh, stone, Vector3(x, 0.3, z))
	var rock_mesh := SphereMesh.new()
	rock_mesh.radial_segments = 12
	rock_mesh.rings = 6
	for i in range(28):
		var along := rng.randf_range(-94,94)
		var outward := rng.randf_range(74,96)
		var pos := Vector3(along,0,outward) if i%2 == 0 else Vector3(outward,0,along)
		if i%4 >= 2: pos *= -1
		pos.y = terrain_height_at(Vector2(pos.x,pos.z))+0.05
		mesh_node(rock_mesh, stone, pos, Vector3(rng.randf_range(1,3), rng.randf_range(0.5,1.5), rng.randf_range(1,2)))

func _terrain_vertex_height(x: float, z: float) -> float:
	# Keep all walkable/buildable ground level; hills rise beyond the player bounds.
	var edge := smoothstep(64,94,maxf(absf(x),absf(z)))
	return maxf(0,terrain_noise.get_noise_2d(x,z)+0.4)*17*edge-0.08

func terrain_height_at(pos: Vector2) -> float:
	# Match the actual rendered terrain triangles, rather than a smooth noise
	# sample that could leave a tree floating above/below the rendered hillside.
	var cell := (pos/TERRAIN_STEP).floor()*TERRAIN_STEP
	var f := (pos-cell)/TERRAIN_STEP
	var a := _terrain_vertex_height(cell.x,cell.y)
	var b := _terrain_vertex_height(cell.x+TERRAIN_STEP,cell.y)
	var c := _terrain_vertex_height(cell.x,cell.y+TERRAIN_STEP)
	var d := _terrain_vertex_height(cell.x+TERRAIN_STEP,cell.y+TERRAIN_STEP)
	return a+(d-c)*f.x+(c-a)*f.y if f.y >= f.x else a+(b-a)*f.x+(d-b)*f.y

func ground_height_at(pos: Vector2) -> float:
	var height := terrain_height_at(pos)
	return maxf(0,height) if maxf(absf(pos.x),absf(pos.y)) <= 80 else height

static func sample_pavilion() -> Array:
	var pieces: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0, stone_index: int = 0):
		pieces.append({"uid": pieces.size()+1, "kind": kind, "stone": stone_index, "position": [pos.x, pos.y, pos.z], "rotation": angle})
	for x in [-18.0, -14.0]:
		for z in [-12.0, -8.0, -4.0]:
			append.call("foundation", Vector3(x, 0, z))
			append.call("foundation", Vector3(x, 0.4, z))
			append.call("ionic_column", Vector3(x, 0.8, z), 0.0, 1)
	for z in [-12.0, -4.0]:
		append.call("entablature", Vector3(-16, 4.9, z), 0.0, 1)
		append.call("pediment", Vector3(-16, 5.65, z), 0.0, 1)
		append.call("finial", Vector3(-16, 6.85, z), 0.0, 1)
	for x in [-18.0, -14.0]:
		for z in [-10.0, -6.0]:
			append.call("entablature", Vector3(x, 4.9, z), PI/2, 1)
	for z in [-10.0, -6.0]:
		append.call("roof", Vector3(-16, 5.65, z))
	append.call("steps", Vector3(-16, 0, -1))
	for x in [-20.5, -11.5]:
		append.call("pedestal", Vector3(x, 0, 0))
		append.call("urn", Vector3(x, 1.1, 0), 0.0, 1)
	return pieces

static func corner_example(include_railing: bool = false) -> Array:
	var result: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0, stone_index: int = 0):
		result.append({"uid":result.size()+1,"kind":kind,"stone":stone_index,"position":[pos.x,pos.y,pos.z],"rotation":angle})
	for x in [-2.0,2.0]:
		for z in [-2.0,2.0]:
			append.call("foundation",Vector3(12+x,0,z))
	var layers: Array = [["wall",0.4,0],["entablature",4.5,1],["cornice",5.25,1]]
	if include_railing:
		layers.append(["balustrade",5.55,1])
	for layer in layers:
		for sign_value in [-1,1]:
			for offset in [-2.0,2.0]:
				append.call(layer[0],Vector3(12+offset,layer[1],sign_value*4),0,layer[2])
				append.call(layer[0],Vector3(12+sign_value*4,layer[1],offset),PI/2,layer[2])
	return result

static func wall_cover_example(foundation_cover: bool = false) -> Array:
	var result: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0, length: float = 4.0):
		var record := {"uid":result.size()+1,"kind":kind,"stone":0,"position":[pos.x,pos.y,pos.z],"rotation":angle}
		if kind in BuildCatalogue.MITRE_KINDS and not is_equal_approx(length,4): record.length = length
		result.append(record)
	for x in [-2.0,2.0]:
		for z in [-2.0,2.0]:
			append.call("foundation",Vector3(12+x,0,z))
			append.call("foundation" if foundation_cover else "flat_roof",Vector3(12+x,4.5,z))
	for side in [-1,1]:
		for along in [-1.89,1.89]:
			append.call("wall_door_pediment" if side == 1 and along > 0 else "wall_window_segmental",Vector3(12+along,0.4,side*3.78),0,3.78)
			append.call("wall",Vector3(12+side*3.78,0.4,along),PI/2,3.78)
	result.append({"uid":result.size()+1,"kind":"steps","stone":0,"position":[13.89,0,4.5],"rotation":0.0,"rise":0.4})
	return result

static func doorway_example() -> Array:
	var result: Array = []
	for finish in range(3):
		var x := 6.0+finish*6
		result.append({"uid":result.size()+1,"kind":"foundation","stone":finish,"position":[x,0,0],"rotation":0.0})
		result.append({"uid":result.size()+1,"kind":"wall_door_pediment","stone":finish,"position":[x,0.4,0],"rotation":0.0})
	return result

static func foundation_example() -> Array:
	var result: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0, stone_index: int = 0):
		result.append({"uid":result.size()+1,"kind":kind,"stone":stone_index,"position":[pos.x,pos.y,pos.z],"rotation":angle})
	for x in [10.0,14.0]:
		for z in [-4.0,0.0]:
			append.call("foundation_podium",Vector3(x,0,z))
			append.call("foundation",Vector3(x,2,z))
			append.call("doric_column",Vector3(x,2.4,z),0,1)
	append.call("steps",Vector3(12,0,5))
	result.back()["rise"] = 2.4
	for z in [-4.0,0.0]:
		append.call("entablature",Vector3(12,6.5,z),0,1)
		append.call("pediment",Vector3(12,7.25,z),0,1)
		append.call("finial",Vector3(12,8.45,z),0,1)
	for x in [10.0,14.0]:
		append.call("entablature",Vector3(x,6.5,-2),PI/2,1)
	append.call("roof",Vector3(12,7.25,-2))
	return result

static func stack_group_example() -> Array:
	return [
		{"uid":1,"kind":"foundation","stone":0,"position":[12,0,0],"rotation":0},
		{"uid":2,"kind":"foundation","stone":0,"position":[16,0,0],"rotation":0},
		{"uid":3,"kind":"doric_column","stone":1,"position":[12,0.4,0],"rotation":0},
		{"uid":4,"kind":"doric_column","stone":1,"position":[16,0.4,0],"rotation":0},
		{"uid":5,"kind":"entablature","stone":1,"position":[14,4.5,0],"rotation":0},
		{"uid":6,"kind":"pedestal","stone":0,"position":[21,0,3],"rotation":0},
		{"uid":7,"kind":"urn","stone":1,"position":[21,1.1,3],"rotation":0},
	]

static func pediment_example() -> Array:
	var result: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0, stone_index: int = 1):
		result.append({"uid":result.size()+1,"kind":kind,"stone":stone_index,"position":[pos.x,pos.y,pos.z],"rotation":angle})
	for x in [-8.0,-4.0,0.0,4.0,8.0]:
		append.call("foundation",Vector3(12+x,0,0),0,0)
		append.call("entablature",Vector3(12+x,4.5,0))
		append.call("pediment_base",Vector3(12+x,5.25,0))
	for x in [-10.0,-6.0,-2.0,2.0,6.0,10.0]:
		append.call("doric_column",Vector3(12+x,0.4,0))
	for side in [-1,1]:
		var slope_kind := "pediment_left" if side < 0 else "pediment_right"
		append.call(slope_kind,Vector3(12+side*8,5.43,0))
		append.call(slope_kind,Vector3(12+side*4,7.83,0))
		append.call("pediment_backing",Vector3(12+side*4,5.43,0))
		append.call("reclining_figure",Vector3(12+side*7.45,5.45,0.09),0 if side < 0 else PI)
		append.call("horse_relief",Vector3(12+side*4,5.51,0.09),0 if side < 0 else PI)
	append.call("pediment_backing",Vector3(12,5.43,0))
	append.call("pediment_backing",Vector3(12,7.83,0))
	append.call("pediment_crown",Vector3(12,10.23,0))
	append.call("draped_statue",Vector3(11,5.51,0.09))
	append.call("draped_statue",Vector3(13,5.51,0.09))
	append.call("draped_statue",Vector3(12,7.91,0.09))
	append.call("finial",Vector3(12,11.43,0))
	return result

static func roof_example() -> Array:
	var result: Array = []
	for record in pediment_example():
		if record.kind == "pediment_base": continue
		var entry: Dictionary = record.duplicate(true)
		entry.uid = result.size()+1
		if entry.kind in BuildCatalogue.PEDIMENT_KINDS+BuildCatalogue.SCULPTURE_KINDS+["finial"]: entry.position[1] -= 0.18
		result.append(entry)
	var front := result.duplicate(true)
	var append := func(kind: String, pos: Vector3, angle: float = 0.0, stone_index: int = 1):
		result.append({"uid":result.size()+1,"kind":kind,"stone":stone_index,"position":[pos.x,pos.y,pos.z],"rotation":angle})
	# A 20 m gable and three four-metre roof-depth bays, all on the same module grid.
	for z in [-4.0,-8.0,-12.0]:
		for x in [-8.0,-4.0,0.0,4.0,8.0]:
			append.call("foundation",Vector3(12+x,0,z),0,0)
		for side in [-1,1]:
			append.call("doric_column",Vector3(12+side*10,0.4,z))
			append.call("entablature",Vector3(12+side*10,4.5,z+2),PI/2)
		for entry in [["roof_left",-8.0,5.25],["roof_left",-4.0,7.65],
			["roof_left_half",-1.0,10.05],["roof_right_half",1.0,10.05],
			["roof_right",4.0,7.65],["roof_right",8.0,5.25]]:
			append.call(entry[0],Vector3(12+entry[1],entry[2],z+2),0,0)
	# The rear gable uses the same sockets as the front and remains one 12 m run away.
	for record in front:
		if record.kind == "foundation": continue
		if record.kind in ["reclining_figure","horse_relief","draped_statue"]: continue
		var pos := Vector3(record.position[0],record.position[1],-12)
		if record.kind == "doric_column" and (is_equal_approx(pos.x,2) or is_equal_approx(pos.x,22)): continue
		append.call(record.kind,pos,record.rotation,record.stone)
	return result

static func dome_example() -> Array:
	var result: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0, stone_index: int = 0):
		result.append({"uid":result.size()+1,"kind":kind,"stone":stone_index,"position":[pos.x,pos.y,pos.z],"rotation":angle})
	for entry in [["dome",5.0,4.0,0],["dome_large",18.0,8.0,1]]:
		var centre: float = entry[1]
		var width: float = entry[2]
		var finish: int = entry[3]
		if width == 4:
			append.call("foundation_large",Vector3(centre,0,0),0,finish)
		else:
			for x in [-4,0,4]:
				for z in [-4,0,4]: append.call("foundation",Vector3(centre+x,0,z),0,finish)
		for x in range(int(-width/2),int(width/2)+1,4):
			for z in range(int(-width/2),int(width/2)+1,4):
				if absf(x) == width/2 or absf(z) == width/2:
					append.call("doric_column",Vector3(centre+x,0.4,z),0,finish)
		for side in [-1,1]:
			for offset in range(int(-width/2+2),int(width/2),4):
				append.call("entablature",Vector3(centre+offset,4.5,side*width/2),0,finish)
				append.call("entablature",Vector3(centre+side*width/2,4.5,offset),PI/2,finish)
		append.call(entry[0],Vector3(centre,5.25,0),0,finish)
	return result

static func flat_roof_example() -> Array:
	var result: Array = dome_example().filter(func(record): return record.kind not in BuildCatalogue.DOME_KINDS)
	for entry in [[5.0,0.0,0],[16.0,-2.0,1],[16.0,2.0,1],[20.0,-2.0,1],[20.0,2.0,1]]:
		result.append({"uid":0,"kind":"flat_roof","stone":entry[2],"position":[entry[0],5.25,entry[1]],"rotation":0.0})
	for i in range(result.size()): result[i].uid = i+1
	return result

static func window_example() -> Array:
	var result: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0):
		result.append({"uid":result.size()+1,"kind":kind,"stone":0,"position":[pos.x,pos.y,pos.z],"rotation":angle})
	for x in [-4,0,4]:
		for z in [-4,0,4]: append.call("foundation",Vector3(12+x,0,z))
	for side in [-1,1]:
		for offset in [-2,2]:
			append.call("wall_window_pediment" if offset < 0 else "wall_window_ellipse",Vector3(12+offset,0.4,side*4))
			append.call("wall",Vector3(12+side*4,0.4,offset),-PI/2)
			append.call("entablature",Vector3(12+offset,4.5,side*4))
			append.call("entablature",Vector3(12+side*4,4.5,offset),-PI/2)
	for x in [-2,2]:
		for z in [-2,2]: append.call("flat_roof",Vector3(12+x,5.25,z))
	return result

static func wall_perimeter_example() -> Array:
	var result: Array = [{"uid":1,"kind":"foundation_large","stone":0,"position":[12,0,0],"rotation":0.0}]
	for side in [-1,1]:
		for offset in [-1.89,1.89]:
			var kind := "wall_window_segmental" if side == 1 else "wall"
			result.append({"uid":result.size()+1,"kind":kind,"stone":0,"position":[12+offset,0.4,side*3.78],"rotation":0.0,"length":3.78})
			result.append({"uid":result.size()+1,"kind":"wall","stone":0,"position":[12+side*3.78,0.4,offset],"rotation":PI/2,"length":3.78})
	return result

static func corinthian_example() -> Array:
	var result: Array = []
	for entry in [[8,1],[12,0],[16,2]]:
		result.append({"uid":result.size()+1,"kind":"foundation","stone":entry[1],"position":[entry[0],0,0],"rotation":0.0})
		result.append({"uid":result.size()+1,"kind":"corinthian_column","stone":entry[1],"position":[entry[0],0.4,0],"rotation":0.0})
	return result

static func column_order_example(style: String) -> Array:
	var result := corinthian_example()
	for record in result:
		if record.kind == "corinthian_column": record.kind = style+"_column"
	return result

static func ceiling_pediment_example() -> Array:
	var result: Array = roof_example().filter(func(record): return record.kind not in BuildCatalogue.ROOF_KINDS)
	for x in [4,8,12,16,20]:
		for z in [-2,-6,-10]:
			result.append({"uid":0,"kind":"flat_roof","stone":1,"position":[x,5.25,z],"rotation":0.0})
	for i in range(result.size()): result[i].uid = i+1
	return result

static func enclosed_roof_example(stone_roof: bool = false) -> Array:
	var result: Array = []
	var append := func(kind: String, pos: Vector3, angle: float = 0.0):
		result.append({"uid":result.size()+1,"kind":kind,"stone":0,"position":[pos.x,pos.y,pos.z],"rotation":angle})
	for x in [8,12,16]:
		for z in [-4,0,4]: append.call("foundation",Vector3(x,0,z))
	for x in [6,10,14,18]:
		for z in [-6,-2,2,6]:
			if x in [6,18] or z in [-6,6]: append.call("doric_column",Vector3(x,0.4,z))
	for side in [-1,1]:
		for offset in [-4,0,4]:
			append.call("entablature",Vector3(12+offset,4.5,side*6))
			append.call("entablature",Vector3(12+side*6,4.5,offset),PI/2)
		append.call("pediment_left",Vector3(8,5.25,side*6))
		append.call("pediment_backing",Vector3(12,5.25,side*6))
		append.call("pediment_crown",Vector3(12,7.65,side*6))
		append.call("pediment_right",Vector3(16,5.25,side*6))
	var prefix := "stone_" if stone_roof else ""
	for z in [-4,0,4]:
		for entry in [["roof_left",8,5.25,0],["roof_left_half",11,7.65,0],["roof_left_half",13,7.65,PI],["roof_left",16,5.25,PI]]:
			append.call(prefix+entry[0],Vector3(entry[1],entry[2],z),entry[3])
	for x in [8,12,16]:
		for z in [-4,0,4]: append.call("flat_roof",Vector3(x,5.25,z))
	return result

static func lion_example() -> Array:
	var result: Array = []
	for entry in [[8,1],[12,0],[16,2]]:
		for part in [["foundation",0.0],["rectangular_pedestal",0.4],["lion_statue",1.6]]:
			result.append({"uid":result.size()+1,"kind":part[0],"stone":entry[1],"position":[entry[0],part[1],0],"rotation":0.0})
	return result
