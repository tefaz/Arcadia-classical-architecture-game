extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Layout := preload("res://tests/layout.gd")
const Cover := preload("res://src/building/wall_cover.gd")
const MeshAudit := preload("res://tests/meshes.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(45,18,45)
	for kind in ["flat_roof","foundation"]:
		for angle in [0.0,PI/4,PI/2]:
			for dimensions in [Vector2(3.56,3.56),Vector2(7.56,3.56),Vector2(4,4),Vector2(8,8),Vector2(5.5,7.5),Vector2(12,12)]:
				var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12.13,1.37,6.27))
				var records := Layout.room("wall",dimensions.x,dimensions.y,frame)
				for i in range(records.size()):
					if i%3 == 0: records[i].kind = "wall_window_segmental"
				builder.restore(records)
				await Tools.settle(tree)
				var roof_y := frame.origin.y+4.1
				var low: Vector2 = -dimensions/2-Vector2.ONE*0.22
				var expected := Rect2(low,dimensions+Vector2.ONE*0.44)
				var columns := ceili(dimensions.x/4)
				var rows := ceili(dimensions.y/4)
				var panels := {}
				var snapped := true
				var fits := true
				var footprint := AABB()
				var initialized := false
				for z in range(rows):
					for x in range(columns):
						var centre := low+Vector2(2+x*4,2+z*4)
						var hit: Dictionary
						if z == 0:
							var aimed_x := clampf(centre.x,-dimensions.x/2+0.02,dimensions.x/2-0.02)
							var target_point := frame*Vector3(aimed_x,4.1,-dimensions.y/2)
							var source: BuildPiece
							for wall in builder.pieces:
								if wall.kind not in BuildCatalogue.WALL_KINDS: continue
								var local: Vector3 = wall.transform.affine_inverse()*target_point
								if absf(local.z) < 0.005 and absf(local.x) < wall.span_length/2+0.005:
									source = wall
									break
							hit = {"position":target_point,"normal":Vector3.UP,"collider":source}
						else:
							var previous: BuildPiece = panels[Vector2i(x,z-1)]
							hit = {"position":previous.transform*Vector3(previous.cover_rect.get_center().x,0.1,previous.cover_rect.end.y),"normal":frame.basis.z,"collider":previous}
						var solution := SnapSolver.solve(kind,angle,hit,builder.pieces,true,true,0,1 if kind == "flat_roof" else 0)
						var position := frame.basis*Vector3(centre.x,roof_y,centre.y)+Vector3(frame.origin.x,0,frame.origin.z)
						snapped = snapped and solution.label.begins_with("Flush wall cover") and solution.position.is_equal_approx(position)
						var transform_value := Transform3D(frame.basis,solution.position)
						fits = fits and builder.placement_error(kind,transform_value).is_empty()
						var panel := builder.add_record(Tools.record(kind,solution.position,builder.next_uid,angle,1))
						panels[Vector2i(x,z)] = panel
						var bounds: AABB = (frame.affine_inverse()*panel.transform)*panel.visual_bounds
						footprint = footprint.merge(bounds) if initialized else bounds
						initialized = true
						await Tools.settle(tree)
				var actual := Rect2(Vector2(footprint.position.x,footprint.position.z),Vector2(footprint.size.x,footprint.size.z))
				check.call(snapped and fits,"%s: top and panel-side snaps cover a %.2f × %.2f m rotated wall room without overlaps" % [kind,dimensions.x,dimensions.y])
				check.call(actual.is_equal_approx(expected) and is_equal_approx(footprint.position.y,4.1),"%s: complete cover is flush with all four outer wall faces at %.0f degrees" % [kind,rad_to_deg(angle)])
				var solid := true
				var space := game.get_world_3d().direct_space_state
				for u in [0.01,0.5,0.99]:
					for v in [0.01,0.5,0.99]:
						var point := expected.position+expected.size*Vector2(u,v)
						var start := frame*Vector3(point.x,4.1+BuildCatalogue.piece_size(kind).y+0.1,point.y)
						var end := start-Vector3.UP*(BuildCatalogue.piece_size(kind).y+0.2)
						var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,2))
						# At rotated box seams an infinitesimal ray can land on either
						# side of float rounding. Probe within the builder's contact tolerance.
						var probe := PhysicsShapeQueryParameters3D.new()
						var shape := SphereShape3D.new()
						shape.radius = 0.002
						probe.shape = shape
						probe.collision_mask = 2
						probe.transform.origin = frame*Vector3(point.x,4.2,point.y)
						var contacts := space.intersect_shape(probe)
						solid = solid and ((not hit.is_empty() and hit.collider.kind == kind) or contacts.any(func(contact): return contact.collider.kind == kind))
				check.call(solid,"%s: fitted collision closes the centre, edges and all roof corners" % kind)
	# Ordinary anchor, free-placement and unfinished wall behavior remain available.
	var frame := Transform3D(Basis.IDENTITY,Vector3(12,0.4,0))
	builder.restore(Layout.room("wall",4,4,frame))
	await Tools.settle(tree)
	var wall: BuildPiece = builder.pieces[0]
	var top := {"position":wall.position+Vector3.UP*4.1,"normal":Vector3.UP,"collider":wall}
	check.call(not SnapSolver.solve("flat_roof",0,top,builder.pieces,true,true,0,0).label.begins_with("Flush"),"T selects manual ceiling anchors instead of automatic room fitting")
	for mode in [[false,true,0.0],[true,false,0.0],[true,true,0.25]]:
		check.call(not SnapSolver.solve("flat_roof",0,top,builder.pieces,mode[0],mode[1],mode[2],1).label.begins_with("Flush"),"Grid/socket bypass and manual elevation retain manual cover placement")
	builder.remove_uid(builder.pieces.back().uid)
	check.call(not SnapSolver.solve("flat_roof",0,top,builder.pieces,true,true,0,1).label.begins_with("Flush"),"An unfinished wall rectangle is not mistaken for a closed room")
	# Native inside-wall ray, actual Place, save/load, picking and history.
	for kind in ["flat_roof","foundation"]:
		builder.restore(Layout.room("wall",4,4,frame))
		builder.choose(kind)
		builder.angle = 0
		player.position = Vector3(12,2.0,0)
		player.look_at_point(Vector3(12,4.3,-2))
		await Tools.settle(tree)
		builder.update_preview()
		check.call(builder.valid and builder.snap_label.begins_with("Flush wall cover") and builder.ghost.cover_rect.size.is_equal_approx(Vector2(4.44,4.44)),kind+": aiming at the upper wall from inside previews a flush cover")
		var preview: AABB = builder.ghost.visual_bounds
		await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
		var panel: BuildPiece = builder.pieces.back()
		check.call(panel.kind == kind and panel.visual_bounds.is_equal_approx(preview),kind+": native placement commits the exact fitted preview")
		var valid_meshes := true
		for child in panel.get_children():
			if child is MeshInstance3D:
				var report := MeshAudit.audit(child.mesh)
				valid_meshes = valid_meshes and report.closed and report.finite and report.winding and not report.degenerate
		check.call(valid_meshes,kind+": fitted stone meshes remain closed and correctly oriented")
		var saved := builder.serialize()
		builder.undo()
		builder.redo()
		game.save_world()
		game.load_world()
		check.call(builder.serialize() == saved and builder.pieces.back().visual_bounds.is_equal_approx(preview),kind+": flush dimensions are reconstructed by history and save/load")
		# A newly fitted upper floor also exposes its true outer perimeter to walls.
		if kind == "foundation":
			panel = builder.pieces.back()
			var bounds := ColumnLayout.rect_of(panel,panel.transform)
			check.call(bounds.is_equal_approx(panel.cover_rect),"Walls and columns see the actual fitted upper-floor footprint")
		player.position = Vector3(45,18,45)
	# Reproduce the actual foundation -> fitted perimeter walls -> roof workflow.
	builder.restore([Tools.record("foundation",Vector3(12,0,0))])
	var platform: BuildPiece = builder.pieces[0]
	for i in range(4):
		var basis := Basis(Vector3.UP,PI*i/2)
		var hit := {"position":Vector3(12,0.4,0)+basis*Vector3(0,0,1.95),"normal":Vector3.UP,"collider":platform}
		var wall_solution := SnapSolver.solve("wall",PI*i/2,hit,builder.pieces,true,true,0)
		var record := Tools.record("wall",wall_solution.position,builder.next_uid,PI*i/2)
		record.length = wall_solution.length
		builder.add_record(record)
	await Tools.settle(tree)
	var wall_top := {"position":builder.pieces[1].position+Vector3.UP*4.1,"normal":Vector3.UP,"collider":builder.pieces[1]}
	for kind in ["flat_roof","foundation"]:
		var solution := SnapSolver.solve(kind,0,wall_top,builder.pieces,true,true,0,1 if kind == "flat_roof" else 0)
		check.call(solution.label.begins_with("Flush") and solution.position.is_equal_approx(Vector3(12,4.5,0)) and builder.placement_error(kind,Transform3D(Basis.IDENTITY,solution.position)).is_empty(),kind+": a standard cover aligns exactly with the foundation beneath four inset perimeter walls")
	# An obstruction must keep the intended roof red instead of choosing an offset fallback.
	builder.restore(Layout.room("wall",4,4,frame))
	builder.add_record(Tools.record("foundation",Vector3(11.78,4.55,-0.22),builder.next_uid))
	builder.choose("flat_roof")
	builder.angle = 0
	player.position = Vector3(12,2,0)
	player.look_at_point(Vector3(12,4.3,-2))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(not builder.valid and builder.snap_label.begins_with("Flush") and builder.ghost.position.is_equal_approx(Vector3(11.78,4.5,-0.22)),"An obstructed flush cover stays on the intended room instead of jumping outside")
	for kind in ["flat_roof","foundation"]:
		builder.restore(Layout.room("wall",5.5,4,frame))
		var first := builder.add_record(Tools.record(kind,Vector3(11.03,4.5,-0.22),builder.next_uid))
		builder.select_slot(BuildCatalogue.TOOL_SLOT)
		await Tools.aim(tree,game,first)
		check.call(builder.begin_stack(),kind+": a fitted wall cover can be selected for stacking")
		builder.finish_stack_selection()
		builder.change_stack_count(1)
		player.look_at_point(player.camera.global_position+Vector3.RIGHT*10)
		builder.update_stack(true)
		check.call(builder.stack_valid and builder.stack_copies.size() == 1 and builder.stack_copies[0].cover_rect.size.is_equal_approx(Vector2(1.94,4.44)),kind+": Stack fits the final short panel to the far wall")
		check.call(builder.confirm_stack() and builder.pieces.back().cover_rect.size.is_equal_approx(Vector2(1.94,4.44)),kind+": confirming Stack retains the fitted roof edge")
	player.position = Vector3(45,18,45)
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
