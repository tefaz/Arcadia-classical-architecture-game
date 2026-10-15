class_name ClassicalBuilder
extends Node3D

const PedimentFit := preload("res://src/building/pediment_fit.gd")
const CeilingRoofFit := preload("res://src/building/ceiling_roof_fit.gd")
const CeilingFit := preload("res://src/building/ceiling_fit.gd")

signal changed
signal message(text: String)
signal sound_requested(kind: String)

const CONTACT_TOLERANCE := 0.003
const StackPlan := preload("res://src/building/stack_plan.gd")

var player: BuilderPlayer
var pieces: Array[BuildPiece] = []
var hotbar: Array = BuildCatalogue.HOTBAR.duplicate()
var selected_slot := BuildCatalogue.DEFAULT_SLOT
var last_build_slot := BuildCatalogue.DEFAULT_SLOT
var stone := 0
var angle := 0.0
var elevation := 0.0
var span_length := 0.0 # Zero chooses a standard bay and automatically fits closing gaps.
var reach := 18.0
var grid := true
var socket_snap := true
var anchor := 0
var ghost: BuildPiece
var marker: MeshInstance3D
var target: BuildPiece
var valid := false
var status := "Aim at the ground to build"
var snap_label := "Grid · 0.5 m"
var next_uid := 1
var history: Array = []
var future: Array = []
var ledger := ResourceLedger.new()
var dirty := false
var outline: MeshInstance3D
var column_guides: MeshInstance3D
var connection_index: Dictionary = {}
var stack_source: BuildPiece
var stack_members: Array[BuildPiece] = []
var stack_selecting := false
var stack_selection_bounds := AABB()
var stack_end: BuildPiece
var stack_count := 0
var stack_step := Vector3.ZERO
var stack_copies: Array[BuildPiece] = []
var stack_valid := false
var stack_status := ""
var _stack_player_position := Vector3.INF
var _stack_world_count := -1
var _stack_member_transforms: Array[Transform3D] = []
var stack_hover: BuildPiece
var stack_hover_outline: MeshInstance3D
var _stack_overlays: Dictionary = {}
var _stack_red := _selection_material(Color(1.0,0.16,0.12,0.36))
var _stack_green := _selection_material(Color(0.18,1.0,0.32,0.36))
var _stack_selected := _selection_material(Color(0.55,0.9,0.8,0.10))
var _stack_first := _selection_material(Color(1.0,0.25,0.2,0.12))
var _stack_second := _selection_material(Color(0.25,1.0,0.4,0.12))

static func _selection_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	marker = MeshInstance3D.new()
	marker.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("9de5cf")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	outline = MeshInstance3D.new()
	outline.material_override = mat
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)
	stack_hover_outline = MeshInstance3D.new()
	stack_hover_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stack_hover_outline.visible = false
	add_child(stack_hover_outline)
	column_guides = MeshInstance3D.new()
	column_guides.material_override = _selection_material(Color(0.12,0.7,0.53,0.9))
	column_guides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column_guides.visible = false
	add_child(column_guides)
	_refresh_ghost()

func selected_kind() -> String:
	return hotbar[selected_slot]

func is_empty_handed() -> bool:
	return selected_kind().is_empty()

func is_stack_tool() -> bool:
	return selected_slot == BuildCatalogue.TOOL_SLOT

func is_building() -> bool:
	return selected_slot < BuildCatalogue.BUILD_SLOTS and not selected_kind().is_empty()

func select_slot(slot: int) -> void:
	cancel_stack()
	selected_slot = posmod(slot,BuildCatalogue.HOTBAR.size())
	if selected_slot < BuildCatalogue.BUILD_SLOTS:
		last_build_slot = selected_slot
	anchor = 1 if selected_kind() == "flat_roof" else 0
	span_length = 0
	elevation = 0
	_refresh_ghost()
	sound_requested.emit("select")
	changed.emit()

