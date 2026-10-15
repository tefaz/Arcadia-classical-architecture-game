extends RefCounted

const Tools := preload("res://tests/building_tools.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,12,40)
	check.call(game.ui.card_buttons.has("rectangular_pedestal") and game.ui.card_buttons.has("lion_statue"),"The pedestal and lion appear in the draggable building library")
	check.call("lion_statue" not in BuildCatalogue.SCULPTURE_KINDS,"The full-depth lion does not occupy the shallow pediment relief sockets")
	for kind in ["rectangular_pedestal","lion_statue"]:
		for finish in range(3):
			var piece := ClassicalGeometry.create(kind,finish)
			check.call(piece.visual_bounds.position.y == 0 and piece.visual_bounds.size.is_equal_approx(BuildCatalogue.piece_size(kind)),kind+": complete geometry matches its dimensions and bottom pivot")
			var matching := true
			var count := 0
			for child in piece.get_children():
				if child is MeshInstance3D:
					matching = matching and child.material_override == ClassicalGeometry.materials[finish]
					count += 1
			check.call(matching and count == 1,kind+": all carving is batched into one shared mesh with finish "+str(finish))
			piece.free()
	for angle in [0.0,PI/4,PI/2]:
		builder.restore([Tools.record("foundation",Vector3(12,0,0),1,angle)])
		await Tools.settle(tree)
		var hit := {"position":Vector3(12,0.4,0),"normal":Vector3.UP,"collider":builder.pieces[0]}
		var pedestal := SnapSolver.solve("rectangular_pedestal",angle,hit,builder.pieces,true,true,0)
		check.call(pedestal.snapped and pedestal.position.is_equal_approx(Vector3(12,0.4,0)) and builder.placement_error("rectangular_pedestal",Transform3D(Basis(Vector3.UP,angle),pedestal.position)).is_empty(),"The rectangular pedestal fits a foundation at %.0f degrees" % rad_to_deg(angle))
		var base := builder.add_record(Tools.record("rectangular_pedestal",pedestal.position,2,angle))
		await Tools.settle(tree)
		hit = {"position":Vector3(12,1.6,0),"normal":Vector3.UP,"collider":base}
		var lion := SnapSolver.solve("lion_statue",angle,hit,builder.pieces,true,true,0)
		check.call(lion.snapped and lion.position.is_equal_approx(Vector3(12,1.6,0)) and builder.placement_error("lion_statue",Transform3D(Basis(Vector3.UP,angle),lion.position)).is_empty(),"The lion centres precisely on its pedestal without overlap, rotated %.0f degrees" % rad_to_deg(angle))
	# Use actual player aim and native click to place both pieces.
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	builder.choose("rectangular_pedestal")
	builder.angle = 0
	builder.stone = 1
	player.position = Vector3(12,4,6)
	player.look_at_point(Vector3(12,0.4,0))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == "rectangular_pedestal","Native click places the rectangular pedestal")
	builder.choose("lion_statue")
	player.look_at_point(Vector3(12,1.6,0))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,1.6,0)),"The native lion preview rests on the pedestal cap")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 3 and builder.pieces.back().kind == "lion_statue","Native click places the lion on its matching pedestal")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"The lion and pedestal preserve position and marble finish through history and save/load")
	await Tools.aim(tree,game,builder.pieces.back())
	builder.clear_slot(8)
	builder.select_slot(8)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "lion_statue" and builder.stone == 1,"Middle-click equips the lion and its finish")
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	await Tools.aim(tree,game,builder.pieces.back())
	check.call(builder.begin_stack(),"The lion can be selected by the stack tool")
	builder.finish_stack_selection()
	player.position = Vector3(40,10,40)
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	builder.change_stack_count(1)
	check.call(builder.stack_valid and builder.confirm_stack(),"The stack tool duplicates the lion using its complete footprint")
	builder.undo()
	check.call(builder.serialize() == records,"Undo removes the lion copy without changing the original pair")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
