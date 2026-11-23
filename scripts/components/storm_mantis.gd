extends Node3D
## Damageable flying Storm Mantis that patrols an existing enemy approach.
## The Arc Launcher finds it through the "enemies" group and calls take_damage().

signal health_changed(current: float, maximum: float)
signal defeated

const APPROACH_GROUP := &"enemy_approaches"
const ENEMY_GROUP := &"enemies"
const LIGHTNING_COLORS := [Color("bfe8ff"), Color("4aa8ff")]
const LIGHTNING_SEGMENTS := 7
const LIGHTNING_WIDTH := 0.022
const LIGHTNING_CORE_WIDTH := 0.009

@export var lightning_enabled := true:
	set(value):
		lightning_enabled = value
		if is_node_ready():
			_light.visible = value
			if not value:
				_lightning_mesh.clear_surfaces()
@export var approach_path: NodePath
@export_range(0.1, 20.0) var travel_speed := 4.0
@export_range(0.0, 8.0) var hover_height := 2.2
@export_range(0.0, 1.0) var bob_amplitude := 0.16
@export_range(0.0, 6.0) var bob_speed := 1.6
@export var max_health := 80.0
@export var health := 80.0
@export var aim_height := 0.0

var _player: AnimationPlayer
var _idle_clip := &""
var _flight_clip := &""
var _path: Path3D
var _curve: Curve3D
var _length := 0.0
var _distance := 0.0
var _traveling := false
var _defeated := false
var _bob_time := 0.0
var _lightning_tick := 0.0
var _lightning_mesh := ImmediateMesh.new()
var _rng := RandomNumberGenerator.new()
var _wing_points: Array[Vector3] = []
@onready var _light: OmniLight3D = $StormLight
@onready var _sparks: CPUParticles3D = $ElectricSparks

func _ready() -> void:
	_rng.randomize()
	max_health = maxf(max_health, 1.0)
	health = clampf(health, 0.0, max_health)
	add_to_group(ENEMY_GROUP)
	_setup_lightning()
	_setup_animation()
	_setup_path()

func is_traveling() -> bool:
	return _traveling

func is_alive() -> bool:
	return not _defeated and health > 0.0

func get_aim_position() -> Vector3:
	return to_global(Vector3(0.0, aim_height, 0.0))

func take_damage(amount: float) -> void:
	if _defeated or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_defeat()

func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	_traveling = false
	lightning_enabled = false
	_sparks.emitting = false
	if _player != null:
		_player.stop()
	remove_from_group(ENEMY_GROUP)
	defeated.emit()
	queue_free()

func _setup_lightning() -> void:
	_wing_points = [
		Vector3(-1.45, 1.10, 0.30),
		Vector3(1.45, 1.10, 0.30),
		Vector3(-0.85, 0.80, 0.05),
		Vector3(0.85, 0.80, 0.05),
		Vector3(0.0, 0.42, -0.78),
		Vector3(0.0, -0.35, 1.45),
	]
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Lightning"
	mesh_instance.mesh = _lightning_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta(&"selection_ignore", true)
	add_child(mesh_instance)
	_light.visible = lightning_enabled

func _setup_animation() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		return
	for clip in _player.get_animation_list():
		if clip.ends_with("Idle") or clip.ends_with("Flight"):
			_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if clip.ends_with("Idle"):
			_idle_clip = clip
		elif clip.ends_with("Flight"):
			_flight_clip = clip
	if _idle_clip != &"":
		_player.play(_idle_clip)

func _setup_path() -> void:
	_path = _resolve_path()
	if _path == null or _path.curve == null:
		return
	_curve = _path.curve
	_length = _curve.get_baked_length()
	if _length <= 0.0:
		_curve = null
		return
	_distance = 0.0
	_traveling = true
	_place_on_path()
	_sync_animation()

