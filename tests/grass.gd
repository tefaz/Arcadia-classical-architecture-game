extends RefCounted

const Tools = preload("res://tests/building_tools.gd")
const MeshAudit = preload("res://tests/meshes.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var meadow = game.world.grass
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	var old_quality: int = meadow.quality
	builder.restore([])
	game._apply_quality(2)
	var region := Rect2(31,3,10,10)
	var original: PackedVector3Array = meadow.visible_roots_in(region)
	check.call(original.size() > 25,"Open buildable ground has scattered grass")
	check.call(meadow.visible_roots_in(Rect2(-1,-14,26,28)).is_empty() and meadow.visible_roots_in(Rect2(-18,-14,4,44)).is_empty(),"The gravel building plot and approach stay clear of grass")
	var total := 0
	var grounded := true
	var batches_match := true
	for chunk: Dictionary in meadow.chunks.values():
		total += chunk.visible_roots.size()
		batches_match = batches_match and chunk.node.multimesh.instance_count == chunk.visible_roots.size()
		for root: Vector3 in chunk.visible_roots:
			grounded = grounded and absf(root.y-game.world.ground_height_at(Vector2(root.x,root.z))+0.012) < 0.001
		if DisplayServer.get_name() != "headless":
			for i in range(chunk.visible_roots.size()):
				var actual: Vector3 = chunk.node.transform*chunk.node.multimesh.get_instance_transform(i).origin
				batches_match = batches_match and actual.distance_to(chunk.visible_roots[i]) < 0.001
	check.call(grounded and batches_match and total > 10000 and total < 40000,"Grass batches contain grounded tufts within a bounded instance budget")
	check.call(meadow.get_child_count() <= 100,"Grass uses spatial MultiMesh batches instead of individual blade nodes")
	var audit := MeshAudit.audit(meadow.chunks.values()[0].node.multimesh.mesh)
	check.call(audit.finite and audit.winding and not audit.degenerate,"Shared folded grass blades have finite normals and valid triangles")
	var start_revision: int = meadow.revision
	builder.refresh_connections()
	check.call(meadow.revision == start_revision,"Unchanged connection refreshes do not rebuild grass")
	# Exercise previews and commit using the ordinary camera ray and mouse input.
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(36,5,15)
	player.look_at_point(Vector3(36,0,8))
	builder.assign_slot(0,"foundation")
	builder.select_slot(0)
	builder.angle = 0
	builder.elevation = 0
	await Tools.settle(tree)
	check.call(builder.valid and builder.ghost.position.distance_to(Vector3(36,0,8)) < 0.1,"Grass is decorative and permits normal ground placement")
	check.call(meadow.visible_roots_in(region) == original and meadow.revision == start_revision,"Moving the building preview leaves grass untouched")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	var cleared: PackedVector3Array = meadow.visible_roots_in(region)
	check.call(builder.pieces.size() == 1 and cleared.size() < original.size(),"A native placement immediately clears grass around the foundation")
	check.call(meadow.visible_roots_in(Rect2(33.6,5.6,4.8,4.8)).is_empty(),"No blade roots remain inside the foundation and its clearance margin")
	builder.undo()
	check.call(meadow.visible_roots_in(region) == original,"Undoing placement restores the exact previous grass")
	builder.redo()
	check.call(meadow.visible_roots_in(region) == cleared,"Redoing placement restores the same cleared ground")
	game.save_world()
	builder.restore([])
	game.load_world()
	check.call(meadow.visible_roots_in(region) == cleared,"Loading a saved building reconstructs its grass clearance")
	# Ground contact, overlaps and yaw must not clear an entire world-space box.
	builder.restore([Tools.record("flat_roof",Vector3(36,5,8))])
	check.call(meadow.visible_roots_in(region) == original,"An elevated roof leaves the grass below it intact")
	var long_wall := Tools.record("wall",Vector3(36,0,8),1,PI/4)
	long_wall.length = 8.0
	builder.restore([long_wall])
	var inverse := Transform3D(Basis(Vector3.UP,PI/4),Vector3(36,0,8)).affine_inverse()
	var rotated_clear := true
	var outside_retained := false
	for root: Vector3 in meadow.visible_roots_in(region):
		var local: Vector3 = inverse*root
		rotated_clear = rotated_clear and not (absf(local.x) < 4.35 and absf(local.z) < 0.6)
		if Vector2(root.x-36,root.z-8).length() < 3 and absf(local.z) > 1: outside_retained = true
	check.call(rotated_clear and outside_retained,"Rotated walls clear their local footprint while keeping grass beside them")
	builder.restore([Tools.record("foundation",Vector3(36,0,8)),Tools.record("foundation",Vector3(36,0,8),2)])
	builder.remove_uid(1)
	check.call(meadow.visible_roots_in(region) == cleared,"Removing one of two overlapping structures keeps the ground cleared")
	builder.remove_uid(2)
	check.call(meadow.visible_roots_in(region) == original,"Removing the final structure restores the original tufts")
	# Batched edits use the same single connection-refresh notification as stacks.
	var before_batch: int = meadow.revision
	builder.add_record(Tools.record("foundation",Vector3(36,0,8)),false)
	builder.add_record(Tools.record("foundation",Vector3(40,0,8),2),false)
	check.call(meadow.revision == before_batch,"Uncommitted batch additions do not repeatedly rebuild vegetation")
	builder.refresh_connections()
	builder.record_action({"op":"batch_add","pieces":builder.serialize()})
	check.call(meadow.revision == before_batch+1 and meadow.visible_roots_in(region).size() < cleared.size(),"Committing a batch clears all of its foundations together")
	builder.undo()
	check.call(meadow.visible_roots_in(region) == original,"Undoing a grouped edit restores all affected grass")
	builder.redo()
	check.call(meadow.visible_roots_in(region).size() < cleared.size(),"Redoing a grouped edit clears all copied footprints")
	game.empty_world()
	check.call(meadow.visible_roots_in(region) == original,"Creating an empty world restores vegetation across the map")
	var counts: Array[int] = []
	for quality in [0,1,2]:
		game._apply_quality(quality)
		counts.append(meadow.visible_roots_in(region).size())
	check.call(counts[0] < counts[1] and counts[1] < counts[2] and counts[2] == original.size(),"Graphics quality scales grass density and restores deterministic High detail")
	var level := true
	for x in [-62.0,-45.0,0.0,45.0,62.0]:
		for z in [-62.0,-45.0,0.0,45.0,62.0]: level = level and is_zero_approx(game.world.ground_height_at(Vector2(x,z)))
	check.call(level,"Rendered buildable ground stays level with the player's ground collider")
	game._apply_quality(old_quality)
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	game.ui.show_menu()
