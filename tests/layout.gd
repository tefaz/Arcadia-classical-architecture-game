extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func record(kind: String, pos: Vector3, uid: int, angle: float = 0, length: float = 4) -> Dictionary:
	var result := {"uid":uid,"kind":kind,"stone":1,"position":[pos.x,pos.y,pos.z],"rotation":angle}
	if not is_equal_approx(length,4): result["length"] = length
	return result

static func room(kind: String, width: float, depth: float, frame: Transform3D) -> Array:
	var result: Array = []
	var rotation_value := frame.basis.get_euler().y
	for z in [-depth/2,depth/2]:
		var x := -width/2
		while x < width/2-0.001:
			var length := minf(4,width/2-x)
			result.append(record(kind,frame*Vector3(x+length/2,0,z),result.size()+1,rotation_value,length))
			x += length
	for x in [-width/2,width/2]:
		var z := -depth/2
		while z < depth/2-0.001:
			var length := minf(4,depth/2-z)
			result.append(record(kind,frame*Vector3(x,0,z+length/2),result.size()+1,rotation_value-PI/2,length))
			z += length
	return result

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	player.active = false
	player.position = Vector3(40,10,40)
	# Every component follows the support's local grid without quantizing away its exact height.
	var frame := Transform3D(Basis(Vector3.UP,PI/4),Vector3(12.13,0.37,6.27))
	for definition in BuildCatalogue.PIECES:
		builder.restore([record(definition.id,frame.origin,1,PI/4)])
		var source := builder.pieces[0]
		var hit := {"position":frame*Vector3(0.24,definition.size.y,0.76),"normal":Vector3.UP,"collider":source}
		var solution := SnapSolver.solve("urn",PI/4,hit,builder.pieces,true,false,0)
		check.call(solution.position.is_equal_approx(frame*Vector3(0,definition.size.y,1)),definition.id+": surface grid preserves rotated local alignment and exact support height")
	for kind in BuildCatalogue.FOUNDATION_KINDS:
		var coherent := true
		for socket in BuildCatalogue.sockets(kind):
			if socket.normal != Vector3.UP: continue
			coherent = coherent and is_equal_approx(socket.position.x,snappedf(socket.position.x,1)) and is_equal_approx(socket.position.z,snappedf(socket.position.z,1))
		check.call(coherent,kind+": support sockets avoid half-metre insets that break standard bays")
	# A real foundation -> four columns -> four-beam ring, without target collision exclusions.
	builder.restore([record("foundation_large",Vector3(12,0,0),1)])
	var platform := builder.pieces[0]
	for x in [-2.0,2.0]:
		for z in [-2.0,2.0]:
			var hit := {"position":Vector3(12+x,0.4,z),"normal":Vector3.UP,"collider":platform}
			var solution := SnapSolver.solve("doric_column",0,hit,builder.pieces,true,true,0)
			builder.add_record(record("doric_column",solution.position,builder.next_uid))
	await Tools.settle(tree)
	var ring := room("entablature",4,4,Transform3D(Basis.IDENTITY,Vector3(12,4.5,0)))
	var compatible := true
	for entry in ring:
		var p: Array = entry.position
		var transform_value := Transform3D(Basis(Vector3.UP,entry.rotation),Vector3(p[0],p[1],p[2]))
		compatible = compatible and builder.placement_error("entablature",transform_value).is_empty()
		entry.uid = builder.next_uid
		builder.add_record(entry)
		await Tools.settle(tree)
	check.call(compatible,"Foundation column sockets support a complete entablature rectangle without blocked corners")
	# Fit the first beam of a narrow column bay without requiring existing runs at the far end.
	builder.restore([record("doric_column",Vector3(12,0.4,0),1),record("doric_column",Vector3(14.5,0.4,0),2)])
	await Tools.settle(tree)
	var column_hit := {"position":Vector3(12,4.5,0),"normal":Vector3.UP,"collider":builder.pieces[0]}
	var first_beam := SnapSolver.solve("entablature",0,column_hit,builder.pieces,true,true,0,1)
	check.call(first_beam.snapped and first_beam.length == 2.5 and first_beam.position.is_equal_approx(Vector3(13.25,4.5,0)),"The first entablature automatically fits a 2.5 m column bay")
	check.call(builder.placement_error("entablature",Transform3D(Basis.IDENTITY,first_beam.position),[],{},0,first_beam.length).is_empty(),"A fitted first beam rests on both column tops without overlap exceptions")
	var fixed_beam := SnapSolver.solve("entablature",0,column_hit,builder.pieces,true,true,0,1,{},4)
	check.call(fixed_beam.length == 4 and fixed_beam.position.is_equal_approx(Vector3(14,4.5,0)),"Explicit span lengths take precedence over automatic support fitting")
	# Short straight infills and double-ended corners must close from either direction and at any rotation.
	for kind in BuildCatalogue.MITRE_KINDS:
		var clean := true
		for length in [0.5,2.5,8.0]:
			for left in [-1,0,1]:
				for right in [-1,0,1]:
					for part in ClassicalGeometry.get_recipe(kind,left,right,length):
						if not part.has("mesh"): continue
						var report := MeshChecks.audit(part.mesh)
						clean = clean and report.finite and report.winding and report.closed and not report.degenerate and report.volume < 0
		check.call(clean,kind+": shortest, fitted and longest span meshes have closed outward-facing corner geometry")
		for width in [2.5,3.0,3.5,5.5]:
			for angle in [0.0,PI/4]:
				frame = Transform3D(Basis(Vector3.UP,angle),Vector3(12.13,1.35,8.27))
				var records := room(kind,width,5.5,frame)
				var closing_index := ceili(width/4)-1
				var missing: Dictionary = records[closing_index]
				records.remove_at(closing_index)
				builder.restore(records)
				await Tools.settle(tree)
				var height: float = BuildCatalogue.get_piece(kind).size.y
				var fixed_x: float = -width/2+4*closing_index
				var fixed := frame*Vector3(fixed_x,0,-2.75)
				var source: BuildPiece
				for piece in builder.pieces:
					if CornerJoints.end_point(piece.transform,1,piece.span_length).distance_to(fixed) < 0.005 or CornerJoints.end_point(piece.transform,-1,piece.span_length).distance_to(fixed) < 0.005:
						source = piece
						break
				var hit := {"position":fixed+Vector3.UP*height/2,"normal":frame.basis.z*-1,"collider":source}
				var solution := SnapSolver.solve(kind,angle,hit,builder.pieces,true,true,0,1,builder.connection_index)
				var expected: Array = missing.position
				var expected_length: float = missing.get("length",4)
				check.call(solution.snapped and is_equal_approx(solution.length,expected_length) and solution.position.is_equal_approx(Vector3(expected[0],expected[1],expected[2])),kind+": automatically fits %.1f m gap in %.1f m rotated rectangle" % [expected_length,width])
				var transform_value := Transform3D(Basis(Vector3.UP,angle),solution.position)
				check.call(builder.placement_error(kind,transform_value,[],{},0,solution.length).is_empty(),kind+": fitted closing span passes real physics at %.1f m and %.0f degrees" % [width,rad_to_deg(angle)])
				# Reverse attachment must preserve the other fixed end.
				var other := frame*Vector3(width/2,0,-2.75)
				hit.position = other+Vector3.UP*height/2
				for peer in builder.pieces:
					if CornerJoints.end_point(peer.transform,1,peer.span_length).distance_to(other) < 0.005 or CornerJoints.end_point(peer.transform,-1,peer.span_length).distance_to(other) < 0.005:
						hit.collider = peer
						break
				var reverse := SnapSolver.solve(kind,angle+PI,hit,builder.pieces,true,true,0,1,builder.connection_index)
				check.call(is_equal_approx(reverse.length,expected_length) and reverse.position.is_equal_approx(solution.position),kind+": infill also fits from the opposite end")
				if is_zero_approx(angle) and is_equal_approx(width,3):
					builder.choose(kind)
					builder.angle = angle
					builder.anchor = 1
					player.position = frame*Vector3(fixed_x+1,height/2-0.72,-4.75)
					player.look_at_point(fixed+Vector3.UP*height/2)
					builder.update_preview()
					check.call(builder.valid and is_equal_approx(builder.ghost.span_length,3),kind+": first-person preview automatically fits the closing span")
					builder.place()
					check.call(builder.pieces.size() == records.size()+1 and builder.pieces.back().span_length == 3,kind+": real Place action creates the fitted component")
					var saved := builder.serialize()
					builder.undo()
					builder.redo()
					check.call(builder.serialize() == saved,kind+": undo/redo preserves fitted lengths and joins")
					var store := WorldStore.new()
					store.save_world(saved,{}, {},"user://layout.json")
					var loaded := store.load_world("user://layout.json")
					builder.restore(loaded.pieces)
					check.call(builder.serialize() == saved and builder.pieces.back().join_left != 0 and builder.pieces.back().join_right != 0,kind+": save/load reconstructs both corners of a fitted span")
					player.position = Vector3(40,10,40)
	# Span centres can lie on quarter-metres; the endpoints must stay on the half-metre layout grid.
	builder.restore([])
	for kind in BuildCatalogue.MITRE_KINDS:
		for angle in [0.0,PI/4]:
			var ground := {"position":Vector3(12.13,0,8.27),"normal":Vector3.UP,"collider":null}
			var solution := SnapSolver.solve(kind,angle,ground,builder.pieces,true,false,0,0,{},2.5)
			var grid_basis := Basis(Vector3.UP,angle)
			var aligned := true
			for end in [-1,1]:
				var endpoint := grid_basis.inverse()*CornerJoints.end_point(Transform3D(grid_basis,solution.position),end,2.5)
				aligned = aligned and is_equal_approx(endpoint.x,snappedf(endpoint.x,0.5)) and is_equal_approx(endpoint.z,snappedf(endpoint.z,0.5))
			check.call(aligned,kind+": custom span endpoints follow the half-metre grid at %.0f degrees" % rad_to_deg(angle))
	# A nearby blocked support must not trap an otherwise valid placement.
	builder.restore([record("step_support",Vector3(12,0,0),1),record("urn",Vector3(12,0.4,0),2)])
	await Tools.settle(tree)
	builder.choose("shaft")
	builder.angle = 0
	player.position = Vector3(12,3,4)
	player.look_at_point(Vector3(12,0.4,0.45))
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,0.4,1)),"Preview leaves a blocked socket for a clear connection on the same aimed face")
	# Grid cannot round a rotated footprint through a vertical face.
	builder.restore([record("foundation_large",Vector3(12,0,0),1)])
	await Tools.settle(tree)
	var hit := {"position":Vector3(16,0.2,0),"normal":Vector3.RIGHT,"collider":builder.pieces[0]}
	var rotated := SnapSolver.solve("foundation",PI/4,hit,builder.pieces,true,false,0)
	check.call(rotated.position.x >= 16+sqrt(8.0)-0.001,"Rotated side placement uses the complete oriented footprint")
	check.call(not builder.placement_error("foundation",Transform3D(Basis.IDENTITY,Vector3(17.95,0,0))).is_empty(),"A five-centimetre structural intersection is rejected rather than hidden by percentage margins")
	# Validate saved length fields and legacy records.
	var entry := record("wall",Vector3.ZERO,1)
	check.call(WorldStore.valid_piece(entry),"Old saves without lengths remain valid four-metre modules")
	for invalid in [0,-1,0.25,1.25,8.5,"3",INF,NAN]:
		entry["length"] = invalid
		check.call(not WorldStore.valid_piece(entry),"Malformed or unsupported saved span length is rejected: "+str(invalid))
	entry = record("urn",Vector3.ZERO,1)
	entry["length"] = 3
	check.call(not WorldStore.valid_piece(entry),"Length overrides are rejected for fixed-size ornaments")
	# Actual keys select lengths, and the Stack tool repeats the resulting module length.
	builder.restore([record("entablature",Vector3(12,2,0),1,0,2.5)])
	game.ui.enter_world()
	player.set_flying(true)
	builder.choose("entablature")
	await Tools.key(tree,KEY_COMMA)
	check.call(builder.span_length == 3.5,"Comma shortens the selected span in half-metre steps")
	await Tools.key(tree,KEY_PERIOD)
	check.call(builder.span_length == 4,"Period lengthens the selected span in half-metre steps")
	await Tools.key(tree,KEY_SLASH)
	check.call(builder.span_length == 0,"Slash returns to automatic gap fitting")
	await Tools.aim(tree,game,builder.pieces[0])
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	builder.begin_stack()
	builder.finish_stack_selection()
	player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
	builder.change_stack_count(2)
	check.call(builder.stack_valid and builder.stack_copies.size() == 2 and is_equal_approx(builder.stack_step.x,2.5),"Stack tool uses the fitted span length for spacing")
	check.call(builder.confirm_stack() and builder.pieces.size() == 3 and builder.pieces.back().span_length == 2.5,"Confirmed stacks preserve fitted geometry and saved lengths")
	builder.undo()
	builder.redo()
	check.call(builder.pieces.size() == 3 and builder.pieces.back().span_length == 2.5,"Batch undo/redo preserves custom module lengths")
	builder.restore([])
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.set_flying(false)
	game.ui.show_menu()
