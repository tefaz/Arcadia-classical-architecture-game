extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")
const Plan := preload("res://src/building/stack_plan.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var capital := ClassicalGeometry.get_recipe("corinthian_capital")
	var column := ClassicalGeometry.get_recipe("corinthian_column")
	var groups := {}
	for part in capital:
		if part.has("mesh"): groups[part.detail] = part
	check.call(groups.has_all(["body","acanthus","corner_volute","volute_web","helix","abacus_flower","abacus"]),"The Corinthian capital includes a bell, acanthus crowns, backed volutes, helices, flowers and moulded abacus")
	check.call(groups.size() <= 8,"Capital ornament is batched into a small number of shared meshes")
	var shared := true
	for part in column:
		if not part.has("detail"): continue
		shared = shared and part.mesh == groups[part.detail].mesh and is_equal_approx(part.transform.origin.y,3.5)
	check.call(shared,"Legacy capitals and complete columns reuse the same carved meshes at their original pivots")
	var front: Variant = MeshChecks.front_hit(capital,Vector3(0,0.85,0.64),Vector3(0,0.68,0.64))
	var corner: Variant = MeshChecks.front_hit(capital,Vector3(0.73,0.85,0.68),Vector3(0.73,0.68,0.68))
	check.call(front == null and corner != null,"The abacus has a recessed side outline and projecting corners rather than a plain square plate")
	var foliage: Dictionary = groups.acanthus
	var thickness: Variant = MeshChecks.front_hit([foliage],Vector3(0,0.2,0.8),Vector3(0,0.2,0))
	check.call(thickness != null and thickness.z > 0.43,"Acanthus leaves and midribs have genuine carved relief outside the bell")
	for kind in ["corinthian_capital","corinthian_column"]:
		for finish in range(3):
			var piece := ClassicalGeometry.create(kind,finish)
			var size := Vector3(1.5,0.8 if kind == "corinthian_capital" else 4.3,1.4)
			check.call(piece.visual_bounds.size.is_equal_approx(size) and is_zero_approx(piece.visual_bounds.position.y),kind+": redesigned carving preserves the exact old footprint and top height")
			var matching := true
			for child in piece.get_children():
				if child is MeshInstance3D: matching = matching and child.material_override == ClassicalGeometry.materials[finish]
			check.call(matching,"All Corinthian ornament uses stone finish "+str(finish))
			piece.free()
	# Native placement and exact top support, with save/history/picking compatibility.
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	builder.choose("corinthian_column")
	builder.angle = 0
	builder.stone = 1
	player.position = Vector3(12,6,7)
	player.look_at_point(Vector3(12,0.4,0))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,0.4,0)),"The detailed Corinthian column previews at the ordinary foundation socket")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == "corinthian_column","Native placement creates the upgraded column")
	var hit := {"position":Vector3(12,4.7,0),"normal":Vector3.UP,"collider":builder.pieces.back()}
	var beam := SnapSolver.solve("entablature",0,hit,builder.pieces,true,true,0)
	check.call(beam.snapped and is_equal_approx(beam.position.y,4.7) and builder.placement_error("entablature",Transform3D(Basis.IDENTITY,beam.position),[],{},0,beam.length).is_empty(),"Entablatures still rest at the exact unchanged 4.7 m support plane without colliding with carved detail")
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records,"Upgraded columns preserve their finish and placement through undo/redo and save/load")
	await Tools.aim(tree,game,builder.pieces.back())
	builder.clear_slot(8)
	builder.select_slot(8)
	await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
	check.call(builder.selected_kind() == "corinthian_column" and builder.stone == 1,"Middle-click still equips the Corinthian column and its finish")
	check.call(Plan.span("corinthian_column").is_equal_approx(Vector3(1.5,4.3,1.5)),"Decorative detail does not change column stack spacing")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
