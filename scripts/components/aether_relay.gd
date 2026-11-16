extends Node3D
## A local resonance relay. Signals allow future network consumers to subscribe.
signal state_changed
signal resonance_emitted

@export var starts_enabled := true
var enabled := true
var attunement := 1.0
var pulse := 0.0
var _time := 0.0
var _gems: Array[ShaderMaterial] = []
@onready var _crystal: Node3D = $Model/SuspendedCrystal
@onready var _satellites: Node3D = $Model/SatelliteShards
@onready var _orbit: Node3D = $Model/GoldenOrbit

func _ready() -> void:
	enabled = starts_enabled
	attunement = 1.0 if enabled else 0.0
	var materials := {}
	for part in $Model.find_children("*", "MeshInstance3D", true, false):
		if part.material_override is ShaderMaterial:
			var original: ShaderMaterial = part.material_override
			if not materials.has(original):
				materials[original] = original.duplicate()
				_gems.append(materials[original])
			part.material_override = materials[original]
	_sync_visuals()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: pulse = 0.0
	state_changed.emit()

func emit_resonance() -> void:
	if not enabled or attunement < 1.0 or pulse > 0.0: return
	pulse = 1.0
	resonance_emitted.emit()
	_sync_visuals()
	state_changed.emit()

func status_text() -> String:
	if not enabled: return "RELAY DORMANT"
	if attunement < 1.0: return "ATTUNING CRYSTAL LATTICE"
	if pulse > 0.0: return "RESONANCE TRANSMITTING"
	return "LATTICE STABLE • RELAY ONLINE"

func _process(delta: float) -> void:
	_time += delta
	_crystal.position.y = 3.1 + sin(_time * 1.3) * .12
	_crystal.rotation.y += delta * .12 * attunement
	_satellites.rotation.y -= delta * .17 * attunement
	_satellites.position.y = 3.1 + sin(_time * 1.3 + .7) * .09
	_orbit.rotation.y += delta * .2 * attunement
	var previous := attunement
	var previous_pulse := pulse
	attunement = move_toward(attunement, 1.0 if enabled else 0.0, delta / 2.5)
	pulse = maxf(0.0, pulse - delta / 2.0)
	_sync_visuals()
	if previous != attunement or previous_pulse != pulse: state_changed.emit()

func _sync_visuals() -> void:
	for gem in _gems:
		gem.set_shader_parameter("power", attunement)
		gem.set_shader_parameter("pulse", pulse)
	$AetherLight.light_energy = attunement * (1.1 + pulse * 2.0)
	_orbit.visible = attunement > .05
	$ResonanceWave.visible = pulse > 0.0
	var radius := 1.0 + (1.0 - pulse) * 5.0
	$ResonanceWave.scale = Vector3(radius, 1.0, radius)
	$ResonanceWave.position.y = 1.25 + (1.0 - pulse) * .5
