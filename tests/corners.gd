extends RefCounted

static func record(kind: String, pos: Vector3, uid: int, angle: float = 0) -> Dictionary:
	return {"uid":uid,"kind":kind,"stone":0,"position":[pos.x,pos.y,pos.z],"rotation":angle}

static func settle(tree: SceneTree) -> void:
	for i in range(2):
		await tree.physics_frame
		await tree.process_frame

static func ring(kind: String, width: int = 4, depth: int = 4, origin: Vector3 = Vector3.ZERO, rotation_value: float = 0) -> Array:
	var result: Array = []
	var basis := Basis(Vector3.UP,rotation_value)
	for sign_value in [-1,1]:
		for x in range(-width/2+2,width/2,4):
			result.append(record(kind,origin+basis*Vector3(x,0,sign_value*depth/2),result.size()+1,rotation_value))
		for z in range(-depth/2+2,depth/2,4):
			result.append(record(kind,origin+basis*Vector3(sign_value*width/2,0,z),result.size()+1,rotation_value+PI/2))
	return result

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	player.active = false
	player.position = Vector3(40,1,40)
	for kind in BuildCatalogue.MITRE_KINDS:
		builder.restore([])
		var a := builder.add_record(record(kind,Vector3(12,0,0),100))
		await settle(tree)
		var height: float = BuildCatalogue.get_piece(kind).size.y
		var hit := {"position":Vector3(14,height/2,0.08),"normal":Vector3.BACK,"collider":a}
		var solution := SnapSolver.solve(kind,-PI/2,hit,builder.pieces,true,true,0)
		check.call(solution.snapped and solution.position.is_equal_approx(Vector3(14,0,2)),kind+": rotated piece snaps to the end at 90 degrees")
		check.call(solution.label.begins_with("Mitred corner"),kind+": preview names the corner connection")
		var outside_hit := hit.duplicate()
		outside_hit.position.z = -0.1
		outside_hit.normal = Vector3.FORWARD
		var same_direction := SnapSolver.solve(kind,-PI/2,outside_hit,builder.pieces,true,true,0)
		check.call(same_direction.position.is_equal_approx(solution.position),kind+": camera side does not override the chosen rotation")
		var other_end := SnapSolver.solve(kind,-PI/2,hit,builder.pieces,true,true,0,2)
		check.call(other_end.position.is_equal_approx(Vector3(14,0,-2)),kind+": T's opposite anchor reverses the corner extension")
		check.call(builder.placement_error(kind,Transform3D(Basis(Vector3.UP,-PI/2),solution.position)).is_empty(),kind+": legitimate corner passes collision checks")
		var b := builder.add_record(record(kind,solution.position,101,-PI/2))
		builder.record_action({"op":"add","piece":b.serialize()})
		await settle(tree)
		check.call(a.join_right == 1 and b.join_left == 1,kind+": both touching ends receive matching mitres")
		check.call(a.visual_bounds.end.x > 2.05,kind+": outside corner fills beyond the logical endpoint")
		var winding_correct := true
		for part in ClassicalGeometry.get_recipe(kind,0,1):
			if not part.has("mesh") or part.transform != Transform3D.IDENTITY:
				continue
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(0,vertices.size(),3):
				var cross := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
				winding_correct = winding_correct and cross.dot(normals[i]) < -0.99
		check.call(winding_correct,kind+": mitred surfaces use Godot's outward-facing triangle order")
		var test_y: float = {"wall":2.0,"entablature":0.67,"cornice":0.24,"balustrade":1.075}.get(kind,2.0)
		var width: float = {"wall":0.32,"entablature":1.3,"cornice":0.8,"balustrade":0.5}.get(kind,0.32)
		var query := PhysicsPointQueryParameters3D.new()
		query.position = Vector3(14+width*0.15,test_y,-width*0.4)
		query.collision_mask = 2
		var hits := game.get_world_3d().direct_space_state.intersect_point(query)
		check.call(hits.size() == 1,kind+": outer corner is solid without overlapping solids")
		var crossing := Transform3D(Basis(Vector3.UP,PI/2),Vector3(12,0,0))
		check.call(not builder.placement_error(kind,crossing).is_empty(),kind+": interior crossing still fails collision checks")
		var third := Transform3D(Basis(Vector3.UP,PI/2),Vector3(14,0,-2))
		check.call(not builder.placement_error(kind,third).is_empty(),kind+": a third run cannot occupy an existing corner")
		builder.undo()
		check.call(a.join_right == 0,kind+": removing one leg restores the neighbor's straight end")
		builder.redo()
		check.call(a.join_right == 1,kind+": undo/redo rebuilds corner connections")
		var saved := builder.serialize()
		check.call(not saved[0].has("join_right"),kind+": save stores placements without brittle connection links")
		builder.restore(saved)
		check.call(builder.pieces[0].join_right == 1,kind+": loading an old-format layout reconstructs the corner")
		# The last side must fit against both existing corners, not just its aimed target.
		var records := ring(kind,4,4,Vector3(12,0,-10))
		var final_record: Dictionary = records.pop_back()
		builder.restore(records)
		await settle(tree)
		var p: Array = final_record.position
		var transform_value := Transform3D(Basis(Vector3.UP,final_record.rotation),Vector3(p[0],p[1],p[2]))
		var joints := CornerJoints.describe(kind,transform_value,builder.connection_index)
		check.call(joints.partners.size() == 2 and not joints.conflict,kind+": closing side finds both corner partners")
		check.call(builder.placement_error(kind,transform_value).is_empty(),kind+": fourth side closes a full square room")
		# Exercise the user's rotate / aim / place flow with a real camera ray.
		builder.choose(kind)
		builder.angle = final_record.rotation
		builder.anchor = 2
		player.position = Vector3(15.6,test_y-0.72,-10.2)
		player.look_at_point(Vector3(13.95,test_y,-12+width/2))
		builder.update_preview()
		check.call(builder.valid and builder.ghost.position.is_equal_approx(transform_value.origin),kind+": first-person corner preview fits the missing side")
		builder.place()
		check.call(builder.pieces.size() == 4,kind+": normal Place action closes the four-sided room")
		player.position = Vector3(40,1,40)
		var all_joined := true
		for piece in builder.pieces:
			all_joined = all_joined and piece.join_left != 0 and piece.join_right != 0
		check.call(all_joined,kind+": every end joins in a closed four-sided layout")
		await settle(tree)
		query.position = Vector3(12,test_y,-10)
		check.call(game.get_world_3d().direct_space_state.intersect_point(query).is_empty(),kind+": the interior remains clear")
		for sx in [-1,1]:
			for sz in [-1,1]:
				query.position = Vector3(12+sx*(2+width*0.15),test_y,-10+sz*(2+width*0.4))
				check.call(game.get_world_3d().direct_space_state.intersect_point(query).size() == 1,kind+": outer corner %d,%d is filled without overlap" % [sx,sz])
		# Multi-bay, rectangular and rotated footprints preserve 4m logical module lengths.
		for size_value in [Vector2i(8,8),Vector2i(8,12)]:
			var rotated := ring(kind,size_value.x,size_value.y,Vector3(12,1.25,12),PI/4)
			rotated.reverse()
			builder.restore(rotated)
			var end_count := 0
			for piece in builder.pieces:
				end_count += int(piece.join_left != 0)+int(piece.join_right != 0)
			check.call(end_count == 8,kind+": rotated %dx%d multi-bay rectangle has exactly four corners" % [size_value.x,size_value.y])
			check.call(builder.pieces.size() == rotated.size(),kind+": corner rebuilding preserves every module")
	builder.restore([])