func choose(kind: String) -> void:
	if BuildCatalogue.get_piece(kind).is_empty():
		return
	if not is_building():
		selected_slot = last_build_slot
	hotbar[selected_slot] = kind
	select_slot(selected_slot)
	message.emit(BuildCatalogue.get_piece(kind).name + " added to slot " + str(selected_slot+1))

func pick_aimed_component() -> bool:
	if not player or not player.active: return false
	var camera := player.camera
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*reach,3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var piece := hit.get("collider") as BuildPiece
	if piece == null: return false
	var kind := BuildCatalogue.library_kind(piece.kind)
	var slot := selected_slot if selected_kind() == kind else hotbar.slice(0,BuildCatalogue.BUILD_SLOTS).find(kind)
	if slot < 0:
		slot = selected_slot if selected_slot < BuildCatalogue.BUILD_SLOTS else last_build_slot
		hotbar[slot] = kind
	stone = piece.stone
	if piece.kind in BuildCatalogue.ROOF_KINDS:
		angle = piece.rotation.y+(PI if kind != piece.kind else 0.0)
	select_slot(slot)
	dirty = true
	message.emit("Picked " + BuildCatalogue.get_piece(kind).name + " · slot " + str(slot+1))
	return true

func assign_slot(slot: int, kind: String) -> bool:
	if slot < 0 or slot >= BuildCatalogue.BUILD_SLOTS or BuildCatalogue.get_piece(kind).is_empty():
		return false
	hotbar[slot] = kind
	if selected_slot == slot:
		anchor = 1 if selected_kind() == "flat_roof" else 0
		span_length = 0
		elevation = 0
		_refresh_ghost()
	dirty = true
	changed.emit()
	sound_requested.emit("select")
	return true

func swap_slots(source: int, destination: int) -> bool:
	if source < 0 or source >= BuildCatalogue.BUILD_SLOTS or destination < 0 or destination >= BuildCatalogue.BUILD_SLOTS:
		return false
	if source == destination:
		return true
	var previous: String = hotbar[destination]
	hotbar[destination] = hotbar[source]
	hotbar[source] = previous
	if selected_slot in [source,destination]:
		anchor = 1 if selected_kind() == "flat_roof" else 0
		span_length = 0
		elevation = 0
		_refresh_ghost()
	dirty = true
	changed.emit()
	sound_requested.emit("select")
	return true

func clear_slot(slot: int) -> bool:
	if slot < 0 or slot >= BuildCatalogue.BUILD_SLOTS or hotbar[slot].is_empty():
		return false
	hotbar[slot] = ""
	if selected_slot == slot:
		anchor = 1 if selected_kind() == "flat_roof" else 0
		span_length = 0
		elevation = 0
		_refresh_ghost()
	dirty = true
	changed.emit()
	sound_requested.emit("select")
	return true

func clear_hotbar() -> bool:
	if hotbar.slice(0,BuildCatalogue.BUILD_SLOTS).all(func(kind): return kind.is_empty()):
		return false
	cancel_stack()
	for slot in range(BuildCatalogue.BUILD_SLOTS):
		hotbar[slot] = ""
	anchor = 1 if selected_kind() == "flat_roof" else 0
	span_length = 0
	elevation = 0
	_refresh_ghost()
	dirty = true
	changed.emit()
	sound_requested.emit("select")
	return true

func _refresh_ghost() -> void:
	if is_instance_valid(ghost):
		remove_child(ghost)
		ghost.queue_free()
	ghost = null
	if not is_building():
		_hide_preview()
		status = "Empty slot · aim at a component to remove it"
		snap_label = "Right-click to remove · E for the library"
		return
	ghost = ClassicalGeometry.create(selected_kind(), stone, true)
	ghost.visible = false
	add_child(ghost)

func _physics_process(_delta: float) -> void:
	if not player or not player.active:
		cancel_stack()
		_hide_preview()
		return
	if is_stacking():
		update_stack()
		return
	if not stack_members.is_empty() or not stack_copies.is_empty(): cancel_stack()
	update_preview()
	if is_stack_tool(): _update_stack_feedback(_aimed_stack_piece())

