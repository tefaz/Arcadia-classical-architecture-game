extends RefCounted

static func run(tree: SceneTree, game: Node3D, check: Callable) -> void:
	var world: SanctuaryWorld = game.world
	game.ui.show_menu()
	check.call(world.sky_fill.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY,"The fill light illuminates architecture without creating a second sun")
	check.call(world.environment.sky.sky_material == world.sky_material and world.sky_material.shader != null,"The sky uses the dedicated single-sun shader")
	var initial_shade := world.environment.ambient_light_energy
	var directions: Array[Vector3] = []
	for progress in [0.0,0.25,0.5,0.75,0.9999]:
		world.restore_daylight(progress)
		var direction := world.sun.global_basis.z
		directions.append(direction)
		check.call(direction.y >= 0 and direction.is_normalized(),"The sun stays above the horizon during daylight at %.4f" % progress)
		var rendered_direction: Vector3 = world.sky_material.get_shader_parameter("sun_direction")
		check.call(rendered_direction.is_equal_approx(direction),"The visible sun stays aligned with the light and shadows")
		check.call(is_equal_approx(world.environment.ambient_light_energy,initial_shade),"The day cycle preserves the user's shade brightness")
	check.call(directions[0].x > 0.9 and directions[4].x < -0.9 and directions[2].y > 0.8,"The sun rises in the east, passes overhead, and sets in the west")
	world.restore_daylight(0.5)
	var midday_color := world.sun.light_color
	world.restore_daylight(0.98)
	check.call(world.sun.light_color.b < midday_color.b,"Late sunlight becomes warmer approaching sunset")
	var sunset_direction := world.sun.global_basis.z
	world.restore_daylight(1.0-0.05/SanctuaryWorld.DAY_LENGTH_SECONDS)
	world.advance_daylight(0.1)
	check.call(world.day_progress < 0.001 and world.sun.global_basis.z.x > 0.9 and world.sun.global_basis.z.y > 0.1,"Reaching sunset immediately jumps to morning without entering night")
	check.call(world.sun.global_basis.z.distance_to(sunset_direction) > 1.8,"The sunset reset changes the visible sun and light in the same update")
	world.restore_daylight(0.2)
	world.advance_daylight(SanctuaryWorld.DAY_LENGTH_SECONDS)
	check.call(is_equal_approx(world.day_progress,0.2),"A full twenty-minute day returns to the same daylight phase")
	world.advance_daylight(SanctuaryWorld.DAY_LENGTH_SECONDS*3+SanctuaryWorld.DAY_LENGTH_SECONDS*0.1)
	check.call(is_equal_approx(world.day_progress,0.3),"Long elapsed frames wrap across multiple days without producing night")
	# Equal elapsed time produces the same clock regardless of update frequency.
	world.restore_daylight(0.2)
	for _frame in range(60): world.advance_daylight(1.0/60)
	var small_steps := world.day_progress
	world.restore_daylight(0.2)
	world.advance_daylight(1.0)
	check.call(is_equal_approx(world.day_progress,small_steps),"The day clock advances consistently at different frame rates")
	for value in [null,-0.5,1.0,INF,NAN,"evening",true]:
		world.restore_daylight(value)
		check.call(is_equal_approx(world.day_progress,SanctuaryWorld.DEFAULT_DAY_PROGRESS),"Invalid or legacy daylight data safely starts in the morning")
	world.restore_daylight(0.4)
	world.advance_daylight(-1)
	world.advance_daylight(INF)
	check.call(is_equal_approx(world.day_progress,0.4),"Invalid elapsed time cannot corrupt the daylight clock")
	# Drive the actual game loop for play/menu/library behavior.
	game.ui.enter_world()
	world.restore_daylight(0.3)
	for _frame in range(3): await tree.process_frame
	check.call(world.day_progress > 0.3,"The day cycle advances while playing")
	game.ui.show_menu()
	var paused_progress := world.day_progress
	for _frame in range(3): await tree.process_frame
	check.call(is_equal_approx(world.day_progress,paused_progress),"Opening the pause menu stops the day clock")
	game.ui.enter_world()
	game.ui.show_catalogue()
	paused_progress = world.day_progress
	for _frame in range(3): await tree.process_frame
	check.call(is_equal_approx(world.day_progress,paused_progress),"The day clock also pauses while browsing the library")
	# Save through the same game entry points used by F5/F9, then exercise a legacy save.
	world.restore_daylight(0.73)
	game.save_world()
	world.restore_daylight(0.1)
	game.load_world()
	check.call(is_equal_approx(world.day_progress,0.73),"Saving and loading preserve the time of day")
	game.store.save_world(game.builder.serialize(),game.player.serialize(),{})
	world.restore_daylight(0.9)
	game.load_world()
	check.call(is_equal_approx(world.day_progress,SanctuaryWorld.DEFAULT_DAY_PROGRESS),"Existing saves without a day clock remain compatible")
	world.restore_daylight(0.9)
	game.empty_world()
	check.call(is_equal_approx(world.day_progress,SanctuaryWorld.DEFAULT_DAY_PROGRESS),"A new empty sanctuary starts in the morning")
	game.ui.show_menu()
