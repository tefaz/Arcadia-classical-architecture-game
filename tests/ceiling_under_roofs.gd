extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Fit := preload("res://src/building/ceiling_fit.gd")
const RoofFit := preload("res://src/building/ceiling_roof_fit.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(45,20,45)
	for angle in [0.0,PI/4,PI/2]:
		for stone in [false,true]:
			for ceiling_first in [false,true]:
				var frame := Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)
				var records := SanctuaryWorld.enclosed_roof_example(stone)
				for record in records:
					var pos := frame*Vector3(record.position[0],record.position[1],record.position[2])
					record.position = [pos.x,pos.y,pos.z]
					record.rotation += angle
				var roofs := records.filter(func(record): return record.kind in BuildCatalogue.ROOF_KINDS)
				var ceiling := records.filter(func(record): return record.kind == "flat_roof")
				builder.restore(records.filter(func(record): return record.kind != "flat_roof" and record.kind not in BuildCatalogue.ROOF_KINDS))
				await Tools.settle(tree)
				var errors: Array = []
				for record in (ceiling+roofs if ceiling_first else roofs+ceiling):
					var pos := Vector3(record.position[0],record.position[1],record.position[2])
					var error := builder.placement_error(record.kind,Transform3D(Basis(Vector3.UP,record.rotation),pos))
					if not error.is_empty(): errors.append(record.kind+": "+error)
					builder.add_record(record)
					await Tools.settle(tree)
				check.call(errors.is_empty(),"Square temple with both pediments, %s slopes and nine ceiling panels fits at %.0f degrees, ceiling first: %s" % ["stone" if stone else "terracotta",rad_to_deg(angle),ceiling_first])
				var clean := true
				var flat := true
				for piece in builder.pieces:
					if piece.kind != "flat_roof": continue
					for part in Fit.recipe(piece.ceiling_rects,piece.ceiling_regions):
						if not part.has("mesh"): continue
						var report := MeshChecks.audit(part.mesh)
						clean = clean and report.closed and report.winding and report.finite and not report.degenerate and report.volume < 0
					var underside: Variant = MeshChecks.front_hit(Fit.recipe(piece.ceiling_rects,piece.ceiling_regions),Vector3(0,-1,0),Vector3(0,0.1,0))
					flat = flat and underside != null and is_zero_approx(underside.y)
				check.call(clean and flat,"All tapered ceiling parts remain closed with flat undersides")
	# A full four-metre ceiling also fits beneath two opposing half slopes.
	builder.restore([Tools.record("roof_left_half",Vector3(11,5,0)),Tools.record("roof_left_half",Vector3(13,5,0),2,PI)])
	await Tools.settle(tree)
	var frame := Transform3D(Basis.IDENTITY,Vector3(12,5,0))
	check.call(builder.placement_error("flat_roof",frame).is_empty(),"One ceiling panel fits under both half slopes of a compact roof")
	var piece := builder.add_record(Tools.record("flat_roof",frame.origin,3))
	check.call(piece.ceiling_regions.size() == 2,"A compact roof fits both ceiling edges")
	var recipe := Fit.recipe(piece.ceiling_rects,piece.ceiling_regions)
	var underside: Variant = MeshChecks.front_hit(recipe,Vector3(-1.95,-1,0),Vector3(-1.95,0.1,0))
	var top: Variant = MeshChecks.front_hit(recipe,Vector3(-1.95,1,0),Vector3(-1.95,0,0))
	check.call(underside != null and is_zero_approx(underside.y) and top != null and is_equal_approx(top.y,0.03),"The ceiling feathers to the slope while keeping its underside on the support plane")
	var saved := builder.serialize()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == saved and builder.pieces.back().ceiling_regions.size() == 2,"Save/load reconstructs both roof edge fits")
	builder.remove_uid(1)
	check.call(builder.pieces.back().ceiling_regions.size() == 1,"Removing one slope restores only that ceiling edge")
	# Interior intersections and wrong elevations must remain ordinary obstacles.
	builder.restore([Tools.record("roof_left",Vector3(12,5,0))])
	await Tools.settle(tree)
	check.call(not builder.placement_error("flat_roof",Transform3D(Basis.IDENTITY,Vector3(12,6,0))).is_empty(),"An elevated ceiling through the middle of a slope remains blocked")
	check.call(RoofFit.plane_for(frame,"roof_left",Transform3D(Basis.IDENTITY,Vector3(16,5,0))) == null,"A roof rising away from the room cannot erase a ceiling panel")
	# Native ceiling placement from an entablature beneath the completed roof.
	builder.restore(SanctuaryWorld.enclosed_roof_example().filter(func(record): return record.kind != "flat_roof"))
	builder.choose("flat_roof")
	builder.angle = -PI/2
	player.position = Vector3(8,4,0)
	player.look_at_point(Vector3(6.65,5,0))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and not builder.ghost.ceiling_regions.is_empty(),"First-person ceiling preview fits beneath the completed roof")
	var count := builder.pieces.size()
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == count+1 and builder.pieces.back().kind == "flat_roof","Native left click adds a ceiling under roof slopes")
	builder.undo()
	builder.redo()
	check.call(builder.pieces.size() == count+1 and not builder.pieces.back().ceiling_regions.is_empty(),"Undo/redo retains the ceiling's roof-edge fit")
	# Repeating an interior tile into the eave recalculates the taper at its destination.
	builder.restore(SanctuaryWorld.enclosed_roof_example().filter(func(record): return record.kind != "flat_roof"))
	var source := builder.add_record(Tools.record("flat_roof",Vector3(12,5.25,0),builder.next_uid))
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	player.position = Vector3(12,3.5,0)
	player.look_at_point(Vector3(12,5.25,0))
	await Tools.settle(tree)
	check.call(builder.begin_stack(),"The interior ceiling panel can be selected from below")
	builder.finish_stack_selection()
	player.position = Vector3(45,18,45)
	player.look_at_point(player.camera.global_position+Vector3.LEFT*10)
	builder.change_stack_count(1)
	check.call(builder.stack_valid and builder.stack_copies.size() == 1 and not builder.stack_copies[0].ceiling_regions.is_empty(),"Stacking an interior ceiling into the eave previews the fitted edge")
	check.call(builder.confirm_stack() and builder.pieces.back().position.is_equal_approx(source.position+Vector3.LEFT*4),"The stack tool fills an eave bay beneath existing roof slopes")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
