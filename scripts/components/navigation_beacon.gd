extends Node3D
## Owns beacon emission and animation; UI observes state_changed.

signal state_changed

var _enabled := true
var _time := 0.0
var _materials: Array[StandardMaterial3D] = []
var _halos: Array[MeshInstance3D] = []
@onready var _crystal: Node3D = $Model/Crystal
@onready var _crystal_rest_height: float = _crystal.position.y

func _ready() -> void:
	# Each beacon owns its energy materials; switching it off must not dim
	# the habitat or another instance that uses the same cyan resource.
	var copies := {}
	for part in $Model.find_children("*", "MeshInstance3D", true, false):
		var mat := part.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			if not copies.has(mat):
				copies[mat] = mat.duplicate()
				_materials.append(copies[mat])
			part.material_override = copies[mat]
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
		_crystal.rotation.y += delta * 0.22
		_crystal.position.y = _crystal_rest_height + sin(_time * 1.4) * 0.09