func _resolve_path() -> Path3D:
	if not approach_path.is_empty():
		var configured := get_node_or_null(approach_path)
		if configured is Path3D:
			return configured
		if configured != null:
			var nested := configured.get_node_or_null("EnemyPath") as Path3D
			if nested != null:
				return nested
	return _nearest_approach_path()

func _nearest_approach_path() -> Path3D:
	var candidates: Array[Path3D] = []
	for approach in get_tree().get_nodes_in_group(APPROACH_GROUP):
		if approach is Node3D:
			var path := (approach as Node3D).get_node_or_null("EnemyPath") as Path3D
			if path != null:
				candidates.append(path)
	if candidates.is_empty():
		for node in get_tree().root.find_children("EnemyPath", "Path3D", true, false):
			if node is Path3D:
				candidates.append(node)
	var nearest: Path3D
	var nearest_distance := INF
	for path in candidates:
		if path.curve == null or path.curve.point_count == 0:
			continue
		var local_point := path.to_local(global_position)
		var offset := path.curve.get_closest_offset(local_point)
		var distance := local_point.distance_squared_to(path.curve.sample_baked(offset))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = path
	return nearest

func _process(delta: float) -> void:
	_bob_time += delta * bob_speed
	if _traveling and _curve != null:
		_distance = minf(_length, _distance + travel_speed * delta)
		if _distance >= _length:
			_traveling = false
			_sync_animation()
	_place_on_path()
	_update_lightning(delta)

func _place_on_path() -> void:
	if _curve == null:
		return
	var local_position := _curve.sample_baked(_distance)
	var base_position := _path.global_transform * local_position
	var before := _curve.sample_baked(maxf(_distance - 0.05, 0.0))
	var after := _curve.sample_baked(minf(_distance + 0.05, _length))
	var direction := _path.global_transform.basis * (after - before)
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	global_position = base_position + Vector3(0.0, hover_height + sin(_bob_time) * bob_amplitude, 0.0)
	if flat_direction.length_squared() > 0.000001:
		look_at(global_position + flat_direction.normalized(), Vector3.UP)

func _sync_animation() -> void:
	if _player == null:
		return
	var clip := _flight_clip if _traveling else _idle_clip
	if clip != &"" and _player.current_animation != clip:
		_player.play(clip)

func _update_lightning(delta: float) -> void:
	if not lightning_enabled:
		return
	_lightning_tick -= delta
	_light.light_energy = 0.7 + sin(_bob_time * 3.0) * 0.18
	if _lightning_tick > 0.0:
		return
	_lightning_tick = _rng.randf_range(0.045, 0.085)
	_draw_lightning()

func _draw_lightning() -> void:
	_lightning_mesh.clear_surfaces()
	if _wing_points.is_empty():
		return
	var pairs := [
		[0, 2], [1, 3], [2, 4], [3, 5], [2, 3], [0, 1],
	]
	_lightning_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(2):
		var pair: Array = pairs[_rng.randi_range(0, pairs.size() - 1)]
		var start := _wing_points[pair[0]]
		var end := _wing_points[pair[1]]
		_draw_bolt(start, end)
	_lightning_mesh.surface_end()

func _draw_bolt(start: Vector3, end: Vector3) -> void:
	var direction := (end - start).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up := direction.cross(side).normalized()
	var previous := start
	for i in range(1, LIGHTNING_SEGMENTS + 1):
		var point := start.lerp(end, i / float(LIGHTNING_SEGMENTS))
		if i < LIGHTNING_SEGMENTS:
			point += side * _rng.randf_range(-0.18, 0.18) + up * _rng.randf_range(-0.18, 0.18)
		for layer in range(LIGHTNING_COLORS.size()):
			_lightning_mesh.surface_set_color(LIGHTNING_COLORS[layer])
			for axis in [side, up]:
				var width: Vector3 = axis * (LIGHTNING_WIDTH if layer == 0 else LIGHTNING_CORE_WIDTH)
				for vertex in [previous - width, previous + width, point + width, previous - width, point + width, point - width]:
					_lightning_mesh.surface_add_vertex(vertex)
		previous = point
