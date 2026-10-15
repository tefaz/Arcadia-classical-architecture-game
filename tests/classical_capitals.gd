extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	for style in ["doric","ionic"]:
		var capital := ClassicalGeometry.get_recipe(style+"_capital")
		var column := ClassicalGeometry.get_recipe(style+"_column")
		var groups := {}
		for part in capital:
			if part.has("mesh"): groups[part.detail] = part
		var expected := ["echinus","abacus"] if style == "doric" else ["echinus","abacus","bolsters","bolster_belts","volute_fields","volutes","channel","eggs","egg_casings","darts","astragal"]
		check.call(groups.has_all(expected) and groups.size() == expected.size(),style+": complete carved details are batched by ornament")
		var shared := true
		for part in column:
			if part.has("detail"): shared = shared and part.mesh == groups[part.detail].mesh and is_equal_approx(part.transform.origin.y,3.5)
		check.call(shared,style+": complete and legacy pieces share cached meshes at their original pivots")
		if style == "ionic":
			var backing: Variant = MeshChecks.front_hit([groups.volute_fields],Vector3(0.54,0.285,1),Vector3(0.54,0.285,0))
			var bolster: Variant = MeshChecks.front_hit([groups.bolsters],Vector3(1,0.285,0),Vector3(0,0.285,0))
			check.call(backing != null and backing.z > 0.48,"Ionic scroll eyes have solid backing")
			check.call(bolster != null and bolster.x > 0.69,"Ionic side bolsters connect the front and back scrolls")
		for kind in [style+"_capital",style+"_column"]:
			for finish in range(3):
				var piece := ClassicalGeometry.create(kind,finish)
				check.call(is_zero_approx(piece.visual_bounds.position.y) and is_equal_approx(piece.visual_bounds.end.y,0.6 if kind.ends_with("capital") else 4.1),kind+": original bottom pivot and top support height survive")
				var matching := true
				for child in piece.get_children():
					if child is MeshInstance3D: matching = matching and child.material_override == ClassicalGeometry.materials[finish]
				check.call(matching,kind+": all carving uses selected finish "+str(finish))
				piece.free()
		var builder: ClassicalBuilder = game.builder
		var player: BuilderPlayer = game.player
		game.ui.enter_world()
		player.set_flying(true)
		builder.restore([Tools.record("foundation",Vector3(12,0,0))])
		builder.choose(style+"_column")
		builder.angle = 0
		builder.stone = 1
		player.position = Vector3(12,6,7)
		player.look_at_point(Vector3(12,0.4,0))
		await Tools.settle(tree)
		builder.update_preview()
		check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,0.4,0)),style+": foundation preview preserves its socket")
		await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
		check.call(builder.pieces.size() == 2 and builder.pieces.back().kind == style+"_column",style+": native input places the upgraded column")
		var hit := {"position":Vector3(12,4.5,0),"normal":Vector3.UP,"collider":builder.pieces.back()}
		var beam := SnapSolver.solve("entablature",0,hit,builder.pieces,true,true,0)
		check.call(beam.snapped and is_equal_approx(beam.position.y,4.5) and builder.placement_error("entablature",Transform3D(Basis.IDENTITY,beam.position),[],{},0,beam.length).is_empty(),style+": beams still attach at 4.5 m without colliding with detail")
		var records := builder.serialize()
		builder.undo()
		builder.redo()
		game.save_world()
		game.load_world()
		check.call(builder.serialize() == records,style+": save/load and undo/redo preserve the column")
		await Tools.aim(tree,game,builder.pieces.back())
		builder.clear_slot(8)
		builder.select_slot(8)
		await Tools.mouse(tree,MOUSE_BUTTON_MIDDLE)
		check.call(builder.selected_kind() == style+"_column" and builder.stone == 1,style+": middle click picks the column and finish")
		builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
		builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
		builder.restore([])
		game.ui.show_menu()
