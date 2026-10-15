class_name ArcadiaInterface
extends CanvasLayer

signal resume_requested
signal save_requested
signal load_requested
signal empty_requested
signal setting_changed(key: String, value: Variant)

var builder: ClassicalBuilder
var player: BuilderPlayer
var hud: ArcadiaHUD
var root: Control
var menu: Control
var catalogue: Control
var settings: Control
var confirmation: ConfirmationDialog
var catalogue_from_menu := false
var cards: GridContainer
var card_scroll: ScrollContainer
var detail_title: Label
var detail_text: Label
var preview_viewport: SubViewport
var preview_camera: Camera3D
var preview_pivot: Node3D
var preview_piece: BuildPiece
var preview_kind := "doric_column"
var active_filter := "All pieces"
var card_buttons: Dictionary = {}
var filter_buttons: Dictionary = {}
var toast_panel: PanelContainer
var toast_label: Label
var finish_picker: OptionButton
var mode_picker: OptionButton
var inventory_slots: Array[ComponentSlot] = []
var clear_hotbar_button: Button
var serif: Font = preload("res://assets/fonts/Serif.ttf")
var sans: Font = preload("res://assets/fonts/Sans.ttf")
const INK := Color("182726")
const GOLD := Color("dac49c")
const WHITE := Color("eee8dc")

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = _theme()
	hud = ArcadiaHUD.new()
	hud.builder = builder
	hud.player = player
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	_make_menu()
	_make_catalogue()
	_make_settings()
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Begin an empty sanctuary?"
	confirmation.dialog_text = "This clears the current building and undo history.\nYour saved sanctuary stays on disk until you save again."
	confirmation.ok_button_text = "Begin empty world"
	confirmation.confirmed.connect(func(): empty_requested.emit())
	root.add_child(confirmation)
	toast_panel = PanelContainer.new()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel",_style(INK,GOLD,1))
	toast_label = _label("",16)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)
	root.add_child(toast_panel)
	show_menu()

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = sans
	theme.default_font_size = 17
	theme.set_color("font_color","Label",WHITE)
	theme.set_color("font_color","Button",WHITE)
	theme.set_color("font_hover_color","Button",GOLD)
	theme.set_stylebox("normal","Button",_style(Color("263734"),Color("41504a"),1))
	theme.set_stylebox("hover","Button",_style(Color("34453e"),GOLD,1))
	theme.set_stylebox("pressed","Button",_style(Color("465347"),GOLD,1))
	theme.set_stylebox("focus","Button",_style(Color(0,0,0,0),GOLD,2))
	return theme

func _style(bg: Color, border: Color, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _label(text: String, size_value: int, serif_font: bool = false, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",color)
	if serif_font:
		label.add_theme_font_override("font",serif)
	return label

func _button(text: String, callback: Callable, height: float = 46) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.pressed.connect(callback)
	return button

func _overlay() -> Control:
	var overlay := Control.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04,0.07,0.06,0.44)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	overlay.hide()
	return overlay

func _panel(parent: Control, min_size: Vector2) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel",_style(INK,Color("6a6b57"),1))
	center.add_child(panel)
	return panel

func _make_menu() -> void:
	menu = _overlay()
	menu.get_child(0).color = Color(0.04,0.07,0.06,0.1)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",48)
	margin.add_theme_constant_override("margin_top",42)
	margin.add_theme_constant_override("margin_bottom",42)
	menu.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 490
	panel.add_theme_stylebox_override("panel",_style(Color(0.07,0.115,0.105,0.96),Color("706b53"),1))
	row.add_child(panel)
	var inset := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		inset.add_theme_constant_override("margin_"+side,28)
	panel.add_child(inset)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	inset.add_child(column)
	column.add_child(_label("A R C A D I A",42,true,GOLD))
	column.add_child(_label("A CLASSICAL BUILDING SANDBOX",12,false,Color("aebeb3")))
	column.add_child(HSeparator.new())
	column.add_child(_label("Build something\nlasting.",38,true))
	var description := _label("A quiet landscape. A library of classical forms.\nShape your own sanctuary, one piece at a time.",16,false,Color("b8c2b7"))
	column.add_child(description)
	column.add_child(_label("∞   Unlimited materials  ·  First-person building",16,false,GOLD))
	mode_picker = OptionButton.new()
	mode_picker.custom_minimum_size.y = 40
	mode_picker.add_item("Game mode: Creative  ·  Unlimited materials",GameModeState.Mode.CREATIVE)
	mode_picker.add_item("Game mode: Survival  ·  Coming later",GameModeState.Mode.SURVIVAL)
	mode_picker.set_item_disabled(1,not GameModeState.SURVIVAL_AVAILABLE)
	mode_picker.select(0)
	mode_picker.item_selected.connect(func(index):
		player.game_mode.restore("creative" if index == 0 else "survival")
		player.set_flying(player.flying)
	)
	column.add_child(mode_picker)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)
	var enter := _button("Enter sanctuary     →",func(): resume_requested.emit(),54)
	enter.add_theme_stylebox_override("normal",_style(GOLD,GOLD))
	enter.add_theme_color_override("font_color",INK)
	column.add_child(enter)
	column.add_child(_button("Explore the building catalogue",func(): show_catalogue()))
	var saves := HBoxContainer.new()
	column.add_child(saves)
	for entry in [["Save sanctuary",save_requested],["Load sanctuary",load_requested]]:
		var button := _button(entry[0],func(): entry[1].emit())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		saves.add_child(button)
	column.add_child(_button("Settings & controls",func(): show_settings()))
	column.add_child(_button("Begin an empty sanctuary",func(): confirmation.popup_centered(Vector2i(520,180)),42))
	column.add_child(_button("Quit game",func(): _request_quit(),38))
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stretch)
	column.add_child(_label("PROTOTYPE 01  /  THE BUILDER'S SANCTUARY",11,false,Color("8b9f92")))

