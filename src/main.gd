extends Node3D

var world: SanctuaryWorld
var player: BuilderPlayer
var builder: ClassicalBuilder
var ui: ArcadiaInterface
var sounds: BuilderSounds
var store := WorldStore.new()
var settings := ConfigFile.new()
var autosave: Timer
var testing := false
var game_mode := GameModeState.new()

func _ready() -> void:
	testing = "--test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args()
	_setup_input()
	settings.load("user://settings.cfg")
	world = SanctuaryWorld.new()
	add_child(world)
	world.set_shade_brightness(float(settings.get_value("controls","shade_light",0.58)))
	player = BuilderPlayer.new()
	player.game_mode = game_mode
	add_child(player)
	player.position = Vector3(-6, 1.05, 10)
	player.look_at_point(Vector3(-20, 3.5, -8))
	player.sensitivity = float(settings.get_value("controls","sensitivity",0.0022))
	player.camera.fov = float(settings.get_value("controls","fov",75))
	builder = ClassicalBuilder.new()
	builder.player = player
	builder.ledger.game_mode = game_mode
	add_child(builder)
	builder.geometry_changed.connect(func(): world.grass.sync_buildings(builder.pieces))
	builder.restore(SanctuaryWorld.sample_pavilion())
	sounds = BuilderSounds.new()
	add_child(sounds)
	sounds.enabled = settings.get_value("controls","sound",true)
	ui = ArcadiaInterface.new()
	ui.builder = builder
	ui.player = player
	ui.set_meta("quality",clampi(int(settings.get_value("controls","quality",1)),0,2))
	ui.set_meta("sound",sounds.enabled)
	ui.set_meta("shade_light",world.environment.ambient_light_energy)
	add_child(ui)
	ui.resume_requested.connect(_resume)
	ui.save_requested.connect(save_world)
	ui.load_requested.connect(load_world)
	ui.empty_requested.connect(empty_world)
	ui.setting_changed.connect(_change_setting)
	builder.message.connect(ui.hud.toast)
	builder.sound_requested.connect(sounds.play)
	_apply_quality(int(settings.get_value("controls","quality",1)))
	get_tree().auto_accept_quit = false
	if not testing and FileAccess.file_exists(WorldStore.SAVE_PATH):
		load_world()
	autosave = Timer.new()
	autosave.wait_time = 90
	autosave.timeout.connect(func():
		if builder.dirty and not testing:
			save_world(true)
	)
	add_child(autosave)
	autosave.start()
	if "--capture" in OS.get_cmdline_user_args():
		_capture()

func _process(delta: float) -> void:
	if player and player.active:
		world.advance_daylight(delta)

func _setup_input() -> void:
	var actions := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"sprint":KEY_SHIFT,"descend":KEY_SHIFT}
	for name_value in actions:
		if not InputMap.has_action(name_value):
			InputMap.add_action(name_value)
		var event := InputEventKey.new()
		event.physical_keycode = actions[name_value]
		InputMap.action_add_event(name_value,event)

