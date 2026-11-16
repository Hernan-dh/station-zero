extends Node3D
## C2 gate activation and resonance. The aperture is visual; no destination
## or unit-transport system exists in the outpost yet.

signal state_changed
signal gate_opened
signal gate_closed
signal resonance_emitted

@export var starts_open := true
@export_range(.1, 20.0) var activation_time := 2.4

var requested_open := true
var aperture := 1.0
var pulse := 0.0
var _vortex: ShaderMaterial
var _crystal: StandardMaterial3D
var _core: StandardMaterial3D
@onready var _surface: MeshInstance3D = $Vortex
@onready var _light: OmniLight3D = $VioletLight
@onready var _pick_shape: CollisionShape3D = $VortexPickBody/Shape

func _ready() -> void:
	requested_open = starts_open
	aperture = 1.0 if starts_open else 0.0
	_vortex = _surface.material_override.duplicate()
	_surface.material_override = _vortex
	_crystal = preload("res://resources/materials/portal_crystal.tres").duplicate()
	_core = preload("res://resources/materials/portal_core.tres").duplicate()
	for part in $Model.find_children("*", "MeshInstance3D", true, false):
		if part.material_override == preload("res://resources/materials/portal_crystal.tres"):
			part.material_override = _crystal
		elif part.material_override == preload("res://resources/materials/portal_core.tres"):
			part.material_override = _core
	_sync_visuals()

func set_open(value: bool) -> void:
	requested_open = value
	if not value: pulse = 0.0
	_sync_visuals()
	state_changed.emit()

func is_open() -> bool:
	return requested_open and aperture >= 1.0

func emit_resonance() -> void:
	if not is_open() or pulse > 0.0: return
	pulse = 1.0
	_sync_visuals()
	resonance_emitted.emit()
	state_changed.emit()

func status_text() -> String:
	if is_open(): return "GATE OPEN • VORTEX STABLE"
	if requested_open: return "OPENING • STABILIZING VORTEX"
	if aperture > 0.0: return "CLOSING • DISSIPATING ENERGY"
	return "GATE DORMANT"

func _process(delta: float) -> void:
	var target := 1.0 if requested_open else 0.0
	if aperture == target and pulse <= 0.0: return
	var previous := aperture
	aperture = move_toward(aperture, target, delta / maxf(activation_time, .1))
	pulse = maxf(0.0, pulse - delta / 1.2)
	_sync_visuals()
	if aperture != previous and aperture == target:
		if requested_open: gate_opened.emit()
		else: gate_closed.emit()
	state_changed.emit()

func _sync_visuals() -> void:
	if _vortex == null: return
	_surface.visible = aperture > .001
	# Match the visible disk; a dormant gate leaves the opening selectable through.
	_pick_shape.disabled = aperture <= .001
	_pick_shape.shape.radius = maxf(.001, 1.649 * aperture)
	_vortex.set_shader_parameter("aperture", aperture)
	_vortex.set_shader_parameter("pulse", pulse)
	_light.light_energy = aperture * (1.8 + pulse * 1.8)
	_crystal.emission_enabled = aperture > 0.0
	_crystal.emission_energy_multiplier = aperture * (1.8 + pulse * 2.0)
	_crystal.albedo_color = Color("8c31db") * (.22 + .78 * aperture)
	_core.albedo_color = Color("e6a1ff") * (.12 + .88 * aperture)
	_core.emission_enabled = aperture > 0.0

