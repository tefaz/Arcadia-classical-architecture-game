extends RefCounted

static func key(tree: SceneTree, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = code == KEY_SHIFT and pressed
	event.ctrl_pressed = code == KEY_CTRL and pressed
	Input.parse_input_event(event)
	await tree.process_frame

static func motion(tree: SceneTree, position: Vector2, relative: Vector2 = Vector2.ZERO, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	tree.root.push_input(event,true)
	await tree.process_frame

static func mouse(tree: SceneTree, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	tree.root.push_input(event,true)
	await tree.process_frame

static func drag(tree: SceneTree, source: Control, destination: Control, check: Callable) -> void:
	var start := source.get_global_rect().get_center()
	var end := destination.get_global_rect().get_center()
	await motion(tree,start)
	await mouse(tree,start,true)
	await motion(tree,start+Vector2(24,12),Vector2(24,12),true)
	check.call(tree.root.gui_is_dragging(),"Pointer movement starts a native component drag")
	await motion(tree,end,end-start-Vector2(24,12),true)
	await mouse(tree,end,false)

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	builder.select_slot(0)
	builder.elevation = 0.5
	await key(tree,KEY_E,true)
	await key(tree,KEY_E,false)
	check.call(game.ui.catalogue.visible and not player.active,"Real E input opens the library and pauses movement")
	check.call(is_equal_approx(builder.elevation,0.5),"Opening E inventory never changes placement height")
	check.call(game.ui.card_buttons.size() == BuildCatalogue.PIECES.size() and game.ui.inventory_slots.size() == 10,"Creative library contains all components and the editable hotbar")
	game.ui.active_filter = "All pieces"
	game.ui._update_cards()
	game.ui.card_scroll.scroll_vertical = 0
	await tree.process_frame
	await tree.process_frame
	var slots: Array = game.ui.inventory_slots
	await drag(tree,game.ui.card_buttons.corinthian_column,slots[2],check)
	check.call(builder.hotbar[2] == "corinthian_column" and builder.hotbar[0] == "foundation","Dragging a library card changes only the requested hotbar slot")
	check.call(game.ui.card_buttons.corinthian_column.visible and game.ui.catalogue.visible,"Library drag copies unlimited components and keeps the menu open")
	check.call(slots[2].component_icon.kind == "corinthian_column" and builder.dirty,"Dropped assignments update the hotbar display and are marked for saving")
	var second: String = builder.hotbar[3]
	await drag(tree,slots[2],slots[3],check)
	check.call(builder.hotbar[2] == second and builder.hotbar[3] == "corinthian_column","Dragging between hotbar slots swaps their assignments")
	game.ui.card_scroll.ensure_control_visible(game.ui.card_buttons.urn)
	await tree.process_frame
	await tree.process_frame
	await drag(tree,game.ui.card_buttons.urn,slots[9],check)
	check.call(builder.hotbar[9] == BuildCatalogue.TOOL_KIND,"Native drag cannot overwrite fixed Stack tool slot")
	check.call(not slots[1]._can_drop_data(Vector2.ZERO,{"arcadia_component":true,"kind":"unknown"}) and not slots[1]._can_drop_data(Vector2.ZERO,"invalid"),"Drop targets reject invalid component data")
	var count := builder.pieces.size()
	check.call(count == SanctuaryWorld.sample_pavilion().size(),"Inventory mouse input does not place or demolish world components")
	check.call(builder.assign_slot(0,"arch"),"Assignment to the currently selected slot succeeds")
	check.call(builder.selected_kind() == "arch" and builder.ghost.kind == "arch","Replacing the selected slot rebuilds the correct placement preview")
	check.call(not builder.assign_slot(9,"wall") and not builder.swap_slots(9,1),"Builder also protects the Stack tool slot from assignments and swaps")
	game.save_world()
	builder.assign_slot(3,"wall")
	game.load_world()
	check.call(builder.hotbar[3] == "corinthian_column","Custom hotbar assignments persist through save and load")
	await key(tree,KEY_E,true)
	await key(tree,KEY_E,false)
	check.call(player.active and not game.ui.catalogue.visible,"E closes the library and resumes building")
	await key(tree,KEY_PAGEUP,true)
	await key(tree,KEY_PAGEUP,false)
	check.call(is_equal_approx(builder.elevation,0.25),"Page Up raises the placement preview after E is reassigned")
	await key(tree,KEY_PAGEDOWN,true)
	await key(tree,KEY_PAGEDOWN,false)
	check.call(is_zero_approx(builder.elevation),"Page Down lowers the placement preview")
	player.set_flying(true)
	player.position = Vector3(12,10,8)
	var altitude := player.position.y
	await key(tree,KEY_SHIFT,true)
	for _frame in range(8): await tree.physics_frame
	check.call(player.position.y < altitude and is_equal_approx(player.velocity.y,-player.walk_speed*1.6),"Real Shift input descends at normal Creative flight speed")
	await key(tree,KEY_SHIFT,false)
	for _frame in range(16): await tree.physics_frame
	altitude = player.position.y
	await key(tree,KEY_CTRL,true)
	await tree.physics_frame
	await tree.physics_frame
	check.call(is_equal_approx(player.position.y,altitude),"Ctrl no longer changes flight altitude")
	await key(tree,KEY_CTRL,false)
	player.set_flying(false)
	await key(tree,KEY_SHIFT,true)
	check.call(Input.is_action_pressed("sprint"),"Shift still activates sprint while walking")
	await key(tree,KEY_SHIFT,false)
	game.ui.show_menu()
	game.ui.show_catalogue()
	await key(tree,KEY_E,true)
	await key(tree,KEY_E,false)
	check.call(game.ui.menu.visible and not player.active,"E closes a library opened from the main menu back to that menu")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
