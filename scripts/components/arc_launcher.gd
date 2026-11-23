extends Node3D
## Targets Node3D members of "enemies" exposing take_damage(amount).
## Optional is_alive() and get_aim_position() allow integration with enemy actors.

signal state_changed
signal fired(endpoint: Vector3)

const ComponentStyle = preload("res://scripts/component_style.gd")
const ComponentSetup = preload("res://scripts/component_setup.gd")
const ARC_CYAN = preload("res://resources/materials/arc_cyan.tres")
const ARC_WHITE = preload("res://resources/materials/arc_white.tres")

@export var attack_range := 9.0
@export var damage := 30.0
@export var recharge_time := 1.8
@export var turn_speed := 100.0

const MIN_BEARING := -180.0
const MAX_BEARING := 180.0

var powered := true
var automatic := true
var charge := 1.0
var bearing := 90.0
var _flash_time := 0.0
var _effect_tick := 0.0
var _endpoint := Vector3.ZERO
var _target: Node3D
var _last_state := {}
var _energy: StandardMaterial3D
var _core: StandardMaterial3D
var _arc_mesh := ImmediateMesh.new()
@onready var _arc := MeshInstance3D.new()
var _rng := RandomNumberGenerator.new()
@onready var _azimuth: Node3D = $Model/Azimuth
@onready var _elevation: Node3D = $Model/Azimuth/Elevation
@onready var _recoil: Node3D = $Model/Azimuth/Elevation/Recoil
@onready var _muzzle: Marker3D = $Model/Azimuth/Elevation/Recoil/Muzzle

func _ready() -> void:
	_rng.randomize()
	var copies := ComponentSetup.duplicate_materials($Model, [ARC_CYAN, ARC_WHITE])
	_energy = copies[ARC_CYAN] as StandardMaterial3D
	_core = copies[ARC_WHITE] as StandardMaterial3D
	_arc.name = "Discharge"
	_arc.mesh = _arc_mesh
	var arc_material: StandardMaterial3D = ARC_WHITE.duplicate()
	arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc_material.vertex_color_use_as_albedo = true
	_arc.material_override = arc_material
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc)
	_azimuth.rotation.y = deg_to_rad(bearing)
	_update_energy()
	_publish_state(true)

func set_powered(value: bool) -> void:
	powered = value
	if not powered:
		_target = null
		_flash_time = 0.0
		_arc_mesh.clear_surfaces()
	_update_energy()
	_publish_state()

func set_automatic(value: bool) -> void:
	automatic = value
	_target = null
	_publish_state()

func set_bearing(value: float) -> void:
	automatic = false
	_target = null
	bearing = wrapf(value, MIN_BEARING, MAX_BEARING)
	_azimuth.rotation.y = deg_to_rad(bearing)
	_elevation.rotation.x = 0.0
	_publish_state()

func can_fire() -> bool:
	return powered and charge >= 1.0

func test_fire() -> void:
	if can_fire():
		# A harmless discharge in the current direction; never damages an unseen target.
		_discharge(_muzzle.global_position + _muzzle.global_basis.z * attack_range)

func status_text() -> String:
	if not powered:
		return "POWER OFF"
	if charge < 1.0:
		return "RECHARGING  %02d%%" % roundi(charge * 100.0)
	return "AUTO • WATCHING" if automatic else "MANUAL • READY"

func _physics_process(delta: float) -> void:
	if powered:
		charge = minf(1.0, charge + delta / maxf(recharge_time, ComponentStyle.ARC_MIN_CHARGE))
		if automatic:
			_target = _nearest_target()
			if is_instance_valid(_target):
				var point := _aim_position(_target)
				var local_point := to_local(point) - _azimuth.position
				var desired := atan2(local_point.x, local_point.z)
				_azimuth.rotation.y = rotate_toward(_azimuth.rotation.y, desired, deg_to_rad(turn_speed) * delta)
				bearing = rad_to_deg(_azimuth.rotation.y)
				var aim: Vector3 = _azimuth.to_local(point) - _elevation.position
				_elevation.rotation.x = clampf(-atan2(aim.y, Vector2(aim.x, aim.z).length()), ComponentStyle.ARC_ELEVATION_MIN, ComponentStyle.ARC_ELEVATION_MAX)
				if can_fire() and absf(angle_difference(_azimuth.rotation.y, desired)) < ComponentStyle.ARC_FIRE_TOLERANCE:
					_discharge(point)
					_target.take_damage(damage)
	_update_energy()
	_publish_state()

