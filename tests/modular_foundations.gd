extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Plan := preload("res://src/building/stack_plan.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	# Every foundation repeats on all axes, including tall side hits and rotated bays.
	for kind in BuildCatalogue.FOUNDATION_KINDS:
		var size := BuildCatalogue.piece_size(kind)
		for angle in [0.0,PI/4,PI/2]:
			builder.restore([Tools.record(kind,Vector3(12,0,0),1,angle)])
			await Tools.settle(tree)
			var source := builder.pieces[0]
			for direction in [Vector3.RIGHT,Vector3.BACK,Vector3.UP]:
				var local: Vector3 = direction*size/2
				local.y = size.y if direction == Vector3.UP else size.y-0.01
				var normal: Vector3 = source.basis*direction
				var hit := {"position":source.transform*local,"normal":normal,"collider":source}
				var solution := SnapSolver.solve(kind,angle,hit,builder.pieces,true,true,0)
				var expected: Vector3 = source.position+source.basis*(direction*size)
				check.call(solution.snapped and solution.position.is_equal_approx(expected),"%s at %.0f degrees repeats by its full size along %s" % [kind,rad_to_deg(angle),direction])
				check.call(builder.placement_error(kind,Transform3D(source.basis,solution.position)).is_empty(),"Repeated foundation bay fits without solid overlap")
				check.call(Plan.step(kind,source.basis,normal).is_equal_approx(expected-source.position),"The stack tool uses the same foundation spacing as manual placement")
	# Structural modules share a flush face through every course: no inset belts or shelves.
	for kind in ["foundation","foundation_raised","foundation_podium"]:
		var size := BuildCatalogue.piece_size(kind)
		var flush := true
		for course in range(roundi(size.y/0.4)):
			var hit: Vector3 = MeshChecks.front_hit(ClassicalGeometry.get_recipe(kind),Vector3(0.4,course*0.4+0.2,3),Vector3(0.4,course*0.4+0.2,0))
			flush = flush and is_equal_approx(hit.z,size.z/2)
		check.call(flush,kind+": all courses have a flush outer face for horizontal and vertical repetition")
	# Fitted stairs meet every existing platform height, including stacked/offset foundations.
	for height in [0.4,0.8,2.0,2.4,4.0,2.43]:
		for angle in [0.0,PI/4,PI/2]:
			builder.restore([Tools.record("foundation",Vector3(12,height-0.4,0),1,angle)])
			await Tools.settle(tree)
			var source := builder.pieces[0]
			for direction in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
				var normal: Vector3 = source.basis*direction
				var landing: Vector3 = source.position+source.basis*(direction*2)+Vector3.UP*0.4
				var hit := {"position":landing-Vector3.UP*0.05,"normal":normal,"collider":source}
				var solution := SnapSolver.solve("steps",0,hit,builder.pieces,true,true,0)
				var basis := Basis(Vector3.UP,solution.get("angle",0.0))
				var size := BuildCatalogue.piece_size("steps",BuildCatalogue.BAY,solution.get("rise",0.8))
				var top: Vector3 = solution.position+basis*Vector3(0,size.y,-size.z/2)
				check.call(solution.snapped and is_equal_approx(solution.rise,height) and top.is_equal_approx(landing) and is_zero_approx(solution.position.y),"%.2f m stairs meet the aimed landing from ground level on a rotated foundation side" % height)
				check.call(builder.placement_error("steps",Transform3D(basis,solution.position),[],{},0,BuildCatalogue.BAY,solution.rise).is_empty(),"The fitted stair flight touches the landing without overlap")
		var piece := ClassicalGeometry.create("steps",0,false,BuildCatalogue.BAY,height)
		var size := BuildCatalogue.piece_size("steps",BuildCatalogue.BAY,height)
		check.call(piece.visual_bounds.size.is_equal_approx(size) and height/BuildCatalogue.stair_count(height) <= 0.20001,"Fitted stair mesh has exact dimensions and climbable risers")
		check.call(Plan.span("steps",BuildCatalogue.BAY,height).is_equal_approx(size),"Stack and group selection bounds include the fitted stair run and rise")
		piece.free()
	# Actual camera ray, ghost, click, history, and save/load must carry the fitted geometry.
	builder.restore([Tools.record("foundation_podium",Vector3(12,0,0))])
	builder.choose("steps")
	builder.angle = PI/2 # The entrance should face the aimed edge automatically.
	builder.elevation = 0
	builder.grid = true
	builder.socket_snap = true
	player.position = Vector3(12,1.2,10)
	player.look_at_point(Vector3(12,1.85,2))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and is_equal_approx(builder.ghost.stair_rise,2) and is_equal_approx(builder.ghost.rotation.y,0) and builder.ghost.position.is_equal_approx(Vector3(12,0,4.5)),"A real side ray previews ten ground-supported steps reaching the podium without manual rotation or height adjustment")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and is_equal_approx(builder.pieces.back().stair_rise,2),"Left-click places the fitted stair geometry rather than the default short flight")
	var records := builder.serialize()
	check.call(records.back().rise == 2 and WorldStore.valid_piece(records.back()),"Fitted stair rise is stored in a valid save record")
	builder.undo()
	builder.redo()
	await Tools.settle(tree)
	check.call(builder.serialize() == records and is_equal_approx(builder.pieces.back().visual_bounds.size.z,5),"Undo/redo restores the complete fitted stairway")
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records and is_equal_approx(builder.pieces.back().visual_bounds.size.y,2),"Save/load preserves the stair's landing height and full run")
	var stair_top: Dictionary = builder.pieces.back().world_sockets()[1]
	check.call(stair_top.position.is_equal_approx(Vector3(12,2,2.25)),"The stair support socket rests on the actual upper tread")
	# Obstructions cannot cause the entrance preview to silently choose a shorter flight.
	builder.remove_uid(int(records.back().uid))
	builder.add_record(Tools.record("foundation",Vector3(12,0,4.5),99))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(not builder.valid and is_equal_approx(builder.ghost.stair_rise,2) and builder.ghost.position.is_equal_approx(Vector3(12,0,4.5)),"An obstructed landing stays blocked at the full fitted height instead of falling back to short stairs")
	builder.remove_uid(99)
	builder.add_record(records.back())
	await Tools.settle(tree)
	# Walk from the ground, up the full staircase, and onto the podium without jumping.
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.set_flying(false)
	player.position = Vector3(12,0.05,8)
	player.look_at_point(Vector3(12,player.camera.global_position.y,-6))
	player.velocity = Vector3.ZERO
	for i in range(12): await tree.physics_frame
	Input.action_press("forward")
	for i in range(100): await tree.physics_frame
	Input.action_release("forward")
	await Tools.settle(tree)
	check.call(player.position.z < 2 and player.position.z > -2 and player.position.y > 1.95 and player.is_on_floor(),"The player walks from the ground up fitted podium stairs onto the platform without jumping")
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	# Stacking fitted stairs preserves dimensions through confirmation and grouped history.
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	var stairs: BuildPiece = builder.pieces.back()
	player.position = Vector3(12,4,10)
	player.look_at_point(stairs.position+Vector3(0,1,0))
	await Tools.settle(tree)
	builder.begin_stack()
	builder.finish_stack_selection()
	player.position = Vector3(40,10,40)
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	builder.change_stack_count(1)
	check.call(builder.stack_valid and builder.stack_copies.size() == 1 and builder.stack_copies[0].stair_rise == 2 and is_equal_approx(builder.stack_copies[0].position.x,16),"The stack tool repeats the full fitted stairway into an adjacent four-metre entrance bay")
	check.call(builder.confirm_stack() and builder.pieces.back().serialize().rise == 2,"Confirming a stair stack keeps its fitted height")
	builder.undo()
	check.call(builder.pieces.size() == 2,"Undo removes the copied fitted stairs as one action")
	# Existing 0.8 m flights retain their original geometry and compact save representation.
	var legacy := Tools.record("steps",Vector3(12,0,5))
	builder.restore([legacy])
	check.call(builder.serialize() == [legacy] and builder.pieces[0].visual_bounds.size.is_equal_approx(Vector3(4,0.8,2)),"Existing saved stair flights remain unchanged")
	for rise in [-1,0,0.1,41,INF,NAN,"2"]:
		var invalid := legacy.duplicate(true)
		invalid.rise = rise
		check.call(not WorldStore.valid_piece(invalid),"Invalid stair heights are rejected before geometry creation")
	var invalid := Tools.record("foundation",Vector3.ZERO)
	invalid.rise = 2
	check.call(not WorldStore.valid_piece(invalid),"Stair height metadata cannot alter a foundation's dimensions")
	builder.restore([])
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	game.ui.show_menu()
