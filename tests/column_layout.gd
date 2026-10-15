extends RefCounted

const Tools := preload("res://tests/building_tools.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12.13,0.37,6.27))
		builder.restore([Tools.record("foundation_large",frame.origin,1,angle)])
		var platform := builder.pieces[0]
		for point in [Vector3(-2,0.4,-2),Vector3(2,0.4,-2),Vector3(2,0.4,2),Vector3(-2,0.4,2)]:
			var expected: Vector3 = frame*point
			var hit := {"position":expected+frame.basis*Vector3(0.65,0,0.55),"normal":Vector3.UP,"collider":platform}
			var solution := SnapSolver.solve("doric_column",0,hit,builder.pieces,true,true,0)
			check.call(solution.position.is_equal_approx(expected) and solution.has("guide_points"),"Approximate column aim snaps to an exact four-metre bay on a %.0f-degree platform" % rad_to_deg(angle))
			builder.add_record(Tools.record("doric_column",solution.position,builder.next_uid))
			await Tools.settle(tree)
		var columns: Array[BuildPiece] = []
		for piece in builder.pieces:
			if piece.kind == "doric_column": columns.append(piece)
		for i in range(4):
			var first := columns[i]
			var last := columns[(i+1)%4]
			var direction := (last.position-first.position).normalized()
			var yaw := atan2(-direction.z,direction.x)
			var top := first.position+Vector3.UP*4.1
			var hit := {"position":top,"normal":Vector3.UP,"collider":first}
			var solution := SnapSolver.solve("entablature",yaw,hit,builder.pieces,true,true,0)
			var transform_value := Transform3D(Basis(Vector3.UP,yaw),solution.position)
			check.call(solution.position.is_equal_approx((first.position+last.position)/2+Vector3.UP*4.1) and solution.length == 4,"Default beam attachment spans the guided column centres without cycling T")
			check.call(builder.placement_error("entablature",transform_value).is_empty(),"The guided column bay accepts its entablature, including the final closing side")
			builder.add_record(Tools.record("entablature",solution.position,builder.next_uid,yaw))
			await Tools.settle(tree)
		var closed := true
		for piece in builder.pieces:
			if piece.kind == "entablature": closed = closed and piece.join_left != 0 and piece.join_right != 0
		check.call(closed,"All eight beam ends mitre into a closed square on the guided columns")
	# Match a hand-built, off-grid first column across joined modules of different sizes.
	builder.restore([Tools.record("foundation",Vector3(12,0,0),1),Tools.record("foundation",Vector3(16,0,0),2),Tools.record("doric_column",Vector3(12.5,0.4,0.5),3)])
	var hit := {"position":Vector3(16.9,0.4,0.8),"normal":Vector3.UP,"collider":builder.pieces[1]}
	var solution := SnapSolver.solve("ionic_column",0,hit,builder.pieces,true,true,0)
	check.call(solution.position.is_equal_approx(Vector3(16.5,0.4,0.5)),"Column layout follows an existing off-grid column across joined foundation tiles, including matching Ionic columns")
	var free := SnapSolver.solve("ionic_column",0,hit,builder.pieces,false,false,0)
	check.call(free.position.is_equal_approx(hit.position) and not free.has("guide_points"),"Alt-style free placement bypasses the column layout")
	var no_grid := SnapSolver.solve("ionic_column",0,hit,builder.pieces,false,true,0)
	check.call(not no_grid.has("guide_points"),"Disabling the grid restores ordinary socket placement")
	var raised := SnapSolver.solve("ionic_column",0,hit,builder.pieces,true,true,0.25)
	check.call(not raised.has("guide_points"),"Manual elevation bypasses automatic column spacing")
	# Nearby buildings and different-height columns must not shift the platform grid.
	builder.restore([Tools.record("foundation_large",Vector3(12,0,0),1),Tools.record("foundation",Vector3(20,0,0),2),Tools.record("doric_column",Vector3(19.5,0.4,0.5),3),Tools.record("corinthian_column",Vector3(10.5,0.4,-1.5),4)])
	hit = {"position":Vector3(10.6,0.4,-1.4),"normal":Vector3.UP,"collider":builder.pieces[0]}
	solution = SnapSolver.solve("doric_column",0,hit,builder.pieces,true,true,0)
	check.call(solution.position.is_equal_approx(Vector3(10,0.4,-2)),"Separate platforms and different column heights cannot steal the layout origin")
	# Real camera/click placement uses the same guide and preserves normal undo and saves.
	builder.restore([Tools.record("foundation_large",Vector3(12,0,0))])
	builder.choose("doric_column")
	builder.angle = 0
	builder.elevation = 0
	builder.grid = true
	builder.socket_snap = true
	player.position = Vector3(10.6,6,4.6)
	player.look_at_point(Vector3(10.6,0.4,-1.4))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(10,0.4,-2)) and builder.column_guides.visible,"A first-person approximate click previews an exact column centre and visible floor guides")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().position.is_equal_approx(Vector3(10,0.4,-2)),"Native left-click places the column on its marked centre")
	var saved := builder.serialize()
	builder.undo()
	builder.redo()
	check.call(builder.serialize() == saved,"Guided columns remain ordinary undoable component records")
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == saved,"Saving and reloading preserves guided column positions exactly")
	builder.choose("entablature")
	player.position = Vector3(7,8,2)
	player.look_at_point(Vector3(10,4.5,-2))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.anchor == 0 and builder.ghost.position.is_equal_approx(Vector3(12,4.5,-2)) and not builder.column_guides.visible,"A real column-top ray starts an entablature at its end with the default anchor")
	builder.choose("doric_column")
	player.position = Vector3(14.6,6,4.6)
	player.look_at_point(Vector3(14.6,0.4,-1.4))
	await Tools.settle(tree)
	check.call(builder.column_guides.visible,"Equipping a column restores the layout guides")
	builder.grid = false
	builder.update_preview()
	check.call(not builder.column_guides.visible,"Disabling grid clears the guides immediately")
	builder.grid = true
	builder.update_preview()
	game.ui.show_catalogue()
	await Tools.settle(tree)
	check.call(not builder.column_guides.visible,"Opening a menu clears column layout guides")
	game.ui.enter_world()
	builder.clear_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	await Tools.settle(tree)
	check.call(not builder.column_guides.visible,"Selecting an empty slot clears the layout overlay")
	builder.restore([])
	game.ui.show_menu()
