extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func decorations_unchanged(length: float, left: int, right: int) -> bool:
	var straight := ClassicalGeometry.get_recipe("wall_window_pediment",0,0,length)
	var joined := ClassicalGeometry.get_recipe("wall_window_pediment",left,right,length)
	var tilted := 0
	for part in straight:
		if part.transform.basis.is_equal_approx(Basis.IDENTITY): continue
		tilted += 1
		var found := false
		for other in joined:
			if other.get("mesh") == part.get("mesh") and other.transform.is_equal_approx(part.transform): found = true
		if not found: return false
	if tilted != 4: return false
	for x in [-0.8,-0.58,0.0,0.58,0.8]:
		for y in [3.20,3.45,3.65,3.85]:
			for side in [-1,1]:
				var from := Vector3(x*minf(1,length/4),y,side*2)
				var to := Vector3(from.x,y,0)
				var original: Variant = MeshChecks.front_hit(straight,from,to)
				var changed: Variant = MeshChecks.front_hit(joined,from,to)
				if original == null or changed == null:
					if original != changed: return false
				elif not original.is_equal_approx(changed): return false
	return true

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	for length in [2.5,3.56,4.0]:
		for left in [-1,0,1]:
			for right in [-1,0,1]:
				check.call(decorations_unchanged(length,left,right),"Pediment slopes and decorative silhouettes remain unchanged at corner flags %d/%d and span %.2f" % [left,right,length])
	var builder: ClassicalBuilder = game.builder
	game.player.position = Vector3(40,10,40)
	builder.restore([Tools.record("wall_window_pediment",Vector3(12,0,0)),Tools.record("wall_window_pediment",Vector3(14,0,2),2,-PI/2)])
	await Tools.settle(tree)
	var correct := true
	for wall in builder.pieces:
		correct = correct and (wall.join_left != 0 or wall.join_right != 0)
		for part in ClassicalGeometry.get_recipe(wall.kind,wall.join_left,wall.join_right):
			if part.get("mesh") is BoxMesh and not part.transform.basis.is_equal_approx(Basis.IDENTITY):
				correct = correct and absf(part.transform.basis.y.x) > 0.5
	check.call(correct,"Two real triangle-window walls form a corner while keeping their diagonal mouldings")
	var records := builder.serialize()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records and decorations_unchanged(4,builder.pieces[0].join_left,builder.pieces[0].join_right),"Saved window corners reconstruct without the extra vertical strips")
	builder.restore([])
