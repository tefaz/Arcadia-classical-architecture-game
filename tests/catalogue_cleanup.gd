extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const MeshChecks := preload("res://tests/meshes.gd")

static func front(parts: Array, x: float, y: float) -> Vector3:
	return MeshChecks.front_hit(parts,Vector3(x,y,3),Vector3(x,y,0))

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	game.ui.show_menu()
	game.ui.show_catalogue()
	game.ui.filter_buttons.Columns.pressed.emit()
	var columns: Array = []
	for kind in game.ui.card_buttons:
		if game.ui.card_buttons[kind].visible: columns.append(kind)
	check.call(columns == ["doric_column","ionic_column","corinthian_column"],"The Columns library offers only the three complete column styles")
	check.call(BuildCatalogue.PIECES.size() == 40 and game.ui.card_buttons.size() == 40,"The library includes modular roofs, two domes, a lion statue and a pediment doorway wall")
	for kind in BuildCatalogue.LEGACY_REPLACEMENTS:
		check.call(not game.ui.card_buttons.has(kind) and not BuildCatalogue.get_piece(kind).is_empty(),kind+": absent from the library while old building records remain supported")
	game.ui.filter_buttons.Foundations.pressed.emit()
	var foundations: Array = []
	for kind in game.ui.card_buttons:
		if game.ui.card_buttons[kind].visible: foundations.append(kind)
	check.call(foundations.size() == 7 and foundations.has("foundation_podium") and foundations.has("steps"),"Foundations has a dedicated filter for platforms, paving, podiums and stairs")
	game.ui.close_overlay()
	# A saved hotbar is updated without changing any already placed column parts.
	var records: Array = []
	var hotbar: Array = BuildCatalogue.HOTBAR.duplicate()
	for i in range(BuildCatalogue.LEGACY_PIECES.size()):
		var kind: String = BuildCatalogue.LEGACY_PIECES[i].id
		records.append(Tools.record(kind,Vector3(4+i*5,2,0),i+1))
		hotbar[i%BuildCatalogue.BUILD_SLOTS] = kind
	check.call(game.store.save_world(records,game.player.serialize(),{"hotbar":hotbar,"slot":2}),"A world with retired column components and the original roof still saves successfully")
	game.load_world()
	check.call(builder.serialize() == records,"Loading preserves every legacy column part and whole roof in its original position")
	for i in range(BuildCatalogue.BUILD_SLOTS):
		var source_index := i+BuildCatalogue.BUILD_SLOTS if i+BuildCatalogue.BUILD_SLOTS < BuildCatalogue.LEGACY_PIECES.size() else i
		var old_kind: String = BuildCatalogue.LEGACY_PIECES[source_index].id
		check.call(builder.hotbar[i] == BuildCatalogue.library_kind(old_kind),"Saved hotbar replaces "+old_kind+" with its current library replacement")
	check.call(builder.selected_slot == 2 and builder.hotbar[BuildCatalogue.TOOL_SLOT] == BuildCatalogue.TOOL_KIND,"Hotbar cleanup preserves the selected slot, empty building slots and Stack tool")
	game.ui.show_catalogue()
	check.call(game.ui.preview_kind == builder.selected_kind(),"The migrated column selection opens its real library card safely")
	game.ui.show_menu()
	# Flush ashlar modules keep the full footprint at every course, with recessed joints.
	var podium := ClassicalGeometry.get_recipe("foundation_podium")
	var continuous := true
	for y in [0.1,0.3,0.65,0.85,1.15,1.4,1.9]:
		var hit := front(podium,0.4,y)
		continuous = continuous and is_equal_approx(hit.z,2.0)
	check.call(continuous,"The temple podium has flush masonry faces through its full height")
	var face := front(podium,0.4,0.65)
	var bed_joint := front(podium,0.4,0.8)
	check.call(face.z-bed_joint.z > 0.015,"The podium's large stone courses have a genuinely recessed horizontal joint")
	var lower_joint := front(podium,0,0.2)
	var upper_stone := front(podium,0,0.6)
	check.call(upper_stone.z-lower_joint.z > 0.015,"Vertical podium joints stagger between the two large ashlar courses")
	for kind in BuildCatalogue.FOUNDATION_KINDS:
		var piece := ClassicalGeometry.create(kind)
		var size := BuildCatalogue.piece_size(kind)
		check.call(piece.visual_bounds.position.is_equal_approx(Vector3(-size.x/2,0,-size.z/2)) and piece.visual_bounds.size.is_equal_approx(size),kind+": redesigned appearance preserves the original footprint and support height")
		piece.free()
	# The new podium remains a walkable, solid platform with an exact column attachment.
	builder.restore([Tools.record("foundation_podium",Vector3(12,0,0))])
	await Tools.settle(tree)
	var hit := {"position":Vector3(12,2,0),"normal":Vector3.UP,"collider":builder.pieces[0]}
	var solution := SnapSolver.solve("ionic_column",0,hit,builder.pieces,true,true,0)
	check.call(solution.snapped and solution.position.is_equal_approx(Vector3(12,2,0)) and builder.placement_error("ionic_column",Transform3D(Basis.IDENTITY,solution.position)).is_empty(),"Complete columns attach to the redesigned podium without overlap or height changes")
	builder.restore(SanctuaryWorld.sample_pavilion())
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	game.ui.active_filter = "All pieces"
	game.ui._update_cards()
	game.ui.show_menu()
