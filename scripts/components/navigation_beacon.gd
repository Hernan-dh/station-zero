extends Node3D
## Owns beacon emission and animation; UI observes state_changed.

signal state_changed

var _enabled := true
var _time := 0.0
var _materials: Array[StandardMaterial3D] = []
@onready var _crystal: Node3D = $Model/Crystal

func _ready() -> void:
	for mesh in _crystal.get_children():
		if mesh is MeshInstance3D:
			_materials.append(mesh.material_override as StandardMaterial3D)
	set_enabled(_enabled)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for mat in _materials:
		mat.emission_enabled = enabled
	state_changed.emit()

func is_enabled() -> bool:
	return _enabled

func _process(delta: float) -> void:
	if _enabled:
		_time += delta
		_crystal.rotation.y += delta * 0.22
		_crystal.position.y = 3.9 + sin(_time * 1.4) * 0.09
