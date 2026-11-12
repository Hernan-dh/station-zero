extends Node3D

const INK = Color("172935")
const SLATE = Color("3c5665")
const DECK = Color("657b87")
const IVORY = Color("d7ddcd")
const TEAL = Color("67eddb")
const GOLD = Color("efb771")

var camera: Camera3D
var beacon: Node3D
var time := 0.0
var yaw := 0.62
var pitch := 0.48
var zoom := 18.0
var dragging := false
var auto_orbit := false
var orbit_button: Button

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func mesh_node(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func box(pos: Vector3, size: Vector3, color: Color, glow: float = 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(mesh, pos, material(color, glow), parent)

func cylinder(pos: Vector3, bottom: float, top: float, height: float, color: Color, sides: int = 8, glow: float = 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh_node(mesh, pos, material(color, glow), parent)

func _ready() -> void:
	build_environment()
	build_platform()
	build_habitat()
	build_details()
	build_interface()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.far = 300.0
	add_child(camera)
	camera.current = true
	update_camera()

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
	cylinder(Vector3(0, -0.55, 0), 5.2, 6.1, 0.95, INK, 12)
	cylinder(Vector3(0, -0.12, 0), 6.14, 6.14, 0.18, SLATE, 12)
	cylinder(Vector3(0, 0.02, 0), 5.98, 5.98, 0.16, DECK, 12)
	cylinder(Vector3(0, -1.12, 0), 2.6, 4.4, 0.3, SLATE, 12)
	cylinder(Vector3(0, -1.38, 0), 1.9, 2.6, 0.3, INK, 8)
	cylinder(Vector3(0, -1.56, 0), 1.6, 1.9, 0.12, TEAL, 8, 2.0)
	cylinder(Vector3(0, -1.69, 0), 1.3, 1.6, 0.18, INK, 8)
	for i in 12:
		var a := TAU * i / 12.0
		var radial := Vector3(sin(a), 0, cos(a))
		var seam := box(radial * 4.1 + Vector3(0, 0.112, 0), Vector3(0.035, 0.015, 3.6), SLATE)
		seam.rotation.y = a
		var rim := box(radial * 5.84 + Vector3(0, 0.17, 0), Vector3(1.6, 0.16, 0.16), IVORY)
		rim.rotation.y = a
		var lamp := box(radial * 5.96 + Vector3(0, -0.12, 0), Vector3(0.65, 0.06, 0.045), TEAL, 2.0)
		lamp.rotation.y = a
		if i % 3 == 0:
			cylinder(radial * 5.68 + Vector3(0, 0.38, 0), 0.12, 0.09, 0.55, INK, 6)
			cylinder(radial * 5.68 + Vector3(0, 0.68, 0), 0.11, 0.11, 0.1, GOLD, 6, 2.0)
	# Short arrival apron and inset guidance strips.
	box(Vector3(0, -0.01, 5.5), Vector3(2.7, 0.32, 3.2), INK)
	box(Vector3(0, 0.16, 5.5), Vector3(2.48, 0.08, 3.15), DECK)
	for x in [-1.08, 1.08]:
		box(Vector3(x, 0.21, 5.55), Vector3(0.06, 0.025, 2.7), TEAL, 1.3)
	for z in [3.4, 3.9, 4.4, 4.9, 5.4, 5.9]:
		box(Vector3(0, 0.213, z), Vector3(0.07, 0.015, 0.23), IVORY)

func build_habitat() -> void:
	cylinder(Vector3(0, 0.27, -0.65), 2.65, 2.65, 0.34, INK)
	cylinder(Vector3(0, 0.49, -0.65), 2.5, 2.4, 0.18, IVORY)
	cylinder(Vector3(0, 1.38, -0.65), 2.3, 2.15, 1.65, IVORY)
	cylinder(Vector3(0, 1.72, -0.65), 2.235, 2.18, 0.55, INK)
	# Eight recessed luminous window bays, framed by structural ribs.
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var pos := Vector3(sin(a) * 2.05, 1.73, cos(a) * 2.05 - 0.65)
		var window := box(pos, Vector3(1.12, 0.3, 0.055), GOLD, 0.6)
		window.rotation.y = a
		var rib := box(Vector3(sin(TAU * i / 8.0) * 2.17, 1.35, cos(TAU * i / 8.0) * 2.17 - 0.65), Vector3(0.16, 1.55, 0.16), SLATE)
		rib.rotation.y = TAU * i / 8.0
	cylinder(Vector3(0, 2.25, -0.65), 2.48, 2.48, 0.2, INK)
	cylinder(Vector3(0, 2.47, -0.65), 2.5, 1.85, 0.28, IVORY)
	cylinder(Vector3(0, 2.65, -0.65), 1.86, 1.86, 0.1, SLATE)
	# Airlock facing the arrival apron.
	box(Vector3(0, 0.98, 1.48), Vector3(1.1, 1.65, 0.3), SLATE)
	box(Vector3(0, 0.93, 1.66), Vector3(0.78, 1.34, 0.09), INK)
	box(Vector3(0, 1.0, 1.715), Vector3(0.035, 1.13, 0.02), DECK)
	box(Vector3(0, 1.75, 1.67), Vector3(0.82, 0.065, 0.08), TEAL, 2.0)
	box(Vector3(0, 0.3, 1.97), Vector3(1.35, 0.3, 0.65), IVORY)
	box(Vector3(0, 0.18, 2.35), Vector3(1.65, 0.17, 0.4), SLATE)
	cylinder(Vector3(0, 2.84, -0.65), 0.9, 0.7, 0.3, INK)
	cylinder(Vector3(0, 3.03, -0.65), 0.72, 0.72, 0.08, GOLD)
	beacon = Node3D.new()
	beacon.position = Vector3(0, 3.9, -0.65)
	add_child(beacon)
	cylinder(Vector3(0, -0.33, 0), 0.0, 0.43, 0.65, Color("319eaa"), 5, 0.55, beacon)
	cylinder(Vector3(0, 0.43, 0), 0.43, 0.0, 0.87, TEAL, 5, 0.75, beacon)
	for i in 3:
		var a := TAU * i / 3.0
		var prong := box(Vector3(sin(a) * 0.68, 3.25, cos(a) * 0.68 - 0.65), Vector3(0.13, 0.95, 0.16), IVORY)
		prong.rotation = Vector3(0.2, a, 0)

func build_details() -> void:
	# A small solar array and service crates keep the silhouette readable.
	for x in [-3.75, 3.75]:
		cylinder(Vector3(x, 0.65, -1.0), 0.16, 0.12, 1.1, INK, 6)
		var panel := Node3D.new()
		panel.position = Vector3(x, 1.2, -1.0)
		panel.rotation_degrees.x = -18
		add_child(panel)
		box(Vector3.ZERO, Vector3(1.65, 0.12, 2.25), IVORY, 0, panel)
		box(Vector3(0, 0.075, 0), Vector3(1.48, 0.04, 2.07), Color("233f62"), 0, panel)
		for z in 6:
			box(Vector3(0, 0.102, -0.86 + z * 0.345), Vector3(1.46, 0.012, 0.025), Color("577f9d"), 0, panel)
		box(Vector3(0, 0.104, 0), Vector3(0.035, 0.012, 2.05), IVORY, 0, panel)
	for pos in [Vector3(2.9, 0.48, 2.0), Vector3(3.6, 0.38, 2.5)]:
		box(pos, Vector3(0.7, 0.7, 0.7), SLATE)
		box(pos + Vector3(0, 0.37, 0), Vector3(0.73, 0.07, 0.73), IVORY)
		box(pos + Vector3(0, 0, 0.356), Vector3(0.42, 0.09, 0.025), GOLD)
	cylinder(Vector3(-1.1, 2.95, -1.4), 0.07, 0.04, 1.05, INK, 6)
	cylinder(Vector3(-1.1, 3.5, -1.4), 0.09, 0.09, 0.12, GOLD, 6, 1.5)
	var label := Label3D.new()
	label.text = "00"
	label.font_size = 110
	label.pixel_size = 0.007
	label.modulate = IVORY
	label.position = Vector3(-2.7, 0.13, 2.7)
	label.rotation_degrees.x = -90
	label.outline_size = 0
	add_child(label)

func ui_label(parent: Control, text: String, size: int, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui_label(ui, "S T A T I O N   Z E R O", 25, IVORY, Vector2(38, 31))
	ui_label(ui, "A SMALL LIGHT IN THE GREAT QUIET", 11, Color("7e99ac"), Vector2(40, 68))
	var footer := Control.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.position.y = -72
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(footer)
	ui_label(footer, "●  OUTPOST ONLINE", 12, TEAL, Vector2(40, 0))
	ui_label(footer, "SECTOR 00   /   DEEP SPACE", 11, Color("7e99ac"), Vector2(40, 23))
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position = Vector2(-365, -65)
	controls.add_theme_constant_override("separation", 12)
	ui.add_child(controls)
	orbit_button = Button.new()
	orbit_button.text = "  AUTO ORBIT  "
	orbit_button.toggle_mode = true
	orbit_button.toggled.connect(func(value: bool): auto_orbit = value)
	controls.add_child(orbit_button)
	var reset := Button.new()
	reset.text = "  RESET VIEW  "
	reset.pressed.connect(reset_view)
	controls.add_child(reset)
	for button in [orbit_button, reset]:
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", IVORY)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142334")
		style.border_color = Color("375364")
		style.set_border_width_all(1)
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("294557")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
	var hint := ui_label(ui, "DRAG TO ORBIT   ·   SCROLL TO ZOOM", 11, Color("7e99ac"), Vector2.ZERO)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -304
	hint.offset_top = 40
	hint.offset_right = -38
	hint.offset_bottom = 60

func reset_view() -> void:
	yaw = 0.62
	pitch = 0.48
	zoom = 18.0
	auto_orbit = false
	orbit_button.button_pressed = false
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(12, zoom - 1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(32, zoom + 1)
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, 0.15, 1.15)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_view()
	update_camera()

func update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var target := Vector3(0, 0.8, 0)
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 28
	camera.size = zoom
	camera.look_at(target)

func _process(delta: float) -> void:
	time += delta
	beacon.rotation.y += delta * 0.22
	beacon.position.y = 3.9 + sin(time * 1.4) * 0.09
	if auto_orbit:
		yaw += delta * 0.08
		update_camera()
	# Release reliably even if the cursor crosses a UI control.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
