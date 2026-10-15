extends RefCounted

const Tools := preload("res://tests/building_tools.gd")
const Fit := preload("res://src/building/ceiling_fit.gd")

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var builder: ClassicalBuilder = game.builder
	var player: BuilderPlayer = game.player
	game.ui.enter_world()
	player.set_flying(true)
	player.position = Vector3(45,18,45)
	builder.restore(SanctuaryWorld.ceiling_pediment_example())
	builder.choose("flat_roof")
	builder.angle = 0
	await Tools.settle(tree)
	# Compare the cheap committed fit with a fresh support solve on both sides of the temple.
	var equivalent := true
	for z in [-2,-10]:
		for x in [4,8,12,16,20]:
			var frame := Transform3D(Basis.IDENTITY,Vector3(x,5.25,z))
			equivalent = equivalent and Fit.rectangles(frame,builder.pieces) == Fit.rectangles(frame,builder.pieces,0,true)
	check.call(equivalent,"Cached ceiling fitting matches fresh support calculations for every edge bay")
	# Exercise real candidate generation, fitted previews and physics checks, including blocked aims.
	# Average batches and a generous 5 ms budget catch the former 8–17 ms regression.
	var worst := 0.0
	for target in [Vector3(12,5.2,0),Vector3(12,7,-0.23),Vector3(22,5.2,-6)]:
		player.position = target+Vector3(0,2.5,5)
		player.look_at_point(target)
		await Tools.settle(tree)
		builder.update_preview()
		var start := Time.get_ticks_usec()
		for i in range(50): builder.update_preview()
		worst = maxf(worst,(Time.get_ticks_usec()-start)/50000.0)
	print("Ceiling preview worst batch average: %.3f ms" % worst)
	check.call(worst < 5,"Ceiling previews near pediments and entablatures stay within a generous frame-time budget")
	# World edits must still invalidate the reused geometry through ordinary connection refresh.
	var gable: BuildPiece
	for piece in builder.pieces:
		if piece.kind == "pediment_left" and is_equal_approx(piece.position.x,4) and is_zero_approx(piece.position.z): gable = piece
	var original_fit: Transform3D = gable.pediment_fit
	var remove: Array[int] = []
	for piece in builder.pieces:
		if piece.kind == "entablature" and absf(piece.position.x-2) < 0.01: remove.append(piece.uid)
	for uid in remove: builder.remove_uid(uid)
	check.call(not gable.pediment_fit.is_equal_approx(original_fit),"Editing supporting corners refreshes the reused gable fit")
	var frame := Transform3D(Basis.IDENTITY,Vector3(4,5.25,-2))
	check.call(Fit.rectangles(frame,builder.pieces) == Fit.rectangles(frame,builder.pieces,0,true),"Ceiling fitting immediately agrees with changed support geometry")
	builder.hotbar = BuildCatalogue.HOTBAR.duplicate()
	builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	builder.restore([])
	game.ui.show_menu()