func _resume() -> void:
	ui.enter_world()
	sounds.play("select")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if builder.is_stacking(): builder.cancel_stack()
			else: ui.escape()
			get_viewport().set_input_as_handled()
			return
		if not event.ctrl_pressed and event.keycode in [KEY_E,KEY_B,KEY_TAB]:
			if ui.catalogue.visible:
				ui.close_overlay()
			elif player.active:
				ui.show_catalogue()
			else:
				return
			get_viewport().set_input_as_handled()
			return
	if not player.active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			builder.pick_aimed_component()
			get_viewport().set_input_as_handled()
			return
		if builder.is_stack_tool():
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if builder.is_stacking() and not builder.stack_selecting: builder.cancel_stack()
					else:
						builder.cancel_stack()
						builder.begin_stack()
				MOUSE_BUTTON_RIGHT:
					if builder.stack_selecting: builder.finish_stack_selection()
					elif builder.is_stacking(): builder.confirm_stack()
				MOUSE_BUTTON_WHEEL_UP:
					if builder.is_stacking(): builder.change_stack_count(1)
					else: builder.select_slot(builder.selected_slot-1)
				MOUSE_BUTTON_WHEEL_DOWN:
					if builder.is_stacking(): builder.change_stack_count(-1)
					else: builder.select_slot(builder.selected_slot+1)
			get_viewport().set_input_as_handled()
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT: builder.place()
			MOUSE_BUTTON_RIGHT: builder.demolish()
			MOUSE_BUTTON_WHEEL_UP: builder.select_slot(builder.selected_slot-1)
			MOUSE_BUTTON_WHEEL_DOWN: builder.select_slot(builder.selected_slot+1)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed:
		if builder.is_stacking() and event.keycode in [KEY_Z,KEY_Y]:
			builder.cancel_stack()
			return
		if event.keycode == KEY_Z:
			if event.shift_pressed:
				builder.redo()
			else:
				builder.undo()
		elif event.keycode == KEY_Y:
			builder.redo()
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		builder.select_slot(event.keycode-KEY_1)
		return
	if event.keycode == KEY_MINUS:
		builder.select_slot(BuildCatalogue.TOOL_SLOT)
		return
	if builder.is_stacking() and event.keycode in [KEY_R,KEY_M,KEY_G,KEY_C,KEY_Q,KEY_PAGEUP,KEY_PAGEDOWN,KEY_HOME,KEY_T,KEY_COMMA,KEY_PERIOD,KEY_SLASH,KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		return
	if not builder.is_building() and event.keycode in [KEY_R,KEY_M,KEY_G,KEY_C,KEY_Q,KEY_PAGEUP,KEY_PAGEDOWN,KEY_HOME,KEY_T,KEY_COMMA,KEY_PERIOD,KEY_SLASH,KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		return
	match event.keycode:
		KEY_R:
			builder.angle = wrapf(builder.angle+deg_to_rad(15 if event.shift_pressed else 90),-PI,PI)
		KEY_M:
			builder.stone = posmod(builder.stone+1,3)
		KEY_G:
			builder.grid = not builder.grid
		KEY_C:
			builder.socket_snap = not builder.socket_snap
		KEY_Q, KEY_PAGEDOWN: builder.elevation = maxf(builder.elevation-0.25,-12)
		KEY_PAGEUP: builder.elevation = minf(builder.elevation+0.25,30)
		KEY_HOME: builder.elevation = 0
		KEY_COMMA, KEY_PERIOD:
			if builder.selected_kind() in BuildCatalogue.MITRE_KINDS:
				var current := builder.span_length if builder.span_length > 0 else (builder.ghost.span_length if is_instance_valid(builder.ghost) else BuildCatalogue.BAY)
				builder.span_length = clampf(current+(-BuildCatalogue.GRID if event.keycode == KEY_COMMA else BuildCatalogue.GRID),BuildCatalogue.MIN_SPAN,BuildCatalogue.MAX_SPAN)
		KEY_SLASH: builder.span_length = 0
		KEY_T:
			var inputs := BuildCatalogue.sockets(builder.selected_kind(),builder.span_length if builder.span_length > 0 else BuildCatalogue.BAY).filter(func(socket): return socket.family == "stack" and socket.normal.y < -0.5)
			builder.anchor = posmod(builder.anchor+1,inputs.size())
		KEY_BRACKETLEFT: builder.reach = maxf(5,builder.reach-2)
		KEY_BRACKETRIGHT: builder.reach = minf(40,builder.reach+2)
		KEY_F:
			player.toggle_flight()
		KEY_H: ui.hud.show_help = not ui.hud.show_help
		KEY_F5: save_world()
		KEY_F9: load_world()

func save_world(automatic: bool = false) -> void:
	var preferences := {"hotbar":builder.hotbar,"slot":builder.selected_slot,"last_build_slot":builder.last_build_slot,"stone":builder.stone,"grid":builder.grid,"socket_snap":builder.socket_snap,"game_mode":game_mode.serialize(),"day_progress":world.day_progress}
	if store.save_world(builder.serialize(),player.serialize(),preferences):
		builder.dirty = false
		if not automatic:
			ui.hud.toast("Sanctuary saved · " + str(builder.pieces.size()) + " components")
	else:
		ui.hud.toast(store.error)

func load_world() -> void:
	var data := store.load_world()
	if data.is_empty():
		ui.hud.toast(store.error)
		return
	var prefs: Dictionary = data.get("preferences",{})
	game_mode.restore(prefs.get("game_mode","creative"))
	world.restore_daylight(prefs.get("day_progress"))
	builder.restore(data.pieces)
	player.restore(data.get("player",{}))
	var bar: Variant = prefs.get("hotbar")
	if bar is Array and bar.size() in [BuildCatalogue.BUILD_SLOTS,10,11]:
		var valid := true
		for kind in bar.slice(0,BuildCatalogue.BUILD_SLOTS):
			if not kind is String or (not kind.is_empty() and BuildCatalogue.get_piece(kind).is_empty()):
				valid = false
		if valid:
			builder.hotbar = bar.slice(0,BuildCatalogue.BUILD_SLOTS).map(func(kind): return BuildCatalogue.library_kind(kind))
			builder.hotbar.append(BuildCatalogue.TOOL_KIND)
	var last_slot: Variant = prefs.get("last_build_slot",1)
	builder.last_build_slot = clampi(int(last_slot),0,8) if (last_slot is float or last_slot is int) else 1
	var slot_value: Variant = prefs.get("slot",BuildCatalogue.DEFAULT_SLOT)
	# Older bars had Inspect at index 9 and the stack tool at index 10.
	# Preserve every editable assignment and map an Inspect selection to an
	# existing empty slot (or the previous building slot if all are filled).
	if (slot_value is float or slot_value is int) and bar is Array:
		var legacy_bar: bool = bar.size() == 11 or (bar.size() == 10 and bar[9] != BuildCatalogue.TOOL_KIND)
		if legacy_bar and int(slot_value) == 9:
			var empty := builder.hotbar.slice(0,BuildCatalogue.BUILD_SLOTS).find("")
			slot_value = empty if empty >= 0 else builder.last_build_slot
	var material_value: Variant = prefs.get("stone",0)
	builder.stone = clampi(int(material_value),0,2) if (material_value is float or material_value is int) else 0
	builder.select_slot(clampi(int(slot_value),0,BuildCatalogue.TOOL_SLOT) if (slot_value is float or slot_value is int) else BuildCatalogue.DEFAULT_SLOT)
	builder.grid = prefs.get("grid",true) == true
	builder.socket_snap = prefs.get("socket_snap",true) == true
	ui.hud.toast("Saved sanctuary restored")

func empty_world() -> void:
	game_mode.restore("creative")
	world.restore_daylight(null)
	player.set_flying(false)
	builder.restore([])
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.dirty = true
	player.position = Vector3(12,1.05,21)
	player.look_at_point(Vector3(12,0,2))
	_resume()
	ui.hud.toast("An empty sanctuary · press E to arrange your building hotbar")

func _change_setting(key: String, value: Variant) -> void:
	ui.set_meta(key,value)
	settings.set_value("controls",key,value)
	settings.save("user://settings.cfg")
	if key == "quality":
		_apply_quality(int(value))
	elif key == "sound":
		sounds.enabled = value
	elif key == "shade_light":
		world.set_shade_brightness(float(value))

func _apply_quality(quality: int) -> void:
	world.Lighting.apply_quality(world,get_viewport(),quality)
	world.grass.set_quality(quality)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and ui:
		ui.show_menu()
		ui._request_quit()

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var quality_index := args.find("--quality")
	if quality_index >= 0 and quality_index+1 < args.size() and args[quality_index+1].is_valid_int():
		_apply_quality(int(args[quality_index+1]))
	var day_index := args.find("--day-progress")
	if day_index >= 0 and day_index+1 < args.size() and args[day_index+1].is_valid_float():
		world.restore_daylight(float(args[day_index+1]))
	if "--catalogue" in args:
		ui.show_catalogue()
		if "--foundations" in args:
			ui.active_filter = "Foundations"
			ui._select_detail("foundation_podium")
		elif "--roofs" in args:
			ui.active_filter = "Roofs"
			ui._select_detail("flat_roof" if "--flat-roofs" in args else ("dome_large" if "--domes" in args else ("stone_roof_left" if "--stone-roofs" in args else "roof_left")))
		elif "--doorway" in args:
			ui.active_filter = "Structure"
			ui._select_detail("wall_door_pediment")
		elif "--windows" in args or "--curved-windows" in args:
			ui.active_filter = "Structure"
			ui._select_detail("wall_window_segmental" if "--curved-windows" in args else "wall_window_pediment")
		elif "--columns" in args:
			ui.active_filter = "Columns"
			ui._select_detail("doric_column" if "--doric" in args else ("corinthian_column" if "--corinthian" in args else "ionic_column"))
	elif "--sun" in args:
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(12,6,12)
		player.camera.fov = 70
		player.look_at_point(player.camera.global_position+world.sun.global_basis.z*100)
	elif "--playing" in args:
		_resume()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.position = Vector3(-7,1.05,7)
		player.look_at_point(Vector3(-16,3,-7))
	elif "--empty" in args:
		empty_world()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif "--overview" in args:
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(-6,7,5)
		player.look_at_point(Vector3(-16,3,-7))
	elif "--trees" in args:
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(55,12,23)
		player.camera.fov = 62
		player.look_at_point(Vector3(86,11,17))
	elif "--landscape" in args:
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(-4,1.05,13)
		player.camera.fov = 65
		player.look_at_point(Vector3(-20,2.1,-7))
	elif "--doorway" in args:
		builder.restore(SanctuaryWorld.doorway_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(16,5.3,14)
		player.camera.fov = 60
		player.look_at_point(Vector3(12,2.5,0))
	elif "--wall-cover" in args:
		builder.restore(SanctuaryWorld.wall_cover_example("--foundation-cover" in args))
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(23,10,13)
		player.camera.fov = 57
		player.look_at_point(Vector3(12,2.8,0))
	elif "--corners" in args:
		builder.restore(SanctuaryWorld.corner_example("--railing" in args))
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(24,10,12)
		player.camera.fov = 62
		player.look_at_point(Vector3(12,2.7,0))
	elif "--foundations" in args:
		builder.restore(SanctuaryWorld.foundation_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(24,6,16)
		player.camera.fov = 62
		player.look_at_point(Vector3(12,3.8,-1))
	elif "--corinthian" in args or "--doric" in args or "--ionic" in args:
		var order := "doric" if "--doric" in args else ("ionic" if "--ionic" in args else "corinthian")
		builder.restore(SanctuaryWorld.column_order_example(order))
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(20,8,12)
		player.camera.fov = 55
		player.look_at_point(Vector3(12,2.5,0))
		if "--capital-detail" in args:
			player.position = Vector3(14,3.6,2.8)
			player.camera.fov = 36
			player.look_at_point(Vector3(12,4.25 if order == "corinthian" else 4.15,0))
	elif "--wall-perimeter" in args:
		builder.restore(SanctuaryWorld.wall_perimeter_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(23,11,14)
		player.camera.fov = 58
		player.look_at_point(Vector3(12,1.5,0))
	elif "--windows" in args or "--curved-windows" in args or "--triangle-windows" in args:
		var window_records := SanctuaryWorld.window_example()
		if "--curved-windows" in args:
			for record in window_records:
				if record.kind == "wall_window_ellipse": record.kind = "wall_window_segmental"
		if "--triangle-windows" in args:
			for record in window_records:
				if record.kind in BuildCatalogue.WALL_KINDS: record.kind = "wall_window_pediment"
		builder.restore(window_records)
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(22,7.2,18)
		player.camera.fov = 57
		player.look_at_point(Vector3(12,2.6,1))
		if "--window-detail" in args:
			player.position = Vector3(16.5,4.6,10.5)
			player.camera.fov = 42
			player.look_at_point(Vector3(14,2.95,4))
	elif "--lions" in args:
		builder.restore(SanctuaryWorld.lion_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(20,6,12)
		player.camera.fov = 55
		player.look_at_point(Vector3(12,1.7,0))
		if "--lion-detail" in args:
			player.position = Vector3(15.2,3.1,4.4)
			player.camera.fov = 43
			player.look_at_point(Vector3(12.2,1.9,0))
	elif "--enclosed-roof" in args:
		builder.restore(SanctuaryWorld.enclosed_roof_example("--stone-roofs" in args))
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(23,14,16)
		player.camera.fov = 62
		player.look_at_point(Vector3(12,4.2,0))
		if "--interior" in args:
			player.position = Vector3(8,2.5,4)
			player.camera.fov = 83
			player.look_at_point(Vector3(13,5.1,-1))
	elif "--ceiling-pediments" in args:
		builder.restore(SanctuaryWorld.ceiling_pediment_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(18,8,-9)
		player.camera.fov = 65
		player.look_at_point(Vector3(12,6.3,0))
	elif "--flat-roofs" in args:
		builder.restore(SanctuaryWorld.flat_roof_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(29,13,19)
		player.camera.fov = 64
		player.look_at_point(Vector3(13,3.8,0))
	elif "--domes" in args:
		builder.restore(SanctuaryWorld.dome_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(30,17,22)
		player.camera.fov = 64
		player.look_at_point(Vector3(13,4.7,0))
	elif "--roofs" in args or "--stone-roofs" in args:
		builder.restore(SanctuaryWorld.roof_example())
		if "--stone-roofs" in args:
			var records := builder.serialize()
			for record in records:
				if record.kind in BuildCatalogue.TERRACOTTA_ROOF_KINDS:
					record.kind = "stone_"+record.kind
					record.stone = 1 if "--marble" in args else 0
			builder.restore(records)
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(35,18,18)
		player.camera.fov = 64
		player.look_at_point(Vector3(12,5.5,-5))
		if "--pediment-front" in args:
			player.position = Vector3(12,3,29)
			player.camera.fov = 48
			player.look_at_point(Vector3(12,5.8,0))
	elif "--pediments" in args:
		builder.restore(SanctuaryWorld.pediment_example())
		ui.menu.hide()
		ui.hud.hide()
		player.position = Vector3(15,6.2,23)
		player.camera.fov = 61
		player.look_at_point(Vector3(12,5.6,0))
	elif "--stack-first" in args:
		builder.restore(SanctuaryWorld.stack_group_example())
		_resume()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.set_flying(true)
		player.position = Vector3(6,1.2,1)
		player.look_at_point(Vector3(11,0.2,1))
		builder.select_slot(BuildCatalogue.TOOL_SLOT)
	elif "--group-stack" in args or "--select-group" in args:
		builder.restore(SanctuaryWorld.stack_group_example())
		_resume()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.set_flying(true)
		player.position = Vector3(6,1.2,1)
		player.look_at_point(Vector3(11,0.2,1))
		await get_tree().physics_frame
		await get_tree().physics_frame
		builder.select_slot(BuildCatalogue.TOOL_SLOT)
		builder.begin_stack()
		player.position = Vector3(14,7.25,6)
		player.look_at_point(Vector3(14,4.875,0))
		await get_tree().physics_frame
		await get_tree().physics_frame
		if "--group-stack" in args:
			builder.finish_stack_selection()
			player.position = Vector3(7,7,12)
			player.look_at_point(Vector3(14,2,0))
			builder.change_stack_count(-2 if "--reverse" in args else 2)
	elif "--stack" in args:
		builder.restore([{"uid":1,"kind":"foundation_long","stone":0,"position":[12,0,0],"rotation":0}])
		_resume()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.set_flying(true)
		player.position = Vector3(4,6,10)
		player.look_at_point(Vector3(12,0.2,0))
		await get_tree().physics_frame
		await get_tree().physics_frame
		builder.select_slot(BuildCatalogue.TOOL_SLOT)
		builder.begin_stack()
		builder.finish_stack_selection()
		builder.change_stack_count(3)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var index := args.find("--capture")
	var path := args[index+1] if index+1 < args.size() else "/tmp/arcadia.png"
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
