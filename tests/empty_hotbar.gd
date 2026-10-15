extends RefCounted

const Inventory := preload("res://tests/inventory.gd")

static func begin_drag(tree: SceneTree, source: Control, check: Callable) -> Vector2:
	var start := source.get_global_rect().get_center()
	await Inventory.motion(tree,start)
	await Inventory.mouse(tree,start,true)
	await Inventory.motion(tree,start+Vector2(24,12),Vector2(24,12),true)
	check.call(tree.root.gui_is_dragging(),"A filled hotbar slot starts a native drag")
	return start

static func drag_out(tree: SceneTree, source: Control, point: Vector2, check: Callable) -> void:
	var start := await begin_drag(tree,source,check)
	await Inventory.motion(tree,point,point-start-Vector2(24,12),true)
	await Inventory.mouse(tree,point,false)

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var ui: ArcadiaInterface = game.ui
	var slots: Array = ui.inventory_slots
	var outside := Vector2(40,tree.root.size.y/2)
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(0)
	game.ui.enter_world()
	ui.show_catalogue()
	await tree.process_frame
	await tree.process_frame
	var before := builder.serialize()
	var history := builder.history.duplicate(true)
	await drag_out(tree,slots[0],outside,check)
	check.call(builder.hotbar[0].is_empty() and builder.selected_slot == 0 and builder.dirty,"Releasing a selected item outside the hotbar empties just its slot and marks it for saving")
	check.call(builder.is_empty_handed() and not builder.is_building() and not is_instance_valid(builder.ghost),"An emptied selected slot has no ghost and behaves like empty hands")
	check.call(slots[0].caption.text.is_empty() and slots[0].component_icon.kind.is_empty(),"Cleared slots display an empty cell")
	check.call(slots.size() == 10 and slots[9].caption.text == "Stack tool" and slots[9].component_icon.kind == BuildCatalogue.TOOL_KIND,"The hotbar has nine editable slots and only the fixed Stack tool")
	# Empty slots remain valid drop targets, and swapping into one moves the component.
	await Inventory.drag(tree,slots[1],slots[0],check)
	check.call(builder.hotbar[0] == "doric_column" and builder.hotbar[1].is_empty() and builder.ghost.kind == "doric_column","Dragging onto an empty slot moves the component and refreshes the equipped ghost")
	check.call(slots[1]._get_drag_data(Vector2.ZERO) == null,"Empty editable slots cannot start a drag")
	await Inventory.drag(tree,slots[0],slots[9],check)
	check.call(builder.hotbar[0] == "doric_column" and builder.hotbar[9] == BuildCatalogue.TOOL_KIND,"Dropping onto the fixed Stack tool preserves both slots")
	var gap := Vector2((slots[0].get_global_rect().end.x+slots[1].get_global_rect().position.x)/2,slots[0].get_global_rect().get_center().y)
	await drag_out(tree,slots[0],gap,check)
	check.call(builder.hotbar[0] == "doric_column","Releasing in a gap inside the hotbar keeps the assignment")
	# Cancellation is different from releasing outside the bar.
	await begin_drag(tree,slots[0],check)
	await Inventory.motion(tree,outside,Vector2.ZERO,true)
	await Inventory.key(tree,KEY_ESCAPE,true)
	await Inventory.key(tree,KEY_ESCAPE,false)
	await Inventory.mouse(tree,outside,false)
	check.call(builder.hotbar[0] == "doric_column" and not tree.root.gui_is_dragging(),"Escape cancels a drag without emptying its source")
	if not ui.catalogue.visible: ui.show_catalogue()
	# Releasing on library content also counts as outside; the library copy remains available.
	ui.card_scroll.ensure_control_visible(ui.card_buttons.foundation)
	await tree.process_frame
	await Inventory.drag(tree,slots[0],ui.card_buttons.foundation,check)
	check.call(builder.hotbar[0].is_empty() and ui.card_buttons.foundation.visible,"Dragging a hotbar item onto library content clears its assignment")
	var empty_layout: Array = builder.hotbar.duplicate()
	await drag_out(tree,ui.card_buttons.foundation,outside,check)
	check.call(builder.hotbar == empty_layout,"Dropping a library copy outside the hotbar leaves assignments intact")
	await Inventory.drag(tree,ui.card_buttons.foundation,slots[0],check)
	check.call(builder.hotbar[0] == "foundation" and is_instance_valid(builder.ghost),"A library card refills an empty selected slot immediately")
	# Clear all uses a real button click and leaves fixed slots and the building untouched.
	var clear_at := ui.clear_hotbar_button.get_global_rect().get_center()
	await Inventory.motion(tree,clear_at)
	await Inventory.mouse(tree,clear_at,true)
	await Inventory.mouse(tree,clear_at,false)
	check.call(builder.hotbar.slice(0,9).all(func(kind): return kind.is_empty()) and ui.clear_hotbar_button.disabled,"Clear slots 1–9 empties the entire editable hotbar in one click")
	check.call(builder.hotbar[9] == BuildCatalogue.TOOL_KIND,"Clear all preserves the dedicated Stack tool")
	check.call(builder.serialize() == before and builder.history == history,"Hotbar removal never changes placed buildings or their undo history")
	check.call(not builder.clear_slot(9) and not builder.clear_slot(10) and not builder.clear_slot(-1),"The builder protects fixed slots and rejects invalid clearing requests")
	ui.close_overlay()
	for slot in range(9):
		builder.select_slot(slot)
		builder.update_preview()
		builder.place()
		check.call(builder.is_empty_handed() and not builder.valid and not is_instance_valid(builder.ghost),"Empty slot %d blocks placement without creating a ghost" % (slot+1))
	await Inventory.key(tree,KEY_T,true)
	await Inventory.key(tree,KEY_T,false)
	await Inventory.key(tree,KEY_PAGEUP,true)
	await Inventory.key(tree,KEY_PAGEUP,false)
	check.call(builder.anchor == 0 and is_zero_approx(builder.elevation),"Build shortcuts remain safe with an empty editable slot selected")
	# Entirely empty and partially empty assignments survive the actual save/load path.
	builder.select_slot(4)
	game.save_world()
	builder.assign_slot(0,"wall")
	game.load_world()
	check.call(builder.hotbar.slice(0,9).all(func(kind): return kind.is_empty()) and builder.selected_slot == 4 and not is_instance_valid(builder.ghost),"A saved empty hotbar reloads with its selected empty slot intact")
	ui.show_catalogue()
	check.call(ui.card_buttons.has(ui.preview_kind) and ui.catalogue.visible,"The library opens safely when every building slot is empty")
	await Inventory.drag(tree,ui.card_buttons.foundation,slots[4],check)
	check.call(builder.hotbar[4] == "foundation" and builder.ghost.kind == "foundation" and not ui.clear_hotbar_button.disabled,"The cleared hotbar is ready to refill from the library")
	game.save_world()
	builder.assign_slot(1,"arch")
	game.load_world()
	check.call(builder.hotbar[4] == "foundation" and builder.hotbar[1].is_empty(),"Partly empty hotbars preserve components and blanks through save/load")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	ui.show_menu()
