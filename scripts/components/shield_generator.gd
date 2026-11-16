extends Node3D
## A2 shield emitter. Combat callers pass a hit to absorb_damage() and apply
## its returned overflow to the protected object. Positions are in world space.

signal state_changed
signal shield_hit(absorbed: float, world_position: Vector3)
signal shield_collapsed
signal shield_restored

@export_range(1.0, 10000.0) var capacity := 240.0
@export_range(0.1, 1000.0) var recharge_rate := 30.0
@export_range(0.0, 60.0) var recharge_delay := 3.0
@export_range(0.0, 60.0) var collapse_delay := 6.0
@export_range(0.5, 20.0) var shield_radius := 2.2

var powered := true
var charge := 0.0
var overloaded := false
var _recharge_wait := 0.0
var _impact_age := 10.0
var _field: ShaderMaterial
var _energy: StandardMaterial3D
var _core: StandardMaterial3D
@onready var _dome: MeshInstance3D = $ShieldField/Dome
@onready var _boundary: MeshInstance3D = $ShieldField/Boundary

func _ready() -> void:
	charge = capacity
	_field = _dome.material_override.duplicate()
	_dome.material_override = _field
	$ShieldField.scale = Vector3.ONE * shield_radius
	_energy = preload("res://resources/materials/arc_cyan.tres").duplicate()
	_core = preload("res://resources/materials/arc_white.tres").duplicate()
	for part in $Model.find_children("*", "MeshInstance3D", true, false):
		if part.material_override == preload("res://resources/materials/arc_cyan.tres"):
			part.material_override = _energy
		elif part.material_override == preload("res://resources/materials/arc_white.tres"):
			part.material_override = _core
	_boundary.material_override = _energy
	_sync_visuals()
	state_changed.emit()

func is_active() -> bool:
	return powered and not overloaded and charge > 0.0

func protects_point(world_position: Vector3) -> bool:
	var point: Vector3 = $ShieldField.to_local(world_position)
	return is_active() and point.y >= -0.01 and point.length_squared() <= 1.02

func absorb_damage(amount: float, world_position: Vector3) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	if not protects_point(world_position):
		return amount
	var absorbed := minf(amount, charge)
	charge = maxf(0.0, charge - absorbed)
	_recharge_wait = recharge_delay
	_impact_age = 0.0
	var point: Vector3 = $ShieldField.to_local(world_position)
	# Project a hit inside the volume onto the visible shell.
	if point.length_squared() < 0.001: point = Vector3.UP
	_field.set_shader_parameter("impact_position", point.normalized())
	if charge <= 0.0:
		overloaded = true
		_recharge_wait = collapse_delay
		shield_collapsed.emit()
	_sync_visuals()
	shield_hit.emit(absorbed, world_position)
	state_changed.emit()
	return amount - absorbed

func test_impact() -> void:
	if not is_active(): return
	var direction := Vector3(.35, .45, .82).normalized()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		direction = $ShieldField.to_local(camera.global_position).normalized()
		direction.y = maxf(.25, direction.y)
		direction = direction.normalized()
	absorb_damage(60.0, $ShieldField.to_global(direction * .99))

func set_powered(value: bool) -> void:
	powered = value
	if not powered: _impact_age = 10.0
	_sync_visuals()
	state_changed.emit()

func status_text() -> String:
	if not powered: return "POWER OFF • FIELD DOWN"
	if overloaded:
		if _recharge_wait > 0: return "OVERLOAD • RESTART IN %.1f s" % _recharge_wait
		return "REBUILDING • RESTORES AT 25%"
	if _recharge_wait > 0: return "HOLDING • RECHARGE IN %.1f s" % _recharge_wait
	if charge < capacity: return "FIELD ONLINE • RECHARGING"
	return "FIELD ONLINE • FULL CHARGE"

func _physics_process(delta: float) -> void:
	if not powered or (charge >= capacity and _recharge_wait <= 0.0): return
	var recharge_delta := maxf(0.0, delta - _recharge_wait)
	_recharge_wait = maxf(0.0, _recharge_wait - delta)
	charge = minf(capacity, charge + recharge_rate * recharge_delta)
	if overloaded and charge >= capacity * .25:
		overloaded = false
		shield_restored.emit()
	_sync_visuals()
	state_changed.emit()

func _process(delta: float) -> void:
	if _impact_age < 10.0:
		_impact_age = minf(10.0, _impact_age + delta)
		_sync_visuals()

func _sync_visuals() -> void:
	if _field == null: return
	var active := is_active()
	var collapse_flash := powered and overloaded and _impact_age < .55
	_dome.visible = active or collapse_flash
	_boundary.visible = active
	_field.set_shader_parameter("charge", charge / capacity)
	_field.set_shader_parameter("strength", 1.0 if active else maxf(0.0, 1.0 - _impact_age / .55))
	_field.set_shader_parameter("impact_age", _impact_age)
	var intensity := (0.3 + 0.7 * charge / capacity) if powered else .04
	_energy.albedo_color = Color("20bffa") * intensity
	_core.albedo_color = Color("bbf4ff") * intensity
	_energy.emission_enabled = powered
	_core.emission_enabled = powered