func _hide_preview() -> void:
	if is_instance_valid(column_guides): column_guides.visible = false
	if is_instance_valid(ghost):
		ghost.visible = false
	marker.visible = false
	outline.visible = false
	valid = false
	target = null

func update_preview() -> void:
	column_guides.visible = false
	if not is_building():
		_hide_preview()
		if is_empty_handed() and player and player.active:
			# Use the same first-hit ray as placement so intervening surfaces
			# and reach still protect components behind them.
			var camera := player.camera
			var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*reach,3)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			target = hit.get("collider") as BuildPiece
			outline.visible = is_instance_valid(target)
			if outline.visible: _update_outline(target)
		return
	var camera := player.camera
	var from := camera.global_position
	var direction := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	target = hit.get("collider") as BuildPiece
	outline.visible = target != null
	if target:
		_update_outline(target)
	if hit.is_empty():
		ghost.visible = false
		marker.visible = false
		valid = false
		status = "Aim at a surface within " + str(int(reach)) + " m"
		return
	var solutions := SnapSolver.candidates(selected_kind(),angle,hit,pieces,grid and not Input.is_key_pressed(KEY_ALT),socket_snap and not Input.is_key_pressed(KEY_ALT),elevation,anchor,connection_index,span_length)
	var solution: Dictionary = solutions[0]
	status = ""
	# Prefer a nearby connection that actually fits, rather than trapping the preview on a blocked socket.
	var choices := solutions.slice(0,31)
	if solutions.size() > 31: choices.append(solutions.back())
	for i in range(choices.size()):
		var candidate: Dictionary = choices[i]
		var error := placement_error(selected_kind(),Transform3D(Basis(Vector3.UP,candidate.get("angle",angle)),candidate.position),[],{},0,candidate.length,candidate.get("rise",BuildCatalogue.STAIR_RISE))
		if i == 0: status = error
		if error.is_empty():
			solution = candidate
			status = ""
			break
	ghost.position = solution.position
	ghost.rotation.y = solution.get("angle",angle)
	var fitting := PedimentFit.transform_for(selected_kind(),ghost.transform,pieces,connection_index)
	var fitting_changed := not ghost.pediment_fit.is_equal_approx(fitting)
	ghost.pediment_fit = fitting
	var ceiling_changed := false
	if selected_kind() == "flat_roof":
		var rects := CeilingFit.rectangles(ghost.transform,pieces)
		var planes := CeilingRoofFit.regions_for(ghost.transform,pieces)
		ceiling_changed = ghost.ceiling_rects != rects or ghost.ceiling_regions != planes
		ghost.ceiling_rects = rects
		ghost.ceiling_regions = planes
	var joints := CornerJoints.describe(selected_kind(),ghost.transform,connection_index,0,solution.length)
	var rise: float = solution.get("rise",BuildCatalogue.STAIR_RISE)
	if fitting_changed or ceiling_changed or ghost.join_left != int(joints.left) or ghost.join_right != int(joints.right) or not is_equal_approx(ghost.span_length,solution.length) or not is_equal_approx(ghost.stair_rise,rise):
		ghost.span_length = solution.length
		ghost.stair_rise = rise
		ClassicalGeometry.configure(ghost,int(joints.left),int(joints.right),true)
	ghost.visible = true
	_update_column_guides(solution)
	snap_label = solution.label
	marker.visible = solution.snapped
	marker.position = solution.socket
	valid = status.is_empty()
	if valid:
		status = "Ready to place"
	ClassicalGeometry.set_preview_valid(ghost, valid)

