class_name ComponentSlot
extends Button

## Library cards copy components; hotbar drags swap assignments or discard them outside the bar.
var builder: ClassicalBuilder
var kind := ""
var slot := -1
var component_icon: ComponentIcon
var caption: Label
var hotbar_area: Control
var _drag_kind := ""
var _released_outside := false

func _ready() -> void:
	if slot >= 0:
		builder.changed.connect(refresh)
		refresh()

func component_kind() -> String:
	return builder.hotbar[slot] if slot >= 0 else kind

func refresh() -> void:
	var current := component_kind()
	if component_icon:
		component_icon.kind = current
		component_icon.queue_redraw()
	if caption:
		var title: String = "Stack tool" if slot == BuildCatalogue.TOOL_SLOT else ("Empty slot" if current.is_empty() else BuildCatalogue.get_piece(current).name)
		caption.text = "" if slot < BuildCatalogue.BUILD_SLOTS and current.is_empty() else title.replace(" column", "").replace("Terracotta ", "").replace("Dentil ", "")
		tooltip_text = title + (" · left selects start / right selects end" if slot == BuildCatalogue.TOOL_SLOT else (" · right-click removes aimed components; drag a library component here" if current.is_empty() else " · drag to swap; drag outside the hotbar to empty"))
	if slot >= 0:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("34413a") if builder.selected_slot == slot else Color("22332f")
		style.border_color = Color("dac49c") if builder.selected_slot == slot else Color("405047")
		style.set_border_width_all(2 if builder.selected_slot == slot else 1)
		style.set_corner_radius_all(4)
		add_theme_stylebox_override("normal",style)

func _get_drag_data(_position: Vector2) -> Variant:
	var current := component_kind()
	if current.is_empty() or slot == BuildCatalogue.TOOL_SLOT:
		return null
	var preview := PanelContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	preview.add_child(row)
	var image := ComponentIcon.new()
	image.kind = current
	image.custom_minimum_size = Vector2(48,48)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var label := Label.new()
	label.text = BuildCatalogue.get_piece(current).name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	set_drag_preview(preview)
	if slot >= 0 and slot < BuildCatalogue.BUILD_SLOTS:
		_drag_kind = current
		_released_outside = false
	return {"arcadia_component":true,"kind":current,"source_slot":slot}

func _input(event: InputEvent) -> void:
	if _drag_kind.is_empty(): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_released_outside = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Only an actual release outside the entire bar discards an assignment.
		# Escape, focus loss, slot gaps and protected slots never do.
		var pointer: Vector2 = get_canvas_transform().affine_inverse()*event.position
		_released_outside = is_instance_valid(hotbar_area) and not hotbar_area.get_global_rect().has_point(pointer) and get_viewport_rect().has_point(event.position)

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or _drag_kind.is_empty(): return
	var discarded := _released_outside and not get_viewport().gui_is_drag_successful() and is_visible_in_tree()
	var dragged_kind := _drag_kind
	_drag_kind = ""
	_released_outside = false
	if discarded and builder.hotbar[slot] == dragged_kind:
		builder.clear_slot(slot)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if slot < 0 or slot >= BuildCatalogue.BUILD_SLOTS or not data is Dictionary:
		return false
	if data.get("arcadia_component") != true or not data.get("kind") is String:
		return false
	if BuildCatalogue.get_piece(data.kind).is_empty():
		return false
	var source: Variant = data.get("source_slot",-1)
	if not source is int or source < -1 or source >= BuildCatalogue.BUILD_SLOTS:
		return false
	return source == -1 or builder.hotbar[source] == data.kind

func _drop_data(position: Vector2, data: Variant) -> void:
	if not _can_drop_data(position,data):
		return
	if data.get("source_slot",-1) >= 0:
		builder.swap_slots(data.source_slot,slot)
	else:
		builder.assign_slot(slot,data.kind)
