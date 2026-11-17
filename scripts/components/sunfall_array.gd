extends Node3D
## Local orbital uplink demonstration; consumers can subscribe to beam_fired.
signal state_changed
signal beam_fired

@export var starts_enabled := true
@export var recharge_seconds := 6.0
const DISCHARGE_SECONDS := 1.2
var enabled := true
var charge := 1.0
var discharge := 0.0
var _time := 0.0
var _energy: StandardMaterial3D

func _ready() -> void:
	enabled = starts_enabled
	charge = 1.0 if enabled else 0.0
	for part in $Model.find_children("*", "MeshInstance3D", true, false):
		if part.material_override != null and part.material_override.resource_name == "SolarEnergy":
			if _energy == null: _energy = part.material_override.duplicate()
			part.material_override = _energy
	_sync_visuals()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		charge = 0.0
		discharge = 0.0
	_sync_visuals()
	state_changed.emit()

func fire_beam() -> void:
	if not enabled or charge < 1.0 or discharge > 0.0: return
	charge = 0.0
	discharge = DISCHARGE_SECONDS
	_sync_visuals()
	beam_fired.emit()
	state_changed.emit()

func status_text() -> String:
	if not enabled: return "ARRAY OFFLINE"
	if discharge > 0.0: return "ORBITAL BEAM DISCHARGING"
	if charge < 1.0: return "ACCUMULATING SOLAR FLUX"
	return "SOLAR CORE STABLE • BEAM READY"

func _process(delta: float) -> void:
	_time += delta
	$Model/UpperHalo.rotation.y += delta * .22 * (1.0 if enabled else 0.0)
	$Model/LowerHalo.rotation.y -= delta * .37 * (1.0 if enabled else 0.0)
	$Model/SolarCore.rotation.y += delta * .18
	$Model/SolarCore.position.y = 4.16 + sin(_time * 1.6) * .045
	var previous := charge
	var previous_discharge := discharge
	if discharge > 0.0:
		discharge = maxf(0.0, discharge - delta)
	elif enabled:
		charge = move_toward(charge, 1.0, delta / maxf(.1, recharge_seconds))
	_sync_visuals()
	if previous != charge or previous_discharge != discharge: state_changed.emit()

func _sync_visuals() -> void:
	var power := (.2 + charge * .8) if enabled else .0
	if discharge > 0.0: power = 1.0
	if _energy != null:
		_energy.albedo_color = Color("ffe8a5") * (.12 + power * .88)
	$Model/UpperHalo.visible = enabled
	$Model/LowerHalo.visible = enabled
	$SolarLight.light_energy = power * (2.5 if discharge > 0.0 else .8)
	$OrbitalBeam.visible = discharge > 0.0
	var width := .7 + .3 * sin(_time * 40.0)
	$OrbitalBeam.scale = Vector3(width,1,width)
