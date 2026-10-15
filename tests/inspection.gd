extends RefCounted

const Tools := preload("res://tests/building_tools.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	check.call(builder.is_empty_handed() and not is_instance_valid(builder.ghost),"Fresh sanctuary starts on an editable empty building slot")
	check.call(builder.hotbar.size() == 10 and game.ui.inventory_slots.size() == 10,"The hotbar has nine building slots and the Stack tool, with no Inspect slot")
	game.ui.enter_world()
	builder.select_slot(0)
	await Tools.key(tree,KEY_0)
	check.call(builder.selected_slot == 0,"The retired 0 shortcut cannot select a hidden Inspect slot")
	builder.clear_slot(8)
	await Tools.key(tree,KEY_9)
	check.call(builder.selected_slot == 8 and builder.is_empty_handed() and not is_instance_valid(builder.ghost),"The 9 shortcut selects an ordinary editable empty slot without a ghost")
	await Tools.key(tree,KEY_T)
	check.call(builder.anchor == 0,"Build shortcuts remain safe with no piece equipped")
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_DOWN)
	check.call(builder.is_stack_tool(),"The wheel reaches Stack immediately after building slot 9")
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_DOWN)
	check.call(builder.selected_slot == 0,"The wheel wraps from Stack to building slot 1")
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	check.call(builder.is_stack_tool(),"The wheel wraps backward from slot 1 to Stack")
	builder.select_slot(8)
	game.ui.show_catalogue()
	check.call(game.ui.card_buttons.has(game.ui.preview_kind),"The library opens safely from an empty building slot")
	builder.choose("urn")
	check.call(builder.selected_slot == 8 and builder.hotbar[8] == "urn" and builder.is_building(),"The former default empty slot can be filled like any other building slot")
	builder.clear_slot(8)
	game.ui.close_overlay()
	game.save_world()
	var saved: Dictionary = game.store.load_world()
	check.call(saved.preferences.slot == 8 and saved.preferences.hotbar.size() == 10,"New saves store ten slots and the selected editable empty slot")
	builder.select_slot(0)
	game.load_world()
	check.call(builder.is_empty_handed() and not is_instance_valid(builder.ghost),"Loading preserves the selected empty slot")
	# Legacy bars lose only Inspect: all nine editable assignments stay in place.
	var old_bar := BuildCatalogue.HOTBAR.slice(0,9)
	old_bar[8] = "urn"
	old_bar[3] = ""
	old_bar.append("")
	old_bar.append(BuildCatalogue.TOOL_KIND)
	for slot in [3,9,10]:
		game.store.save_world(builder.serialize(),player.serialize(),{"hotbar":old_bar,"slot":slot,"last_build_slot":2})
		game.load_world()
		var expected := 9 if slot == 10 else 3
		check.call(builder.hotbar == old_bar.slice(0,9)+[BuildCatalogue.TOOL_KIND] and builder.selected_slot == expected,"Legacy eleven-slot saves preserve assignments and migrate empty/Inspect/Stack selections correctly")
	old_bar.remove_at(10)
	game.store.save_world(builder.serialize(),player.serialize(),{"hotbar":old_bar,"slot":9})
	game.load_world()
	check.call(builder.selected_slot == 3 and builder.hotbar.size() == 10,"Legacy ten-slot Inspect saves select an existing editable empty slot")
	old_bar[3] = "wall"
	game.store.save_world(builder.serialize(),player.serialize(),{"hotbar":old_bar,"slot":9,"last_build_slot":2})
	game.load_world()
	check.call(builder.selected_slot == 2 and builder.hotbar.slice(0,9) == old_bar.slice(0,9),"A fully populated legacy Inspect save selects the previous build slot without erasing assignments")
	game.store.save_world(builder.serialize(),player.serialize(),{"hotbar":old_bar.slice(0,9),"slot":4})
	game.load_world()
	check.call(builder.selected_slot == 4 and builder.hotbar.size() == 10 and builder.hotbar[9] == BuildCatalogue.TOOL_KIND,"Original nine-slot saves preserve their selection and gain only the Stack tool")
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	game.save_world()
	builder.select_slot(0)
	game.load_world()
	check.call(builder.is_stack_tool(),"A new ten-slot save retains Stack rather than treating it as legacy Inspect")
	check.call(game.world.sky_fill.light_energy > 0 and not game.world.sky_fill.shadow_enabled,"Shaded surfaces receive a gentle daylight fill")
	game._change_setting("shade_light",0.68)
	check.call(is_equal_approx(game.world.environment.ambient_light_energy,0.68) and is_equal_approx(float(game.settings.get_value("controls","shade_light")),0.68),"Shade brightness setting applies and persists")
	game._change_setting("shade_light",0.58)
	var terrain_arrays: Array = game.world.terrain.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = terrain_arrays[Mesh.ARRAY_NORMAL]
	var upward := true
	for normal in normals: upward = upward and normal.y > 0
	check.call(upward,"Procedural landscape surfaces face upward")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	game.empty_world()
	check.call(builder.is_empty_handed() and not is_instance_valid(builder.ghost),"A fresh empty sanctuary begins on an editable empty slot")
	builder.restore(SanctuaryWorld.sample_pavilion())
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	game.ui.show_menu()
