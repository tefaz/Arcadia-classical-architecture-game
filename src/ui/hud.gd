class_name ArcadiaHUD
extends Control

var builder: ClassicalBuilder
var player: BuilderPlayer
var serif: Font = preload("res://assets/fonts/Serif.ttf")
var sans: Font = preload("res://assets/fonts/Sans.ttf")
var medium: Font = preload("res://assets/fonts/SansMedium.ttf")
var icons: Array[ComponentIcon] = []
var crosshair: ColorRect
var show_help := false
var toast_text := ""
var toast_time := 0.0
var elapsed := 0.0
const SLOT_SIZE := 56
const SLOT_STEP := 62
const GOLD := Color("dbc397")
const WHITE := Color("eee9de")
const MUTED := Color("aab9b1")
const PANEL := Color(0.075,0.115,0.11,0.72)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(BuildCatalogue.HOTBAR.size()):
		var icon := ComponentIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size = Vector2(32,32)
		add_child(icon)
		icons.append(icon)
	crosshair = ColorRect.new()
	crosshair.name = "AdaptiveCrosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -24
	crosshair.offset_top = -24
	crosshair.offset_right = 24
	crosshair.offset_bottom = 24
	crosshair.z_index = 1
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://src/ui/crosshair.gdshader")
	crosshair.material = shader_material
	add_child(crosshair)

func hotbar_rect() -> Rect2:
	var width := (builder.hotbar.size()-1)*SLOT_STEP+SLOT_SIZE
	return Rect2((size.x-width)/2,size.y-SLOT_SIZE-20,width,SLOT_SIZE)

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time-delta)
	elapsed += delta
	if elapsed > 0.08:
		elapsed = 0
		queue_redraw()
	var bar := hotbar_rect()
	for i in range(icons.size()):
		icons[i].kind = builder.hotbar[i]
		icons[i].position = bar.position+Vector2(i*SLOT_STEP+12,13)
		icons[i].color = GOLD if i == builder.selected_slot else MUTED
		icons[i].queue_redraw()

func toast(text_value: String) -> void:
	toast_text = text_value
	toast_time = 2.5
	queue_redraw()

