extends Node3D
## A local resonance relay. Signals allow future network consumers to subscribe.
signal state_changed
signal resonance_emitted

const ComponentStyle = preload("res://scripts/component_style.gd")
const ComponentSetup = preload("res://scripts/component_setup.gd")

@export var starts_enabled := true
var enabled := true
var attunement := 1.0
var pulse := 0.0
var _time := 0.0
var _last_state := {}
var _gems: Array[ShaderMaterial] = []
var _crystal_rest_y := 0.0
var _satellite_rest_y := 0.0
@onready var _crystal: Node3D = $Model/SuspendedCrystal
@onready var _satellites: Node3D = $Model/SatelliteShards
@onready var _orbit: Node3D = $Model/GoldenOrbit

func _ready() -> void:
	enabled = starts_enabled
	attunement = 1.0 if enabled else 0.0
	_crystal_rest_y = _crystal.position.y
	_satellite_rest_y = _satellites.position.y
	var copies := ComponentSetup.duplicate_matching($Model, func(material: Material) -> bool: return material is ShaderMaterial)
	for material in copies.values():
		_gems.append(material as ShaderMaterial)
	_sync_visuals()
	_publish_state(true)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: pulse = 0.0
	_sync_visuals()
	_publish_state()

func emit_resonance() -> void:
	if not enabled or attunement < 1.0 or pulse > 0.0: return
	pulse = 1.0
	resonance_emitted.emit()
	_sync_visuals()
	_publish_state()

func status_text() -> String:
	if not enabled: return "RELAY DORMANT"
	if attunement < 1.0: return "ATTUNING CRYSTAL LATTICE"
	if pulse > 0.0: return "RESONANCE TRANSMITTING"
	return "LATTICE STABLE • RELAY ONLINE"

func _process(delta: float) -> void:
	_time += delta
	_crystal.position.y = _crystal_rest_y + sin(_time * ComponentStyle.RELAY_CRYSTAL_BOB_SPEED) * ComponentStyle.RELAY_CRYSTAL_BOB_AMPLITUDE
	_crystal.rotation.y += delta * ComponentStyle.RELAY_CRYSTAL_SPIN * attunement
	_satellites.rotation.y -= delta * ComponentStyle.RELAY_SATELLITE_SPIN * attunement
	_satellites.position.y = _satellite_rest_y + sin(_time * ComponentStyle.RELAY_SATELLITE_BOB_SPEED + ComponentStyle.RELAY_SATELLITE_PHASE) * ComponentStyle.RELAY_SATELLITE_BOB_AMPLITUDE
	_orbit.rotation.y += delta * ComponentStyle.RELAY_ORBIT_SPIN * attunement
	attunement = move_toward(attunement, 1.0 if enabled else 0.0, delta / ComponentStyle.RELAY_ATTUNE_TIME)
	pulse = maxf(0.0, pulse - delta / ComponentStyle.RELAY_PULSE_TIME)
	_sync_visuals()
	_publish_state()

func _publish_state(force := false) -> void:
	var snapshot := {"status": status_text(), "attunement": roundi(attunement * 100.0), "enabled": enabled, "pulsing": pulse > 0.0}
	if force or snapshot != _last_state:
		_last_state = snapshot
		state_changed.emit()

func _sync_visuals() -> void:
	for gem in _gems:
		gem.set_shader_parameter("power", attunement)
		gem.set_shader_parameter("pulse", pulse)
	$AetherLight.light_energy = attunement * (ComponentStyle.RELAY_LIGHT_BASE + pulse * ComponentStyle.RELAY_LIGHT_PULSE)
	_orbit.visible = attunement > ComponentStyle.RELAY_WAVE_VISIBLE
	$ResonanceWave.visible = pulse > 0.0
	var radius := ComponentStyle.RELAY_WAVE_MIN_RADIUS + (1.0 - pulse) * ComponentStyle.RELAY_WAVE_RADIUS
	$ResonanceWave.scale = Vector3(radius, 1.0, radius)
	$ResonanceWave.position.y = ComponentStyle.RELAY_WAVE_HEIGHT + (1.0 - pulse) * ComponentStyle.RELAY_WAVE_TRAVEL
