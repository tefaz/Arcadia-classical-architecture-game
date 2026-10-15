extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Groups := preload("res://tests/group_stacks.gd")

static func mesh_of(piece: BuildPiece) -> MeshInstance3D:
	for child in piece.get_children():
		if child is MeshInstance3D: return child
	return null

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	game.ui.enter_world()
	builder.restore(Groups.facade())
	var first := builder.pieces[0]
	var last := builder.pieces[4]
	var first_mesh := mesh_of(first)
	var last_mesh := mesh_of(last)
	var original_material := first_mesh.material_override
	var original_overlay := StandardMaterial3D.new()
	first_mesh.material_overlay = original_overlay
	var records := builder.serialize()
	builder.select_slot(BuildCatalogue.TOOL_SLOT)
	game.player.set_flying(true)
	game.player.position = Vector3(6,1.2,1)
	game.player.look_at_point(Vector3(11,0.2,1))
	await Tools.settle(tree)
	var red: StandardMaterial3D = first_mesh.material_overlay
	check.call(builder.stack_hover == first and builder.stack_hover_outline.visible and red.albedo_color.r > red.albedo_color.g*2,"Before the first click, the aimed component and hover outline turn red")
	check.call(first_mesh.material_override == original_material and builder.serialize() == records,"Hover tint preserves the stone material and saved component data")
	game.player.look_at_point(game.player.camera.global_position+Vector3.UP*10)
	await Tools.settle(tree)
	check.call(first_mesh.material_overlay == original_overlay and not builder.stack_hover_outline.visible,"Looking away restores the previous overlay and hides the hover outline")
	game.player.look_at_point(Vector3(11,0.2,1))
	await Tools.settle(tree)
	await Tools.mouse(tree,MOUSE_BUTTON_LEFT)
	game.player.position = Vector3(14,7.25,6)
	game.player.look_at_point(Vector3(14,4.875,0))
	await Tools.settle(tree)
	var green: StandardMaterial3D = last_mesh.material_overlay
	check.call(builder.stack_selecting and builder.stack_hover == last and green.albedo_color.g > green.albedo_color.r*2,"After the first click, the hovered second component turns green")
	check.call(first_mesh.material_overlay.albedo_color.a < red.albedo_color.a,"The selected first point keeps a subtle red tint while choosing the second")
	check.call(mesh_of(builder.pieces[2]).material_overlay.albedo_color.a < green.albedo_color.a,"Members inside the live selection have a subtle surface tint")
	await Tools.mouse(tree,MOUSE_BUTTON_RIGHT)
	check.call(not builder.stack_selecting and not builder.stack_hover_outline.visible,"Locking the selection removes the strong hover highlight")
	check.call(last_mesh.material_overlay.albedo_color.g > last_mesh.material_overlay.albedo_color.r*2 and last_mesh.material_overlay.albedo_color.a < green.albedo_color.a,"The selected second point retains a subtle green tint")
	builder.change_stack_count(1)
	check.call(builder.stack_copies.size() > 0 and mesh_of(builder.stack_copies[0]).material_overlay == null,"Copied previews keep their independent placement validity colors")
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	check.call(first_mesh.material_overlay == original_overlay and last_mesh.material_overlay == null and builder._stack_overlays.is_empty(),"Switching tools restores all original overlays")
	await Groups.select(tree,game,first,last)
	game.ui.show_menu()
	await Tools.settle(tree)
	check.call(first_mesh.material_overlay == original_overlay and last_mesh.material_overlay == null and not builder.stack_hover_outline.visible,"Opening the menu clears endpoint and selection colors")
	game.ui.enter_world()
	await Groups.select(tree,game,first,last)
	game.player.look_at_point(game.player.camera.global_position+Vector3.UP*10)
	builder.remove_uid(first.uid)
	await Tools.settle(tree)
	check.call(not builder.is_stacking() and last_mesh.material_overlay == null,"Removing a selected component clears the remaining selection tint")
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
