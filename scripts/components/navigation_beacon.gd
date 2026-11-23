extends Node3D
## Owns beacon emission and animation; UI observes state_changed.

signal state_changed

const ComponentStyle = preload("res://scripts/component_style.gd")
const ComponentSetup = preload("res://scripts/component_setup.gd")

var _enabled := true
var _time := 0.0
var _materials: Array[StandardMaterial3D] = []
var _halos: Array[MeshInstance3D] = []
@onready var _crystal: Node3D = $Model/Crystal
@onready var _crystal_rest_height: float = _crystal.position.y

func _ready() -> void:
	# Each beacon owns its energy materials; switching it off must not dim
	# the habitat or another instance that uses the same cyan resource.
	var copies := ComponentSetup.duplicate_matching($Model, func(material: Material) -> bool: return material is StandardMaterial3D and material.emission_enabled)
	for material in copies.values():
		_materials.append(material as StandardMaterial3D)
	for part in $Model.find_children("*", "MeshInstance3D", true, false):
		if "Halo" in part.name:
			_halos.append(part)
	set_enabled(_enabled)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for mat in _materials:
		mat.emission_enabled = enabled
	for halo in _halos:
		halo.visible = enabled
	state_changed.emit()

func is_enabled() -> bool:
	return _enabled

func _process(delta: float) -> void:
	if _enabled:
		_time += delta
		_crystal.rotation.y += delta * ComponentStyle.BEACON_SPIN
		_crystal.position.y = _crystal_rest_height + sin(_time * ComponentStyle.BEACON_BOB_SPEED) * ComponentStyle.BEACON_BOB_AMPLITUDE
