extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	for kind in BuildCatalogue.WINDOW_KINDS:
		var recipe := ClassicalGeometry.get_recipe(kind)
		check.call(MeshChecks.front_hit(recipe,Vector3(0,1.9,2),Vector3(0,1.9,-2)) == null and MeshChecks.front_hit(recipe,Vector3(0,1.9,-2),Vector3(0,1.9,2)) == null,kind+": the window is visually open from both sides")
		check.call(MeshChecks.front_hit(recipe,Vector3(0,2.0,0),Vector3(0,3.9,0)) != null,kind+": the opening has a visible upper reveal")
		check.call(MeshChecks.front_hit(recipe,Vector3(0,2.0,0),Vector3(1.2,2.0,0)) != null,kind+": the opening has a visible side reveal")
		for finish in range(3):
			var piece := ClassicalGeometry.create(kind,finish)
			var matching := true
			for child in piece.get_children():
				if child is MeshInstance3D: matching = matching and child.material_override == ClassicalGeometry.materials[finish]
			check.call(matching,kind+": wall, sill and surround share stone finish "+str(finish))
			check.call(is_equal_approx(piece.visual_bounds.size.x,4) and is_equal_approx(piece.visual_bounds.size.y,4.1),kind+": decoration stays within the wall bay's width and height")
			piece.free()
		for angle in [0.0,PI/4]:
			var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,0.4,0))
			builder.restore([Tools.record(kind,frame.origin,1,angle)])
			await Tools.settle(tree)
			var space := game.get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(frame*Vector3(0,1.9,2),frame*Vector3(0,1.9,-2),2)
			check.call(space.intersect_ray(query).is_empty(),kind+": a real physics ray passes through the opening at %.0f degrees" % rad_to_deg(angle))
			var point := PhysicsPointQueryParameters3D.new()
			point.collision_mask = 2
			for local in [Vector3(1.5,2,0),Vector3(0,0.5,0),Vector3(0,3.8,0)]:
				point.position = frame*local
				check.call(not space.intersect_point(point).is_empty(),"Window piers, lower wall and upper wall remain solid")
			point.position = frame*Vector3(0,3.05,0)
			check.call(space.intersect_point(point).is_empty() == (kind == "wall_window_ellipse"),"The elliptical variant has a genuinely curved open head above the rectangular window height")
			point.position = frame*Vector3(0.76,3.05,0)
			check.call(not space.intersect_point(point).is_empty(),"The wall fills the upper corner outside the curved opening")
			# Compatible wall styles share the same corner construction profile.
			var hit := {"position":frame*Vector3(2,2.05,0.08),"normal":frame.basis.z,"collider":builder.pieces[0]}
			var solution := SnapSolver.solve("wall",angle-PI/2,hit,builder.pieces,true,true,0)
			var transform_value := Transform3D(Basis(Vector3.UP,angle-PI/2),solution.position)
			check.call(solution.snapped and builder.placement_error("wall",transform_value).is_empty(),"A plain wall mitres directly into a window wall")
			var peer := builder.add_record(Tools.record("wall",solution.position,2,angle-PI/2))
			check.call(peer.join_left != 0 and builder.pieces[0].join_right != 0,"Mixed plain/window corners rebuild both matching mitres")
			builder.restore([Tools.record("wall",frame.origin,1,angle)])
			await Tools.settle(tree)
			hit.collider = builder.pieces[0]
			solution = SnapSolver.solve(kind,angle-PI/2,hit,builder.pieces,true,true,0)
			check.call(solution.snapped and builder.placement_error(kind,Transform3D(Basis(Vector3.UP,angle-PI/2),solution.position)).is_empty(),"A window wall also mitres into an existing plain wall")
	builder.restore([Tools.record("wall_window_pediment",Vector3(10,0.4,4)),Tools.record("wall",Vector3(14,0.4,4),2)])
	var dome_hit := {"position":Vector3(10,4.5,4),"normal":Vector3.UP,"collider":builder.pieces[0]}
	var dome := SnapSolver.solve("dome_large",0,dome_hit,builder.pieces,true,true,0)
	check.call(dome.snapped and dome.position.is_equal_approx(Vector3(12,4.5,0)),"A grand dome centres over a mixed plain/window wall run")
	# Curving the pediment leaves the original rectangular aperture intact.
	var triangle := ClassicalGeometry.get_recipe("wall_window_pediment")
	var curved := ClassicalGeometry.get_recipe("wall_window_segmental")
	var same_opening := true
	for x in [-0.7,0.0,0.7]:
		for y in [1.1,1.9,2.75]:
			for direction in [-1,1]:
				var from := Vector3(x,y,direction*2)
				var to := Vector3(x,y,-direction*2)
				same_opening = same_opening and MeshChecks.front_hit(triangle,from,to) == null and MeshChecks.front_hit(curved,from,to) == null
	check.call(same_opening,"The curved pediment keeps exactly the triangular style's rectangular window opening")
	for side in [-1,1]:
		var curved_hit: Variant = MeshChecks.front_hit(curved,Vector3(0.8,3.48,side*2),Vector3(0.8,3.48,0))
		var triangle_hit: Variant = MeshChecks.front_hit(triangle,Vector3(0.8,3.48,side*2),Vector3(0.8,3.48,0))
		check.call(curved_hit != null and triangle_hit != null and absf(curved_hit.z)-absf(triangle_hit.z) > 0.07,"A raised segmental cornice replaces the triangle on both wall faces")
	var field: Variant = MeshChecks.front_hit(curved,Vector3(0,3.32,2),Vector3(0,3.32,0))
	var cornice: Variant = MeshChecks.front_hit(curved,Vector3(0,3.67,2),Vector3(0,3.67,0))
	var shoulder: Variant = MeshChecks.front_hit(curved,Vector3(1,3.45,2),Vector3(1,3.45,0))
	check.call(field != null and cornice != null and cornice.z-field.z > 0.08,"The curved cornice projects above its recessed tympanum for real shadow lines")
	check.call(shoulder != null and shoulder.z < 0.20,"The segmental curve has sloping shoulders rather than the old bulging half-ellipse")
	# Native placement, finish controls, persistence and picking.
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	builder.choose("wall_window_segmental")
	builder.angle = 0
	builder.stone = 0
	player.position = Vector3(12,5,7)
	player.look_at_point(Vector3(12,0.4,0))
	await Tools.key(tree,KEY_M)
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,0.4,0)),"The new window wall previews at the ordinary foundation support height")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == "wall_window_segmental" and builder.pieces.back().stone == 1,"Native placement creates a marble curved-pediment window wall")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Window style, finish and placement survive undo/redo and save/load")
	player.position = Vector3(13.4,1,6)
	player.look_at_point(Vector3(13.4,2,0))
	await Tools.settle(tree)
	builder.clear_slot(8)
	builder.select_slot(8)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "wall_window_segmental" and builder.stone == 1,"Middle-clicking a window pier equips its wall style and finish")
	# The opening also permits normal interaction with components behind it.
	builder.restore([Tools.record("wall_window_ellipse",Vector3(12,0,0)),Tools.record("urn",Vector3(12,1.5,-2),2,0,2)])
	player.position = Vector3(12,1,5)
	player.look_at_point(Vector3(12,1.55,-2))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "urn" and builder.stone == 2,"Native middle-click reaches a component through the open window")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