func text_at(text_value: String, pos: Vector2, font_size: int = 16, color: Color = WHITE, font: Font = null) -> void:
	draw_string(font if font else sans,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func centered(text_value: String, y: float, font_size: int = 16, color: Color = WHITE, font: Font = null) -> void:
	var f: Font = font if font else sans
	text_at(text_value,Vector2((size.x-f.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)/2,y),font_size,color,f)

func caption(text_value: String, y: float, font_size: int, color: Color = WHITE, font: Font = null) -> void:
	var f: Font = font if font else sans
	var width := f.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+20
	draw_rect(Rect2((size.x-width)/2,y-font_size-4,width,font_size+12),PANEL)
	centered(text_value,y,font_size,color,f)

func _draw() -> void:
	if not builder:
		return
	var bar := hotbar_rect()
	if builder.is_stacking():
		if builder.stack_selecting:
			caption("Select area · "+str(builder.stack_members.size())+" components",bar.position.y-13,17,WHITE,serif)
			caption("Second point · Green · Right-click to select · Left resets first",bar.position.y-41,12,Color("92e5ab"))
			if builder.stack_members.size() > builder.StackPlan.MAX_PREVIEW_PIECES:
				caption("Select up to 256 components",bar.position.y-65,13,Color("f3ad94"))
		else:
			var title: String = BuildCatalogue.get_piece(builder.stack_source.kind).name if builder.stack_members.size() == 1 else str(builder.stack_members.size())+" components"
			caption("Stack · " + title,bar.position.y-13,17,WHITE,serif)
			var quantity := str(absi(builder.stack_count))+" copies" if builder.stack_members.size() == 1 else str(absi(builder.stack_count))+" sets · "+str(builder.stack_copies.size())+" new components"
			var direction := "Up" if builder.stack_step.y > 0.001 else ("Down" if builder.stack_step.y < -0.001 else ("Opposite view" if builder.stack_count < 0 else "Along view"))
			caption(quantity+" · "+direction+" · Left cancels / Right confirms",bar.position.y-41,12,MUTED)
		if not builder.stack_selecting and builder.stack_count != 0 and not builder.stack_valid:
			caption(builder.stack_status,bar.position.y-65,13,Color("f3ad94"))
	elif builder.is_stack_tool():
		caption("Stack tool",bar.position.y-13,17,WHITE,serif)
		caption("First point · Red · Left-click to select",bar.position.y-41,12,Color("f3a299"))
	elif builder.is_empty_handed() and is_instance_valid(builder.target):
		caption(BuildCatalogue.get_piece(builder.target.kind).name,bar.position.y-13,17,WHITE,serif)
		caption("Right-click to remove · Ctrl+Z to undo",bar.position.y-41,12,MUTED)
	elif builder.is_building():
		caption(BuildCatalogue.get_piece(builder.selected_kind()).name,bar.position.y-13,17,WHITE,serif)
		var context: String = BuildCatalogue.MATERIALS[builder.stone] + " · " + ("Grid 0.5 m" if builder.grid else "Free grid") + " · " + ("Snap" if builder.socket_snap else "Free snap")
		if builder.selected_kind() in BuildCatalogue.ROOF_KINDS:
			if builder.selected_kind() in BuildCatalogue.TERRACOTTA_ROOF_KINDS:
				context = context.replace(BuildCatalogue.MATERIALS[builder.stone],"Terracotta")
			if builder.snap_label.begins_with("Roof") or builder.snap_label == "Continuous roof pitch": context += " · "+builder.snap_label
		if builder.selected_kind() in BuildCatalogue.MITRE_KINDS:
			context += " · %s %s m" % ["Auto" if builder.span_length == 0 else "Length",String.num(builder.ghost.span_length if is_instance_valid(builder.ghost) else BuildCatalogue.BAY,2)]
		if builder.selected_kind() == "steps" and is_instance_valid(builder.ghost):
			context += " · %.2f m rise · %d steps" % [builder.ghost.stair_rise,BuildCatalogue.stair_count(builder.ghost.stair_rise)]
			if builder.snap_label.begins_with("Stairs fit landing"): context += " · Fitted to landing"
		if not is_zero_approx(builder.elevation):
			context += " · %+.2f m" % builder.elevation
		if builder.anchor != 0 and builder.selected_kind() not in BuildCatalogue.COVER_KINDS:
			var inputs := BuildCatalogue.sockets(builder.selected_kind()).filter(func(socket): return socket.family == "stack" and socket.normal.y < -0.5)
			var attachment: Vector3 = inputs[builder.anchor].position
			context += " · Left end" if attachment.x < 0 else " · Right end"
		if builder.snap_label.begins_with("Foundation perimeter"): context += " · Flush foundation edge"
		if builder.selected_kind() == "flat_roof": context += " · "+BuildCatalogue.cover_anchor_label(builder.anchor)
		if "Fitted" in builder.snap_label: context += " · Fitted to gap"
		if builder.snap_label.begins_with("Mitred corner"):
			context += " · Mitred corner"
		if builder.snap_label.begins_with("Column layout"):
			context = context.replace("Grid 0.5 m","Grid 4 m column centres")
		if builder.snap_label.begins_with("Column-to-column"):
			context += " · End on column"
		caption(context,bar.position.y-41,12,MUTED)
		if builder.valid and builder.column_guides.visible:
			caption("Marked centres match entablature bays · Alt for free placement",bar.position.y-65,12,MUTED)
		elif builder.valid and builder.snap_label.begins_with("Column-to-column"):
			caption("R turns the beam · T reverses its direction",bar.position.y-65,12,MUTED)
		elif builder.valid and builder.selected_kind() in BuildCatalogue.ROOF_KINDS:
			caption("Aim at a pediment’s rear face or a roof edge · R rotates",bar.position.y-65,12,MUTED)
		elif builder.valid and builder.selected_kind() in BuildCatalogue.COVER_KINDS:
			caption("R turns the attached edge · T cycles centre / edges / corners",bar.position.y-65,12,MUTED)
		if is_instance_valid(builder.ghost) and builder.ghost.visible and not builder.valid:
			caption(builder.status,bar.position.y-65,13,Color("f3ad94"))
	for i in range(builder.hotbar.size()):
		var slot := Rect2(bar.position+Vector2(i*SLOT_STEP,0),Vector2(SLOT_SIZE,SLOT_SIZE))
		draw_rect(slot,PANEL)
		if i == builder.selected_slot:
			draw_rect(slot,GOLD,false,1.5)
		text_at(BuildCatalogue.slot_key(i),slot.position+Vector2(4,13),11,GOLD if i == builder.selected_slot else MUTED,medium)
	var shortcuts := "E  Library     −  Stack tool     H  Controls"
	if builder.is_building() and builder.selected_kind() in BuildCatalogue.MITRE_KINDS:
		shortcuts = "E  Library     , .  Length     /  Auto-fit     H  Controls"
	text_at(shortcuts,Vector2(20,size.y-24),12,MUTED)
	if show_help:
		var origin := Vector2(20,size.y-308)
		draw_rect(Rect2(origin,Vector2(310,254)),PANEL)
		text_at("CONTROLS  ·  H to hide",origin+Vector2(12,23),12,GOLD,medium)
		var rows := [["LMB / RMB",("First / Second point" if builder.stack_selecting or not builder.is_stacking() else "Cancel / Confirm") if builder.is_stack_tool() else "Place / Remove"],["MMB","Pick aimed component"],["1–9","Select slot"],["− / Wheel","Stack tool / Count"],["R / Shift+R","Rotate 90° / 15°"],["PgDn / PgUp","Lower / Raise"],[",   .   /","Shorter / Longer / Auto"],["W ×2 + hold","Sprint forward"],["Space ×2 / Shift","Fly / Descend"],["M / G / C","Stone / Grid / Snap"],["T / Alt","Anchor / Free place"],["Ctrl Z / Y","Undo / Redo"]]
		for j in range(rows.size()):
			text_at(rows[j][0],origin+Vector2(12,45+j*18),12,WHITE,medium)
			text_at(rows[j][1],origin+Vector2(125,45+j*18),12,MUTED)
	if toast_time > 0:
		caption(toast_text,42,14,WHITE)
