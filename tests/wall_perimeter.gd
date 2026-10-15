extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Perimeter := preload("res://src/building/wall_perimeter.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	for foundation in BuildCatalogue.FOUNDATION_KINDS:
		for angle in [0.0,PI/4]:
			var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,1.2,0))
			builder.restore([Tools.record(foundation,frame.origin,1,angle)])
			await Tools.settle(tree)
			var size := BuildCatalogue.piece_size(foundation)
			for kind in BuildCatalogue.WALL_KINDS:
				for side in [-1,1]:
					var hit := {"position":frame*Vector3(-size.x/2+0.08,size.y,side*(size.z/2-0.08)),"normal":Vector3.UP,"collider":builder.pieces[0]}
					var solution := SnapSolver.solve(kind,angle,hit,builder.pieces,true,true,0)
					var expected := frame*Vector3(-size.x/2+2+(0 if size.x == 4 else 0.11),size.y,side*(size.z/2-0.22))
					var span := 3.56 if size.x == 4 else 3.78
					check.call(solution.snapped and solution.position.is_equal_approx(expected) and is_equal_approx(solution.length,span),kind+": a corner-top hit fits the first bay flush on "+foundation)
					check.call(builder.placement_error(kind,Transform3D(frame.basis,solution.position),[],{},0,solution.length).is_empty(),"The flush wall sits at the exact platform top without overlap")
					var record := Tools.record(kind,solution.position,2,angle)
					record.length = solution.length
					check.call(WorldStore.valid_piece(record),"Trimmed perimeter wall lengths remain valid save records")
	# A two-foundation platform has one exposed perimeter, without a wall on the internal seam.
	builder.restore([Tools.record("foundation",Vector3(10,0,0)),Tools.record("foundation",Vector3(14,0,0),2)])
	await Tools.settle(tree)
	var front := {"position":Vector3(8.1,0.4,1.95),"normal":Vector3.UP,"collider":builder.pieces[0]}
	var first := SnapSolver.solve("wall",0,front,builder.pieces,true,true,0)
	front.position.x = 15.9
	front.collider = builder.pieces[1]
	var last := SnapSolver.solve("wall",0,front,builder.pieces,true,true,0)
	check.call(first.position.is_equal_approx(Vector3(10.11,0.4,1.78)) and last.position.is_equal_approx(Vector3(13.89,0.4,1.78)) and is_equal_approx(first.length,3.78) and is_equal_approx(last.length,3.78),"Joined foundation bays trim only the outer run ends and meet exactly at their shared seam")
	var internal := {"position":Vector3(11.95,0.4,0),"normal":Vector3.UP,"collider":builder.pieces[0]}
	check.call(Perimeter.solve("wall",Basis(Vector3.UP,PI/2),internal,builder.pieces,0,0).is_empty(),"A joined foundation's internal seam is never treated as an exposed edge")
	# A neighbour covering only half an edge leaves just the other half exposed.
	var rectangles: Array[Rect2] = [Rect2(-2,-4,4,8),Rect2(2,0,4,4)]
	var exposed := Perimeter.intervals(rectangles,1,1,2)
	check.call(exposed.size() == 1 and exposed[0].is_equal_approx(Vector2(-4,0)),"Stepped platforms keep only the uncovered part of an edge")
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	await Tools.settle(tree)
	var top := {"position":Vector3(12,0.4,1.95),"normal":Vector3.UP,"collider":builder.pieces[0]}
	check.call(not SnapSolver.solve("wall",0,top,builder.pieces,false,true,0).label.begins_with("Foundation perimeter") and not SnapSolver.solve("wall",0,top,builder.pieces,true,false,0).label.begins_with("Foundation perimeter"),"Disabling grid or sockets bypasses automatic perimeter fitting")
	check.call(not SnapSolver.solve("wall",PI/4,top,builder.pieces,true,true,0).label.begins_with("Foundation perimeter") and not SnapSolver.solve("wall",0,top,builder.pieces,true,true,0,0,{},3).label.begins_with("Foundation perimeter"),"Skewed rotations and explicit lengths retain manual placement")
	var side_hit := top.duplicate()
	side_hit.position = Vector3(12,0.39,2)
	side_hit.normal = Vector3.BACK
	check.call(not SnapSolver.solve("wall",0,side_hit,builder.pieces,true,true,0).label.begins_with("Foundation perimeter"),"An actual foundation side hit retains side placement")
	# The two inset centre lines also meet at an inward L-shaped corner.
	builder.restore([Tools.record("foundation",Vector3(10,0,0)),Tools.record("foundation",Vector3(14,0,0),2),Tools.record("foundation",Vector3(10,0,4),3)])
	await Tools.settle(tree)
	var l_front := {"position":Vector3(14,0.4,1.95),"normal":Vector3.UP,"collider":builder.pieces[1]}
	var l_side := {"position":Vector3(11.95,0.4,4),"normal":Vector3.UP,"collider":builder.pieces[2]}
	var horizontal := SnapSolver.solve("wall",0,l_front,builder.pieces,true,true,0)
	var vertical := SnapSolver.solve("wall",PI/2,l_side,builder.pieces,true,true,0)
	check.call(horizontal.position.is_equal_approx(Vector3(13.78,0.4,1.78)) and vertical.position.is_equal_approx(Vector3(11.78,0.4,3.78)) and horizontal.length == 4 and vertical.length == 4,"L-shaped platform walls extend their inset lines to the same concave corner")
	var horizontal_record := Tools.record("wall",horizontal.position,4)
	horizontal_record.length = horizontal.length
	builder.add_record(horizontal_record)
	await Tools.settle(tree)
	check.call(builder.placement_error("wall",Transform3D(Basis(Vector3.UP,PI/2),vertical.position),[],{},0,vertical.length).is_empty(),"The fitted inward corner passes real collision checks")
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	await Tools.settle(tree)
	# Four native clicks close a flush ring, without manually nudging position or length.
	builder.choose("wall")
	builder.angle = 0
	for i in range(4):
		var basis := Basis(Vector3.UP,PI*i/2)
		player.position = Vector3(12,0,0)+basis*Vector3(0,8,8)
		player.look_at_point(Vector3(12,0.4,0)+basis*Vector3(0,0,1.95))
		await Tools.settle(tree)
		builder.update_preview()
		check.call(builder.valid and builder.snap_label.begins_with("Foundation perimeter"),"A real foundation-top ray previews a flush wall on side "+str(i))
		await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
		if i < 3: await Tools.key(tree,KEY_R)
	check.call(builder.pieces.size() == 5,"Four ordinary clicks place all four perimeter walls")
	var bounds := AABB()
	var initialized := false
	var mitred := true
	for piece in builder.pieces:
		if piece.kind != "wall": continue
		var extent: AABB = piece.transform*piece.visual_bounds
		bounds = extent if not initialized else bounds.merge(extent)
		initialized = true
		mitred = mitred and piece.join_left != 0 and piece.join_right != 0
	check.call(mitred and bounds.position.is_equal_approx(Vector3(10,0.4,-2)) and bounds.size.is_equal_approx(Vector3(4,4.1,4)),"The closed wall ring mitres at all corners and its outer masonry exactly matches the foundation footprint")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Precise perimeter spans and placements survive undo/redo and save/load")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