func _update_column_guides(solution: Dictionary) -> void:
	if not solution.has("guide_points"): return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var lift := Vector3.UP*0.025
	var frame: Basis = solution.guide_basis
	for point in solution.guide_points:
		# Small centre crosses and dashed four-metre runs keep the floor legible.
		for axis in [frame.x,frame.z]:
			mesh.surface_add_vertex(point-axis*0.16+lift)
			mesh.surface_add_vertex(point+axis*0.16+lift)
		for i in range(16):
			var a := TAU*i/16
			var b := TAU*(i+1)/16
			mesh.surface_add_vertex(point+(frame.x*cos(a)+frame.z*sin(a))*0.24+lift)
			mesh.surface_add_vertex(point+(frame.x*cos(b)+frame.z*sin(b))*0.24+lift)
	var lines: Array = solution.guide_lines
	for i in range(0,lines.size(),2):
		for dash in range(8):
			mesh.surface_add_vertex(lines[i].lerp(lines[i+1],dash/8.0)+lift)
			mesh.surface_add_vertex(lines[i].lerp(lines[i+1],(dash+0.5)/8.0)+lift)
	mesh.surface_end()
	column_guides.mesh = mesh
	column_guides.visible = true

func placement_error(kind: String, transform_value: Transform3D, excluded: Array[RID] = [], planned_connections: Dictionary = {}, ignore_uid: int = 0, length: float = BuildCatalogue.BAY, stair_rise: float = BuildCatalogue.STAIR_RISE, planned_pieces: Array = []) -> String:
	var pos := transform_value.origin
	if absf(pos.x) > 60 or absf(pos.z) > 60 or pos.y < -0.02 or pos.y + BuildCatalogue.piece_size(kind,length,stair_rise).y > 40:
		return "Outside the sanctuary · build within 60 m"
	if pieces.size() >= WorldStore.MAX_PIECES:
		return "Sanctuary component limit reached"
	for existing in pieces:
		if existing.kind == kind and is_equal_approx(existing.span_length,length) and (kind != "steps" or is_equal_approx(existing.stair_rise,stair_rise)) and existing.position.distance_squared_to(pos) < 0.0001 and absf(angle_difference(existing.rotation.y, transform_value.basis.get_euler().y)) < 0.01:
			return "A component already occupies this position"
	var joints := CornerJoints.describe(kind,transform_value,connection_index if planned_connections.is_empty() else planned_connections,ignore_uid,length)
	if joints.conflict:
		return "This corner already connects two runs"
	var ignored: Array[RID] = excluded.duplicate()
	# Matched corner partners and roof ends reconfigure on commit; other solids remain obstacles.
	for peer in joints.partners:
		if peer.get_rid() not in ignored:
			ignored.append(peer.get_rid())
	var fitting_peers := pieces if planned_pieces.is_empty() else planned_pieces
	# Gables cut existing edge panels on commit, including when built after the ceiling.
	if kind in CeilingFit.GABLES:
		for peer in fitting_peers:
			if peer.kind == "flat_roof" and CeilingFit.cut_for(peer.transform,kind,transform_value,fitting_peers).has_area():
				if peer.get_rid() not in ignored: ignored.append(peer.get_rid())
	if kind in BuildCatalogue.ROOF_KINDS:
		for peer in fitting_peers:
			if peer.kind == "flat_roof" and CeilingRoofFit.plane_for(peer.transform,kind,transform_value) != null:
				if peer.get_rid() not in ignored: ignored.append(peer.get_rid())
	var recipe := ClassicalGeometry.get_recipe(kind,int(joints.left),int(joints.right),length,stair_rise)
	if kind == "flat_roof":
		recipe = CeilingFit.recipe(CeilingFit.rectangles(transform_value,fitting_peers,ignore_uid,not planned_pieces.is_empty()),CeilingRoofFit.regions_for(transform_value,fitting_peers,ignore_uid,planned_connections))
	recipe = PedimentFit.recipe(kind,transform_value,fitting_peers,recipe,connection_index if planned_connections.is_empty() else planned_connections)
	# Test the same fitted solids shown by the preview and committed piece.
	for part in recipe:
		if not part.has("shape"):
			continue
		var shape: Shape3D = part.shape.duplicate()
		if shape is BoxShape3D:
			shape.size = (shape.size-Vector3.ONE*CONTACT_TOLERANCE*2).max(Vector3.ONE*0.001)
		elif shape is CylinderShape3D:
			shape.radius = maxf(0.001,shape.radius-CONTACT_TOLERANCE)
			shape.height = maxf(0.001,shape.height-CONTACT_TOLERANCE*2)
		elif shape is ConvexPolygonShape3D:
			var points: PackedVector3Array = shape.points
			var centre := Vector3.ZERO
			for v in points:
				centre += v
			centre /= points.size()
			var radius := 0.0
			for v in points: radius = maxf(radius,v.distance_to(centre))
			for i in range(points.size()):
				points[i] = centre+(points[i]-centre)*maxf(0.1,1-CONTACT_TOLERANCE/maxf(radius,0.001))
			shape.points = points
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = transform_value * part.transform
		query.collision_mask = 6
		# Player is checked separately rather than excluded from placement.
		query.exclude = ignored.filter(func(rid): return rid != player.get_rid()) if player else ignored
		var collisions := get_world_3d().direct_space_state.intersect_shape(query, 1)
		if not collisions.is_empty():
			return "Move clear of the preview" if collisions[0].collider is BuilderPlayer else "Components overlap · adjust position or height"
	return ""

