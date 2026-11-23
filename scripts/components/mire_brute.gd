extends Node3D
## Damageable Mire Brute that moves along an existing enemy approach.
## The Arc Launcher finds it through the "enemies" group and calls take_damage().

signal health_changed(current: float, maximum: float)
signal defeated

const APPROACH_GROUP := &"enemy_approaches"
const ENEMY_GROUP := &"enemies"

@export var vapor_enabled := true:
	set(value):
		vapor_enabled = value
		if is_node_ready():
			$ToxicVapor.emitting = value
@export var approach_path: NodePath
@export_range(0.1, 20.0) var travel_speed := 2.5
@export var max_health := 100.0
@export var health := 100.0
@export var aim_height := 1.7

var _player: AnimationPlayer
var _idle_clip := &""
var _lumber_clip := &""
var _path: Path3D
var _curve: Curve3D
var _length := 0.0
var _distance := 0.0
var _traveling := false
var _defeated := false

func _ready() -> void:
	max_health = maxf(max_health, 1.0)
	health = clampf(health, 0.0, max_health)
	add_to_group(ENEMY_GROUP)
	$ToxicVapor.emitting = vapor_enabled
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
	vapor_enabled = false
	if _player != null:
		_player.stop()
	remove_from_group(ENEMY_GROUP)
	defeated.emit()
	queue_free()

func _setup_animation() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		return
	for clip in _player.get_animation_list():
		if clip.ends_with("Idle") or clip.ends_with("Lumber"):
			_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if clip.ends_with("Idle"):
			_idle_clip = clip
		elif clip.ends_with("Lumber"):
			_lumber_clip = clip
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
	if not _traveling or _curve == null:
		return
	_distance = minf(_length, _distance + travel_speed * delta)
	_place_on_path()
	if _distance >= _length:
		_traveling = false
		_sync_animation()

func _place_on_path() -> void:
	var local_position := _curve.sample_baked(_distance)
	global_position = _path.global_transform * local_position
	var before := _curve.sample_baked(maxf(_distance - 0.05, 0.0))
	var after := _curve.sample_baked(minf(_distance + 0.05, _length))
	var direction := _path.global_transform.basis * (after - before)
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() > 0.000001:
		look_at(global_position + flat_direction.normalized(), Vector3.UP)

func _sync_animation() -> void:
	if _player == null:
		return
	var clip := _lumber_clip if _traveling else _idle_clip
	if clip != &"" and _player.current_animation != clip:
		_player.play(clip)
