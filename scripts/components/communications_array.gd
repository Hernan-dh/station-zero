extends Node3D
## Owns pointing state and sweep. Manual bearing changes stop the sweep.

signal state_changed

const ComponentStyle = preload("res://scripts/component_style.gd")

const MIN_BEARING := -180.0
const MAX_BEARING := 180.0
const MIN_ELEVATION := 0.0
const MAX_ELEVATION := 85.0

var _bearing := ComponentStyle.DISH_INITIAL_BEARING
var _elevation := ComponentStyle.DISH_INITIAL_ELEVATION
var _sweeping := false
var _last_state := {}
@onready var _base: Node3D = $Model/AzimuthBearing
@onready var _dish: Node3D = $Model/AzimuthBearing/ElevationHinge

func _ready() -> void:
	_base.rotation.y = deg_to_rad(_bearing)
	_dish.rotation.x = -deg_to_rad(_elevation)
	_publish_state(true)

func set_bearing(value: float) -> void:
	_sweeping = false
	_bearing = clampf(value, MIN_BEARING, MAX_BEARING)
	_base.rotation.y = deg_to_rad(_bearing)
	_publish_state()

func get_bearing() -> float:
	return _bearing

func set_elevation(value: float) -> void:
	_elevation = clampf(value, MIN_ELEVATION, MAX_ELEVATION)
	_dish.rotation.x = -deg_to_rad(_elevation)
	_publish_state()

func get_elevation() -> float:
	return _elevation

func set_sweeping(enabled: bool) -> void:
	_sweeping = enabled
	_publish_state()

func is_sweeping() -> bool:
	return _sweeping

func _process(delta: float) -> void:
	if _sweeping:
		_bearing = wrapf(_bearing + delta * ComponentStyle.DISH_SWEEP_SPEED, MIN_BEARING, MAX_BEARING)
		_base.rotation.y = deg_to_rad(_bearing)
		_publish_state()

func _publish_state(force := false) -> void:
	# Only the values the panel displays; the sweep no longer emits every frame.
	var snapshot := {"bearing": roundi(_bearing), "elevation": roundi(_elevation), "sweeping": _sweeping}
	if force or snapshot != _last_state:
		_last_state = snapshot
		state_changed.emit()
