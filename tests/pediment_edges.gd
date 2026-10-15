extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")
const Fit := preload("res://src/building/pediment_fit.gd")
const Layout := preload("res://tests/layout.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(45,18,45)
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(1.13,0,2.27))
		var records := SanctuaryWorld.roof_example()
		for record in records:
			var pos := frame*Vector3(record.position[0],record.position[1],record.position[2])
			record.position = [pos.x,pos.y,pos.z]
			record.rotation += angle
		builder.restore(records)
		await Tools.settle(tree)
		var front_parts: Array = []
		var low := INF
		var high := -INF
		var colliders_baked := true
		var finial_ok := false
		for piece in builder.pieces:
			var local: Vector3 = frame.affine_inverse()*piece.position
			if absf(local.z) > 0.001: continue
			if piece.kind == "finial": finial_ok = is_equal_approx(piece.visual_bounds.position.y,Fit.LIP)
			if piece.kind not in BuildCatalogue.RAKE_KINDS: continue
			var bounds: AABB = (frame.affine_inverse()*piece.transform)*piece.visual_bounds
			low = minf(low,bounds.position.x)
			high = maxf(high,bounds.end.x)
			for child in piece.get_children():
				if child is CollisionShape3D: colliders_baked = colliders_baked and child.basis.is_equal_approx(Basis.IDENTITY)
			var parts := Fit.apply(ClassicalGeometry.get_recipe(piece.kind,piece.join_left,piece.join_right),piece.pediment_fit)
			for part in parts:
				var transformed: Dictionary = part.duplicate()
				transformed.transform = frame.affine_inverse()*piece.transform*part.transform
				front_parts.append(transformed)
		check.call(is_equal_approx(low,1.35) and is_equal_approx(high,22.65),"Large pediment reaches both mitred outer entablature corners at %.0f degrees" % rad_to_deg(angle))
		check.call(colliders_baked,"Fitted pediment collision uses real shape dimensions rather than nonuniform node scaling")
		check.call(finial_ok,"The ridge finial rests on the raised stone cap")
		var hidden := true
		for i in range(81):
			var x := 2+i*0.25
			var y := 5.25+(10-absf(x-12))*0.6+0.15
			hidden = hidden and MeshChecks.front_hit(front_parts,Vector3(x,y,1),Vector3(x,y,-1)) != null
		check.call(hidden,"The whole 20 m roof outline, including tile thickness, is hidden behind the front pediment")
		# All neighbouring rakes use the same affine fit, preserving a continuous diagonal.
		var endpoints := {}
		var continuous := true
		for piece in builder.pieces:
			if piece.kind not in BuildCatalogue.RAKE_KINDS: continue
			for socket in BuildCatalogue.sockets(piece.kind):
				if socket.family != "pediment_rake": continue
				var logical: Vector3 = piece.transform*socket.position
				var key := CornerJoints.point_key(logical)
				var rendered: Vector3 = piece.transform*(piece.pediment_fit*socket.position)
				if endpoints.has(key): continuous = continuous and endpoints[key].distance_to(rendered) < 0.001
				endpoints[key] = rendered
		check.call(continuous,"Widened slope and crown seams meet exactly without cuts or kinks")
		# Unrelated obstacles still block placement in the new overhang.
		var frame_back := Transform3D(frame.basis,frame*Vector3(4,5.25,0))
		var probe := builder.add_record(Tools.record("pedestal",frame*Vector3(1.5,5.25,-0.23),builder.next_uid,angle))
		await Tools.settle(tree)
		var excluded: Array[RID] = []
		for piece in builder.pieces:
			if piece != probe: excluded.append(piece.get_rid())
		check.call(not builder.placement_error("pediment_backing",frame_back,excluded).is_empty(),"The fitted outer edge still rejects unrelated solid overlaps")
	# Compact gables and larger spans use actual support widths, never a fixed overhang scale.
	for width in [4.0,12.0]:
		var frame := Transform3D(Basis.IDENTITY,Vector3(12,4.5,0))
		builder.restore(Layout.room("entablature",width,4,frame))
		var low := INF
		var high := -INF
		for entry in ([["pediment_crown",0,0]] if width == 4 else [["pediment_left",-4,0],["pediment_crown",0,2.4],["pediment_right",4,0]]):
			var piece := builder.add_record(Tools.record(entry[0],Vector3(12+entry[1],5.25+entry[2],2),builder.next_uid))
			var bounds: AABB = piece.transform*piece.visual_bounds
			low = minf(low,bounds.position.x)
			high = maxf(high,bounds.end.x)
		check.call(is_equal_approx(low,12-width/2-0.65) and is_equal_approx(high,12+width/2+0.65),"A %.0f m gable follows its own outer corner span" % width)
	builder.restore([Tools.record("entablature",Vector3(12,4.5,0)),Tools.record("pediment_crown",Vector3(12,5.25,0),2)])
	check.call(builder.pieces.back().pediment_fit.is_equal_approx(Transform3D.IDENTITY),"A straight beam with no mitred overhang keeps the gable at its exact existing width")
	# Existing saved placements refit after supports change, and base/backing courses share the same width.
	var records := SanctuaryWorld.pediment_example()
	records.append(Tools.record("entablature",Vector3(2,4.5,-2),100,PI/2))
	records.append(Tools.record("entablature",Vector3(22,4.5,-2),101,PI/2))
	builder.restore(records)
	await Tools.settle(tree)
	var fitted_base: BuildPiece
	for piece in builder.pieces:
		if piece.kind == "pediment_base" and is_equal_approx(piece.position.x,4): fitted_base = piece
	check.call(fitted_base != null and is_equal_approx((fitted_base.transform*fitted_base.visual_bounds).position.x,1.35),"Base cornices share the slope's exact outer-corner alignment")
	var saved := builder.serialize()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == saved,"Gable fitting preserves all existing save coordinates and attachment records")
	builder.remove_uid(100)
	var unfit := true
	for piece in builder.pieces:
		if piece.kind == "pediment_base" and is_equal_approx(piece.position.x,4):
			unfit = is_equal_approx((piece.transform*piece.visual_bounds).position.x,2)
	check.call(unfit,"Removing a corner beam returns the gable end to the remaining support edge")
	# Native first-person placement uses the fitted mesh before committing the next slope.
	builder.restore(records.filter(func(record): return record.kind not in BuildCatalogue.PEDIMENT_KINDS and record.kind not in BuildCatalogue.SCULPTURE_KINDS and record.kind != "finial"))
	builder.choose("pediment_left")
	builder.angle = 0
	player.position = Vector3(4,8,6)
	player.look_at_point(Vector3(4,5.25,0))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and is_equal_approx((builder.ghost.transform*builder.ghost.visual_bounds).position.x,1.35),"Native placement previews the first slope at the outer corner")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.back().kind == "pediment_left" and is_equal_approx((builder.pieces.back().transform*builder.pieces.back().visual_bounds).position.x,1.35),"Clicking commits the same outer-corner geometry shown in the preview")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
