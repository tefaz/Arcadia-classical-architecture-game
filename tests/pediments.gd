extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	player.active = false
	player.position = Vector3(40,10,40)
	for kind in BuildCatalogue.SCULPTURE_KINDS:
		var piece := ClassicalGeometry.create(kind)
		check.call(piece.visual_bounds.size.y >= BuildCatalogue.get_piece(kind).size.y*0.96,kind+": complete sculpture mesh reaches its advertised height")
		piece.free()
	check.call(MeshChecks.front_hit(ClassicalGeometry.get_recipe("draped_statue"),Vector3(0,1.83,1),Vector3(0,1.83,-1)) != null,"Standing statue has a visible carved head above its plinth")
	check.call(MeshChecks.front_hit(ClassicalGeometry.get_recipe("horse_relief"),Vector3(-0.2,0.95,1),Vector3(-0.2,0.95,-1)) != null,"Horse relief has a visible sculpted body above its plinth")
	# Chain along the actual raking endpoints, including rotated buildings and reverse construction.
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,4,0))
		for pair in [["pediment_left","pediment_left",Vector3(2,2.4,0),Vector3(4,2.4,0),Vector3.RIGHT],
			["pediment_left","pediment_crown",Vector3(2,2.4,0),Vector3(4,2.4,0),Vector3.RIGHT],
			["pediment_crown","pediment_right",Vector3(2,0,0),Vector3(4,-2.4,0),Vector3.RIGHT],
			["pediment_right","pediment_right",Vector3(2,0,0),Vector3(4,-2.4,0),Vector3.RIGHT],
			["pediment_right","pediment_crown",Vector3(-2,2.4,0),Vector3(-4,2.4,0),Vector3.LEFT],
			["pediment_backing","pediment_backing",Vector3(2,1.0,0),Vector3(4,0,0),Vector3.RIGHT],
			["pediment_base","pediment_base",Vector3(2,0.09,0),Vector3(4,0,0),Vector3.RIGHT]]:
			builder.restore([Tools.record(pair[0],frame.origin,1,angle)])
			await Tools.settle(tree)
			var hit := {"position":frame*pair[2],"normal":frame.basis*pair[4],"collider":builder.pieces[0]}
			var solution := SnapSolver.solve(pair[1],angle,hit,builder.pieces,true,true,0)
			check.call(solution.snapped and solution.position.is_equal_approx(frame*pair[3]),"%s joins %s at the correct height, rotated %.0f degrees" % [pair[1],pair[0],rad_to_deg(angle)])
			check.call(builder.placement_error(pair[1],Transform3D(frame.basis,solution.position)).is_empty(),"Joined pediment modules meet without solid overlap")
	# A complete twenty-metre assembly must pass the same physics checks as interactive placement.
	builder.restore([])
	var clean_assembly := true
	for record in SanctuaryWorld.pediment_example():
		var pos := Vector3(record.position[0],record.position[1],record.position[2])
		var error := builder.placement_error(record.kind,Transform3D(Basis(Vector3.UP,record.rotation),pos))
		clean_assembly = clean_assembly and error.is_empty()
		builder.add_record(record)
		await Tools.settle(tree)
	check.call(clean_assembly,"A complete 20 m pediment and all its sculptures fit without collisions")
	# Backing blocks leave a genuine recess; sculptures attach to that front face in both directions.
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,4,0))
		builder.restore([Tools.record("pediment_backing",frame.origin,1,angle)])
		await Tools.settle(tree)
		for kind in BuildCatalogue.SCULPTURE_KINDS:
			for turn in [0.0,PI]:
				var hit := {"position":frame*Vector3(0,0.65,-0.15),"normal":frame.basis.z,"collider":builder.pieces[0]}
				var solution := SnapSolver.solve(kind,angle+turn,hit,builder.pieces,true,true,0)
				check.call(solution.snapped and solution.position.is_equal_approx(frame*Vector3(0,0.08,0.09)),kind+": snaps inside rotated recess facing either way")
				check.call(builder.placement_error(kind,Transform3D(Basis(Vector3.UP,angle+turn),solution.position)).is_empty(),kind+": sculpture clears the backing without ignoring its collision")
		var side_hit := {"position":frame*Vector3(0,0.65,-0.31),"normal":-frame.basis.z,"collider":builder.pieces[0]}
		check.call(not SnapSolver.solve("horse_relief",angle,side_hit,builder.pieces,true,true,0).snapped,"The rear face cannot steal a sculpture's front attachment")
	# Check that both reclining poses actually remain under the sloping stone moulding.
	for side in [-1,1]:
		var slope_kind := "pediment_left" if side < 0 else "pediment_right"
		var turn := 0.0 if side < 0 else PI
		builder.restore([Tools.record(slope_kind,Vector3(12,4,0))])
		await Tools.settle(tree)
		var hit := {"position":Vector3(12-side*0.55,4.5,-0.15),"normal":Vector3.BACK,"collider":builder.pieces[0]}
		var solution := SnapSolver.solve("reclining_figure",turn,hit,builder.pieces,true,true,0)
		check.call(solution.snapped and is_equal_approx(solution.position.y,4.02),"Reclining figure attaches inside the low pediment corner")
		check.call(builder.placement_error("reclining_figure",Transform3D(Basis(Vector3.UP,turn),solution.position)).is_empty(),"Reclining pose clears the rising cornice")
		var contained := true
		var transform_value := Transform3D(Basis(Vector3.UP,turn),solution.position-Vector3(12,4,0))
		for part in ClassicalGeometry.get_recipe("reclining_figure"):
			if not part.has("mesh"): continue
			for triangle in MeshChecks.triangles(part.mesh):
				for vertex in triangle.v:
					var v: Vector3 = transform_value*part.transform*vertex
					contained = contained and v.y < (2+v.x*-side)*0.6-0.19
		check.call(contained,"Every visible vertex of the corner sculpture stays below the mouldings")
	# The high-end face is aimable in first person, so the diagonal join works through real clicks.
	builder.restore([Tools.record("pediment_left",Vector3(12,4,0))])
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(19,4.75,0)
	player.look_at_point(Vector3(14,6.34,0))
	builder.choose("pediment_left")
	builder.angle = 0
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(16,6.4,0)),"Real high-end ray continues a pediment four metres along and 2.4 m up")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().position.is_equal_approx(Vector3(16,6.4,0)),"Native left-click places the next raking module at the exact seam")
	player.position = Vector3(23,7.15,0)
	player.look_at_point(Vector3(18,8.74,0))
	builder.choose("pediment_crown")
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 3 and builder.pieces.back().kind == "pediment_crown" and builder.pieces.back().position.is_equal_approx(Vector3(20,8.8,0)),"Native placement adds the crown to the completed rising slope")
	# Native camera placement, undo/redo and save restore use ordinary stable component records.
	builder.restore([Tools.record("pediment_backing",Vector3(12,4,0))])
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(12,3.1,6)
	player.look_at_point(Vector3(12,4.75,-0.15))
	builder.choose("horse_relief")
	builder.angle = 0
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,4.08,0.09)),"Real camera previews the horse inside the tympanum")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == "horse_relief","Native left-click places the recessed horse sculpture")
	builder.undo()
	check.call(builder.pieces.size() == 1,"Undo removes a sculpture independently of the pediment")
	builder.redo()
	check.call(builder.pieces.size() == 2,"Redo restores the sculpture's exact recessed position")
	var store := WorldStore.new()
	check.call(store.save_world(builder.serialize(),player.serialize(),{},"user://pediment-test.json"),"Pediment and sculpture save with existing world format")
	var loaded := store.load_world("user://pediment-test.json")
	builder.restore(loaded.get("pieces",[]))
	check.call(builder.pieces.size() == 2 and builder.pieces.back().position.is_equal_approx(Vector3(12,4.08,0.09)),"Saved sculpture keeps its attachment after load")
	for kind in BuildCatalogue.PEDIMENT_KINDS+BuildCatalogue.SCULPTURE_KINDS:
		check.call(game.ui.card_buttons.has(kind),kind+": available in the draggable building library")
	builder.restore([])
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	player.set_flying(false)
	game.ui.show_menu()
