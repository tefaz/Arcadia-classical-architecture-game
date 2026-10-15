extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Layout := preload("res://tests/layout.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func room(kind: String, angle: float) -> Array:
	var size := BuildCatalogue.piece_size(kind)
	var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,0.4,0))
	var records := [Tools.record("foundation" if size.x == 4 else "foundation_large",Vector3(12,0,0),1,angle)]
	for record in Layout.room("wall",size.x,size.z,frame):
		record.uid += 1
		records.append(record)
	return records

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	for kind in BuildCatalogue.STONE_ROOF_KINDS+BuildCatalogue.DOME_KINDS:
		for finish in range(3):
			var piece := ClassicalGeometry.create(kind,finish)
			var correct := true
			for child in piece.get_children():
				if child is MeshInstance3D: correct = correct and child.material_override == ClassicalGeometry.materials[finish]
			check.call(correct,kind+": every visible surface uses the selected stone finish "+str(finish))
			piece.free()
	var face: Variant = MeshChecks.front_hit(ClassicalGeometry.get_recipe("stone_roof_left"),Vector3(0.5,4,0.5),Vector3(0.5,0,0.5))
	var joint: Variant = MeshChecks.front_hit(ClassicalGeometry.get_recipe("stone_roof_left"),Vector3(0.5,4,0),Vector3(0.5,0,0))
	check.call(face != null and joint != null and face.y-joint.y > 0.03,"The stone roof has broad slabs with genuinely recessed joints")
	for kind in BuildCatalogue.STONE_ROOF_KINDS:
		var profile := BuildCatalogue.roof_profile(kind)
		var gable := "pediment_crown" if profile.ends_with("half") else ("pediment_left" if profile == "left" else "pediment_right")
		builder.restore([Tools.record(gable,Vector3(12,4,0))])
		await Tools.settle(tree)
		var size := BuildCatalogue.piece_size(gable)
		var offset := -1.0 if profile == "left_half" else (1.0 if profile == "right_half" else 0.0)
		var hit := {"position":Vector3(12+offset,4+size.y/2,-0.31),"normal":Vector3.FORWARD,"collider":builder.pieces[0]}
		var solution := SnapSolver.solve(kind,0,hit,builder.pieces,true,true,0)
		check.call(solution.snapped and solution.position.is_equal_approx(Vector3(12+offset,4,-2)),kind+": fits the same pediment profile as its terracotta counterpart")
		check.call(builder.placement_error(kind,Transform3D(Basis.IDENTITY,solution.position)).is_empty(),"Stone roof gable cutbacks fit without overlapping the cornice")
		builder.restore([Tools.record(kind,Vector3(12,4,0))])
		hit = {"position":Vector3(12,4+BuildCatalogue.piece_size(kind).y/2+0.05,2),"normal":Vector3.BACK,"collider":builder.pieces[0]}
		solution = SnapSolver.solve("roof_"+profile,0,hit,builder.pieces,true,true,0)
		check.call(solution.snapped and solution.position.is_equal_approx(Vector3(12,4,4)),"Stone and terracotta roof bays can join without changing their spacing")
	for kind in BuildCatalogue.DOME_KINDS:
		var size := BuildCatalogue.piece_size(kind)
		for angle in [0.0,PI/4]:
			builder.restore(room(kind,angle))
			await Tools.settle(tree)
			var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,0.4,0))
			var source: BuildPiece
			for piece in builder.pieces:
				var local: Vector3 = frame.affine_inverse()*piece.position
				if piece.kind == "wall" and is_equal_approx(local.z,size.z/2):
					source = piece
					break
			var top := source.position+Vector3.UP*4.1
			var hit := {"position":top,"normal":Vector3.UP,"collider":source}
			var solution := SnapSolver.solve(kind,angle,hit,builder.pieces,true,true,0)
			var expected := Vector3(12,4.5,0)
			check.call(solution.snapped and solution.position.is_equal_approx(expected),kind+": a top hit centres the roof over the complete matching wall run at %.0f degrees" % rad_to_deg(angle))
			check.call(builder.placement_error(kind,Transform3D(frame.basis,solution.position)).is_empty(),"The square dome base fits all four room walls without overlap")
			var dome := builder.add_record(Tools.record(kind,expected,builder.next_uid,angle,1))
			await Tools.settle(tree)
			check.call(dome.visual_bounds.size.is_equal_approx(size),"The dome's square base and crown reach exactly their advertised dimensions")
			var query := PhysicsPointQueryParameters3D.new()
			query.collision_mask = 2
			query.position = expected+Vector3.UP*(size.y/2)
			check.call(game.get_world_3d().direct_space_state.intersect_point(query).is_empty(),"The dome's interior remains empty and usable")
			query.position = expected+Vector3.UP*(size.y-0.05)
			check.call(not game.get_world_3d().direct_space_state.intersect_point(query).is_empty(),"The curved dome shell has a solid crown")
			query.position = expected+frame.basis*Vector3(size.x/2-0.05,0.08,size.z/2-0.05)
			check.call(not game.get_world_3d().direct_space_state.intersect_point(query).is_empty(),"The square coping covers the room corners outside the round dome")
		var parts := ClassicalGeometry.get_recipe(kind)
		var outside: Variant = MeshChecks.front_hit(parts,Vector3(0,size.y+2,0),Vector3(0,0,0))
		var inside: Variant = MeshChecks.front_hit(parts,Vector3(0,0.05,0),Vector3(0,size.y+2,0))
		check.call(outside != null and inside != null and outside.y > inside.y and outside.y-inside.y < 0.3,"Both the outer dome and its hollow inner ceiling are visible with finite shell thickness")
	# Native wall-top placement, material selection, persistence, picking and stacking.
	builder.restore(room("dome",0))
	builder.stone = 1
	builder.choose("dome")
	builder.angle = 0
	builder.elevation = 0
	player.position = Vector3(12,7,8)
	player.look_at_point(Vector3(12,4.5,2))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,4.5,0)),"A real wall-top ray previews the dome over the room with no manual height adjustment")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.back().kind == "dome" and builder.pieces.back().stone == 1,"Native placement creates a marble dome")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Dome geometry and stone finish survive undo/redo and save/load")
	var dome: BuildPiece = builder.pieces.back()
	await Tools.aim(tree,game,dome)
	builder.clear_slot(8)
	builder.select_slot(8)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "dome" and builder.stone == 1,"Middle-click picks a dome and its matching marble finish")
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	builder.begin_stack()
	builder.finish_stack_selection()
	player.position = Vector3(40,10,40)
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	builder.change_stack_count(1)
	check.call(builder.stack_valid and builder.stack_copies.size() == 1 and builder.stack_copies[0].position.is_equal_approx(Vector3(16,4.5,0)),"The stack tool repeats domes using the square base footprint")
	check.call(builder.confirm_stack(),"A dome stack confirms as ordinary stone components")
	builder.undo()
	check.call(builder.serialize() == records,"Undo removes a copied dome without changing the original room")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.active_filter = "All pieces"
	game.ui._update_cards()
	game.ui.show_menu()
