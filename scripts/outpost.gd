extends Node3D
## Geometry, layout and environment are authored in scenes; this script
## validates metadata contracts and wires selection.

const Metadata = preload("res://scripts/metadata.gd")

func _ready() -> void:
	Metadata.validate(self)
	$SelectionUI.prepare_selection()
	$CameraControls.selection_requested.connect($SelectionUI.select_at)
