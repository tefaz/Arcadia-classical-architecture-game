extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func front(piece: BuildPiece, x: float, y: float) -> Variant:
	return MeshChecks.front_hit(ClassicalGeometry.get_recipe(piece.kind,piece.join_left,piece.join_right),Vector3(x,y,1),Vector3(x,y,-1))

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	game.ui.enter_world()
	game.player.set_flying(true)
	game.player.position = Vector3(40,10,40)
	for angle in [0.0,PI/4,PI/2]:
		var frame := Transform3D(Basis(Vector3.UP,angle),Vector3(12,4,0))
		for side in [-1,1]:
			var kind := "pediment_left" if side < 0 else "pediment_right"
			builder.restore([Tools.record(kind,frame.origin,1,angle)])
			var first := builder.pieces[0]
			check.call(front(first,side*1.98,-0.048) == null,"An exposed pediment eave remains trimmed to its own base")
			var next := builder.add_record(Tools.record(kind,frame*Vector3(-side*4,2.4,0),2,angle))
			await Tools.settle(tree)
			var hit: Variant = front(next,side*1.98,-0.048)
			check.call(hit != null and is_equal_approx(hit.z,0.35),"%s at %.0f degrees has a continuous outer cornice through the rising module seam" % [kind,rad_to_deg(angle)])
			var dentil: Variant = front(next,side*1.875,-0.175)
			check.call(dentil != null and is_equal_approx(dentil.z,0.23),"Dentils continue at their normal spacing through the connected low end")
			var records := builder.serialize()
			builder.restore(records)
			check.call(front(builder.pieces[1],side*1.98,-0.048) != null,"Loading ordinary component records reconstructs the continuous cornice")
			builder.remove_uid(1)
			check.call(front(builder.pieces[0],side*1.98,-0.048) == null,"Removing the neighboring slope restores a clean exposed eave")
	# Both crown ends continue the rakes, without changing backing or sculpture collisions.
	builder.restore([Tools.record("pediment_left",Vector3(8,4,0),1),Tools.record("pediment_right",Vector3(16,4,0),2)])
	var crown := builder.add_record(Tools.record("pediment_crown",Vector3(12,6.4,0),3))
	check.call(crown.join_left == 1 and crown.join_right == 1 and front(crown,-1.98,-0.048) != null and front(crown,1.98,-0.048) != null,"The crown continues both diagonal cornices without notches")
	for kind in BuildCatalogue.RAKE_KINDS:
		var sound := true
		for left in [0,1]:
			for right in [0,1]:
				for part in ClassicalGeometry.get_recipe(kind,left,right):
					if not part.has("mesh"): continue
					var audit := MeshChecks.audit(part.mesh)
					sound = sound and audit.finite and audit.winding and audit.closed and not audit.degenerate and audit.volume < 0
		check.call(sound,kind+": every exposed and connected profile has closed outward-facing geometry")
	# Internal trim may overlap the recessed backing visually, but never adds a conflicting solid.
	builder.restore([Tools.record("pediment_left",Vector3(12,4,0),1),Tools.record("pediment_backing",Vector3(16,4,0),2)])
	await Tools.settle(tree)
	var target := Transform3D(Basis.IDENTITY,Vector3(16,6.4,0))
	check.call(builder.placement_error("pediment_left",target).is_empty(),"The completed cornice fits above a full backing course without collision exemptions")
	# A preview must already show the completed seam before the mouse click commits it.
	builder.choose("pediment_left")
	builder.angle = 0
	game.player.position = Vector3(19,4.75,0)
	game.player.look_at_point(Vector3(14,6.34,0))
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.join_left == 1 and front(builder.ghost,-1.98,-0.048) != null,"The first-person placement preview includes the continuous cornice")
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	var records := builder.serialize()
	builder.undo()
	builder.redo()
	check.call(builder.serialize() == records and front(builder.pieces.back(),-1.98,-0.048) != null,"Undo/redo restores the completed pediment seam")
	builder.restore([])
	builder.clear_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	game.ui.show_menu()