func place() -> void:
	if is_stacking():
		cancel_stack()
		return
	if not is_building():
		return
	update_preview()
	if not valid:
		message.emit(status)
		return
	var definition := BuildCatalogue.get_piece(selected_kind())
	if not ledger.spend(definition.cost):
		message.emit("More materials needed")
		return
	var record := ghost.serialize()
	record.uid = next_uid
	record.stone = stone
	add_record(record)
	record_action({"op": "add", "piece": record})
	sound_requested.emit("place")

func demolish() -> void:
	if is_stacking():
		confirm_stack()
		return
	if not player or not player.active or is_stack_tool():
		return
	update_preview()
	if not is_instance_valid(target):
		return
	var record := target.serialize()
	remove_uid(target.uid)
	ledger.refund(BuildCatalogue.get_piece(record.kind).cost)
	record_action({"op": "remove", "piece": record})
	sound_requested.emit("remove")
	message.emit("Removed " + BuildCatalogue.get_piece(record.kind).name + " · Ctrl+Z to undo")

func add_record(record: Dictionary, update_connections: bool = true) -> BuildPiece:
	var piece := ClassicalGeometry.create(record.kind,int(record.stone),false,float(record.get("length",BuildCatalogue.BAY)),float(record.get("rise",BuildCatalogue.STAIR_RISE)))
	piece.uid = int(record.uid)
	var pos: Array = record.position
	piece.position = Vector3(pos[0], pos[1], pos[2])
	piece.rotation.y = record.rotation
	add_child(piece)
	pieces.append(piece)
	next_uid = maxi(next_uid, piece.uid + 1)
	if update_connections:
		refresh_connections()
	return piece

func remove_uid(uid: int, update_connections: bool = true) -> void:
	for piece in pieces:
		if piece.uid == uid:
			if piece == stack_source or piece in stack_members: cancel_stack()
			pieces.erase(piece)
			remove_child(piece)
			piece.queue_free()
			break
	target = null
	if update_connections: refresh_connections()

func refresh_connections() -> void:
	connection_index = CornerJoints.index_pieces(pieces)
	for piece in pieces:
		if piece.kind in BuildCatalogue.PEDIMENT_KINDS or piece.kind == "finial":
			var fitting := PedimentFit.transform_for(piece.kind,piece.transform,pieces,connection_index)
			if not piece.pediment_fit.is_equal_approx(fitting):
				piece.pediment_fit = fitting
				ClassicalGeometry.configure(piece,piece.join_left,piece.join_right)
	for piece in pieces:
		if piece.kind not in BuildCatalogue.MITRE_KINDS and piece.kind not in BuildCatalogue.RAKE_KINDS and piece.kind not in BuildCatalogue.ROOF_KINDS:
			continue
		var joints := CornerJoints.describe(piece.kind,piece.transform,connection_index,piece.uid,piece.span_length)
		var left := 0 if joints.conflict else int(joints.left)
		var right := 0 if joints.conflict else int(joints.right)
		if left != piece.join_left or right != piece.join_right:
			ClassicalGeometry.configure(piece,left,right)
	# Roof end trims must settle before ceiling regions read their physical depth.
	for piece in pieces:
		if piece.kind == "flat_roof":
			var rects := CeilingFit.rectangles(piece.transform,pieces,piece.uid)
			var planes := CeilingRoofFit.regions_for(piece.transform,pieces,piece.uid)
			if piece.ceiling_rects != rects or piece.ceiling_regions != planes:
				piece.ceiling_rects = rects
				piece.ceiling_regions = planes
				ClassicalGeometry.configure(piece,0,0)