func _request_quit() -> void:
	if builder.dirty:
		var dialog := ConfirmationDialog.new()
		dialog.title = "Leave the sanctuary?"
		dialog.dialog_text = "You have unsaved building changes.\nSave your sanctuary from the menu to keep them."
		dialog.ok_button_text = "Quit without saving"
		dialog.confirmed.connect(func(): get_tree().quit())
		root.add_child(dialog)
		dialog.popup_centered(Vector2i(480,160))
	else:
		get_tree().quit()

func _make_catalogue() -> void:
	catalogue = _overlay()
	var panel := _panel(catalogue,Vector2(1120,740))
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation",10)
	panel.add_child(main)
	var title := HBoxContainer.new()
	main.add_child(title)
	var label := _label("The building library",26,true,GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(label)
	title.add_child(_button("Close  ·  E / Esc",func(): close_overlay(),38))
	main.add_child(_label("Drag components to slots 1–9. Empty slots: right-click to remove · −: Stack tool.",14,false,Color("afbeb3")))
	var filters := HBoxContainer.new()
	main.add_child(filters)
	for category in ["All pieces","Foundations","Structure","Columns","Pediments","Roofs","Sculpture","Details"]:
		var button := _button(category,func(): active_filter=category; _update_cards(),32)
		filter_buttons[category] = button
		filters.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	main.add_child(row)
	card_scroll = ScrollContainer.new()
	card_scroll.custom_minimum_size = Vector2(800,446)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(card_scroll)
	cards = GridContainer.new()
	cards.columns = 5
	cards.add_theme_constant_override("h_separation",10)
	cards.add_theme_constant_override("v_separation",10)
	card_scroll.add_child(cards)
	for definition in BuildCatalogue.PIECES:
		var button := ComponentSlot.new()
		button.builder = builder
		button.kind = definition.id
		button.tooltip_text = definition.name + " · drag to your hotbar"
		button.custom_minimum_size.y = 104
		button.pressed.connect(func(): _select_detail(definition.id))
		button.custom_minimum_size.x = 148
		cards.add_child(button)
		card_buttons[definition.id] = button
		var icon := ComponentIcon.new()
		icon.kind = definition.id
		icon.position = Vector2(48,5)
		icon.size = Vector2(52,52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var name_label := _label(definition.name,12)
		button.add_child(name_label)
		var name_width := name_label.get_theme_font("font").get_string_size(definition.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		if name_width > 140:
			name_label.add_theme_font_size_override("font_size",maxi(9,floori(12*140/name_width)))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0,62)
		name_label.size.x = 148
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dims: Vector3 = definition.size
		var dimension := _label(String.num(dims.x,2) + " × " + String.num(dims.y,2) + " × " + String.num(dims.z,2) + " m",10,false,Color("8fa497"))
		dimension.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dimension.position = Vector2(0,83)
		dimension.size.x = 148
		dimension.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(dimension)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 256
	details.add_theme_constant_override("separation",10)
	row.add_child(details)
	detail_title = _label("Doric column",23,true,GOLD)
	details.add_child(detail_title)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(256,216)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(container)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(256,216)
	preview_viewport.own_world_3d = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(preview_viewport)
	preview_pivot = Node3D.new()
	preview_viewport.add_child(preview_pivot)
	var camera := Camera3D.new()
	preview_camera = camera
	camera.position = Vector3(6,4,7)
	camera.look_at_from_position(camera.position,Vector3(0,1.8,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	preview_viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	light.light_energy = 0.45
	preview_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50,145,0)
	fill.light_color = Color("c4dbed")
	fill.light_energy = 0.15
	preview_viewport.add_child(fill)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("22312e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d0dbe1")
	env.environment.ambient_light_energy = 0.45
	preview_viewport.add_child(env)
	detail_text = _label("",14,false,Color("b8c5b9"))
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text.custom_minimum_size = Vector2(256,80)
	details.add_child(detail_text)
	details.add_child(_label("Stone finish",12,false,GOLD))
	var finishes := OptionButton.new()
	finish_picker = finishes
	for material_name in BuildCatalogue.MATERIALS:
		finishes.add_item(material_name)
	finishes.item_selected.connect(func(index): builder.stone=index; _select_detail(preview_kind); builder.changed.emit())
	details.add_child(finishes)
	var hotbar_heading := HBoxContainer.new()
	main.add_child(hotbar_heading)
	var hotbar_title := _label("YOUR HOTBAR",12,false,GOLD)
	hotbar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hotbar_heading.add_child(hotbar_title)
	clear_hotbar_button = _button("Clear slots 1–9",func(): builder.clear_hotbar(),30)
	clear_hotbar_button.tooltip_text = "Empty the nine building slots, ready for new components."
	hotbar_heading.add_child(clear_hotbar_button)
	builder.changed.connect(_refresh_hotbar_actions)
	_refresh_hotbar_actions()
	var hotbar := HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation",6)
	main.add_child(hotbar)
	for i in range(BuildCatalogue.HOTBAR.size()):
		var button := ComponentSlot.new()
		button.builder = builder
		button.slot = i
		button.hotbar_area = hotbar
		button.custom_minimum_size = Vector2(84,72)
		button.pressed.connect(func(): builder.select_slot(i))
		hotbar.add_child(button)
		inventory_slots.append(button)
		var number := _label(BuildCatalogue.slot_key(i),12,false,GOLD)
		number.position = Vector2(7,3)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)
		var icon := ComponentIcon.new()
		icon.position = Vector2(26,7)
		icon.size = Vector2(40,40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.component_icon = icon
		button.add_child(icon)
		var caption := _label("",10)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.position = Vector2(0,53)
		caption.size.x = 92
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.caption = caption
		button.add_child(caption)
		button.refresh()
	main.add_child(_label("Drag slots to swap · Drag outside the hotbar to empty · E / Esc to close",13,false,Color("adbea9")))
	_select_detail("doric_column")
	_update_cards()

func _refresh_hotbar_actions() -> void:
	clear_hotbar_button.disabled = builder.hotbar.slice(0,BuildCatalogue.BUILD_SLOTS).all(func(kind): return kind.is_empty())

func _select_detail(kind: String) -> void:
	kind = BuildCatalogue.library_kind(kind)
	if BuildCatalogue.get_piece(kind).is_empty(): kind = "doric_column"
	preview_kind = kind
	var definition := BuildCatalogue.get_piece(kind)
	preview_camera.size = maxf(5.4,maxf(definition.size.x,definition.size.z)*1.35)
	detail_title.text = definition.name
	detail_text.text = definition.description
	if is_instance_valid(preview_piece):
		preview_pivot.remove_child(preview_piece)
		preview_piece.queue_free()
	preview_piece = ClassicalGeometry.create(kind,builder.stone)
	preview_piece.collision_layer = 0
	preview_piece.position.y = 1.8 - definition.size.y/2
	preview_pivot.add_child(preview_piece)
	_update_cards()

func _update_cards() -> void:
	for kind in card_buttons:
		var definition := BuildCatalogue.get_piece(kind)
		card_buttons[kind].visible = active_filter == "All pieces" or definition.group == active_filter
		card_buttons[kind].add_theme_stylebox_override("normal",_style(Color("34413a") if kind == preview_kind else Color("22332f"),GOLD if kind == preview_kind else Color("405047"),1))
	for category in filter_buttons:
		filter_buttons[category].add_theme_color_override("font_color",GOLD if category == active_filter else WHITE)

func _make_settings() -> void:
	settings = _overlay()
	var panel := _panel(settings,Vector2(810,680))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	column.add_child(_label("Make yourself at home",32,true,GOLD))
	var controls := _label("WASD  Move     Shift  Sprint on foot / Fly down     Space  Jump / Fly up\nDouble-tap W, hold second press  Sprint     Double-tap Space / F  Toggle flight\n1–9 / Wheel  Select slot     E / B / Tab  Library     LMB / RMB  Place / Remove     MMB  Pick\n−  Stack tool · Left / Right: endpoints · Wheel: ± repeats · Look up/down: vertical\nR  Rotate 90°     Shift+R  Rotate 15°     PgDn / PgUp  Height ±0.25 m\nT  Cycle anchor     M  Material     G  Grid     C  Socket snap     Alt  Free place\nCtrl+Z / Y  Undo / Redo     F5 / F9  Save / Load     H  Help\n[ / ]  Placement reach     Home  Reset height     F11  Fullscreen",16,false,Color("bcc9bb"))
	column.add_child(controls)
	column.add_child(HSeparator.new())
	column.add_child(_label("Mouse sensitivity",17,false,GOLD))
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0008
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = player.sensitivity
	sensitivity.value_changed.connect(func(value): player.sensitivity=value; setting_changed.emit("sensitivity",value))
	column.add_child(sensitivity)
	column.add_child(_label("Field of view",17,false,GOLD))
	var fov := HSlider.new()
	fov.min_value = 60
	fov.max_value = 100
	fov.value = player.camera.fov
	fov.value_changed.connect(func(value): player.camera.fov=value; setting_changed.emit("fov",value))
	column.add_child(fov)
	column.add_child(_label("Brightness in shade",17,false,GOLD))
	var shade := HSlider.new()
	shade.min_value = 0.35
	shade.max_value = 0.85
	shade.step = 0.01
	shade.value = float(get_meta("shade_light",0.58))
	shade.value_changed.connect(func(value): setting_changed.emit("shade_light",value))
	column.add_child(shade)
	var quality := OptionButton.new()
	quality.add_item("Simple · shadows off")
	quality.add_item("Balanced · shadows + 2× antialiasing")
	quality.add_item("High · sharper shadows + 4× antialiasing")
	quality.select(int(get_meta("quality",1)))
	quality.item_selected.connect(func(index): setting_changed.emit("quality",index))
	column.add_child(quality)
	var sound := CheckButton.new()
	sound.text = "Building sounds"
	sound.button_pressed = get_meta("sound",true)
	sound.toggled.connect(func(value): setting_changed.emit("sound",value))
	column.add_child(sound)
	column.add_child(_button("Back to sanctuary  ·  Esc",func(): close_overlay(),48))
	column.add_child(_label("Your sanctuary is saved locally. The previous save is kept as a .bak file.",14,false,Color("93a997")))

func _process(delta: float) -> void:
	toast_panel.visible = hud.toast_time > 0 and not player.active
	if toast_panel.visible:
		toast_label.text = hud.toast_text
		toast_panel.size = Vector2(maxf(320,sans.get_string_size(hud.toast_text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+48),44)
		toast_panel.position = Vector2((root.size.x-toast_panel.size.x)/2,root.size.y-55)
	if catalogue.visible:
		preview_pivot.rotation.y += delta * 0.28

func show_menu() -> void:
	builder.cancel_stack()
	mode_picker.select(player.game_mode.mode)
	menu.show()
	catalogue.hide()
	settings.hide()
	hud.hide()
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func show_catalogue() -> void:
	builder.cancel_stack()
	catalogue_from_menu = menu.visible
	menu.hide()
	catalogue.show()
	hud.hide()
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	finish_picker.select(builder.stone)
	_select_detail(builder.hotbar[builder.last_build_slot] if not builder.is_building() else builder.selected_kind())
	card_scroll.call_deferred("ensure_control_visible",card_buttons[preview_kind])

func show_settings() -> void:
	menu.hide()
	settings.show()

func close_overlay() -> void:
	if settings.visible or (catalogue.visible and catalogue_from_menu):
		show_menu()
	else:
		resume_requested.emit()

func enter_world() -> void:
	menu.hide()
	catalogue.hide()
	settings.hide()
	hud.show()
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	player.active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func escape() -> void:
	if catalogue.visible or settings.visible:
		close_overlay()
	elif menu.visible:
		resume_requested.emit()
	else:
		show_menu()
