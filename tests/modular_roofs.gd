extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")
const Plan := preload("res://src/building/stack_plan.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,4,0))
		for pair in [["roof_left","roof_left",Vector3(2,2.4,0),Vector3(4,2.4,0)],
			["roof_left","roof_right",Vector3(2,2.4,0),Vector3(4,0,0)],
			["roof_left","roof_left_half",Vector3(2,2.4,0),Vector3(3,2.4,0)],
			["roof_left_half","roof_right_half",Vector3(1,1.2,0),Vector3(2,0,0)],
			["roof_right_half","roof_right",Vector3(1,0,0),Vector3(3,-2.4,0)],
			["roof_right","roof_right",Vector3(2,0,0),Vector3(4,-2.4,0)]]:
			builder.restore([Tools.record(pair[0],frame.origin,1,angle)])
			await Tools.settle(tree)
			var hit := {"position":frame*pair[2],"normal":frame.basis.x,"collider":builder.pieces[0]}
			var solution := SnapSolver.solve(pair[1],angle,hit,builder.pieces,true,true,0)
			check.call(solution.snapped and solution.position.is_equal_approx(frame*pair[3]),"%s joins %s at the exact roof pitch and ridge, rotated %.0f degrees" % [pair[1],pair[0],rad_to_deg(angle)])
			check.call(builder.placement_error(pair[1],Transform3D(frame.basis,solution.position)).is_empty(),"Modular roof pitch joins have no solid overlap")
		for kind in BuildCatalogue.ROOF_KINDS:
			builder.restore([Tools.record(kind,frame.origin,1,angle)])
			await Tools.settle(tree)
			var size := BuildCatalogue.piece_size(kind)
			for side in [-1,1]:
				var hit := {"position":frame*Vector3(0,size.y/2+0.05,side*2),"normal":frame.basis.z*side,"collider":builder.pieces[0]}
				var solution := SnapSolver.solve(kind,angle,hit,builder.pieces,true,true,0)
				check.call(solution.snapped and solution.position.is_equal_approx(frame*Vector3(0,0,side*4)),kind+": roof depth extends in exact four-metre bays in either direction")
				check.call(builder.placement_error(kind,Transform3D(frame.basis,solution.position)).is_empty(),"Repeated roof depth bays meet without overlap")
			check.call(Plan.step(kind,frame.basis,frame.basis.z).is_equal_approx(frame.basis.z*4),"The stack tool preserves roof depth without gaps from tile details")
		# Gables attach to their own profile, with both halves fitting the crown.
		for pair in [["pediment_left","roof_left",0.0],["pediment_right","roof_right",0.0],
			["pediment_crown","roof_left_half",-1.0],["pediment_crown","roof_right_half",1.0],
			["pediment","roof_left_half",-1.0],["pediment","roof_right_half",1.0]]:
			builder.restore([Tools.record(pair[0],frame.origin,1,angle)])
			await Tools.settle(tree)
			var size := BuildCatalogue.piece_size(pair[0])
			var hit := {"position":frame*Vector3(pair[2],size.y/2,-0.31),"normal":-frame.basis.z,"collider":builder.pieces[0]}
			var solution := SnapSolver.solve(pair[1],angle,hit,builder.pieces,true,true,0)
			check.call(solution.snapped and solution.position.is_equal_approx(frame*Vector3(pair[2],0,-2.0)),pair[1]+": attaches directly behind its matching pediment profile")
			check.call(builder.placement_error(pair[1],Transform3D(frame.basis,solution.position)).is_empty(),"Roof tiles clear the pediment without collision exemptions")
	# Roof-top edge aiming must continue the slope rather than stack another roof above it.
	builder.restore([Tools.record("roof_left",Vector3(12,4,0))])
	var hit := {"position":Vector3(13.8,6.33,0),"normal":Vector3(-0.6,1,0).normalized(),"collider":builder.pieces[0]}
	var solution := SnapSolver.solve("roof_right",0,hit,builder.pieces,true,true,0)
	check.call(solution.snapped and solution.position.is_equal_approx(Vector3(16,4,0)),"A roof-top high-edge hit joins the opposite slope at the ridge")
	# The room beneath a roof stays empty, while the sloping tile shell is solid.
	builder.restore([Tools.record("roof_left",Vector3(10,4,0)),Tools.record("roof_right",Vector3(14,4,0),2)])
	await Tools.settle(tree)
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = 2
	query.position = Vector3(12,5,0)
	check.call(game.get_world_3d().direct_space_state.intersect_point(query).is_empty(),"The new roof leaves a usable hollow attic instead of filling the gable volume")
	query.position = Vector3(10,5.25,0)
	check.call(game.get_world_3d().direct_space_state.intersect_point(query).size() == 1,"The tile shell itself has a solid sloping collision surface")
	# Tile geometry meets continuously at a module boundary, not just the logical sockets.
	var a: Variant = MeshChecks.front_hit(ClassicalGeometry.get_recipe("roof_left"),Vector3(1.99,4,0.1),Vector3(1.99,0,0.1))
	var b: Variant = MeshChecks.front_hit(ClassicalGeometry.get_recipe("roof_left"),Vector3(-1.99,4,0.1),Vector3(-1.99,0,0.1))
	check.call(a != null and b != null and is_equal_approx(b.y+2.4-a.y,0.012),"Roof panels keep one uninterrupted diagonal through repeated slope seams")
	# Rear gables use the same construction planes, preserving four-metre building depth.
	for kind in BuildCatalogue.ROOF_KINDS:
		builder.restore([Tools.record(kind,Vector3(12,4,0))])
		await Tools.settle(tree)
		var size := BuildCatalogue.piece_size(kind)
		var profile := BuildCatalogue.roof_profile(kind)
		var gable_kind := "pediment_crown" if size.x == 2 else ("pediment_left" if profile == "left" else "pediment_right")
		var offset := 1.0 if profile == "left_half" else (-1.0 if profile == "right_half" else 0.0)
		var rear_hit := {"position":Vector3(12,4+size.y/2+0.05,-2),"normal":Vector3.FORWARD,"collider":builder.pieces[0]}
		var rear := SnapSolver.solve(gable_kind,0,rear_hit,builder.pieces,true,true,0)
		check.call(rear.snapped and rear.position.is_equal_approx(Vector3(12+offset,4,-2)),"A matching rear gable snaps back from each roof profile onto the construction grid")
		check.call(builder.placement_error(gable_kind,Transform3D(Basis.IDENTITY,rear.position)).is_empty(),"Rear-gable placement allows the fitted roof end to trim before checking contact")
		builder.add_record(Tools.record(gable_kind,rear.position,2))
		check.call(builder.pieces[0].join_left == 1 and is_equal_approx(builder.pieces[0].visual_bounds.position.z,-1.65),"An attached rear gable trims only the roof end shell to its inside face")
		builder.remove_uid(2)
		check.call(builder.pieces[0].join_left == 0 and is_equal_approx(builder.pieces[0].visual_bounds.position.z,-2),"Removing a gable restores the full roof-depth module")
		var clean := true
		for back in [0,1]:
			for front in [0,1]:
				for part in ClassicalGeometry.get_recipe(kind,back,front):
					if not part.has("mesh"): continue
					var report := MeshChecks.audit(part.mesh)
					clean = clean and report.finite and report.winding and report.closed and not report.degenerate and report.volume < 0
		check.call(clean,"Every open and gable-trimmed roof variant has closed outward-facing geometry")
	# A complete wide building must work with real colliders, including ridge finials.
	builder.restore([])
	var errors: Array = []
	for record in SanctuaryWorld.roof_example():
		var position := Vector3(record.position[0],record.position[1],record.position[2])
		var error := builder.placement_error(record.kind,Transform3D(Basis(Vector3.UP,record.rotation),position))
		if not error.is_empty(): errors.append(record.kind+": "+error)
		builder.add_record(record)
		await Tools.settle(tree)
	check.call(errors.is_empty(),"The full 20 × 12 m roof, front/rear gables, ridge finials and colonnade fit without overlaps: "+str(errors))
	# First-person back-face snapping and native placement, history, save and picking.
	builder.restore([Tools.record("pediment_left",Vector3(12,4,0))])
	builder.choose("roof_left")
	builder.angle = 0
	builder.elevation = 0
	player.position = Vector3(12,4,-8)
	player.look_at_point(Vector3(12,5.15,-0.31))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,4,-2.0)),"A real rear-face ray previews the matching roof immediately behind a modular pediment")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == "roof_left","Native left-click places a modular terracotta roof")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Roof modules retain their exact pitch placements through undo/redo and save/load")
	builder.clear_slot(8)
	builder.select_slot(8)
	player.position = Vector3(12,4,-8)
	player.look_at_point(Vector3(12,5.25,-4.0))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "roof_left","Middle-click picking equips the correct modular roof slope")
	var roof := builder.pieces[1]
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	await Tools.aim(tree,game,roof)
	builder.begin_stack()
	builder.finish_stack_selection()
	player.position = Vector3(40,10,40)
	player.look_at_point(player.camera.global_position+Vector3.FORWARD*10)
	builder.change_stack_count(1)
	check.call(builder.stack_valid and builder.stack_copies.size() == 1 and builder.stack_copies[0].position.is_equal_approx(Vector3(12,4,-6)),"The stack tool extends a gable-attached roof by an exact four-metre depth bay")
	check.call(is_equal_approx(roof.visual_bounds.size.z,3.65) and is_equal_approx(builder.stack_copies[0].visual_bounds.size.z,4),"A repeated interior roof bay restores full depth instead of copying the gable cutback")
	check.call(builder.confirm_stack(),"Repeated roof-depth bays confirm through the normal stack tool")
	builder.undo()
	check.call(builder.serialize() == records,"Undo removes the repeated roof bay without disturbing the gable fit")
	# Existing full roofs remain intact; only their hotbar assignment migrates to a half.
	var legacy := Tools.record("roof",Vector3(12,4,0))
	builder.restore([legacy])
	var bar := BuildCatalogue.HOTBAR.duplicate()
	bar[6] = "roof"
	game.store.save_world(builder.serialize(),player.serialize(),{"hotbar":bar,"slot":6})
	game.load_world()
	check.call(builder.serialize() == [legacy] and builder.hotbar[6] == "roof_left_half","Existing whole roofs stay unchanged while old hotbar assignments migrate to a separate half")
	game.ui.show_catalogue()
	game.ui.filter_buttons.Roofs.pressed.emit()
	var visible: Array = []
	for kind in game.ui.card_buttons:
		if game.ui.card_buttons[kind].visible: visible.append(kind)
	check.call(visible == ["roof_left","roof_left_half","stone_roof_left","stone_roof_left_half"]+["flat_roof"]+BuildCatalogue.DOME_KINDS and not game.ui.card_buttons.has("roof"),"The Roofs filter offers modular slopes and domes in place of the old single roof")
	game.ui.active_filter = "All pieces"
	game.ui._update_cards()
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
