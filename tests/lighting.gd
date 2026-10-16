extends RefCounted

static func run(game: Node3D, check: Callable) -> void:
	var world: SanctuaryWorld = game.world
	var advanced := world.Lighting.is_forward_plus()
	var previous_quality := int(game.settings.get_value("controls","quality",1))
	var previous_shade := world.environment.ambient_light_energy
	var previous_day := world.day_progress
	world.set_shade_brightness(0.47)
	world.restore_daylight(0.72)
	var pieces: Array = game.builder.serialize()
	# Change through the settings entry point, including High -> Simple, to catch
	# expensive effects remaining enabled after reducing quality during play.
	for quality in [2,0,1,2,0]:
		game._change_setting("quality",quality)
		check.call(world.sun.shadow_enabled == (quality > 0),"Graphics settings turn real sun shadows on and off")
		check.call(world.environment.ssao_enabled == (advanced and quality > 0) and world.environment.ssil_enabled == (advanced and quality == 2),"Contact shading and indirect light respect quality and the active renderer")
		check.call(world.environment.glow_enabled == (advanced and quality > 0),"Cinematic highlight glow turns off with Simple and on with supported quality profiles")
		check.call(is_equal_approx(world.environment.ambient_light_energy,0.47) and is_equal_approx(world.day_progress,0.72),"Changing graphics preserves shade brightness and the daylight clock")
		var saved := ConfigFile.new()
		saved.load("user://settings.cfg")
		check.call(int(saved.get_value("controls","quality",-1)) == quality and int(game.ui.get_meta("quality")) == quality,"Graphics choice is persisted and kept in the settings UI")
	check.call(game.builder.serialize() == pieces,"Changing lighting leaves the player's building intact")
	game._apply_quality(-100)
	check.call(not world.sun.shadow_enabled and game.get_viewport().msaa_3d == Viewport.MSAA_DISABLED,"An invalid low quality setting safely uses Simple")
	game._apply_quality(100)
	check.call(world.sun.shadow_enabled and game.get_viewport().msaa_3d == Viewport.MSAA_4X,"An invalid high quality setting safely uses High")
	if advanced:
		check.call(world.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY and world.environment.tonemap_mode == Environment.TONE_MAPPER_AGX,"Cinematic lighting uses directional sky ambience and AgX highlights")
		check.call(world.sun.light_angular_distance > 0 and world.sky_fill.light_energy < 0.1,"Cinematic sunlight has a finite soft source and restrained fill")
	else:
		check.call(not world.environment.ssao_enabled and not world.environment.ssil_enabled,"The fallback avoids Forward+ screen-space effects")
	world.restore_daylight(previous_day)
	world.set_shade_brightness(previous_shade)
	var limestone: Color = BuildCatalogue.MATERIAL_COLORS[0]
	var marble: Color = BuildCatalogue.MATERIAL_COLORS[1]
	check.call(limestone.r < marble.r-0.1 and limestone.r-limestone.b > 0.1,"Limestone retains a warm, darker base colour distinct from white marble")
	game._change_setting("quality",previous_quality)
