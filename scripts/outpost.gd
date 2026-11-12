extends Node3D

const INK = Color("172935")
const SLATE = Color("3c5665")
const DECK = Color("657b87")
const IVORY = Color("d7ddcd")
const TEAL = Color("67eddb")
const GOLD = Color("efb771")

var camera: Camera3D
var beacon: Node3D
var beacon_object: Node3D
var beacon_enabled := true
var beacon_materials: Array[StandardMaterial3D] = []
var beacon_button: Button
var communications_array: Node3D
var array_base: Node3D
var dish_pivot: Node3D
var array_controls: VBoxContainer
var bearing_slider: HSlider
var elevation_slider: HSlider
var bearing_label: Label
var elevation_label: Label
var sweep_button: Button
var array_bearing := 35.0
var dish_elevation := 35.0
var array_sweeping := false
var time := 0.0
var yaw := 0.62
var pitch := 0.48
var zoom := 18.0
var camera_target := Vector3(0, 0.8, 0)
var dragging := false
var pan_button := MOUSE_BUTTON_NONE
var auto_orbit := false
var orbit_button: Button
var build_selection: Node3D
var selected_object: Node3D
var selection_panel: PanelContainer
var selection_name: Label
var selection_material: StandardMaterial3D
var click_origin := Vector2.ZERO
var click_pending := false
const CLICK_DISTANCE := 5.0

