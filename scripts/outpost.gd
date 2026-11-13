extends "res://scripts/models/procedural_model.gd"
## Builds the static outpost. Interactive objects and UI are composed in outpost.tscn.

const ProceduralModel = preload("res://scripts/models/procedural_model.gd")

func selectable(display_name: String) -> ProceduralModel:
	var model := ProceduralModel.new()
	model.name = display_name.to_pascal_case()
	model.set_meta("display_name", display_name)
	add_child(model)
	return model

func _ready() -> void:
	build_environment()
	build_platform()
	build_habitat()
	build_details()
	$SelectionUI.prepare_selection()
	$CameraControls.selection_requested.connect($SelectionUI.select_at)

func build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080f20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a1bed5")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color("fff0d5")
	key.light_energy = 1.65
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 70.0
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 145, 0)
	rim.light_color = Color("7b9dff")
	rim.light_energy = 0.65
	add_child(rim)
	# A fixed, seeded field keeps the surrounding void quiet and reproducible.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.035
	star_mesh.height = 0.07
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.mesh = star_mesh
	stars.instance_count = 260
	for i in stars.instance_count:
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
		var scale_value := rng.randf_range(0.45, 1.5)
		stars.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), direction * rng.randf_range(65, 100)))
	var field := MultiMeshInstance3D.new()
	field.multimesh = stars
	field.material_override = material(Color("b5c9e4"), 1.0)
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)

func build_platform() -> void:
	var model = selectable("Outpost Platform")
	model.cylinder(Vector3(0, -0.55, 0), 5.2, 6.1, 0.95, INK, 12)
	model.cylinder(Vector3(0, -0.12, 0), 6.14, 6.14, 0.18, SLATE, 12)
	model.cylinder(Vector3(0, 0.02, 0), 5.98, 5.98, 0.16, DECK, 12)
	model.cylinder(Vector3(0, -1.12, 0), 2.6, 4.4, 0.3, SLATE, 12)
	model.cylinder(Vector3(0, -1.38, 0), 1.9, 2.6, 0.3, INK, 8)
	model.cylinder(Vector3(0, -1.56, 0), 1.6, 1.9, 0.12, TEAL, 8, 2.0)
	model.cylinder(Vector3(0, -1.69, 0), 1.3, 1.6, 0.18, INK, 8)
	for i in 12:
		var a := TAU * i / 12.0
		var radial := Vector3(sin(a), 0, cos(a))
		var seam := model.box(radial * 4.1 + Vector3(0, 0.112, 0), Vector3(0.035, 0.015, 3.6), SLATE)
		seam.rotation.y = a
		var rim := model.box(radial * 5.84 + Vector3(0, 0.17, 0), Vector3(1.6, 0.16, 0.16), IVORY)
		rim.rotation.y = a
		var lamp := model.box(radial * 5.96 + Vector3(0, -0.12, 0), Vector3(0.65, 0.06, 0.045), TEAL, 2.0)
		lamp.rotation.y = a
		if i % 3 == 0:
			model.cylinder(radial * 5.68 + Vector3(0, 0.38, 0), 0.12, 0.09, 0.55, INK, 6)
			model.cylinder(radial * 5.68 + Vector3(0, 0.68, 0), 0.11, 0.11, 0.1, GOLD, 6, 2.0)
	# Short arrival apron and inset guidance strips.
	model.box(Vector3(0, -0.01, 5.5), Vector3(2.7, 0.32, 3.2), INK)
	model.box(Vector3(0, 0.16, 5.5), Vector3(2.48, 0.08, 3.15), DECK)
	for x in [-1.08, 1.08]:
		model.box(Vector3(x, 0.21, 5.55), Vector3(0.06, 0.025, 2.7), TEAL, 1.3)
	for z in [3.4, 3.9, 4.4, 4.9, 5.4, 5.9]:
		model.box(Vector3(0, 0.213, z), Vector3(0.07, 0.015, 0.23), IVORY)

