extends Node3D
## C2 gate activation and resonance. The aperture is visual; no destination
## or unit-transport system exists in the outpost yet.

signal state_changed
signal gate_opened
signal gate_closed
signal resonance_emitted

const ComponentStyle = preload("res://scripts/component_style.gd")
const ComponentSetup = preload("res://scripts/component_setup.gd")
const PORTAL_CRYSTAL = preload("res://resources/materials/portal_crystal.tres")
const PORTAL_CORE = preload("res://resources/materials/portal_core.tres")

@export var starts_open := true
@export_range(.1, 20.0) var activation_time := 2.4

var requested_open := true
var aperture := 1.0
var pulse := 0.0
var _last_state := {}
var _vortex: ShaderMaterial
var _crystal: StandardMaterial3D
var _core: StandardMaterial3D
@onready var _surface: MeshInstance3D = $Vortex
@onready var _light: OmniLight3D = $VioletLight
@onready var _pick_shape: CollisionShape3D = $VortexPickBody/Shape
var _pick_radius := 1.0

func _ready() -> void:
	requested_open = starts_open
	aperture = 1.0 if starts_open else 0.0
	_pick_radius = _pick_shape.shape.radius
	_vortex = _surface.material_override.duplicate()
	_surface.material_override = _vortex
	var copies := ComponentSetup.duplicate_materials($Model, [PORTAL_CRYSTAL, PORTAL_CORE])
	_crystal = copies[PORTAL_CRYSTAL] as StandardMaterial3D
	_core = copies[PORTAL_CORE] as StandardMaterial3D
	_sync_visuals()
	_publish_state(true)

func set_open(value: bool) -> void:
	requested_open = value
	if not value: pulse = 0.0
	_sync_visuals()
	_publish_state()

func is_open() -> bool:
	return requested_open and aperture >= 1.0

func emit_resonance() -> void:
	if not is_open() or pulse > 0.0: return
	pulse = 1.0
	_sync_visuals()
	resonance_emitted.emit()
	_publish_state()

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
	pulse = maxf(0.0, pulse - delta / ComponentStyle.PORTAL_PULSE_DECAY)
	_sync_visuals()
	if aperture != previous and aperture == target:
		if requested_open: gate_opened.emit()
		else: gate_closed.emit()
	_publish_state()

func _publish_state(force := false) -> void:
	var snapshot := {"status": status_text(), "aperture": roundi(aperture * 100.0), "requested_open": requested_open, "open": is_open(), "pulsing": pulse > 0.0}
	if force or snapshot != _last_state:
		_last_state = snapshot
		state_changed.emit()

func _sync_visuals() -> void:
	if _vortex == null: return
	_surface.visible = aperture > ComponentStyle.PORTAL_APERTURE_EPSILON
	# Match the visible disk; a dormant gate leaves the opening selectable through.
	_pick_shape.disabled = aperture <= ComponentStyle.PORTAL_APERTURE_EPSILON
	_pick_shape.shape.radius = maxf(ComponentStyle.PORTAL_APERTURE_EPSILON, _pick_radius * aperture)
	_vortex.set_shader_parameter("aperture", aperture)
	_vortex.set_shader_parameter("pulse", pulse)
	_light.light_energy = aperture * (ComponentStyle.PORTAL_LIGHT_BASE + pulse * ComponentStyle.PORTAL_LIGHT_PULSE)
	_crystal.emission_enabled = aperture > 0.0
	_crystal.emission_energy_multiplier = aperture * (ComponentStyle.PORTAL_CRYSTAL_EMISSION_BASE + pulse * ComponentStyle.PORTAL_CRYSTAL_EMISSION_PULSE)
	_crystal.albedo_color = ComponentStyle.PORTAL_CRYSTAL_COLOR * (ComponentStyle.PORTAL_CRYSTAL_MIN + ComponentStyle.PORTAL_CRYSTAL_RANGE * aperture)
	_core.albedo_color = ComponentStyle.PORTAL_CORE_COLOR * (ComponentStyle.PORTAL_CORE_MIN + ComponentStyle.PORTAL_CORE_RANGE * aperture)
	_core.emission_enabled = aperture > 0.0

