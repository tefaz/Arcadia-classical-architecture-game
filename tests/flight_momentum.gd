extends RefCounted

static func frames(tree: SceneTree, count: int) -> void:
	for _frame in range(count):
		await tree.physics_frame
		await tree.process_frame

static func reset(player: BuilderPlayer, origin: Vector3 = Vector3(12,12,12)) -> void:
	player.set_flying(true)
	player.position = origin
	player.rotation.y = 0
	player.head.rotation.x = -1.2
	player.active = true

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var player: BuilderPlayer = game.player
	game.builder.restore([])
	game.builder.select_slot(BuildCatalogue.DEFAULT_SLOT)
	game.ui.enter_world()
	# Movement stays in world space after release, even when the camera turns.
	reset(player)
	Input.action_press("forward")
	await frames(tree,10)
	var speed := player.velocity.length()
	check.call(is_equal_approx(speed,16) and is_equal_approx(player.position.y,12),"Flight builds to its normal speed while staying level when looking down")
	Input.action_release("forward")
	var released_at := player.position
	player.rotation.y = PI/2
	await frames(tree,2)
	check.call(player.position.z < released_at.z and player.velocity.z < 0 and player.velocity.length() < speed,"Releasing flight input keeps a little movement while momentum slows")
	check.call(is_equal_approx(player.position.x,released_at.x),"Turning the view while coasting preserves the original direction")
	await frames(tree,18)
	var drift := player.position.distance_to(released_at)
	check.call(player.velocity.is_zero_approx() and drift > 0.2 and drift < 2,"Flight comes fully to rest after a short coast of less than two metres")
	var stopped_at := player.position
	await frames(tree,8)
	check.call(player.position.is_equal_approx(stopped_at),"Released flight settles completely without lingering drift")
	# A quick tap builds less momentum than holding a key.
	reset(player)
	Input.action_press("forward")
	await frames(tree,1)
	Input.action_release("forward")
	released_at = player.position
	await frames(tree,20)
	check.call(player.position.distance_to(released_at) < drift*0.5,"A brief flight tap coasts less than sustained movement")
	# Vertical flight and combined movement use the same momentum and speed cap.
	for action in ["jump","descend"]:
		reset(player)
		Input.action_press(action)
		await frames(tree,10)
		Input.action_release(action)
		released_at = player.position
		await frames(tree,2)
		check.call((player.position.y-released_at.y)*(1 if action == "jump" else -1) > 0 and absf(player.velocity.y) > 0,"Vertical flight coasts briefly after releasing "+action)
		await frames(tree,18)
		check.call(player.velocity.is_zero_approx() and absf(player.position.y-released_at.y) < 2,"Vertical flight brakes to a complete stop")
	reset(player)
	Input.action_press("forward")
	Input.action_press("right")
	Input.action_press("jump")
	await frames(tree,15)
	check.call(is_equal_approx(player.velocity.length(),16),"Diagonal flight retains the normal total speed limit")
	Input.action_release("forward")
	Input.action_release("right")
	Input.action_release("jump")
	# An opposing key responds promptly instead of forcing the player to finish coasting.
	reset(player)
	Input.action_press("forward")
	await frames(tree,10)
	Input.action_release("forward")
	Input.action_press("back")
	await frames(tree,9)
	check.call(player.velocity.z > 0,"Opposing input promptly reverses flight momentum")
	Input.action_release("back")
	game.ui.show_catalogue()
	check.call(player.velocity.is_zero_approx(),"Opening the library immediately clears flight momentum")
	game.ui.close_overlay()
	stopped_at = player.position
	await frames(tree,15)
	check.call(player.position.is_equal_approx(stopped_at),"Closing the library cannot resume old flight momentum")
	# The ordinary controller collision stops coasting at stone walls.
	game.builder.add_record({"uid":1,"kind":"wall","stone":0,"position":[12,8,0],"rotation":0})
	await frames(tree,2)
	reset(player,Vector3(12,10,1.2))
	Input.action_press("forward")
	await frames(tree,6)
	Input.action_release("forward")
	await frames(tree,20)
	check.call(player.position.z >= 0.45 and player.velocity.is_zero_approx(),"Flight momentum stops at a wall without passing through it")
	game.builder.restore([])
	reset(player,Vector3(61.7,12,12))
	Input.action_press("right")
	await frames(tree,12)
	Input.action_release("right")
	check.call(is_equal_approx(player.position.x,62) and is_zero_approx(player.velocity.x),"The sanctuary boundary clears outward flight momentum")
	# Compare real controller movement at different physics rates, not a separate movement formula.
	var original_rate := Engine.physics_ticks_per_second
	var distances: Array[float] = []
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		reset(player)
		Input.action_press("forward")
		await frames(tree,ceili(rate*0.2))
		Input.action_release("forward")
		released_at = player.position
		await frames(tree,ceili(rate*0.3))
		distances.append(player.position.distance_to(released_at))
		check.call(player.velocity.is_zero_approx(),"Flight comes to rest at %d physics ticks per second" % rate)
	Engine.physics_ticks_per_second = original_rate
	check.call(distances.max()-distances.min() < 0.32,"Coasting distance stays consistent across 30, 60 and 120 physics ticks")
	player.set_flying(false)
	game.ui.show_menu()
