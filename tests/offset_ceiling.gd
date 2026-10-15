extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Layout := preload("res://tests/layout.gd")
const Fit := preload("res://src/building/ceiling_fit.gd")
const MeshChecks := preload("res://tests/meshes.gd")

# The dimensions, half-metre ceiling phase and saved camera reproduce the reported build.
static func temple() -> Array:
	var result := Layout.room("entablature",16,16,Transform3D(Basis.IDENTITY,Vector3(12,6.3,-1)))
	var append := func(kind: String, pos: Vector3, angle: float = 0.0):
		result.append(Tools.record(kind,pos,result.size()+1,angle))
	for z in [-9,7]:
		for entry in [["pediment_left",6,7.05],["pediment_left",10,9.45],["pediment_right",18,7.05],["pediment_right",14,9.45],["pediment_backing",10,7.05],["pediment_backing",14,7.05]]:
			append.call(entry[0],Vector3(entry[1],entry[2],z))
	for z in [-7,-3,1,5]:
		for entry in [[6,7.05,0],[10,9.45,0],[18,7.05,PI],[14,9.45,PI]]:
			append.call("roof_left",Vector3(entry[0],entry[1],z),entry[2])
	return result

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(45,20,45)
	for angle in [0.0,PI/4]:
		for ceiling_first in [false,true]:
			var frame := Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)
			var records := temple()
			for record in records:
				var pos := frame*Vector3(record.position[0],record.position[1],record.position[2])
				record.position = [pos.x,pos.y,pos.z]
				record.rotation += angle
			var roofs := records.filter(func(record): return record.kind in BuildCatalogue.ROOF_KINDS)
			builder.restore(records.filter(func(record): return record.kind not in BuildCatalogue.ROOF_KINDS))
			var ceiling: Array = []
			for x in [6.5,10.5,14.5,18.5]:
				for z in [-6.5,-2.5,1.5,5.5]: ceiling.append(Tools.record("flat_roof",frame*Vector3(x,7.05,z),100+ceiling.size(),angle))
			await Tools.settle(tree)
			var errors: Array = []
			for record in (ceiling+roofs if ceiling_first else roofs+ceiling):
				var pos := Vector3(record.position[0],record.position[1],record.position[2])
				var error := builder.placement_error(record.kind,Transform3D(Basis(Vector3.UP,record.rotation),pos))
				if not error.is_empty(): errors.append(record.kind+": "+error)
				builder.add_record(record)
				await Tools.settle(tree)
			check.call(errors.is_empty(),"All sixteen half-metre-offset ceiling bays fit both pediments and roof slopes, rotated %.0f, ceiling first %s" % [rad_to_deg(angle),ceiling_first])
			var closed := true
			for piece in builder.pieces:
				if piece.kind != "flat_roof": continue
				for part in Fit.recipe(piece.ceiling_rects,piece.ceiling_regions):
					if not part.has("mesh"): continue
					var report := MeshChecks.audit(part.mesh)
					closed = closed and report.closed and report.winding and report.finite and not report.degenerate and report.volume < 0
			check.call(closed,"Offset corner and split-bay ceiling meshes remain closed and correctly oriented")
	# A finite roof bay may cut only its actual depth, never the unroofed part of a panel.
	builder.restore([Tools.record("roof_left",Vector3(18,7.05,1),1,PI),Tools.record("flat_roof",Vector3(18.5,7.05,1.5),2)])
	var panel: BuildPiece = builder.pieces.back()
	var recipe := Fit.recipe(panel.ceiling_rects,panel.ceiling_regions)
	var under: Variant = MeshChecks.front_hit(recipe,Vector3(1.8,1,0),Vector3(1.8,0,0))
	var beyond: Variant = MeshChecks.front_hit(recipe,Vector3(1.8,1,1.8),Vector3(1.8,0,1.8))
	check.call(under == null and beyond != null and is_equal_approx(beyond.y,0.2),"Eave clipping stops at the actual roof bay instead of erasing an uncovered ceiling edge")
	await Tools.settle(tree)
	var roof_frame := Transform3D(Basis(Vector3.UP,PI),Vector3(18,7.05,5))
	check.call(builder.placement_error("roof_left",roof_frame).is_empty(),"The next offset roof bay can be added above an existing ceiling")
	builder.add_record(Tools.record("roof_left",roof_frame.origin,3,PI))
	check.call(panel.ceiling_regions.size() == 1 and is_equal_approx(panel.ceiling_regions[0].high,2),"Contiguous roof bays merge into one continuous ceiling edge fit")
	# Reproduce the player's eight existing tiles, camera, aim and next click.
	builder.restore(temple())
	for point in [Vector2(6.5,-6.5),Vector2(6.5,-2.5),Vector2(6.5,1.5),Vector2(10.5,-6.5),Vector2(14.5,-6.5),Vector2(10.5,-2.5),Vector2(10.5,1.5),Vector2(14.5,-2.5)]:
		builder.add_record(Tools.record("flat_roof",Vector3(point.x,7.05,point.y),builder.next_uid))
	builder.choose("flat_roof")
	builder.angle = 0
	player.restore({"flying":true,"position":[14.9247922897339,7.15210247039795,4.04407167434692],"yaw":-1.24108481407166,"pitch":-0.182642102241516})
	await Tools.settle(tree)
	builder.update_preview()
	check.call(builder.valid and builder.ghost.position.is_equal_approx(Vector3(18.5,7.05,1.5)),"The reported saved camera previews the missing right-hand panel on the existing ceiling grid")
	var count := builder.pieces.size()
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	check.call(builder.pieces.size() == count+1 and builder.pieces.back().position.is_equal_approx(Vector3(18.5,7.05,1.5)),"Native click fills the exact bay that failed in the reported build")
	var saved := builder.serialize()
	builder.undo()
	builder.redo()
	game.save_world()
	game.load_world()
	check.call(builder.serialize() == saved and not builder.pieces.back().ceiling_regions.is_empty(),"The offset infill and its fit survive history and save/load")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
