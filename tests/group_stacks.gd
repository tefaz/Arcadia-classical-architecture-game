extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Plan := preload("res://src/building/stack_plan.gd")

static func facade() -> Array:
	return [
		Tools.record("foundation",Vector3(12,0,0),1),
		Tools.record("foundation",Vector3(16,0,0),2,PI/2),
		Tools.record("doric_column",Vector3(12,0.4,0),3,PI/2,1),
		Tools.record("doric_column",Vector3(16,0.4,0),4,0,2),
		Tools.record("entablature",Vector3(14,4.5,0),5,0,1),
		Tools.record("urn",Vector3(12,0,4),6),
		Tools.record("pedestal",Vector3(12,6,0),7),
	]

static func select(tree: SceneTree, game: Node3D, first: BuildPiece, last: BuildPiece) -> void:
	game.builder.select_slot(BuildCatalogue.TOOL_SLOT)
	await Tools.aim(tree,game,first)
	# Aim at an exposed corner of the foundation, clear of its supported column.
	game.player.position = first.position+first.basis*Vector3(-6,1.2,1)
	game.player.look_at_point(first.position+first.basis*Vector3(-1,0.2,1))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	var size: Vector3 = BuildCatalogue.get_piece(last.kind).size
	game.player.position = last.position+Vector3(0,size.y+2,6)
	game.player.look_at_point(last.position+Vector3.UP*size.y/2)
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_RIGHT)

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore(facade())
	await Tools.key(tree,KEY_V)
	check.call(builder.is_empty_handed() and not builder.is_stacking(),"V no longer activates the selection tool")
	await Tools.key(tree,KEY_MINUS)
	check.call(builder.is_stack_tool() and not is_instance_valid(builder.ghost) and builder.last_build_slot < 9,"Minus equips the dedicated tool without a building ghost or overwriting the previous build slot")
	await Tools.mouse(tree,MOUSE_BUTTON_RIGHT)
	check.call(not builder.is_stacking() and builder.pieces.size() == 7 and builder.history.is_empty(),"Right-click before the first point cannot demolish or place components")
	check.call(not builder.assign_slot(BuildCatalogue.TOOL_SLOT,"arch") and not builder.swap_slots(0,BuildCatalogue.TOOL_SLOT),"The dedicated tool slot cannot be replaced or swapped with a component")
	var tool_button: ComponentSlot = game.ui.inventory_slots[BuildCatalogue.TOOL_SLOT]
	check.call(tool_button.component_kind() == BuildCatalogue.TOOL_KIND and tool_button._get_drag_data(Vector2.ZERO) == null,"The library shows the fixed tool with no component drag payload")
	game.save_world()
	builder.select_slot(0)
	game.load_world()
	check.call(builder.is_stack_tool() and builder.hotbar[BuildCatalogue.TOOL_SLOT] == BuildCatalogue.TOOL_KIND and not is_instance_valid(builder.ghost),"Save/load restores the dedicated tool slot without creating a mesh")
	var old_bar := BuildCatalogue.HOTBAR.slice(0,9)
	old_bar.append("")
	game.store.save_world(builder.serialize(),player.serialize(),{"hotbar":old_bar,"slot":9})
	game.load_world()
	check.call(builder.is_empty_handed() and builder.hotbar.size() == 10 and builder.hotbar[9] == BuildCatalogue.TOOL_KIND,"Legacy Inspect selections migrate to an editable empty slot alongside the fixed tool")
	await select(tree,game,builder.pieces[0],builder.pieces[4])
	check.call(builder.is_stacking() and not builder.stack_selecting,"Left and right clicks lock the start and end using the equipped hotbar tool")
	var ids: Array = builder.stack_members.map(func(piece): return piece.uid)
	check.call(ids == [1,2,3,4,5],"Area selection includes intermediate foundations, columns and the endpoint beam")
	check.call(not ids.has(6) and not ids.has(7),"Components outside the selection's depth and height remain unselected")
	check.call(builder.outline.visible and builder.stack_copies.is_empty() and builder.history.is_empty(),"The selection outline is visible before any copies or undo actions exist")
	var reverse := Plan.select_between(builder.pieces[4],builder.pieces[0],builder.pieces)
	var reverse_ids: Array = reverse.map(func(piece): return piece.uid)
	reverse_ids.sort()
	check.call(reverse_ids == [1,2,3,4,5],"Reversing the two endpoints selects the same assembly")
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	check.call(builder.stack_count == 2 and builder.stack_copies.size() == 10,"The wheel counts complete sets and previews every selected component")
	check.call(builder.stack_step.is_equal_approx(Vector3(8,0,0)) and builder.stack_valid,"Group repeat spacing uses the full assembly width")
	var faithful := true
	for i in range(builder.stack_copies.size()):
		var original := builder.stack_members[i%5]
		var copy := builder.stack_copies[i]
		faithful = faithful and copy.kind == original.kind and copy.stone == original.stone
		faithful = faithful and copy.basis.is_equal_approx(original.basis)
		faithful = faithful and copy.position.is_equal_approx(original.position+Vector3(8*(i/5+1),0,0))
	check.call(faithful,"Each repeated set retains all relative positions, individual rotations and finishes")
	var original_records := builder.serialize().duplicate(true)
	await Tools.mouse(tree,MOUSE_BUTTON_RIGHT)
	check.call(builder.pieces.size() == 17 and builder.history.size() == 1 and not builder.is_stacking(),"Right click places both complete sets as one grouped command")
	var complete := builder.serialize().duplicate(true)
	await Tools.key(tree,KEY_Z,true)
	check.call(builder.serialize() == original_records,"One Ctrl+Z restores all original components and removes every repeated set")
	await Tools.key(tree,KEY_Y,true)
	check.call(builder.serialize() == complete,"Ctrl+Y restores the entire mixed-component group with stable identities")
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == complete and builder.history.is_empty(),"Saved groups reload as ordinary components with their complete arrangement")
	# Locked selection, without additional copies, remains harmless when cancelled.
	builder.restore(facade())
	await select(tree,game,builder.pieces[0],builder.pieces[4])
	builder.change_stack_count(2)
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 7 and builder.history.is_empty() and not builder.is_stacking(),"Left click discards a whole pending group without changing the originals")
	# Confirmation must be atomic even when the obstacle only touches the last member.
	await select(tree,game,builder.pieces[0],builder.pieces[4])
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	builder.change_stack_count(2)
	builder.add_record(Tools.record("wall",Vector3(30,4.5,0),8))
	await Tools.settle(tree)
	var before := builder.serialize().duplicate(true)
	var next_id := builder.next_uid
	check.call(not builder.stack_valid and not builder.confirm_stack(),"One obstructed member blocks all copies of the whole selection")
	check.call(builder.serialize() == before and builder.history.is_empty() and builder.next_uid == next_id,"Rejected groups cannot partially place components or consume IDs")
	builder.remove_uid(8)
	await Tools.settle(tree)
	check.call(builder.confirm_stack() and builder.pieces.size() == 17,"The pending complete selection can confirm once its obstacle is removed")
	# Moving an interior member leaves the group width unchanged, but must update its ghosts.
	builder.restore(facade())
	await select(tree,game,builder.pieces[0],builder.pieces[4])
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	builder.change_stack_count(1)
	builder.pieces[2].position.x += 0.25
	builder.update_stack()
	check.call(builder.stack_step.is_equal_approx(Vector3(8,0,0)) and builder.stack_copies[2].position.is_equal_approx(Vector3(20.25,0.4,0)),"Validation tracks every member transform even when the outside bounds stay unchanged")
	builder.remove_uid(4)
	check.call(not builder.is_stacking() and builder.stack_copies.is_empty(),"Removing a secondary selected component cancels the group safely")
	# The selection frame follows rotated construction, rather than the world axes.
	var rotation_value := deg_to_rad(30)
	var basis := Basis(Vector3.UP,rotation_value)
	var rotated: Array = []
	for i in range(3): rotated.append(Tools.record("foundation",Vector3(12,0,0)+basis*Vector3(i*4,0,0),i+1,rotation_value))
	builder.restore(rotated)
	await select(tree,game,builder.pieces[0],builder.pieces[2])
	check.call(builder.stack_members.size() == 3 and not builder.stack_selecting,"Rotated endpoints select their intervening modules")
	player.look_at_point(player.camera.global_position+basis.x*10)
	builder.change_stack_count(1)
	check.call(builder.stack_step.is_equal_approx(basis*Vector3(12,0,0)) and builder.stack_valid,"Rotated groups repeat by their combined length along their own axes")
	check.call(builder.confirm_stack() and builder.pieces.size() == 6,"A rotated multi-piece selection places as a complete group")
	# Scrolling cannot lock an unfinished selection.
	builder.restore(facade())
	await Tools.aim(tree,game,builder.pieces[0])
	player.position = Vector3(6,1.2,1)
	player.look_at_point(Vector3(11,0.2,1))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	player.position = Vector3(14,7.25,6)
	player.look_at_point(Vector3(14,4.875,0))
	await Tools.settle(tree)
	check.call(builder.stack_selecting and builder.stack_members.size() == 5,"The highlighted selection updates live while aiming at the finishing component")
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	check.call(builder.stack_selecting and builder.stack_members.size() == 5 and builder.stack_copies.is_empty(),"Scrolling before the second point leaves the selection unchanged")
	await Tools.mouse(tree,MOUSE_BUTTON_RIGHT)
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	check.call(not builder.stack_selecting and builder.stack_copies.size() == 5,"Scrolling after right-click repeats the complete selection")
	builder.cancel_stack()
	# The preview budget counts components, not just the number of repetitions.
	var grid: Array = []
	for x in range(3):
		for z in range(3): grid.append(Tools.record("foundation",Vector3(12+x*4,0,z*4),grid.size()+1))
	builder.restore(grid)
	await select(tree,game,builder.pieces[0],builder.pieces[8])
	builder.change_stack_count(999)
	check.call(builder.stack_members.size() == 9 and builder.stack_count == 28 and builder.stack_copies.size() == 252,"Large groups respect the total preview-component budget")
	await Tools.key(tree,KEY_ESCAPE)
	check.call(builder.stack_copies.is_empty() and builder.pieces.size() == 9,"Cancelling a large group clears every preview")
	# Signed scrolling repeats either way on every axis, including vertical groups.
	var pair := [Tools.record("foundation",Vector3(12,8,0),1),Tools.record("foundation",Vector3(16,8,0),2)]
	for look in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN]:
		builder.restore(pair)
		await select(tree,game,builder.pieces[0],builder.pieces[1])
		player.look_at_point(player.camera.global_position+look*10)
		await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_DOWN)
		var expected: Vector3 = -look*Vector3(8,0.4,4)
		check.call(builder.stack_count == -1 and builder.stack_copies.size() == 2 and builder.stack_step.is_equal_approx(expected) and builder.stack_valid,"Backward scrolling repeats the complete group opposite the view: "+str(look))
		check.call(builder.stack_copies[0].position.is_equal_approx(builder.pieces[0].position+expected) and builder.stack_copies[1].position.is_equal_approx(builder.pieces[1].position+expected),"Reverse copies preserve the complete group layout: "+str(look))
		await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
		check.call(builder.stack_count == 0 and builder.stack_copies.is_empty() and not builder.confirm_stack(),"Crossing zero clears reverse ghosts without placing an empty batch")
		await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
		check.call(builder.stack_count == 1 and builder.stack_step.is_equal_approx(-expected) and builder.stack_valid,"Forward scrolling after zero repeats toward the view: "+str(look))
		await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_DOWN)
		await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_DOWN)
		await Tools.mouse(tree,MOUSE_BUTTON_RIGHT)
		check.call(builder.pieces.size() == 4 and builder.history.size() == 1,"Reverse horizontal or vertical groups confirm in one batch")
		await Tools.key(tree,KEY_Z,true)
		check.call(builder.serialize() == pair,"Undo removes every reverse copy and preserves the original elevated group")
		await Tools.key(tree,KEY_Y,true)
		check.call(builder.pieces.size() == 4,"Redo restores all reverse horizontal or vertical copies")
	# Check attainable mouse-look angles, rather than perfectly vertical vectors.
	builder.restore(pair)
	await select(tree,game,builder.pieces[0],builder.pieces[1])
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	player.head.rotation.x = 1.2
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_UP)
	check.call(builder.stack_step.y > 0 and builder.stack_valid,"An upward camera pitch inside the mouse-look range selects vertical group stacking")
	player.head.rotation.x = -1.2
	await tree.process_frame
	builder.update_stack(true)
	check.call(builder.stack_step.y < 0 and builder.stack_valid,"A downward camera pitch inside the mouse-look range switches the pending group downward")
	builder.change_stack_count(-999)
	check.call(builder.stack_count == -32 and builder.stack_copies.size() == 64,"Reverse counts obey the same per-operation cap")
	builder.restore(grid)
	await select(tree,game,builder.pieces[0],builder.pieces[8])
	builder.change_stack_count(-999)
	check.call(builder.stack_count == -28 and builder.stack_copies.size() == 252,"Reverse groups obey the total preview-component budget")
	builder.restore([Tools.record("foundation",Vector3(12,0,0),1)])
	await select(tree,game,builder.pieces[0],builder.pieces[0])
	player.look_at_point(player.camera.global_position+Vector3.UP*10)
	await Tools.mouse(tree,MOUSE_BUTTON_WHEEL_DOWN)
	var before_reverse := builder.serialize().duplicate(true)
	check.call(not builder.stack_valid and not builder.confirm_stack() and builder.serialize() == before_reverse and builder.next_uid == 2,"Reverse downward stacking below the construction floor cannot partially place or consume IDs")
	builder.restore(SanctuaryWorld.sample_pavilion())
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.set_flying(false)
	game.ui.show_menu()
