extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Fit := preload("res://src/building/ceiling_fit.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func at(kind: String, frame: Transform3D, local: Vector3, uid: int, turn: float = 0) -> Dictionary:
	return Tools.record(kind,frame*local,uid,frame.basis.get_euler().y+turn)

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(40,10,40)
	for angle in [0.0,PI/4,PI/2,PI*1.5]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,4.75,0))
		for kind in Fit.GABLES:
			for turn in [0.0,PI/2]:
				builder.restore([at("entablature",frame,Vector3(0,-0.75,0),1),at(kind,frame,Vector3.ZERO,2)])
				await Tools.settle(tree)
				var panel_frame := Transform3D(frame.basis*Basis(Vector3.UP,turn),frame*Vector3(0,0,-2))
				check.call(builder.placement_error("flat_roof",panel_frame).is_empty(),"Edge ceiling fits %s at building %.0f / panel %.0f degrees" % [kind,rad_to_deg(angle),rad_to_deg(turn)])
				var panel := builder.add_record(Tools.record("flat_roof",panel_frame.origin,3,panel_frame.basis.get_euler().y))
				await Tools.settle(tree)
				var bounds: AABB = frame.affine_inverse()*panel.transform*panel.visual_bounds
				check.call(bounds.end.z <= -0.249 and bounds.end.z >= -0.351,"Fitted slab stops at the gable back rather than penetrating its thickness")
				var clean := true
				for part in Fit.recipe(panel.ceiling_rects):
					if not part.has("mesh"): continue
					var report := MeshChecks.audit(part.mesh)
					clean = clean and report.closed and report.winding and report.finite and not report.degenerate and report.volume < 0
				check.call(clean,"Cut slab edges and surface joints remain closed and correctly oriented")
	# Both ends of a four-metre bay can meet gables; interior beams and other panels still block.
	var frame := Transform3D(Basis.IDENTITY,Vector3(12,4.75,0))
	builder.restore([at("pediment_base",frame,Vector3(0,0,-2),1),at("pediment_base",frame,Vector3(0,0,2),2)])
	await Tools.settle(tree)
	check.call(builder.placement_error("flat_roof",frame).is_empty(),"Ceiling fits between two pediments without moving its bay centre")
	var panel := builder.add_record(at("flat_roof",frame,Vector3.ZERO,3))
	check.call(is_equal_approx(panel.visual_bounds.position.z,-1.65) and is_equal_approx(panel.visual_bounds.end.z,1.65),"Both physical slab ends trim while logical spacing remains four metres")
	builder.restore([at("pediment_backing",frame,Vector3.ZERO,1)])
	await Tools.settle(tree)
	check.call(not builder.placement_error("flat_roof",frame).is_empty(),"A pediment through the middle of a slab remains an invalid intersection")
	builder.restore([at("wall",frame,Vector3(0,0,-2),1)])
	await Tools.settle(tree)
	check.call(not builder.placement_error("flat_roof",frame).is_empty(),"Ceiling fitting does not permit unrelated wall overlaps")
	# Partial-width pediments notch only their own part of an edge.
	builder.restore([at("pediment_backing",frame,Vector3(2,0,2),1)])
	var partial := Fit.rectangles(frame,builder.pieces)
	var area := 0.0
	for rect in partial: area += rect.get_area()
	check.call(partial.size() == 2 and area > 15 and area < 16,"An offset pediment preserves the uncovered half of the ceiling edge")
	builder.restore([at("pediment_backing",frame,Vector3(0,0.2,2),1)])
	check.call(Fit.rectangles(frame,builder.pieces) == [Rect2(-2,-2,4,4)],"A pediment above the slab does not cut a needless gap")
	# A whole temple ceiling closes against both large pediments at the original 4 m seams.
	var temple := SanctuaryWorld.ceiling_pediment_example()
	builder.restore(temple.filter(func(record): return record.kind != "flat_roof"))
	await Tools.settle(tree)
	var errors: Array = []
	for record in temple:
		if record.kind != "flat_roof": continue
		var pos := Vector3(record.position[0],record.position[1],record.position[2])
		var error := builder.placement_error("flat_roof",Transform3D(Basis.IDENTITY,pos))
		if not error.is_empty(): errors.append(error)
		builder.add_record(record)
		await Tools.settle(tree)
	check.call(errors.is_empty(),"All fifteen ceiling bays close a 20 by 12 metre temple behind both pediments")
	# Reverse construction order, removal, history and save reconstruction.
	builder.restore([at("flat_roof",frame,Vector3(0,0,-2),1)])
	await Tools.settle(tree)
	check.call(builder.placement_error("pediment_backing",frame).is_empty(),"A gable can be placed after its neighbouring ceiling")
	var gable := builder.add_record(at("pediment_backing",frame,Vector3.ZERO,2))
	builder.record_action({"op":"add","piece":gable.serialize()})
	check.call(is_equal_approx(builder.pieces[0].visual_bounds.end.z,1.69),"Adding a gable cuts the existing ceiling back to its rear face")
	var fitted := builder.pieces[0].ceiling_rects.duplicate()
	builder.undo()
	check.call(is_equal_approx(builder.pieces[0].visual_bounds.end.z,2),"Removing the gable restores the full ceiling panel")
	builder.redo()
	check.call(builder.pieces[0].ceiling_rects == fitted,"Redo reconstructs the fitted edge")
	var records := builder.serialize()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == records and builder.pieces[0].ceiling_rects == fitted,"Saved original bay positions reconstruct fitted ceiling edges on load")
	# Last panel in a large pediment bay, using the ordinary side snap and native placement.
	builder.restore([at("pediment_backing",frame,Vector3.ZERO,1),at("pediment_left",frame,Vector3(0,2.4,0),2),at("flat_roof",frame,Vector3(0,0,-6),3)])
	builder.choose("flat_roof")
	builder.angle = 0
	player.position = Vector3(14.4,4.13,-1.5)
	player.look_at_point(Vector3(13.5,4.85,-4))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(12,4.75,-2)) and builder.ghost.visual_bounds.end.z < 1.7,"The final ceiling bay previews fitted to the back of a large pediment")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == 4 and builder.pieces.back().position.is_equal_approx(Vector3(12,4.75,-2)),"Native input closes the last ceiling bay without shifting its neighbour seam")
	# Stacking recalculates the cut at the destination, keeping the four-metre bay step.
	builder.restore([at("pediment_backing",frame,Vector3.ZERO,1),at("flat_roof",frame,Vector3(0,0,-6),2)])
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	await Tools.aim(tree,game,builder.pieces[1])
	builder.begin_stack()
	builder.finish_stack_selection()
	player.position = Vector3(40,10,40)
	player.look_at_point(player.camera.global_position+Vector3.BACK*10)
	builder.change_stack_count(1)
	check.call(builder.stack_valid and builder.stack_copies.size() == 1 and builder.stack_copies[0].visual_bounds.end.z < 1.7,"Stack previews fit the final bay to the pediment automatically")
	check.call(builder.confirm_stack() and builder.pieces.back().position.is_equal_approx(Vector3(12,4.75,-2)),"Stack confirmation retains the original four-metre seam and fitted edge")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
