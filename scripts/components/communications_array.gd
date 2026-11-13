extends Node3D
## Owns pointing state and sweep. Manual bearing changes stop the sweep.

signal state_changed

var _bearing := 35.0
var _elevation := 35.0
var _sweeping := false
@onready var _base: Node3D = $Model/AzimuthBearing
@onready var _dish: Node3D = $Model/AzimuthBearing/ElevationHinge

func _ready() -> void:
	_base.rotation.y = deg_to_rad(_bearing)
	_dish.rotation.x = -deg_to_rad(_elevation)

func set_bearing(value: float) -> void:
	_sweeping = false
	_bearing = clampf(value, -180.0, 180.0)
	_base.rotation.y = deg_to_rad(_bearing)
	state_changed.emit()

func get_bearing() -> float:
	return _bearing

func set_elevation(value: float) -> void:
	_elevation = clampf(value, 0.0, 85.0)
	_dish.rotation.x = -deg_to_rad(_elevation)
	state_changed.emit()

func get_elevation() -> float:
	return _elevation

func set_sweeping(enabled: bool) -> void:
	_sweeping = enabled
	state_changed.emit()

func is_sweeping() -> bool:
	return _sweeping

func _process(delta: float) -> void:
	if _sweeping:
		_bearing = wrapf(_bearing + delta * 12.0, -180.0, 180.0)
		_base.rotation.y = deg_to_rad(_bearing)
		state_changed.emit()
