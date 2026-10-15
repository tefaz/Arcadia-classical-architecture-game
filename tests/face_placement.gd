extends RefCounted

const Tools := preload("res://tests/building_tools.gd")

static func side_only(candidates: Array, top: float) -> bool:
	for candidate in candidates:
		if candidate.snapped and candidate.position.y >= top-0.001: return false
	return true

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	player.active = false
	player.position = Vector3(40,10,40)
	# Even a side hit immediately below an upper edge must never expose stacking candidates.
	for source_kind in ["foundation","entablature","doric_column"]:
		builder.restore([Tools.record(source_kind,Vector3(12,2,0))])
		var source := builder.pieces[0]
		var size := BuildCatalogue.piece_size(source_kind)
		var hit := {"position":Vector3(12,2+size.y-0.01,size.z/2),"normal":Vector3.BACK,"collider":source}
		for definition in BuildCatalogue.PIECES:
			var candidates := SnapSolver.candidates(definition.id,0,hit,builder.pieces,true,true,0)
			check.call(side_only(candidates,2+size.y),source_kind+" side: "+definition.id+" cannot snap on top near the upper edge")
	# On a short component, the opposite end can be inside the snap radius.
	var short_record := Tools.record("cornice",Vector3(12,2,0))
	short_record["length"] = 0.5
	for angle in [0.0,PI/4,PI/2]:
		short_record.rotation = angle
		builder.restore([short_record])
		var source := builder.pieces[0]
		var normal := -source.basis.x
		var hit := {"position":source.transform*Vector3(-0.25,0.24,0),"normal":normal,"collider":source}
		var candidates := SnapSolver.candidates("cornice",angle,hit,builder.pieces,true,true,0)
		var facing := true
		for candidate in candidates:
			if candidate.snapped: facing = facing and (candidate.position-hit.position).dot(normal) >= -0.001
		check.call(facing,"Side candidates stay at the aimed end of a short component rotated %.0f degrees" % rad_to_deg(angle))
	# A neighboring component cannot steal the preview, even if its top is closer.
	builder.restore([Tools.record("cornice",Vector3(12,2,0)),Tools.record("pedestal",Vector3(12,1.2,1),2)])
	var aimed := builder.pieces[0]
	var hit := {"position":Vector3(12,2.24,0.4),"normal":Vector3.BACK,"collider":aimed}
	var candidates := SnapSolver.candidates("base",0,hit,builder.pieces,true,true,0)
	check.call(candidates.all(func(candidate): return not candidate.snapped or candidate.target == aimed),"A side hit cannot attach to a neighboring component's top")
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	hit = {"position":Vector3(14.05,0,0),"normal":Vector3.UP,"collider":null}
	candidates = SnapSolver.candidates("base",0,hit,builder.pieces,true,true,0)
	check.call(candidates.all(func(candidate): return not candidate.snapped),"Looking at ground does not attach to a nearby component")
	# Top and underside hits must not fall back to horizontal edge sockets.
	builder.restore([Tools.record("foundation",Vector3(12,2,0))])
	aimed = builder.pieces[0]
	hit = {"position":Vector3(14,2.4,0),"normal":Vector3.UP,"collider":aimed}
	candidates = SnapSolver.candidates("foundation",0,hit,builder.pieces,true,true,0)
	check.call(candidates.all(func(candidate): return not candidate.snapped or is_equal_approx(candidate.position.y,2.4)),"A top hit offers only stacking connections, including at an edge")
	hit = {"position":Vector3(14,2,0),"normal":Vector3.DOWN,"collider":aimed}
	candidates = SnapSolver.candidates("foundation",0,hit,builder.pieces,true,true,0)
	check.call(candidates.all(func(candidate): return not candidate.snapped or is_equal_approx(candidate.position.y,1.6)),"An underside hit offers only attachments below the component")
	hit.position.x = 12
	var underside := SnapSolver.solve("pedestal",0,hit,builder.pieces,true,true,0)
	check.call(underside.snapped and is_equal_approx(underside.position.y,0.9),"A non-foundation component can attach below an aimed underside")
	# Real camera, raycast, and dispatched left-click: the upper side edge must place beside.
	game.ui.enter_world()
	player.set_flying(true)
	builder.choose("base")
	builder.angle = 0
	builder.grid = true
	builder.socket_snap = true
	player.position = Vector3(12,1.63,6)
	player.look_at_point(Vector3(12,2.35,2))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.target == aimed and builder.valid and is_equal_approx(builder.ghost.position.y,2),"A real upper-side ray previews beside the foundation rather than on top")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and is_equal_approx(builder.pieces.back().position.y,2),"Left-clicking a side face places beside the existing piece")
	builder.undo()
	await Tools.settle(tree)
	player.position = Vector3(12,5,6)
	player.look_at_point(Vector3(12,2.4,1.9))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.target == aimed and builder.valid and is_equal_approx(builder.ghost.position.y,2.4),"Looking at the actual top face previews on top")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and is_equal_approx(builder.pieces.back().position.y,2.4),"Left-clicking the top face still stacks correctly")
	builder.undo()
	await Tools.settle(tree)
	builder.update_preview()
	player.position = Vector3(12,1.63,6)
	player.look_at_point(Vector3(12,2.35,2))
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and is_equal_approx(builder.pieces.back().position.y,2),"Click rechecks the aimed face after moving from a top preview to a side")
	# If the aimed end is blocked, a clear opposite end must not be used instead.
	builder.restore([short_record,Tools.record("base",Vector3(9.75,2,0),2)])
	# Return the short run to the world X axis after the rotation coverage above.
	builder.pieces[0].rotation.y = 0
	builder.refresh_connections()
	builder.choose("cornice")
	builder.angle = 0
	player.position = Vector3(11,1.52,2)
	player.look_at_point(Vector3(11.75,2.24,0))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.target == builder.pieces[0] and not builder.valid and builder.ghost.position.x < 12,"A blocked aimed end remains blocked instead of jumping to the clear opposite end")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2,"Left-click cannot place at an un-aimed face when the aimed face is blocked")
	builder.restore([])
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.set_flying(false)
	game.ui.show_menu()
