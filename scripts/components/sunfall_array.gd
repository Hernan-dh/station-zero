extends Node3D
## Local orbital uplink demonstration; consumers can subscribe to beam_fired.
signal state_changed
signal beam_fired

const ComponentStyle = preload("res://scripts/component_style.gd")
const ComponentSetup = preload("res://scripts/component_setup.gd")

@export var starts_enabled := true
@export var recharge_seconds := 6.0
const DISCHARGE_SECONDS := 1.2
var enabled := true
var charge := 1.0
var discharge := 0.0
var _time := 0.0
var _last_state := {}
var _energy: StandardMaterial3D
var _core_rest_y := 0.0

func _ready() -> void:
	enabled = starts_enabled
	charge = 1.0 if enabled else 0.0
	_core_rest_y = $Model/SolarCore.position.y
	var copies := ComponentSetup.duplicate_matching($Model, func(material: Material) -> bool: return material.resource_name == "SolarEnergy")
	if not copies.is_empty():
		_energy = copies.values()[0] as StandardMaterial3D
	_sync_visuals()
	_publish_state(true)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		charge = 0.0
		discharge = 0.0
	_sync_visuals()
	_publish_state()

func fire_beam() -> void:
	if not enabled or charge < 1.0 or discharge > 0.0: return
	charge = 0.0
	discharge = DISCHARGE_SECONDS
	_sync_visuals()
	beam_fired.emit()
	_publish_state()

func status_text() -> String:
	if not enabled: return "ARRAY OFFLINE"
	if discharge > 0.0: return "ORBITAL BEAM DISCHARGING"
	if charge < 1.0: return "ACCUMULATING SOLAR FLUX"
	return "SOLAR CORE STABLE • BEAM READY"

func _process(delta: float) -> void:
	_time += delta
	$Model/UpperHalo.rotation.y += delta * ComponentStyle.SUNFALL_HALO_SPIN * (1.0 if enabled else 0.0)
	$Model/LowerHalo.rotation.y -= delta * ComponentStyle.SUNFALL_LOWER_HALO_SPIN * (1.0 if enabled else 0.0)
	$Model/SolarCore.rotation.y += delta * ComponentStyle.SUNFALL_CORE_SPIN
	$Model/SolarCore.position.y = _core_rest_y + sin(_time * ComponentStyle.SUNFALL_CORE_BOB_SPEED) * ComponentStyle.SUNFALL_CORE_BOB_AMPLITUDE
	if discharge > 0.0:
		discharge = maxf(0.0, discharge - delta)
	elif enabled:
		charge = move_toward(charge, 1.0, delta / maxf(.1, recharge_seconds))
	_sync_visuals()
	_publish_state()

func _publish_state(force := false) -> void:
	var snapshot := {"status": status_text(), "charge": roundi(charge * 100.0), "enabled": enabled, "discharging": discharge > 0.0}
	if force or snapshot != _last_state:
		_last_state = snapshot
		state_changed.emit()

func _sync_visuals() -> void:
	var power := (.2 + charge * .8) if enabled else .0
	if discharge > 0.0: power = 1.0
	if _energy != null:
		_energy.albedo_color = ComponentStyle.SUNFALL_ENERGY_COLOR * (ComponentStyle.SUNFALL_ENERGY_MIN + power * ComponentStyle.SUNFALL_ENERGY_RANGE)
	$Model/UpperHalo.visible = enabled
	$Model/LowerHalo.visible = enabled
	$SolarLight.light_energy = power * (ComponentStyle.SUNFALL_LIGHT_DISCHARGE if discharge > 0.0 else ComponentStyle.SUNFALL_LIGHT_IDLE)
	$OrbitalBeam.visible = discharge > 0.0
	var width := ComponentStyle.SUNFALL_BEAM_WIDTH + ComponentStyle.SUNFALL_BEAM_PULSE * sin(_time * ComponentStyle.SUNFALL_BEAM_SPEED)
	$OrbitalBeam.scale = Vector3(width,1,width)
