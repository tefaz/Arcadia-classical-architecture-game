extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshAudit := preload("res://tests/meshes.gd")
const Layout := preload("res://tests/layout.gd")
const KIND := "wall_door_pediment"

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	check.call(game.ui.card_buttons.has(KIND) and BuildCatalogue.get_piece(KIND).group == "Structure","The pediment doorway has its own Structure library card")
	var recipe := ClassicalGeometry.get_recipe(KIND)
	var opening := true
	for x in [-0.8,0.0,0.8]:
		for y in [0.01,0.15,1.4,2.65]:
			for side in [-1,1]:
				opening = opening and MeshAudit.front_hit(recipe,Vector3(x,y,side*2),Vector3(x,y,-side*2)) == null
	check.call(opening,"The doorway is visually open on both faces from ground level to the lintel")
	for side in [-1,1]:
		var field: Variant = MeshAudit.front_hit(recipe,Vector3(0,3.32,side*2),Vector3(0,3.32,0))
		var rake: Variant = MeshAudit.front_hit(recipe,Vector3(0.75,3.39,side*2),Vector3(0.75,3.39,0))
		check.call(field != null and rake != null and absf(rake.z) > absf(field.z)+0.03,"A raised triangular pediment frames a recessed field on doorway face "+str(side))
	for finish in range(3):
		var piece := ClassicalGeometry.create(KIND,finish)
		var matching := true
		for child in piece.get_children():
			if child is MeshInstance3D: matching = matching and child.material_override == ClassicalGeometry.materials[finish]
		check.call(matching and is_equal_approx(piece.visual_bounds.size.x,4) and is_equal_approx(piece.visual_bounds.size.y,4.1),"The complete doorway uses stone finish %d and keeps ordinary wall dimensions" % finish)
		piece.free()
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,0.4,0))
		builder.restore([Tools.record(KIND,frame.origin,1,angle)])
		await Tools.settle(tree)
		var space := game.get_world_3d().direct_space_state
		var passable := true
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 1.75
		query.shape = capsule
		query.collision_mask = 2
		for z in [-0.8,-0.3,0.0,0.3,0.8]:
			for x in [-0.5,0.0,0.5]:
				query.transform = Transform3D(frame.basis,frame*Vector3(x,0.9,z))
				passable = passable and space.intersect_shape(query).is_empty()
		check.call(passable,"The real player capsule clears the doorway and threshold at %.0f degrees" % rad_to_deg(angle))
		var solid := true
		for point in [Vector3(1.5,1.2,0),Vector3(-1.5,1.2,0),Vector3(0,2.85,0)]:
			var ray := PhysicsRayQueryParameters3D.create(frame*(point+Vector3.BACK*2),frame*(point+Vector3.FORWARD*2),2)
			solid = solid and not space.intersect_ray(ray).is_empty()
		check.call(solid,"Doorway piers and lintel retain real collision")
		var wall_hit := {"position":frame*Vector3(2,2.05,0.08),"normal":frame.basis.z,"collider":builder.pieces[0]}
		var solution := SnapSolver.solve("wall_window_pediment",angle-PI/2,wall_hit,builder.pieces,true,true,0)
		check.call(solution.snapped and builder.placement_error("wall_window_pediment",Transform3D(Basis(Vector3.UP,angle-PI/2),solution.position)).is_empty(),"A window wall mitres directly into the doorway wall")
	# Walk through both ways with the actual movement controller.
	builder.restore([Tools.record(KIND,Vector3(12,0,0))])
	player.set_flying(false)
	for side in [-1,1]:
		player.position = Vector3(12,0.9,side*2)
		player.look_at_point(Vector3(12,1.62,-side*3))
		player.velocity = Vector3.ZERO
		await Tools.settle(tree)
		Input.action_press("forward")
		for i in range(65): await tree.physics_frame
		Input.action_release("forward")
		check.call(player.position.z*side < -1 and player.position.y > 0.8,"The player can walk fully through the doorway from side "+str(side))
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	# A door is part of the same perimeter and flush-ceiling contract as other walls.
	var walls := Layout.room("wall",3.56,3.56,Transform3D(Basis.IDENTITY,Vector3(12,0.4,0)))
	walls[0].kind = KIND
	builder.restore(walls)
	await Tools.settle(tree)
	var source: BuildPiece = builder.pieces[0]
	var cover_hit := {"position":source.position+Vector3.UP*4.1,"normal":Vector3.UP,"collider":source}
	var cover := SnapSolver.solve("flat_roof",0,cover_hit,builder.pieces,true,true,0,1)
	check.call(cover.label.begins_with("Flush wall cover") and cover.position.is_equal_approx(Vector3(12,4.5,0)) and builder.placement_error("flat_roof",Transform3D(Basis.IDENTITY,cover.position)).is_empty(),"A doorway room accepts the same flush ceiling as plain and window walls")
	# Native placement, finish selection, history, loading and picking.
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	builder.choose(KIND)
	builder.angle = 0
	builder.stone = 0
	player.position = Vector3(12,5,7)
	player.look_at_point(Vector3(12,0.4,0))
	await Tools.key(tree,KEY_M)
	await Tools.settle(tree)
	check.call(builder.valid,"The doorway previews on an ordinary foundation")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == KIND and builder.pieces.back().stone == 1,"A native click places the doorway in the selected marble finish")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Doorway identity, finish and position survive undo/redo and save/load")
	player.position = Vector3(13.4,1.3,5)
	player.look_at_point(Vector3(13.4,2,0))
	await Tools.settle(tree)
	builder.clear_slot(8)
	builder.select_slot(8)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == KIND and builder.stone == 1,"Middle-clicking the jamb equips the doorway and its finish")
	# Picking through the opening must reach the object behind it.
	builder.restore([Tools.record(KIND,Vector3(12,0,0)),Tools.record("urn",Vector3(12,0,-2),2,0,2)])
	player.position = Vector3(12,0.9,4)
	player.look_at_point(Vector3(12,0.7,-2))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "urn" and builder.stone == 2,"The open door permits ordinary interaction with pieces behind it")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