func record_action(action: Dictionary) -> void:
	history.append(action)
	if history.size() > 150:
		history.pop_front()
	future.clear()
	dirty = true
	changed.emit()

func undo() -> void:
	cancel_stack()
	if history.is_empty():
		message.emit("Nothing to undo")
		return
	var action: Dictionary = history.pop_back()
	if action.op == "batch_add":
		for record in action.pieces: remove_uid(int(record.uid),false)
		refresh_connections()
	elif action.op == "add":
		remove_uid(int(action.piece.uid))
	else:
		add_record(action.piece)
	future.append(action)
	dirty = true
	changed.emit()
	sound_requested.emit("remove")
	message.emit("Undone · Ctrl+Y to redo")

func redo() -> void:
	cancel_stack()
	if future.is_empty():
		message.emit("Nothing to redo")
		return
	var action: Dictionary = future.pop_back()
	if action.op == "batch_add":
		for record in action.pieces: add_record(record,false)
		refresh_connections()
	elif action.op == "add":
		add_record(action.piece)
	else:
		remove_uid(int(action.piece.uid))
	history.append(action)
	dirty = true
	changed.emit()
	sound_requested.emit("place")

func serialize() -> Array:
	return pieces.map(func(piece): return piece.serialize())

func restore(records: Array) -> void:
	cancel_stack()
	for piece in pieces:
		remove_child(piece)
		piece.queue_free()
	pieces.clear()
	next_uid = 1
	for record in records:
		add_record(record,false)
	refresh_connections()
	history.clear()
	future.clear()
	target = null
	dirty = false
	changed.emit()

func is_stacking() -> bool:
	return is_instance_valid(stack_source)

func begin_stack() -> bool:
	if is_stacking():
		if stack_selecting: return finish_stack_selection()
		cancel_stack()
		return false
	if not ledger.creative:
		message.emit("Stacking is available in Creative mode")
		return false
	var source := _aimed_stack_piece()
	if source == null:
		message.emit("Aim at a placed component and left-click to set the first point")
		return false
	_hide_preview()
	stack_source = source
	stack_members.assign([source])
	stack_end = source
	stack_selecting = true
	stack_count = 0
	stack_step = Vector3.ZERO
	_stack_world_count = -1
	update_stack(true)
	return true

func _aimed_stack_piece() -> BuildPiece:
	var camera := player.camera
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*reach,2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as BuildPiece

func finish_stack_selection() -> bool:
	if not is_stacking() or not stack_selecting: return false
	var endpoint := _aimed_stack_piece()
	if endpoint == null:
		message.emit("Aim at the last component and right-click to set the second point")
		return false
	stack_end = endpoint
	stack_members = StackPlan.select_between(stack_source,endpoint,pieces)
	if stack_members.size() > StackPlan.MAX_PREVIEW_PIECES:
		message.emit("Select up to 256 components at a time")
		return false
	stack_selecting = false
	update_stack(true)
	return true

func cancel_stack() -> void:
	_clear_stack_feedback()
	for copy in stack_copies:
		remove_child(copy)
		copy.queue_free()
	stack_copies.clear()
	stack_source = null
	stack_members.clear()
	stack_end = null
	stack_selecting = false
	_stack_member_transforms.clear()
	stack_count = 0
	stack_valid = false
	stack_status = ""
	if is_instance_valid(outline): outline.visible = false

