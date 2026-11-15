extends Node3D
## Geometry and environment are authored in scenes; this script wires selection.

func _ready() -> void:
	$SelectionUI.prepare_selection()
	$CameraControls.selection_requested.connect($SelectionUI.select_at)
