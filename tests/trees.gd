extends RefCounted

const Trees = preload("res://src/world/trees.gd")
const MeshAudit = preload("res://tests/meshes.gd")

static func run(game: Node3D, check: Callable) -> void:
	var world: SanctuaryWorld = game.world
	var layout := Trees.perimeter_layout()
	check.call(layout == Trees.perimeter_layout(),"Perimeter trees have reproducible species, shapes and positions")
	check.call(layout.size() >= 96,"The map retains a substantial wooded perimeter")
	var protected := Rect2(-70,-70,140,140)
	var sides := [0,0,0,0]
	var species_counts := {}
	var clear := true
	var grounded := true
	var terrain_matches := true
	var terrain_arrays := world.terrain.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
	for record in layout:
		sides[record.side] += 1
		species_counts[record.species] = species_counts.get(record.species,0)+1
		var frame: Transform3D = record.transform
		var bounds: AABB = frame*Trees.recipe(record.species,record.variant).bounds
		var footprint := Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(0.2)
		clear = clear and not protected.intersects(footprint)
		var pos := Vector2(frame.origin.x,frame.origin.z)
		var height := Trees.planting_height(frame,world.terrain_height_at)
		grounded = grounded and height < world.terrain_height_at(pos) and height > world.terrain_height_at(pos)-3.0
		# Compare the sampler with the actual rendered terrain triangles.
		var cell := (pos/SanctuaryWorld.TERRAIN_STEP).floor()+Vector2.ONE*(SanctuaryWorld.TERRAIN_CELLS/2)
		var first := (int(cell.x)*SanctuaryWorld.TERRAIN_CELLS+int(cell.y))*6
		var indices: PackedInt32Array = terrain_arrays[Mesh.ARRAY_INDEX]
		var hit: Variant = null
		for triangle in [0,3]:
			var found: Variant = Geometry3D.segment_intersects_triangle(Vector3(pos.x,50,pos.y),Vector3(pos.x,-10,pos.y),vertices[indices[first+triangle]],vertices[indices[first+triangle+1]],vertices[indices[first+triangle+2]])
			if found != null: hit = found
		terrain_matches = terrain_matches and hit != null and absf(hit.y-world.terrain_height_at(pos)) < 0.001
	check.call(clear,"Every complete tree canopy, including wind, stays outside the protected building area")
	check.call(sides.min() >= 24 and species_counts.size() == 3,"All four map edges have a mix of Mediterranean tree species")
	check.call(grounded and terrain_matches,"Tree planting follows the rendered hillside triangles and buries root flares")
	for species in Trees.SPECIES:
		for variant in range(Trees.VARIANTS):
			var model := Trees.recipe(species,variant)
			check.call(model.wood == Trees.recipe(species,variant).wood and model.foliage == Trees.recipe(species,variant).foliage,"%s %d: repeated trees share cached meshes" % [species,variant])
			var valid := true
			var triangles := 0
			for part in ["wood","foliage"]:
				var report := MeshAudit.audit(model[part])
				valid = valid and report.finite and report.winding and not report.degenerate
				triangles += MeshAudit.triangles(model[part]).size()
			check.call(valid,"%s %d: branch and leaf meshes have finite normals, correct winding and no collapsed triangles" % [species,variant])
			check.call(triangles < 45000,"%s %d: detailed geometry stays within the shared-mesh budget" % [species,variant])
	var grove := world.get_node("PerimeterTrees")
	var trunks := 0
	var crowns := 0
	var planted := true
	for child in grove.get_children():
		var batch: MultiMesh = child.multimesh
		if child.name.ends_with("_wood"): trunks += batch.instance_count
		else: crowns += batch.instance_count
		# The headless dummy RenderingServer does not retain MultiMesh transforms.
		if DisplayServer.get_name() == "headless": continue
		for i in range(batch.instance_count):
			var frame := batch.get_instance_transform(i)
			planted = planted and absf(frame.origin.y-Trees.planting_height(frame,world.terrain_height_at)) < 0.001
	check.call(trunks == layout.size() and crowns == layout.size() and planted,"Live tree batches include every tree with grounded trunks and matching crowns")
	check.call(grove.get_child_count() <= 72,"The perimeter batches trees by species, variant and map edge")
