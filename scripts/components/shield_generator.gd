extends Node3D
## A2 shield emitter. Combat callers pass a hit to absorb_damage() and apply
## its returned overflow to the protected object. Positions are in world space.

signal state_changed
signal shield_hit(absorbed: float, world_position: Vector3)
signal shield_collapsed
signal shield_restored

const ComponentStyle = preload("res://scripts/component_style.gd")
const ComponentSetup = preload("res://scripts/component_setup.gd")
const ARC_CYAN = preload("res://resources/materials/arc_cyan.tres")
const ARC_WHITE = preload("res://resources/materials/arc_white.tres")

@export_range(1.0, 10000.0) var capacity := 240.0
@export_range(0.1, 1000.0) var recharge_rate := 30.0
@export_range(0.0, 60.0) var recharge_delay := 3.0
@export_range(0.0, 60.0) var collapse_delay := 6.0
@export_range(0.5, 20.0) var shield_radius := 2.2

var powered := true
var charge := 0.0
var overloaded := false
var _recharge_wait := 0.0
var _impact_age := ComponentStyle.SHIELD_IMPACT_DECAY
var _last_state := {}
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
	var copies := ComponentSetup.duplicate_materials($Model, [ARC_CYAN, ARC_WHITE])
	_energy = copies[ARC_CYAN] as StandardMaterial3D
	_core = copies[ARC_WHITE] as StandardMaterial3D
	_boundary.material_override = _energy
	_sync_visuals()
	_publish_state(true)

func is_active() -> bool:
	return powered and not overloaded and charge > 0.0

func protects_point(world_position: Vector3) -> bool:
	var point: Vector3 = $ShieldField.to_local(world_position)
	return is_active() and point.y >= ComponentStyle.SHIELD_PROTECTION_BOTTOM and point.length_squared() <= ComponentStyle.SHIELD_PROTECTION_RADIUS

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
	if point.length_squared() < ComponentStyle.SHIELD_SURFACE_EPSILON: point = Vector3.UP
	_field.set_shader_parameter("impact_position", point.normalized())
	if charge <= 0.0:
		overloaded = true
		_recharge_wait = collapse_delay
		shield_collapsed.emit()
	_sync_visuals()
	shield_hit.emit(absorbed, world_position)
	_publish_state()
	return amount - absorbed

func test_impact() -> void:
	if not is_active(): return
	var direction := ComponentStyle.SHIELD_IMPACT_VECTOR.normalized()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		direction = $ShieldField.to_local(camera.global_position).normalized()
		direction.y = maxf(ComponentStyle.SHIELD_IMPACT_MIN_HEIGHT, direction.y)
		direction = direction.normalized()
	absorb_damage(ComponentStyle.SHIELD_IMPACT_AMOUNT, $ShieldField.to_global(direction * ComponentStyle.SHIELD_IMPACT_RADIUS))

func set_powered(value: bool) -> void:
	powered = value
	if not powered: _impact_age = ComponentStyle.SHIELD_IMPACT_DECAY
	_sync_visuals()
	_publish_state()

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
	if overloaded and charge >= capacity * ComponentStyle.SHIELD_RESTORE_FRACTION:
		overloaded = false
		shield_restored.emit()
	_sync_visuals()
	_publish_state()

func _process(delta: float) -> void:
	if _impact_age < ComponentStyle.SHIELD_IMPACT_DECAY:
		_impact_age = minf(ComponentStyle.SHIELD_IMPACT_DECAY, _impact_age + delta)
		_sync_visuals()

func _publish_state(force := false) -> void:
	# Status includes the recharge countdown; charge is shown as an integer.
	var snapshot := {"status": status_text(), "charge": roundi(charge), "powered": powered, "overloaded": overloaded, "active": is_active()}
	if force or snapshot != _last_state:
		_last_state = snapshot
		state_changed.emit()

func _sync_visuals() -> void:
	if _field == null: return
	var active := is_active()
	var collapse_flash := powered and overloaded and _impact_age < ComponentStyle.SHIELD_COLLAPSE_FLASH
	_dome.visible = active or collapse_flash
	_boundary.visible = active
	_field.set_shader_parameter("charge", charge / capacity)
	_field.set_shader_parameter("strength", 1.0 if active else maxf(0.0, 1.0 - _impact_age / ComponentStyle.SHIELD_COLLAPSE_FLASH))
	_field.set_shader_parameter("impact_age", _impact_age)
	var intensity := (ComponentStyle.SHIELD_INTENSITY_MIN + ComponentStyle.SHIELD_INTENSITY_RANGE * charge / capacity) if powered else ComponentStyle.SHIELD_OFF_INTENSITY
	_energy.albedo_color = ComponentStyle.SHIELD_ENERGY_COLOR * intensity
	_core.albedo_color = ComponentStyle.SHIELD_CORE_COLOR * intensity
	_energy.emission_enabled = powered
	_core.emission_enabled = powered
