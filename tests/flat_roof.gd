extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Layout := preload("res://tests/layout.gd")
const Plan := preload("res://src/building/stack_plan.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	var anchors := BuildCatalogue.sockets("flat_roof").filter(func(socket): return socket.family == "stack" and socket.normal.y < -0.5)
	check.call(anchors.size() == 9,"A flat cover offers centre, four edge and four corner anchors")
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,4,0))
		builder.restore([Tools.record("entablature",frame.origin,1,angle)])
		await Tools.settle(tree)
		var hit := {"position":frame*Vector3(0,0.75,0),"normal":Vector3.UP,"collider":builder.pieces[0]}
		for anchor in range(9):
			var solution := SnapSolver.solve("flat_roof",angle,hit,builder.pieces,true,true,0,anchor)
			var expected: Vector3 = frame*Vector3(0,0.75,0)-frame.basis*anchors[anchor].position
			check.call(solution.snapped and solution.position.is_equal_approx(expected),"Flat cover anchor %d fits exactly above a rotated entablature at %.0f degrees" % [anchor,rad_to_deg(angle)])
			check.call(builder.placement_error("flat_roof",Transform3D(frame.basis,expected)).is_empty(),"The flat cover rests on the entablature without overlapping it")
		# The same corner can attach to the beam's end, rather than its midpoint.
		hit.position = frame*Vector3(-2,0.75,0)
		var corner := SnapSolver.solve("flat_roof",angle,hit,builder.pieces,true,true,0,5)
		check.call(corner.snapped and corner.position.is_equal_approx(frame*Vector3(0,0.75,2)),"A corner anchor reaches the exact beam endpoint")
		# Anchors also work on open ground and without socket snapping.
		var ground := {"position":Vector3(12,0,0),"normal":Vector3.UP,"collider":null}
		var free := SnapSolver.solve("flat_roof",angle,ground,[],false,false,0,8)
		check.call(free.position.is_equal_approx(ground.position-frame.basis*anchors[8].position),"Free placement honours the chosen corner anchor")
	# Four tiles cover an eight-metre room, all on one support plane.
	builder.restore(Layout.room("entablature",8,8,Transform3D(Basis.IDENTITY,Vector3(12,4,0))))
	await Tools.settle(tree)
	var errors: Array = []
	for x in [10,14]:
		for z in [-2,2]:
			var position := Vector3(x,4.75,z)
			var error := builder.placement_error("flat_roof",Transform3D(Basis.IDENTITY,position))
			if not error.is_empty(): errors.append(error)
			builder.add_record(Tools.record("flat_roof",position,builder.next_uid))
			await Tools.settle(tree)
	check.call(errors.is_empty(),"Four flat covers tile an 8 × 8 m entablature ring without gaps or overlaps")
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = 2
	query.position = Vector3(12,4.5,0)
	check.call(game.get_world_3d().direct_space_state.intersect_point(query).is_empty(),"The flat ceiling leaves the room below empty")
	var seam := PhysicsShapeQueryParameters3D.new()
	var probe := SphereShape3D.new()
	probe.radius = 0.005
	seam.shape = probe
	seam.collision_mask = 2
	seam.transform.origin = Vector3(12,4.85,0)
	check.call(game.get_world_3d().direct_space_state.intersect_shape(seam).size() == 4,"All four solid roof tiles meet at the centre seam")
	for finish in range(3):
		var piece := ClassicalGeometry.create("flat_roof",finish)
		check.call(piece.visual_bounds.position.is_equal_approx(Vector3(-2,0,-2)) and piece.visual_bounds.size.is_equal_approx(Vector3(4,0.2,4)),"Flat cover bounds remain exactly 4 × 0.2 × 4 m")
		var matching := true
		for child in piece.get_children():
			if child is MeshInstance3D: matching = matching and child.material_override == ClassicalGeometry.materials[finish]
		check.call(matching,"Flat cover surfaces use the selected stone finish "+str(finish))
		piece.free()
	# Side-face snapping extends the cover in all four directions, regardless of anchor.
	builder.restore([Tools.record("flat_roof",Vector3(12,4,0))])
	await Tools.settle(tree)
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var hit := {"position":Vector3(12,4.1,0)+direction*2,"normal":direction,"collider":builder.pieces[0]}
		var solution := SnapSolver.solve("flat_roof",0,hit,builder.pieces,true,true,0,8)
		check.call(solution.snapped and solution.position.is_equal_approx(Vector3(12,4,0)+direction*4),"Side snapping tiles a flat cover along "+str(direction))
		check.call(builder.placement_error("flat_roof",Transform3D(Basis.IDENTITY,solution.position)).is_empty(),"Neighbouring flat roof tiles meet without overlap")
	# Native default edge placement, corner selection and centre selection.
	builder.restore([Tools.record("entablature",Vector3(12,4,2))])
	builder.choose("flat_roof")
	builder.angle = 0
	builder.stone = 1
	player.position = Vector3(12,7,8)
	player.look_at_point(Vector3(12,4.75,2))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.anchor == 1 and builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,4.75,0)),"Equipping a flat roof defaults to an edge anchor extending inward from the entablature")
	for i in range(5): await Tools.key(tree,KEY_T)
	player.look_at_point(Vector3(10.1,4.75,2))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.anchor == 6 and builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,4.75,0)),"Native T input selects a corner and aligns it to the beam end")
	for i in range(3): await Tools.key(tree,KEY_T)
	check.call(builder.anchor == 0,"T can explicitly select the centre after the edge and corner anchors")
	await Tools.key(tree,KEY_T)
	player.look_at_point(Vector3(12,4.75,2))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == "flat_roof" and builder.pieces.back().stone == 1,"Native placement adds the marble flat cover above its support")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Flat cover position and finish survive undo/redo and save/load")
	await Tools.aim(tree,game,builder.pieces.back())
	builder.clear_slot(8)
	builder.select_slot(8)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "flat_roof" and builder.stone == 1 and builder.anchor == 1,"Middle-click equips a flat cover with its finish and default edge anchor")
	check.call(Plan.step("flat_roof",Basis.IDENTITY,Vector3.RIGHT) == Vector3(4,0,0) and Plan.step("flat_roof",Basis.IDENTITY,Vector3.UP).is_equal_approx(Vector3(0,0.2,0)),"Stack spacing follows the slab's exact horizontal and vertical dimensions")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
