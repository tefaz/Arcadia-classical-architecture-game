extends RefCounted
## The integrated cinematic lighting profile. Keep renderer-specific tuning here so
## the Compatibility fallback never enables unsupported Forward+ effects.

const DIRECT_ENERGY_SCALE := 2.4

static func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

static func setup(environment: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D) -> void:
	fill.light_color = Color("a0b9d6")
	fill.light_energy = 0.035 if is_forward_plus() else 0.08
	environment.fog_light_energy = 0.45
	if not is_forward_plus():
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = 0.78
		return
	# Sky irradiance gives upward and downward faces different ambient light.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_agx_contrast = 1.35
	environment.tonemap_exposure = 1.05
	environment.fog_density = 0.0016
	sun.light_angular_distance = 0.85
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = true
	# A short radius brings out mouldings and contacts without dark outlines.
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 1.15
	environment.ssao_power = 1.2
	environment.ssao_detail = 0.5
	environment.ssao_light_affect = 0.0
	environment.ssil_radius = 3.0
	environment.ssil_intensity = 0.45
	environment.ssil_normal_rejection = 1.0
	# Bloom is restricted to HDR highlights, so pale stone does not acquire a veil.
	environment.glow_hdr_threshold = 1.6
	environment.glow_intensity = 0.25
	environment.glow_strength = 0.6
	environment.glow_bloom = 0.0

static func apply_quality(world: SanctuaryWorld, viewport: Viewport, quality: int) -> void:
	quality = clampi(quality,0,2)
	world.sun.shadow_enabled = quality > 0
	viewport.msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
	RenderingServer.directional_shadow_atlas_set_size(4096 if quality == 2 else 2048,false)
	world.environment.ssao_enabled = is_forward_plus() and quality > 0
	world.environment.ssil_enabled = is_forward_plus() and quality == 2
	world.environment.glow_enabled = is_forward_plus() and quality > 0
	if is_forward_plus():
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if quality == 2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)

static func setup_preview(environment: Environment, key: DirectionalLight3D, fill: DirectionalLight3D) -> void:
	if not is_forward_plus(): return
	key.light_energy *= DIRECT_ENERGY_SCALE
	fill.light_energy = 0.08
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_agx_contrast = 1.35
	environment.tonemap_exposure = 1.05