func change_stack_count(change: int) -> void:
	if not is_stacking(): return
	if stack_selecting: return
	var max_sets := mini(StackPlan.MAX_COPIES,StackPlan.MAX_PREVIEW_PIECES/stack_members.size())
	stack_count = clampi(stack_count+change,-max_sets,max_sets)
	var total := absi(stack_count)*stack_members.size()
	while stack_copies.size() > total:
		var copy: BuildPiece = stack_copies.pop_back()
		remove_child(copy)
		copy.queue_free()
	while stack_copies.size() < total:
		var member := stack_members[stack_copies.size()%stack_members.size()]
		var copy := ClassicalGeometry.create(member.kind,member.stone,true,member.span_length,member.stair_rise)
		copy.uid = -stack_copies.size()-1
		add_child(copy)
		stack_copies.append(copy)
	update_stack(true)

func update_stack(force: bool = false) -> void:
	if not is_stacking():
		if not stack_copies.is_empty(): cancel_stack()
		return
	for member in stack_members:
		if not is_instance_valid(member) or member.get_parent() != self:
			cancel_stack()
			return
	if stack_selecting:
		var endpoint := _aimed_stack_piece()
		if endpoint != null: stack_end = endpoint
		stack_selection_bounds = StackPlan.selection_bounds(stack_source,stack_end)
		stack_members = StackPlan.select_between(stack_source,stack_end,pieces)
		_update_stack_outline()
		_update_stack_feedback(endpoint)
		return
	stack_selection_bounds = StackPlan.group_bounds(stack_members)
	var step := StackPlan.step(stack_source.kind,stack_source.basis,-player.camera.global_basis.z,stack_source.span_length,stack_source.stair_rise) if stack_members.size() == 1 else StackPlan.step_size(stack_selection_bounds.size,stack_source.basis,-player.camera.global_basis.z)
	if stack_count < 0: step = -step
	outline.visible = true
	_update_stack_outline()
	_update_stack_feedback(null)
	var transforms: Array[Transform3D] = []
	for member in stack_members: transforms.append(member.transform)
	if not force and step.is_equal_approx(stack_step) and _stack_world_count == pieces.size() and _stack_member_transforms == transforms and _stack_player_position.distance_squared_to(player.position) < 0.0001:
		return
	stack_step = step
	_stack_member_transforms = transforms
	_stack_player_position = player.position
	_stack_world_count = pieces.size()
	for i in range(stack_copies.size()):
		var member := stack_members[i%stack_members.size()]
		var repetition := i/stack_members.size()+1
		stack_copies[i].transform = Transform3D(member.basis,member.position+step*repetition)
	var all_pieces: Array = pieces.duplicate()
	all_pieces.append_array(stack_copies)
	var connections := CornerJoints.index_pieces(all_pieces)
	stack_status = "Scroll to add copies" if stack_count == 0 else ""
	if pieces.size()+stack_copies.size() > WorldStore.MAX_PIECES:
		stack_status = "Sanctuary component limit reached"
	for copy in stack_copies:
		var joints := CornerJoints.describe(copy.kind,copy.transform,connections,copy.uid,copy.span_length)
		var fitting := PedimentFit.transform_for(copy.kind,copy.transform,all_pieces,connections)
		var fitting_changed := not copy.pediment_fit.is_equal_approx(fitting)
		copy.pediment_fit = fitting
		var ceiling_changed := false
		if copy.kind == "flat_roof":
			var rects := CeilingFit.rectangles(copy.transform,all_pieces,copy.uid,true)
			var planes := CeilingRoofFit.regions_for(copy.transform,all_pieces,copy.uid,connections)
			ceiling_changed = copy.ceiling_rects != rects or copy.ceiling_regions != planes
			copy.ceiling_rects = rects
			copy.ceiling_regions = planes
		if fitting_changed or ceiling_changed or copy.join_left != int(joints.left) or copy.join_right != int(joints.right):
			ClassicalGeometry.configure(copy,int(joints.left),int(joints.right),true)
		var error := placement_error(copy.kind,copy.transform,[],connections,copy.uid,copy.span_length,copy.stair_rise,all_pieces)
		if stack_status.is_empty() and not error.is_empty(): stack_status = error
	stack_valid = stack_count != 0 and stack_status.is_empty()
	for copy in stack_copies: ClassicalGeometry.set_preview_valid(copy,stack_valid)

