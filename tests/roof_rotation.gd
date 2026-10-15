extends RefCounted

const Tools := preload("res://tests/building_tools.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	for angle in [0.0,PI/4]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,4,0))
		for kind in ["roof_left","roof_left_half","stone_roof_left","stone_roof_left_half"]:
			var size := BuildCatalogue.piece_size(kind)
			var half := size.x == 2
			var gable := "pediment_crown" if half else "pediment_right"
			var offset := 1.0 if half else 0.0
			builder.restore([Tools.record(gable,frame.origin,1,angle)])
			await Tools.settle(tree)
			var hit := {"position":frame*Vector3(offset,size.y/2,-0.31),"normal":-frame.basis.z,"collider":builder.pieces[0]}
			var solution := SnapSolver.solve(kind,angle+PI,hit,builder.pieces,true,true,0)
			var expected := frame*Vector3(offset,0,-2)
			check.call(solution.snapped and solution.position.is_equal_approx(expected),kind+": rotating 180 degrees fits the right-hand pediment at %.0f degrees" % rad_to_deg(angle))
			check.call(builder.placement_error(kind,Transform3D(Basis(Vector3.UP,angle+PI),expected)).is_empty(),"The rotated slope clears the gable cornice")
			var roof := builder.add_record(Tools.record(kind,expected,2,angle+PI))
			check.call(roof.join_left == 1 and roof.join_right == 0,"The rotated slope trims its attached local back end")
			builder.remove_uid(1)
			await Tools.settle(tree)
			hit = {"position":expected+frame.basis.z*2+Vector3.UP*size.y/2,"normal":frame.basis.z,"collider":roof}
			var rear := SnapSolver.solve(gable,angle,hit,builder.pieces,true,true,0)
			check.call(rear.snapped and rear.position.is_equal_approx(frame.origin),"A right-hand gable can attach after a rotated generic slope")
			check.call(builder.placement_error(gable,Transform3D(frame.basis,frame.origin)).is_empty(),"Reverse placement trims the rotated roof before checking collision")
			# Extend a legacy right slope with the current library slope rotated 180 degrees.
			var old: String = kind.replace("left","right")
			builder.restore([Tools.record(old,frame.origin,1,angle)])
			await Tools.settle(tree)
			hit = {"position":frame*Vector3(0,size.y/2,2),"normal":frame.basis.z,"collider":builder.pieces[0]}
			solution = SnapSolver.solve(kind,angle+PI,hit,builder.pieces,true,true,0)
			check.call(solution.snapped and solution.position.is_equal_approx(frame*Vector3(0,0,4)),"Rotated library slopes continue saved right-slope depth bays")
			# Close a ridge using two copies of the same kind.
			builder.restore([Tools.record(kind,frame.origin,1,angle)])
			await Tools.settle(tree)
			hit = {"position":frame*Vector3(size.x/2,size.y,0),"normal":frame.basis.x,"collider":builder.pieces[0]}
			solution = SnapSolver.solve(kind,angle+PI,hit,builder.pieces,true,true,0)
			check.call(solution.snapped and solution.position.is_equal_approx(frame*Vector3(size.x,0,0)),"Two copies of one slope close the ridge when one is turned around")
	# Native R input, placement, persistence, and picking a retired side.
	builder.restore([Tools.record("pediment_right",Vector3(12,4,0))])
	builder.choose("stone_roof_left")
	builder.angle = 0
	player.position = Vector3(12,4,-8)
	player.look_at_point(Vector3(12,5.15,-0.31))
	await Tools.key(tree,KEY_R)
	await Tools.key(tree,KEY_R)
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,4,-2)),"Pressing R twice previews the single stone slope behind a right pediment")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == "stone_roof_left" and is_equal_approx(absf(builder.pieces.back().rotation.y),PI),"Native placement uses the same slope kind on the opposite side")
	var records := builder.serialize()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Rotated generic slopes preserve their orientation and gable fit through save/load")
	builder.restore([Tools.record("stone_roof_right",Vector3(12,4,0),1,PI/4,1)])
	await Tools.settle(tree)
	await Tools.aim(tree,game,builder.pieces[0])
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "stone_roof_left" and absf(angle_difference(builder.angle,PI/4+PI)) < 0.001 and builder.stone == 1,"Picking a saved right slope equips the single current slope with equivalent rotation and finish")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