func _nearest_target() -> Node3D:
	var nearest: Node3D
	var best := attack_range * attack_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D or candidate.is_queued_for_deletion() or not candidate.has_method("take_damage"):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var point := _aim_position(candidate)
		var offset := to_local(point) - _azimuth.position - _elevation.position
		var pitch := atan2(offset.y, Vector2(offset.x, offset.z).length())
		if pitch > -ComponentStyle.ARC_ELEVATION_MIN or pitch < -ComponentStyle.ARC_ELEVATION_MAX:
			continue
		var distance := _muzzle.global_position.distance_squared_to(point)
		if distance <= best:
			best = distance
			nearest = candidate
	return nearest

func _aim_position(target: Node3D) -> Vector3:
	if target.has_method("get_aim_position"):
		return target.get_aim_position()
	return target.global_position

func _discharge(endpoint: Vector3) -> void:
	charge = 0.0
	_endpoint = endpoint
	_flash_time = ComponentStyle.ARC_FLASH_TIME
	_effect_tick = 0.0
	_draw_arc()
	fired.emit(endpoint)
	_publish_state()

func _publish_state(force := false) -> void:
	# Emit only when the panel's readable state changes, never on every tick.
	var snapshot := {"status": status_text(), "bearing": roundi(fposmod(bearing, 360.0)), "powered": powered, "automatic": automatic, "ready": can_fire()}
	if force or snapshot != _last_state:
		_last_state = snapshot
		state_changed.emit()

func _process(delta: float) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	_recoil.position.z = -ComponentStyle.ARC_RECOIL * (_flash_time / ComponentStyle.ARC_FLASH_TIME)
	if _flash_time > 0.0:
		_effect_tick -= delta
		if _effect_tick <= 0.0:
			_draw_arc()
			_effect_tick = ComponentStyle.ARC_EFFECT_INTERVAL
	elif _arc_mesh.get_surface_count() > 0:
		_arc_mesh.clear_surfaces()

func _update_energy() -> void:
	var intensity := (ComponentStyle.ARC_INTENSITY_MIN + charge * ComponentStyle.ARC_INTENSITY_RANGE) if powered else ComponentStyle.ARC_OFF_INTENSITY
	_energy.albedo_color = ComponentStyle.ARC_ENERGY_COLOR * intensity
	_core.albedo_color = ComponentStyle.ARC_CORE_COLOR * intensity
	_energy.emission_enabled = powered
	_core.emission_enabled = powered

func _draw_arc() -> void:
	_arc_mesh.clear_surfaces()
	var start := to_local(_muzzle.global_position)
	var end := to_local(_endpoint)
	var direction := (end - start).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up := direction.cross(side).normalized()
	# Crossed ribbons remain visible from every camera angle in Compatibility.
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := start
	for i in range(1, ComponentStyle.ARC_SEGMENTS + 1):
		var point := start.lerp(end, i / float(ComponentStyle.ARC_SEGMENTS))
		if i < ComponentStyle.ARC_SEGMENTS:
			point += side * _rng.randf_range(-ComponentStyle.ARC_JITTER, ComponentStyle.ARC_JITTER) + up * _rng.randf_range(-ComponentStyle.ARC_JITTER, ComponentStyle.ARC_JITTER)
		for layer in [0, 1]:
			_arc_mesh.surface_set_color(ComponentStyle.ARC_LAYER_COLORS[layer])
			for axis in [side, up]:
				var width: Vector3 = axis * (ComponentStyle.ARC_WIDTH if layer == 0 else ComponentStyle.ARC_CORE_WIDTH)
				for vertex in [previous - width, previous + width, point + width, previous - width, point + width, point - width]:
					_arc_mesh.surface_add_vertex(vertex)
		previous = point
	_arc_mesh.surface_end()