func build_habitat() -> void:
	var model = selectable("Habitat")
	model.cylinder(Vector3(0, 0.27, -0.65), 2.65, 2.65, 0.34, INK)
	model.cylinder(Vector3(0, 0.49, -0.65), 2.5, 2.4, 0.18, IVORY)
	model.cylinder(Vector3(0, 1.38, -0.65), 2.3, 2.15, 1.65, IVORY)
	model.cylinder(Vector3(0, 1.72, -0.65), 2.235, 2.18, 0.55, INK)
	# Eight recessed luminous window bays, framed by structural ribs.
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var pos := Vector3(sin(a) * 2.05, 1.73, cos(a) * 2.05 - 0.65)
		var window := model.box(pos, Vector3(1.12, 0.3, 0.055), GOLD, 0.6)
		window.rotation.y = a
		var rib := model.box(Vector3(sin(TAU * i / 8.0) * 2.17, 1.35, cos(TAU * i / 8.0) * 2.17 - 0.65), Vector3(0.16, 1.55, 0.16), SLATE)
		rib.rotation.y = TAU * i / 8.0
	model.cylinder(Vector3(0, 2.25, -0.65), 2.48, 2.48, 0.2, INK)
	model.cylinder(Vector3(0, 2.47, -0.65), 2.5, 1.85, 0.28, IVORY)
	model.cylinder(Vector3(0, 2.65, -0.65), 1.86, 1.86, 0.1, SLATE)
	# Airlock facing the arrival apron.
	model.box(Vector3(0, 0.98, 1.48), Vector3(1.1, 1.65, 0.3), SLATE)
	model.box(Vector3(0, 0.93, 1.66), Vector3(0.78, 1.34, 0.09), INK)
	model.box(Vector3(0, 1.0, 1.715), Vector3(0.035, 1.13, 0.02), DECK)
	model.box(Vector3(0, 1.75, 1.67), Vector3(0.82, 0.065, 0.08), TEAL, 2.0)
	model.box(Vector3(0, 0.3, 1.97), Vector3(1.35, 0.3, 0.65), IVORY)
	model.box(Vector3(0, 0.18, 2.35), Vector3(1.65, 0.17, 0.4), SLATE)
	model.cylinder(Vector3(0, 2.84, -0.65), 0.9, 0.7, 0.3, INK)
	model.cylinder(Vector3(0, 3.03, -0.65), 0.72, 0.72, 0.08, GOLD)

func build_details() -> void:
	var model: ProceduralModel
	# A small solar array and service crates keep the silhouette readable.
	for x in [-3.75, 3.75]:
		model = selectable("Port Solar Array" if x < 0 else "Starboard Solar Array")
		model.cylinder(Vector3(x, 0.65, -1.0), 0.16, 0.12, 1.1, INK, 6)
		var panel := Node3D.new()
		panel.position = Vector3(x, 1.2, -1.0)
		panel.rotation_degrees.x = -18
		model.add_child(panel)
		model.box(Vector3.ZERO, Vector3(1.65, 0.12, 2.25), IVORY, 0, panel)
		model.box(Vector3(0, 0.075, 0), Vector3(1.48, 0.04, 2.07), Color("233f62"), 0, panel)
		for z in 6:
			model.box(Vector3(0, 0.102, -0.86 + z * 0.345), Vector3(1.46, 0.012, 0.025), Color("577f9d"), 0, panel)
		model.box(Vector3(0, 0.104, 0), Vector3(0.035, 0.012, 2.05), IVORY, 0, panel)
	for pos in [Vector3(2.9, 0.48, 2.0), Vector3(3.6, 0.38, 2.5)]:
		model = selectable("Service Crate 01" if pos.x < 3.0 else "Service Crate 02")
		model.box(pos, Vector3(0.7, 0.7, 0.7), SLATE)
		model.box(pos + Vector3(0, 0.37, 0), Vector3(0.73, 0.07, 0.73), IVORY)
		model.box(pos + Vector3(0, 0, 0.356), Vector3(0.42, 0.09, 0.025), GOLD)
	model = selectable("Communications Antenna")
	model.cylinder(Vector3(-1.1, 2.95, -1.4), 0.07, 0.04, 1.05, INK, 6)
	model.cylinder(Vector3(-1.1, 3.5, -1.4), 0.09, 0.09, 0.12, GOLD, 6, 1.5)
	var label := Label3D.new()
	label.text = "00"
	label.font_size = 110
	label.pixel_size = 0.007
	label.modulate = IVORY
	label.position = Vector3(-2.7, 0.13, 2.7)
	label.rotation_degrees.x = -90
	label.outline_size = 0
	add_child(label)
