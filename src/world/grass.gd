extends Node3D
## Shared opaque blade meshes in spatial batches. Only edited chunks are rebuilt.

const CHUNK_SIZE := 16.0
const HALF_EXTENT := 80.0
const SPACING := 0.72
const CLEARANCE := 0.56 # Includes tuft width and wind, preventing blades through stone.
const GrassShader = preload("res://src/world/grass.gdshader")

var chunks: Dictionary = {}
var blockers: Dictionary = {}
var material: ShaderMaterial
var quality := 1
var revision := 0

func populate(height_at: Callable) -> void:
	name = "MeadowGrass"
	material = ShaderMaterial.new()
	material.shader = GrassShader
	var mesh := tuft_mesh()
	var noise := FastNoiseLite.new()
	noise.seed = 742
	noise.frequency = 0.065
	var rng := RandomNumberGenerator.new()
	rng.seed = 21873
	var cells := int(HALF_EXTENT/SPACING)
	for x in range(-cells,cells):
		for z in range(-cells,cells):
			var p := (Vector2(x,z)+Vector2(rng.randf_range(0.15,0.85),rng.randf_range(0.15,0.85)))*SPACING
			var density := smoothstep(-0.5,0.35,noise.get_noise_2d(p.x,p.y))
			if rng.randf() > density*0.85 or in_clearing(p): continue
			var key := chunk_at(p)
			if not chunks.has(key):
				var node := MultiMeshInstance3D.new()
				node.name = "Grass_%d_%d" % [key.x,key.y]
				node.position = Vector3(key.x*CHUNK_SIZE,0,key.y*CHUNK_SIZE)
				node.material_override = material
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.extra_cull_margin = 0.15
				node.visibility_range_end = 74.0
				var batch := MultiMesh.new()
				batch.transform_format = MultiMesh.TRANSFORM_3D
				batch.mesh = mesh
				node.multimesh = batch
				add_child(node)
				chunks[key] = {"node":node,"samples":[],"visible_roots":PackedVector3Array()}
			var size := rng.randf_range(0.65,1.2)
			var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,rng.randf_range(0.65,1.15),size))
			chunks[key].samples.append({"frame":Transform3D(basis,Vector3(p.x,height_at.call(p)-0.012,p.y)),"rank":rng.randf()})
	_rebuild(chunks.keys())

static func in_clearing(p: Vector2) -> bool:
	# Match the feathered gravel plot and approach in ground.gdshader, including blades.
	return Rect2(-1.6,-14.6,27.2,29.2).has_point(p) or Rect2(-18.6,-15.6,5.2,47.2).has_point(p)

static func chunk_at(p: Vector2) -> Vector2i:
	return Vector2i((p/CHUNK_SIZE).floor())

func set_quality(value: int) -> void:
	value = clampi(value,0,2)
	if value == quality: return
	quality = value
	material.set_shader_parameter("fade_start",[24.0,38.0,54.0][quality])
	material.set_shader_parameter("fade_end",[40.0,62.0,80.0][quality])
	for chunk: Dictionary in chunks.values(): chunk.node.visibility_range_end = [52.0,74.0,92.0][quality]
	_rebuild(chunks.keys())

func sync_buildings(pieces: Array) -> void:
	var next: Dictionary = {}
	var dirty: Dictionary = {}
	for piece: BuildPiece in pieces:
		var bounds := piece.visual_bounds
		bounds.position.x -= CLEARANCE
		bounds.position.z -= CLEARANCE
		bounds.size.x += CLEARANCE*2
		bounds.size.z += CLEARANCE*2
		# The blade tips can reach 0.45 m. Roofs high overhead leave grass alone.
		bounds.position.y -= 0.48
		bounds.size.y += 0.58
		var world_bounds: AABB = piece.transform*bounds
		var footprint := Rect2(Vector2(world_bounds.position.x,world_bounds.position.z),Vector2(world_bounds.size.x,world_bounds.size.z))
		var block := {"frame":piece.transform,"bounds":bounds,"footprint":footprint,"inverse":piece.transform.affine_inverse()}
		next[piece.uid] = block
		if not blockers.has(piece.uid) or blockers[piece.uid].frame != block.frame or blockers[piece.uid].bounds != bounds:
			_mark_chunks(footprint,dirty)
			if blockers.has(piece.uid): _mark_chunks(blockers[piece.uid].footprint,dirty)
	for uid in blockers:
		if not next.has(uid): _mark_chunks(blockers[uid].footprint,dirty)
	blockers = next
	if not dirty.is_empty(): _rebuild(dirty.keys())