func confirm_stack() -> bool:
	if not is_stacking(): return false
	if stack_selecting:
		message.emit("Right-click the last component to set the second point")
		return false
	if not ledger.creative:
		message.emit("Stacking is available in Creative mode")
		return false
	# Recheck player, obstacles and limits at confirmation, rather than trusting cached previews.
	update_stack(true)
	if not is_stacking(): return false
	if not stack_valid:
		message.emit(stack_status)
		return false
	var records: Array = []
	for copy in stack_copies:
		var record := copy.serialize()
		record.uid = next_uid+records.size()
		records.append(record)
	for record in records: add_record(record,false)
	refresh_connections()
	cancel_stack()
	record_action({"op":"batch_add","pieces":records})
	sound_requested.emit("place")
	return true

func _update_outline(piece: BuildPiece, destination: MeshInstance3D = null) -> void:
	if destination == null: destination = outline
	var bounds := piece.visual_bounds.grow(0.025)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_outline_box(mesh,bounds,Transform3D.IDENTITY)
	mesh.surface_end()
	destination.mesh = mesh
	destination.transform = piece.transform

func _clear_stack_feedback() -> void:
	for mesh in _stack_overlays:
		if is_instance_valid(mesh): mesh.material_overlay = _stack_overlays[mesh].original
	_stack_overlays.clear()
	stack_hover = null
	if is_instance_valid(stack_hover_outline): stack_hover_outline.visible = false

func _update_stack_feedback(hovered: BuildPiece) -> void:
	stack_hover = hovered
	var desired: Dictionary = {}
	for member in stack_members:
		var tint := _stack_selected
		if member == stack_source: tint = _stack_first
		if member == stack_end and not stack_selecting: tint = _stack_second
		_add_stack_overlay(desired,member,tint)
	if is_instance_valid(hovered):
		_add_stack_overlay(desired,hovered,_stack_green if stack_selecting else _stack_red)
	for mesh in _stack_overlays.keys():
		if not is_instance_valid(mesh):
			_stack_overlays.erase(mesh)
		elif not desired.has(mesh):
			mesh.material_overlay = _stack_overlays[mesh].original
			_stack_overlays.erase(mesh)
	for mesh in desired:
		if not _stack_overlays.has(mesh):
			_stack_overlays[mesh] = {"original":mesh.material_overlay}
		mesh.material_overlay = desired[mesh]
	stack_hover_outline.visible = is_instance_valid(hovered)
	if stack_hover_outline.visible:
		stack_hover_outline.material_override = _stack_green if stack_selecting else _stack_red
		_update_outline(hovered,stack_hover_outline)

func _add_stack_overlay(desired: Dictionary, piece: BuildPiece, material: Material) -> void:
	for child in piece.get_children():
		if child is MeshInstance3D: desired[child] = material

func _update_stack_outline() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_outline_box(mesh,stack_selection_bounds.grow(0.03),Transform3D.IDENTITY)
	var inverse := stack_source.transform.affine_inverse()
	for i in range(mini(stack_members.size(),StackPlan.MAX_PREVIEW_PIECES)):
		var member := stack_members[i]
		_outline_box(mesh,member.visual_bounds.grow(0.02),inverse*member.transform)
	mesh.surface_end()
	outline.mesh = mesh
	outline.transform = stack_source.transform
	outline.visible = true

func _outline_box(mesh: ImmediateMesh, bounds: AABB, transform_value: Transform3D) -> void:
	var corners: Array[Vector3] = []
	for y in [bounds.position.y,bounds.end.y]:
		for z in [bounds.position.z,bounds.end.z]:
			for x in [bounds.position.x,bounds.end.x]:
				corners.append(transform_value*Vector3(x,y,z))
	for edge in [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]]:
		mesh.surface_add_vertex(corners[edge[0]])
		mesh.surface_add_vertex(corners[edge[1]])