func selectable(display_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = display_name.to_pascal_case()
	root.set_meta("display_name", display_name)
	add_child(root)
	build_selection = root
	return root

func prepare_selection() -> void:
	selection_material = material(TEAL)
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.albedo_color = Color(TEAL, 0.3)
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Geometry-accurate colliders keep gaps empty and respect occlusion.
	for node in find_children("*", "MeshInstance3D", true, false):
		node.create_trimesh_collision()

func select_at(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * camera.far)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node3D = null
	if not hit.is_empty():
		var node: Node = hit.collider
		while node != self:
			if node.has_meta("display_name"):
				target = node as Node3D
				break
			node = node.get_parent()
	set_selection(target)

func set_selection(target: Node3D) -> void:
	if is_instance_valid(selected_object):
		for mesh in selected_object.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = null
	selected_object = target
	selection_panel.visible = target != null
	beacon_button.visible = target == beacon_object
	array_controls.visible = target == communications_array
	selection_panel.offset_top = -350 if target == communications_array else (-220 if target == beacon_object else -176)
	if target != null:
		selection_name.text = target.get_meta("display_name")
		for mesh in target.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = selection_material

func set_beacon_enabled(enabled: bool) -> void:
	beacon_enabled = enabled
	for mat in beacon_materials:
		mat.emission_enabled = enabled
	beacon_button.set_pressed_no_signal(enabled)
	beacon_button.text = "BEACON ON  ·  TURN OFF" if enabled else "BEACON OFF  ·  TURN ON"

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
	if parent == self and build_selection != null:
		parent = build_selection
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
	build_communications_array()
	build_selection = null
	prepare_selection()
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
	selectable("Outpost Platform")
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
	selectable("Habitat")
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
	beacon_object = selectable("Navigation Beacon")
	beacon = Node3D.new()
	beacon.position = Vector3(0, 3.9, -0.65)
	build_selection.add_child(beacon)
	var lower := cylinder(Vector3(0, -0.33, 0), 0.0, 0.43, 0.65, Color("319eaa"), 5, 0.55, beacon)
	var upper := cylinder(Vector3(0, 0.43, 0), 0.43, 0.0, 0.87, TEAL, 5, 0.75, beacon)
	beacon_materials.append(lower.material_override as StandardMaterial3D)
	beacon_materials.append(upper.material_override as StandardMaterial3D)
	for i in 3:
		var a := TAU * i / 3.0
		var prong := box(Vector3(sin(a) * 0.68, 3.25, cos(a) * 0.68 - 0.65), Vector3(0.13, 0.95, 0.16), IVORY)
		prong.rotation = Vector3(0.2, a, 0)

func build_details() -> void:
	# A small solar array and service crates keep the silhouette readable.
	for x in [-3.75, 3.75]:
		selectable("Port Solar Array" if x < 0 else "Starboard Solar Array")
		cylinder(Vector3(x, 0.65, -1.0), 0.16, 0.12, 1.1, INK, 6)
		var panel := Node3D.new()
		panel.position = Vector3(x, 1.2, -1.0)
		panel.rotation_degrees.x = -18
		build_selection.add_child(panel)
		box(Vector3.ZERO, Vector3(1.65, 0.12, 2.25), IVORY, 0, panel)
		box(Vector3(0, 0.075, 0), Vector3(1.48, 0.04, 2.07), Color("233f62"), 0, panel)
		for z in 6:
			box(Vector3(0, 0.102, -0.86 + z * 0.345), Vector3(1.46, 0.012, 0.025), Color("577f9d"), 0, panel)
		box(Vector3(0, 0.104, 0), Vector3(0.035, 0.012, 2.05), IVORY, 0, panel)
	for pos in [Vector3(2.9, 0.48, 2.0), Vector3(3.6, 0.38, 2.5)]:
		selectable("Service Crate 01" if pos.x < 3.0 else "Service Crate 02")
		box(pos, Vector3(0.7, 0.7, 0.7), SLATE)
		box(pos + Vector3(0, 0.37, 0), Vector3(0.73, 0.07, 0.73), IVORY)
		box(pos + Vector3(0, 0, 0.356), Vector3(0.42, 0.09, 0.025), GOLD)
	selectable("Communications Antenna")
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

# Local +Z is the dish's boresight. The deck mount stays fixed while the
# azimuth bearing carries a separate X-axis elevation hinge and reflector.
func build_communications_array() -> void:
	communications_array = selectable("Communications Array")
	communications_array.position = Vector3(-3.25, 0.12, 2.15)
	cylinder(Vector3(0, 0.10, 0), 0.82, 0.72, 0.2, INK)
	cylinder(Vector3(0, 0.23, 0), 0.70, 0.70, 0.08, IVORY)
	cylinder(Vector3(0, 0.32, 0), 0.59, 0.59, 0.10, TEAL, 12, 0.7)
	for i in 8:
		var a := TAU * i / 8.0
		cylinder(Vector3(sin(a) * 0.62, 0.285, cos(a) * 0.62), 0.045, 0.045, 0.04, GOLD, 6)
	array_base = Node3D.new()
	array_base.name = "AzimuthBearing"
	communications_array.add_child(array_base)
	cylinder(Vector3(0, 0.44, 0), 0.63, 0.48, 0.16, SLATE, 12, 0, array_base)
	cylinder(Vector3(0, 0.93, 0), 0.35, 0.24, 0.85, IVORY, 8, 0, array_base)
	box(Vector3(0, 0.85, 0.30), Vector3(0.14, 0.39, 0.055), INK, 0, array_base)
	box(Vector3(0, 0.96, 0.335), Vector3(0.07, 0.16, 0.025), TEAL, 1.0, array_base)
	for x in [-0.49, 0.49]:
		box(Vector3(x, 1.37, -0.18), Vector3(0.17, 0.96, 0.26), SLATE, 0, array_base)
		var axle := cylinder(Vector3(x, 1.82, -0.18), 0.20, 0.20, 0.24, GOLD, 8, 0, array_base)
		axle.rotation.z = PI / 2
	dish_pivot = Node3D.new()
	dish_pivot.name = "ElevationHinge"
	dish_pivot.position = Vector3(0, 1.82, -0.18)
	array_base.add_child(dish_pivot)
	cylinder(Vector3(0, 0, -0.17), 0.30, 0.23, 0.26, INK, 8, 0, dish_pivot).rotation.x = PI / 2
	build_reflector(IVORY, 0.0)
	build_reflector(SLATE, -0.07)
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		array_strut(Vector3(cos(a), sin(a), 0.38), Vector3(cos(b), sin(b), 0.38), 0.035, GOLD)
		if i % 2 == 0:
			array_strut(Vector3(0, 0, -0.12), Vector3(cos(a), sin(a), 0.28), 0.028, INK)
	# Three delicate feed spars frame a luminous crystal receiver.
	for i in 3:
		var a := TAU * i / 3.0 + PI / 2
		array_strut(Vector3(cos(a) * 0.91, sin(a) * 0.91, 0.32), Vector3(0, 0, 0.98), 0.025, SLATE)
	var receiver := cylinder(Vector3(0, 0, 0.96), 0.13, 0.13, 0.20, GOLD, 6, 0, dish_pivot)
	receiver.rotation.x = PI / 2
	var crystal := cylinder(Vector3(0, 0, 1.13), 0.13, 0.0, 0.22, TEAL, 5, 0.8, dish_pivot)
	crystal.rotation.x = PI / 2
	set_array_bearing(array_bearing)
	set_dish_elevation(dish_elevation)

func build_reflector(color: Color, depth_offset: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 4:
		for segment in 16:
			var points: Array[Vector3] = []
			for corner in [Vector2(ring, segment), Vector2(ring + 1, segment), Vector2(ring + 1, segment + 1), Vector2(ring, segment + 1)]:
				var radius: float = corner.x / 4.0
				var angle: float = corner.y * TAU / 16.0
				points.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.38 * radius * radius + depth_offset))
			for index in ([0, 2, 1] if ring == 0 else [0, 2, 1, 0, 3, 2]):
				var point := points[index]
				surface.set_normal(Vector3(-0.76 * point.x, -0.76 * point.y, 1).normalized())
				surface.add_vertex(point)
	var mat := material(color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node(surface.commit(), Vector3.ZERO, mat, dish_pivot)

func array_strut(start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var strut := cylinder((start + end) * 0.5, radius, radius, start.distance_to(end), color, 6, 0, dish_pivot)
	strut.quaternion = Quaternion(Vector3.UP, (end - start).normalized())

func set_array_bearing(value: float) -> void:
	array_bearing = value
	array_base.rotation.y = deg_to_rad(value)
	if is_instance_valid(bearing_label):
		bearing_label.text = "BASE BEARING   %03d°" % roundi(fposmod(value, 360.0))
		bearing_slider.set_value_no_signal(value)

func set_dish_elevation(value: float) -> void:
	dish_elevation = clampf(value, 0.0, 85.0)
	dish_pivot.rotation.x = -deg_to_rad(dish_elevation)
	if is_instance_valid(elevation_label):
		elevation_label.text = "DISH ELEVATION   %02d°" % roundi(dish_elevation)

func build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui_label(ui, "S T A T I O N   Z E R O", 25, IVORY, Vector2(38, 31))
	ui_label(ui, "A SMALL LIGHT IN THE GREAT QUIET", 11, Color("7e99ac"), Vector2(40, 68))
	selection_panel = PanelContainer.new()
	selection_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	selection_panel.offset_left = 40
	selection_panel.offset_top = -176
	selection_panel.offset_right = 304
	selection_panel.offset_bottom = -96
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("142334")
	panel_style.border_color = TEAL
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	selection_panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(selection_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	selection_panel.add_child(info)
	ui_label(info, "SELECTED OBJECT", 10, TEAL, Vector2.ZERO)
	selection_name = ui_label(info, "", 18, IVORY, Vector2.ZERO)
	beacon_button = Button.new()
	beacon_button.toggle_mode = true
	beacon_button.custom_minimum_size.y = 36
	beacon_button.toggled.connect(set_beacon_enabled)
	info.add_child(beacon_button)
	set_beacon_enabled(beacon_enabled)
	beacon_button.hide()
	array_controls = VBoxContainer.new()
	array_controls.add_theme_constant_override("separation", 8)
	info.add_child(array_controls)
	bearing_label = ui_label(array_controls, "", 11, TEAL, Vector2.ZERO)
	bearing_slider = HSlider.new()
	bearing_slider.name = "BaseBearing"
	bearing_slider.min_value = -180
	bearing_slider.max_value = 180
	bearing_slider.step = 1
	bearing_slider.custom_minimum_size = Vector2(240, 20)
	bearing_slider.tooltip_text = "Rotate the base around the deck mount"
	bearing_slider.value_changed.connect(func(value: float):
		array_sweeping = false
		sweep_button.set_pressed_no_signal(false)
		set_array_bearing(value))
	array_controls.add_child(bearing_slider)
	elevation_label = ui_label(array_controls, "", 11, TEAL, Vector2.ZERO)
	elevation_slider = HSlider.new()
	elevation_slider.name = "DishElevation"
	elevation_slider.max_value = 85
	elevation_slider.step = 1
	elevation_slider.custom_minimum_size.y = 20
	elevation_slider.tooltip_text = "Tilt the dish independently, from horizon to near zenith"
	elevation_slider.value_changed.connect(set_dish_elevation)
	array_controls.add_child(elevation_slider)
	sweep_button = Button.new()
	sweep_button.text = "AUTO SWEEP"
	sweep_button.toggle_mode = true
	sweep_button.tooltip_text = "Rotate the base continuously while holding dish elevation"
	sweep_button.toggled.connect(func(value: bool): array_sweeping = value)
	array_controls.add_child(sweep_button)
	set_array_bearing(array_bearing)
	set_dish_elevation(dish_elevation)
	elevation_slider.set_value_no_signal(dish_elevation)
	array_controls.hide()
	selection_panel.hide()
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
	for button in [orbit_button, reset, beacon_button, sweep_button]:
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
	var hint := ui_label(ui, "CLICK TO SELECT   ·   DRAG TO ORBIT   ·   RIGHT DRAG / SHIFT + DRAG TO PAN   ·   SCROLL TO ZOOM", 11, Color("7e99ac"), Vector2.ZERO)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -730
	hint.offset_top = 40
	hint.offset_right = -38
	hint.offset_bottom = 60

func reset_view() -> void:
	yaw = 0.62
	pitch = 0.48
	zoom = 18.0
	camera_target = Vector3(0, 0.8, 0)
	dragging = false
	click_pending = false
	pan_button = MOUSE_BUTTON_NONE
	auto_orbit = false
	orbit_button.button_pressed = false
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				click_pending = false
				if event.shift_pressed:
					pan_button = MOUSE_BUTTON_LEFT
					dragging = false
				elif pan_button == MOUSE_BUTTON_NONE:
					dragging = true
					click_origin = event.position
					click_pending = true
			else:
				if click_pending and event.position.distance_to(click_origin) <= CLICK_DISTANCE:
					select_at(event.position)
				click_pending = false
				dragging = false
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			click_pending = false
			pan_button = MOUSE_BUTTON_RIGHT
			dragging = false
		if event.button_index == pan_button and not event.pressed:
			pan_button = MOUSE_BUTTON_NONE
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(12, zoom - 1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(32, zoom + 1)
	if event is InputEventMouseMotion:
		if pan_button != MOUSE_BUTTON_NONE:
			# Move in the camera's screen plane so the outpost follows the drag.
			# Projection accounts for orthographic zoom and viewport aspect ratio.
			camera_target += camera.project_position(Vector2.ZERO, 28.0) - camera.project_position(event.relative, 28.0)
		elif dragging:
			if click_pending and event.position.distance_to(click_origin) <= CLICK_DISTANCE:
				return
			click_pending = false
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch + event.relative.y * 0.004, 0.15, 1.15)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_view()
	update_camera()

func update_camera() -> void:
	if not is_instance_valid(camera):
		return
	camera.position = camera_target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 28
	camera.size = zoom
	camera.look_at(camera_target)

func _process(delta: float) -> void:
	if array_sweeping:
		set_array_bearing(wrapf(array_bearing + delta * 12.0, -180.0, 180.0))
	if beacon_enabled:
		time += delta
		beacon.rotation.y += delta * 0.22
		beacon.position.y = 3.9 + sin(time * 1.4) * 0.09
	if auto_orbit and pan_button == MOUSE_BUTTON_NONE:
		yaw += delta * 0.08
		update_camera()
	# Release reliably even if the cursor crosses a UI control.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		click_pending = false
	if pan_button != MOUSE_BUTTON_NONE and not Input.is_mouse_button_pressed(pan_button):
		pan_button = MOUSE_BUTTON_NONE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		click_pending = false
		pan_button = MOUSE_BUTTON_NONE