func _mark_chunks(rect: Rect2, dirty: Dictionary) -> void:
	var first := chunk_at(rect.position)
	var last := chunk_at(rect.end)
	for x in range(first.x,last.x+1):
		for z in range(first.y,last.y+1):
			var key := Vector2i(x,z)
			if chunks.has(key): dirty[key] = true

func _rebuild(keys: Array) -> void:
	revision += 1
	for key: Vector2i in keys:
		var chunk: Dictionary = chunks[key]
		var region := Rect2(Vector2(key)*CHUNK_SIZE,Vector2.ONE*CHUNK_SIZE)
		var nearby: Array = []
		for block: Dictionary in blockers.values():
			if region.intersects(block.footprint): nearby.append(block)
		var frames: Array[Transform3D] = []
		var roots := PackedVector3Array()
		for sample: Dictionary in chunk.samples:
			if sample.rank > [0.4,0.75,1.0][quality]: continue
			var frame: Transform3D = sample.frame
			var covered := false
			for block: Dictionary in nearby:
				if block.bounds.has_point(block.inverse*frame.origin):
					covered = true
					break
			if covered: continue
			roots.append(frame.origin)
			frame.origin -= chunk.node.position
			frames.append(frame)
		chunk.visible_roots = roots
		var batch: MultiMesh = chunk.node.multimesh
		batch.instance_count = frames.size()
		for i in range(frames.size()): batch.set_instance_transform(i,frames[i])

func visible_roots_in(rect: Rect2) -> PackedVector3Array:
	var result := PackedVector3Array()
	var selected := {}
	_mark_chunks(rect,selected)
	for key in selected:
		for root: Vector3 in chunks[key].visible_roots:
			if rect.has_point(Vector2(root.x,root.z)): result.append(root)
	return result

static func tuft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9182
	for blade in range(7):
		var angle := rng.randf()*TAU
		var direction := Vector3(cos(angle),0,sin(angle))
		var across := Vector3(-direction.z,0,direction.x)
		var root := direction*rng.randf_range(0.015,0.18)
		var height := rng.randf_range(0.16,0.34)
		var width := rng.randf_range(0.009,0.019)
		var lean := rng.randf_range(0.06,0.16)
		var rows: Array = []
		for t in [0.0,0.43,0.76]:
			var centre: Vector3 = root+Vector3.UP*height*t+direction*lean*t*t
			var w: float = width*(1.0-t*0.8)
			rows.append([centre-across*w,centre+direction*w*0.25,centre+across*w])
		for level in range(2):
			for side in range(2):
				_triangle(surface,[rows[level][side],rows[level+1][side+1],rows[level+1][side]],float(level)/3.0,float(level+1)/3.0,float(level+1)/3.0)
				_triangle(surface,[rows[level][side],rows[level][side+1],rows[level+1][side+1]],float(level)/3.0,float(level)/3.0,float(level+1)/3.0)
		var tip := root+Vector3.UP*height+direction*lean
		for side in range(2): _triangle(surface,[rows[2][side],rows[2][side+1],tip],0.76,0.76,1.0)
	surface.index()
	return surface.commit()

static func _triangle(surface: SurfaceTool, points: Array, a: float, b: float, c: float) -> void:
	var normal: Vector3 = -(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	for i in range(3):
		surface.set_normal(normal)
		surface.set_uv(Vector2(0,[a,b,c][i]))
		surface.add_vertex(points[i])
