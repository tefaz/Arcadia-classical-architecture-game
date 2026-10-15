extends SceneTree

var failures := 0
var checks := 0
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func settle(frames: int = 2) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame

func record(kind: String, pos: Vector3, uid: int = 1, rotation_value: float = 0) -> Dictionary:
	return {"uid":uid,"kind":kind,"stone":0,"position":[pos.x,pos.y,pos.z],"rotation":rotation_value}

func jump_event(pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	return event

func tap_space(player: BuilderPlayer, at_msec: int) -> void:
	player.handle_jump_input(jump_event(true),at_msec)
	player.handle_jump_input(jump_event(false),at_msec+20)

func _run() -> void:
	game = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	game.testing = true
	game.sounds.enabled = false
	await settle()
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	check(game.game_mode.is_creative() and builder.ledger.creative,"New worlds default to Creative with unlimited materials")
	check(game.ui.mode_picker.is_item_disabled(1),"Survival is clearly reserved as an unavailable future mode")
	check(player.game_mode == builder.ledger.game_mode,"Flight and building resources share the same game mode")
	preload("res://tests/meshes.gd").run(check)
	await preload("res://tests/inspection.gd").run(self,game,check)
	await preload("res://tests/inventory.gd").run(self,game,check)
	var ids := {}
	for definition in BuildCatalogue.PIECES:
		check(not ids.has(definition.id),"Catalogue ID is unique: " + definition.id)
		ids[definition.id] = true
		var piece := ClassicalGeometry.create(definition.id)
		check(piece.get_child_count() > 1,"Geometry and collisions exist: " + definition.id)
		piece.free()
	await preload("res://tests/building_tools.gd").run(self,game,check)
	await preload("res://tests/group_stacks.gd").run(self,game,check)
	await preload("res://tests/corners.gd").run(self,game,check)
	await preload("res://tests/layout.gd").run(self,game,check)
	await preload("res://tests/face_placement.gd").run(self,game,check)
	await preload("res://tests/pediments.gd").run(self,game,check)
	builder.restore([])
	var foundation := builder.add_record(record("foundation",Vector3(12,0,0)))
	await settle()
	var hit := {"position":Vector3(12,0.4,0),"normal":Vector3.UP,"collider":foundation}
	var result := SnapSolver.solve("base",0,hit,builder.pieces,true,true,0)
	check(result.snapped and result.position.is_equal_approx(Vector3(12,0.4,0)),"Base attaches exactly to foundation top")
	hit.position = Vector3(14,0.2,0)
	hit.normal = Vector3.RIGHT
	result = SnapSolver.solve("foundation",0,hit,builder.pieces,true,true,0)
	check(result.position.is_equal_approx(Vector3(16,0,0)),"Foundations join edge to edge")
	hit.position = Vector3(12.24,0.4,0.26)
	hit.normal = Vector3.UP
	result = SnapSolver.solve("base",0,hit,builder.pieces,true,false,0.25)
	check(result.position.is_equal_approx(Vector3(12,0.65,0.5)),"Grid and elevation work without socket snapping")
	var base := builder.add_record(record("base",Vector3(12,0.4,0),2))
	await settle()
	hit = {"position":Vector3(12,0.9,0),"normal":Vector3.UP,"collider":base}
	result = SnapSolver.solve("shaft",0,hit,builder.pieces,true,true,0)
	check(result.position.is_equal_approx(Vector3(12,0.9,0)),"Shaft attaches to base")
	var shaft := builder.add_record(record("shaft",result.position,3))
	await settle()
	hit = {"position":Vector3(12,3.9,0),"normal":Vector3.UP,"collider":shaft}
	result = SnapSolver.solve("doric_capital",0,hit,builder.pieces,true,true,0)
	check(result.position.is_equal_approx(Vector3(12,3.9,0)),"Capital attaches to shaft")
	check(builder.placement_error("doric_capital",Transform3D(Basis.IDENTITY,result.position),[shaft.get_rid()]).is_empty(),"Valid assembled capital passes collision check")
	var capital := builder.add_record(record("doric_capital",result.position,4))
	await settle()
	hit = {"position":Vector3(12,4.5,0),"normal":Vector3.UP,"collider":capital}
	result = SnapSolver.solve("entablature",0,hit,builder.pieces,true,true,0,1)
	check(result.position.is_equal_approx(Vector3(14,4.5,0)),"Alternate anchor attaches a beam end to a capital")
	check(not builder.placement_error("foundation",Transform3D(Basis.IDENTITY,Vector3(12,0,0))).is_empty(),"Duplicate placement is rejected")
	check(not builder.placement_error("wall",Transform3D(Basis.IDENTITY,Vector3(12,0,0))).is_empty(),"Intersecting solids are rejected")
	check(not builder.placement_error("foundation",Transform3D(Basis.IDENTITY,Vector3(70,0,0))).is_empty(),"Placement beyond world bounds is rejected")
	# Real first-person raycast placement, history, and branch invalidation.
	builder.restore([])
	player.position = Vector3(12,1.05,8)
	player.look_at_point(Vector3(12,0,0))
	builder.select_slot(0)
	await settle()
	builder.update_preview()
	check(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,0,0)),"First-person ground ray creates a valid snapped preview")
	builder.place()
	check(builder.pieces.size() == 1 and builder.dirty,"Creative placement creates a real component without resources")
	builder.undo()
	check(builder.pieces.is_empty() and builder.future.size() == 1,"Undo removes a placed component")
	builder.redo()
	check(builder.pieces.size() == 1,"Redo restores a placed component")
	builder.undo()
	await settle()
	builder.place()
	check(builder.future.is_empty(),"A new edit clears the redo branch")
	await settle()
	var placed: Dictionary = builder.pieces[0].serialize()
	builder.remove_uid(int(placed.uid))
	builder.record_action({"op":"remove","piece":placed})
	builder.undo()
	check(builder.pieces.size() == 1 and builder.pieces[0].uid == int(placed.uid),"Demolition undo preserves component identity")
	# Walk-through collision for the arch, rather than a bounding box across its opening.
	builder.restore([])
	builder.add_record(record("arch",Vector3(12,0,0)))
	await settle()
	var space := game.get_world_3d().direct_space_state
	var doorway := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(12,1,-3),Vector3(12,1,3),2))
	check(doorway.is_empty(),"Arch doorway is physically open")
	var pier := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(13.7,1,-3),Vector3(13.7,1,3),2))
	check(not pier.is_empty(),"Arch piers block movement")
	var crown := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(12,3.8,-3),Vector3(12,3.8,3),2))
	check(not crown.is_empty(),"Arch voussoirs have physical collision")
	# Save round-trip and recovery behavior use isolated test files.
	var store := WorldStore.new()
	var path := "user://test-world.json"
	var records := builder.serialize()
	check(store.save_world(records,player.serialize(),{"hotbar":builder.hotbar},path),"World saves to disk")
	var loaded := store.load_world(path)
	check(not loaded.is_empty() and loaded.pieces.size() == 1 and loaded.pieces[0].kind == "arch","Saved world round-trips")
	check(store.save_world(records,player.serialize(),{},path) and FileAccess.file_exists(path+".bak"),"Previous save is retained as a backup")
	var bad := record("missing_kind",Vector3.ZERO)
	check(not WorldStore.valid_piece(bad),"Unknown saved component is rejected")
	bad = record("arch",Vector3.ZERO)
	bad.stone = 1.5
	check(not WorldStore.valid_piece(bad),"Fractional material ID is rejected")
	bad.position = [0,"bad",0]
	check(not WorldStore.valid_piece(bad),"Malformed saved coordinates are rejected")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{bad json")
	file.close()
	check(store.load_world(path).is_empty() and not store.error.is_empty(),"Damaged save fails with a recoverable message")
	check(builder.pieces.size() == 1,"Failed load leaves current buildings intact")
	var ledger := ResourceLedger.new()
	check(ledger.spend({"stone":999999}),"Creative resources are unlimited")
	ledger.creative = false
	ledger.inventory = {"stone":3}
	check(not ledger.spend({"stone":4}) and ledger.inventory.stone == 3,"Future survival resource spending is atomic")
	check(ledger.spend({"stone":2}) and ledger.inventory.stone == 1,"Future survival resource balance is usable")
	# UI state transitions must correctly pause movement and restore it after the catalogue.
	game.ui.enter_world()
	check(player.active,"Enter sanctuary enables player input")
	game.ui.show_catalogue()
	check(not player.active and game.ui.catalogue.visible,"Catalogue pauses player and releases pointer")
	builder.choose("corinthian_column")
	check(builder.selected_kind() == "corinthian_column","Library equips a part into the active slot")
	game.ui.close_overlay()
	check(player.active and not game.ui.catalogue.visible,"Closing in-game catalogue resumes play")
	game.ui.show_menu()
	game.ui.show_catalogue()
	game.ui.close_overlay()
	check(not player.active and game.ui.menu.visible,"Catalogue opened from menu returns to menu")
	# Gravity and a jump are checked in the actual controller.
	builder.restore([])
	player.position = Vector3(12,2,8)
	player.flying = false
	player.active = true
	await settle(40)
	check(player.is_on_floor() and player.position.y > 0.8 and player.position.y < 1.1,"Walking controller settles on the ground")
	Input.action_press("jump")
	await settle(3)
	Input.action_release("jump")
	check(player.position.y > 1.05,"Player can jump")
	# Controller collision and stepping use real geometry, not mocked movement.
	player.active = false
	builder.add_record(record("wall",Vector3(12,0,0)))
	player.position = Vector3(12,1,2)
	player.rotation.y = 0
	player.velocity = Vector3.ZERO
	player.active = true
	Input.action_press("forward")
	await settle(35)
	Input.action_release("forward")
	check(player.position.z > 0.45 and player.position.z < 1.2,"Walking player is stopped by a built wall")
	player.active = false
	builder.restore([])
	builder.add_record(record("steps",Vector3(12,0,0)))
	player.position = Vector3(12,1,2.5)
	player.velocity = Vector3.ZERO
	player.active = true
	Input.action_press("forward")
	await settle(30)
	Input.action_release("forward")
	check(player.position.y > 1.2 and player.position.z < 1,"Walking player climbs the temple steps")
	player.flying = true
	var initial_y := player.position.y
	Input.action_press("jump")
	await settle(5)
	Input.action_release("jump")
	check(player.position.y > initial_y,"Creative flight rises with the jump key")
	player.active = false
	# Exercise real button signals, including the save/load lambdas in the menu.
	game.ui.show_menu()
	for button in game.ui.menu.find_children("*","Button",true,false):
		if button.text == "Save sanctuary":
			button.pressed.emit()
	check(FileAccess.file_exists(WorldStore.SAVE_PATH),"Menu Save button writes the sanctuary")
	var saved_count := builder.pieces.size()
	builder.restore([])
	for button in game.ui.menu.find_children("*","Button",true,false):
		if button.text == "Load sanctuary":
			button.pressed.emit()
	check(builder.pieces.size() == saved_count,"Menu Load button restores the sanctuary")
	game.ui.show_catalogue()
	game.ui.filter_buttons.Columns.pressed.emit()
	check(game.ui.active_filter == "Columns" and not game.ui.card_buttons.foundation.visible,"Catalogue category buttons filter components")
	game.ui.card_buttons.ionic_column.pressed.emit()
	check(game.ui.preview_kind == "ionic_column","Catalogue cards update the 3D preview")
	game.ui.finish_picker.item_selected.emit(2)
	check(builder.stone == 2 and game.ui.preview_piece.stone == 2,"Catalogue finish picker updates the model and builder")
	game.ui.close_overlay()
	game.ui.hud.toast("Saved")
	await process_frame
	check(game.ui.toast_panel.visible,"Save feedback remains visible in the menu")
	# Timing is injected for deterministic tap tests; one integration test uses real input dispatch.
	game.ui.enter_world()
	player.set_flying(false)
	game.ui.hud.toast_time = 0
	tap_space(player,1000)
	check(not player.flying,"One Space tap keeps the player walking")
	tap_space(player,1200)
	check(player.flying,"Two quick Space taps enable Creative flight")
	check(is_zero_approx(game.ui.hud.toast_time),"Entering flight stays silent without an unnecessary notification")
	tap_space(player,1300)
	check(player.flying,"A third tap does not immediately toggle flight back off")
	tap_space(player,1500)
	check(not player.flying,"The next quick pair turns Creative flight off")
	check(is_zero_approx(game.ui.hud.toast_time),"Leaving flight also stays silent")
	player.reset_jump_taps()
	tap_space(player,2000)
	tap_space(player,2500)
	check(not player.flying,"Slow Space taps do not toggle flight")
	player.reset_jump_taps()
	player.handle_jump_input(jump_event(true),3000)
	player.handle_jump_input(jump_event(true,true),3100)
	player.handle_jump_input(jump_event(true),3200)
	check(not player.flying,"Holding Space and repeated press events cannot toggle flight")
	player.handle_jump_input(jump_event(false),3250)
	player.reset_jump_taps()
	tap_space(player,4000)
	game.ui.show_menu()
	game.ui.enter_world()
	tap_space(player,4100)
	check(not player.flying,"Pausing clears unfinished double-tap gestures")
	game.ui.show_catalogue()
	tap_space(player,4200)
	tap_space(player,4300)
	check(not player.flying,"Space in a menu or catalogue cannot enable flight")
	game.ui.close_overlay()
	player.set_flying(false)
	Input.parse_input_event(jump_event(true))
	await process_frame
	Input.parse_input_event(jump_event(false))
	await process_frame
	Input.parse_input_event(jump_event(true))
	await process_frame
	Input.parse_input_event(jump_event(false))
	await process_frame
	check(player.flying,"Real keyboard input dispatch recognizes double-tap Space")
	player.set_flying(true)
	player.head.rotation.x = -1.2
	player.position = Vector3(12,8,8)
	var flight_y := player.position.y
	Input.action_press("forward")
	await settle(5)
	Input.action_release("forward")
	check(is_equal_approx(player.position.y,flight_y),"WASD flight stays level while looking down to place pieces")
	Input.action_press("descend")
	await settle(5)
	Input.action_release("descend")
	check(player.position.y < flight_y,"The descent action lowers the player during Creative flight")
	player.velocity = Vector3(2,3,4)
	player.toggle_flight()
	check(not player.flying and player.velocity.is_zero_approx(),"Exiting flight clears movement velocity")
	player.set_flying(true)
	game.save_world()
	var mode_save: Dictionary = game.store.load_world()
	check(mode_save.preferences.game_mode == "creative" and mode_save.player.flying,"Save records Creative mode and flight state")
	player.set_flying(false)
	game.load_world()
	check(player.flying and game.game_mode.is_creative(),"Loading restores Creative flight and mode")
	game.game_mode.mode = GameModeState.Mode.SURVIVAL
	player.set_flying(false)
	tap_space(player,5000)
	tap_space(player,5100)
	player.toggle_flight()
	check(not player.flying and not builder.ledger.creative,"Flight shortcuts are Creative-only in the mode foundation")
	game.game_mode.restore(null)
	check(game.game_mode.is_creative(),"Older saves without a mode default to Creative")
	game.game_mode.restore("survival")
	check(game.game_mode.is_creative(),"Unavailable Survival saves fall back to playable Creative mode")
	game.empty_world()
	check(game.game_mode.is_creative() and not player.flying,"An empty sanctuary starts in Creative on foot")
	await preload("res://tests/flight_momentum.gd").run(self,game,check)
	await preload("res://tests/daylight.gd").run(self,game,check)
	await preload("res://tests/catalogue_cleanup.gd").run(self,game,check)
	await preload("res://tests/empty_hotbar.gd").run(self,game,check)
	await preload("res://tests/stack_feedback.gd").run(self,game,check)
	await preload("res://tests/modular_foundations.gd").run(self,game,check)
	await preload("res://tests/empty_slot_deletion.gd").run(self,game,check)
	await preload("res://tests/column_layout.gd").run(self,game,check)
	await preload("res://tests/pediment_seams.gd").run(self,game,check)
	await preload("res://tests/pediment_edges.gd").run(self,game,check)
	await preload("res://tests/pick_component.gd").run(self,game,check)
	await preload("res://tests/modular_roofs.gd").run(self,game,check)
	await preload("res://tests/stone_and_domes.gd").run(self,game,check)
	await preload("res://tests/roof_rotation.gd").run(self,game,check)
	await preload("res://tests/flat_roof.gd").run(self,game,check)
	await preload("res://tests/ceiling_pediments.gd").run(self,game,check)
	await preload("res://tests/ceiling_performance.gd").run(self,game,check)
	await preload("res://tests/ceiling_under_roofs.gd").run(self,game,check)
	await preload("res://tests/offset_ceiling.gd").run(self,game,check)
	await preload("res://tests/window_walls.gd").run(self,game,check)
	await preload("res://tests/wall_perimeter.gd").run(self,game,check)
	await preload("res://tests/window_corner_details.gd").run(self,game,check)
	await preload("res://tests/sprint.gd").run(self,game,check)
	await preload("res://tests/corinthian.gd").run(self,game,check)
	await preload("res://tests/classical_capitals.gd").run(self,game,check)
	await preload("res://tests/lion_statue.gd").run(self,game,check)
	print("\n%d checks; %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
