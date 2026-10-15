extends RefCounted

const StackPlan := preload("res://src/building/stack_plan.gd")

static func record(kind: String, pos: Vector3, uid: int = 1, angle: float = 0, stone: int = 0) -> Dictionary:
	return {"uid":uid,"kind":kind,"stone":stone,"position":[pos.x,pos.y,pos.z],"rotation":angle}

static func settle(tree: SceneTree) -> void:
	for i in range(2):
		await tree.physics_frame
		await tree.process_frame

static func key(tree: SceneTree, code: Key, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await tree.process_frame

static func mouse(tree: SceneTree, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await tree.process_frame

static func aim(tree: SceneTree, game: Node3D, source: BuildPiece) -> void:
	game.player.set_flying(true)
	var height: float = BuildCatalogue.get_piece(source.kind).size.y
	game.player.position = source.position+source.basis*Vector3(-6,height/2+1,0)
	game.player.look_at_point(source.position+Vector3.UP*height/2)
	await settle(tree)

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.position = Vector3(40,10,40)
	player.set_flying(true)
	for kind in BuildCatalogue.FOUNDATION_KINDS:
		var size: Vector3 = BuildCatalogue.get_piece(kind).size
		check.call(is_zero_approx(fmod(size.x,2)) and is_zero_approx(fmod(size.z,2)) and is_equal_approx(size.y/0.4,roundf(size.y/0.4)),kind+": foundation dimensions follow two/four-metre bays and 0.4 m courses")
		var bottom_edges := true
		for socket in BuildCatalogue.sockets(kind):
			if socket.family == "floor": bottom_edges = bottom_edges and is_zero_approx(socket.position.y)
		check.call(bottom_edges,kind+": edge sockets align the bases of different foundation heights")
	builder.restore([record("foundation_large",Vector3(12,0,0))])
	await settle(tree)
	var source := builder.pieces[0]
	var hit := {"position":Vector3(16,0.2,-2),"normal":Vector3.RIGHT,"collider":source}
	var solution := SnapSolver.solve("foundation",0,hit,builder.pieces,true,true,0)
	check.call(solution.snapped and solution.position.is_equal_approx(Vector3(18,0,-2)),"Small foundations attach to individual four-metre bays along a grand foundation")
	hit = {"position":Vector3(14,0.4,2),"normal":Vector3.UP,"collider":source}
	solution = SnapSolver.solve("doric_column",0,hit,builder.pieces,true,true,0)
	check.call(solution.snapped and solution.position.is_equal_approx(Vector3(14,0.4,2)),"Grand foundation top sockets retain four-metre column bays")
	builder.restore([record("foundation_podium",Vector3(12,0,0))])
	await settle(tree)
	hit = {"position":Vector3(14,0.2,0),"normal":Vector3.RIGHT,"collider":builder.pieces[0]}
	solution = SnapSolver.solve("foundation",0,hit,builder.pieces,true,true,0)
	check.call(solution.snapped and is_zero_approx(solution.position.y),"A low foundation beside a tall podium stays on the ground")
	builder.restore([record("foundation_long",Vector3(12,0,0),1,PI/2)])
	await settle(tree)
	hit = {"position":Vector3(12,0.2,-4),"normal":Vector3.FORWARD,"collider":builder.pieces[0]}
	solution = SnapSolver.solve("foundation",0,hit,builder.pieces,true,true,0)
	check.call(solution.snapped and solution.position.is_equal_approx(Vector3(12,0,-6)),"Rotated long foundations still connect without grid gaps")
	builder.restore([record("steps",Vector3(12,1.2,0))])
	await settle(tree)
	hit = {"position":Vector3(12,1.2,0),"normal":Vector3.DOWN,"collider":builder.pieces[0]}
	solution = SnapSolver.solve("step_support",0,hit,builder.pieces,true,true,0)
	check.call(solution.snapped and solution.position.is_equal_approx(Vector3(12,0.8,0)),"Stair support snaps directly below existing raised temple steps")
	check.call(builder.placement_error("step_support",Transform3D(Basis.IDENTITY,solution.position)).is_empty(),"The fitted stair support has no collision with the steps above")
	builder.restore([record("step_support",Vector3(12,0,0))])
	await settle(tree)
	hit = {"position":Vector3(12,0.4,0),"normal":Vector3.UP,"collider":builder.pieces[0]}
	solution = SnapSolver.solve("steps",0,hit,builder.pieces,true,true,0)
	check.call(solution.position.is_equal_approx(Vector3(12,0.4,0)),"Temple steps attach cleanly onto a stair support")
	# Start from empty hands with actual keyboard/mouse dispatch; previews must not enter the world.
	builder.restore([record("foundation",Vector3(12,0,0),1,0,2)])
	await aim(tree,game,builder.pieces[0])
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	await mouse(tree,MOUSE_BUTTON_LEFT)
	await mouse(tree,MOUSE_BUTTON_RIGHT)
	check.call(builder.is_stacking() and builder.stack_source.uid == 1 and builder.is_stack_tool(),"The equipped tool selects the aimed component with left/right clicks")
	await mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	await mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	check.call(builder.stack_count == 2 and builder.stack_valid,"Real wheel input adds two valid stack previews")
	check.call(builder.stack_copies[0].position.is_equal_approx(Vector3(16,0,0)) and builder.stack_copies[1].position.is_equal_approx(Vector3(20,0,0)),"Stack copies follow the dominant look direction in full foundation bays")
	check.call(builder.pieces.size() == 1 and builder.history.is_empty() and not builder.dirty and builder.next_uid == 2,"Preview copies do not change the world, history, save state, or ID allocation")
	var harmless := true
	for copy in builder.stack_copies:
		harmless = harmless and copy.collision_layer == 0
		for child in copy.get_children(): harmless = harmless and not child is CollisionShape3D
	check.call(harmless,"Stack previews have no collision bodies or gameplay shapes")
	await mouse(tree,MOUSE_BUTTON_WHEEL_DOWN)
	check.call(builder.stack_count == 1,"Wheel down removes a preview rather than changing hotbar slots")
	await mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(not builder.is_stacking() and builder.stack_copies.is_empty() and builder.pieces.size() == 1,"Left click cancels every preview without touching the source")
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	await mouse(tree,MOUSE_BUTTON_LEFT)
	await mouse(tree,MOUSE_BUTTON_RIGHT)
	builder.change_stack_count(2)
	await mouse(tree,MOUSE_BUTTON_RIGHT)
	check.call(not builder.is_stacking() and builder.pieces.size() == 3,"Right click confirms the entire stack into the world")
	check.call(builder.history.size() == 1 and builder.history[0].op == "batch_add" and builder.history[0].pieces.size() == 2,"A confirmed stack records one grouped undo action")
	check.call(builder.pieces[1].stone == 2 and builder.pieces[2].stone == 2 and builder.pieces[0].uid == 1,"Copies preserve the selected source finish and leave its identity intact")
	var placed := builder.serialize().duplicate(true)
	await key(tree,KEY_Z,true)
	check.call(builder.pieces.size() == 1 and builder.future.size() == 1,"Ctrl+Z removes the whole stack in one step")
	await key(tree,KEY_Y,true)
	check.call(builder.serialize() == placed,"Ctrl+Y restores the complete stack with its original IDs and transforms")
	var removed: Dictionary = builder.pieces[1].serialize()
	builder.remove_uid(int(removed.uid))
	builder.record_action({"op":"remove","piece":removed})
	builder.undo()
	builder.undo()
	check.call(builder.pieces.size() == 1 and builder.future.size() == 2,"Demolition undo composes correctly with a previous grouped stack undo")
	builder.redo()
	builder.redo()
	check.call(builder.pieces.size() == 2,"Redo restores a stack then repeats a later single-piece demolition")
	# Rotated arrays use the source's own axes, not a fixed world grid.
	var angle := deg_to_rad(30)
	builder.restore([record("foundation_long",Vector3(12,0,0),1,angle)])
	await aim(tree,game,builder.pieces[0])
	check.call(builder.begin_stack(),"A rotated long foundation can be selected for stacking")
	builder.finish_stack_selection()
	builder.change_stack_count(2)
	var expected := Basis(Vector3.UP,angle)*Vector3(8,0,0)
	check.call(builder.stack_step.is_equal_approx(expected) and builder.stack_valid,"Rotated stack spacing follows the source's eight-metre local axis")
	check.call(builder.confirm_stack() and absf(angle_difference(builder.pieces[1].rotation.y,angle)) < 0.001,"Rotated copies keep the source rotation at confirmation")
	# A batch can complete a mitre, but cannot force a third run through that corner.
	builder.restore([record("wall",Vector3(12,0,0)),record("wall",Vector3(18,0,2),2,PI/2)])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(2)
	check.call(not builder.stack_valid and builder.stack_status.contains("corner"),"A stack cannot create an unsupported third run at a corner")
	builder.change_stack_count(-1)
	check.call(builder.stack_valid and builder.stack_copies[0].join_right != 0,"A one-copy stack previews the same fitted mitre as normal placement")
	check.call(builder.confirm_stack() and builder.pieces[1].join_right != 0 and builder.pieces[2].join_right != 0,"Confirming a stack updates both pieces of the new corner")
	builder.undo()
	check.call(builder.pieces.size() == 2 and builder.pieces[1].join_right == 0,"Grouped undo restores the old unjoined corner geometry")
	builder.redo()
	check.call(builder.pieces[1].join_right != 0 and builder.pieces[2].join_right != 0,"Grouped redo reconstructs the fitted corner")
	# Looking upward changes the same pending operation to a vertical stack.
	builder.restore([record("step_support",Vector3(12,0,0))])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(2)
	player.look_at_point(player.camera.global_position+Vector3.UP*10)
	builder.update_stack(true)
	check.call(builder.stack_step.is_equal_approx(Vector3(0,0.4,0)) and builder.stack_valid,"Looking up previews stair supports vertically at their exact course height")
	check.call(builder.confirm_stack() and is_equal_approx(builder.pieces[2].position.y,0.8),"Three stacked supports form a solid 1.2-metre stair plinth")
	game.save_world()
	var saved: Dictionary = game.store.load_world()
	check.call(saved.pieces.size() == 3 and saved.pieces.all(func(piece): return WorldStore.valid_piece(piece)),"Confirmed support stacks save as ordinary compatible component records")
	game.load_world()
	check.call(builder.pieces.size() == 3 and builder.history.is_empty(),"Loading a stack reconstructs its pieces without retaining transient tool history")
	# Reject the whole array even when only its last copy hits an obstacle.
	builder.restore([record("foundation",Vector3(12,0,0)),record("wall",Vector3(20,0,0),2)])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(2)
	var before := builder.serialize().duplicate(true)
	check.call(not builder.stack_valid and not builder.confirm_stack(),"An obstacle in the final copy blocks confirmation of the entire stack")
	check.call(builder.serialize() == before and builder.history.is_empty() and builder.next_uid == 3,"Blocked confirmation cannot place an earlier valid copy or consume IDs")
	game.save_world()
	saved = game.store.load_world()
	check.call(saved.pieces.size() == 2 and saved.pieces.all(func(piece): return piece.uid > 0),"Saving during a preview omits all transient copies")
	builder.remove_uid(2)
	await settle(tree)
	check.call(builder.confirm_stack() and builder.pieces.size() == 3,"Removing an obstacle lets the existing pending stack confirm safely")
	# An obstacle can move without changing piece count; confirmation must query physics again.
	builder.restore([record("foundation",Vector3(12,0,0)),record("wall",Vector3(40,0,0),2)])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(2)
	check.call(builder.stack_valid,"A clear array starts with a valid preview")
	builder.pieces[1].position.x = 20
	await settle(tree)
	check.call(not builder.confirm_stack() and builder.pieces.size() == 2,"Confirm rechecks an obstacle moved into a previously valid preview")
	builder.restore([record("foundation",Vector3(12,0,0))])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(1)
	player.position = Vector3(16,1.05,0)
	await settle(tree)
	check.call(not builder.confirm_stack() and builder.stack_status.contains("Move clear"),"Stack confirmation rejects copies through the player")
	player.position = Vector3(16,5,0)
	await settle(tree)
	check.call(builder.confirm_stack(),"Moving clear of the preview allows the stack to confirm")
	builder.restore([record("foundation",Vector3(58,0,0))])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(1)
	check.call(not builder.confirm_stack() and builder.stack_status.contains("Outside"),"Stacks respect the construction boundary without partial placement")
	builder.restore([record("foundation",Vector3(12,0,0))])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.stack_source.position.y = 39.4
	player.look_at_point(player.camera.global_position+Vector3.UP*10)
	builder.change_stack_count(1)
	check.call(not builder.confirm_stack() and builder.pieces.size() == 1,"Stack height limits include the full height of the last copy")
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		check.call(StackPlan.step("foundation",Basis.IDENTITY,direction).is_equal_approx(direction*Vector3(4,0.4,4)),"Stack direction preserves the sign of axis "+str(direction))
	builder.restore([record("foundation",Vector3(12,0,0))])
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(999)
	check.call(builder.stack_count == StackPlan.MAX_COPIES,"Wheel counts are bounded to keep preview work manageable")
	builder.change_stack_count(-StackPlan.MAX_COPIES)
	check.call(builder.stack_count == 0 and not builder.confirm_stack() and builder.history.is_empty(),"A zero-copy stack cannot create an empty undo action")
	builder.change_stack_count(1)
	await key(tree,KEY_ESCAPE)
	check.call(not builder.is_stacking() and player.active,"Escape cancels the tool without opening the pause menu")
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(1)
	await key(tree,KEY_E)
	check.call(not builder.is_stacking() and game.ui.catalogue.visible,"Opening the library discards pending stack previews")
	game.ui.close_overlay()
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(1)
	builder.select_slot(0)
	check.call(not builder.is_stacking() and builder.stack_copies.is_empty(),"Selecting a hotbar component safely exits the stack tool")
	await aim(tree,game,builder.pieces[0])
	builder.begin_stack()
	builder.finish_stack_selection()
	builder.change_stack_count(1)
	builder.remove_uid(1)
	check.call(not builder.is_stacking() and builder.stack_copies.is_empty(),"Deleting the source clears all pending copies")
	builder.ledger.creative = false
	check.call(not builder.begin_stack(),"The prototype reserves stack duplication for unlimited Creative resources")
	game.game_mode.restore("creative")
	builder.restore(SanctuaryWorld.sample_pavilion())
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.set_flying(false)
	game.ui.show_menu()
