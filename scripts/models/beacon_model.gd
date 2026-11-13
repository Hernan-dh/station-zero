extends "res://scripts/models/procedural_model.gd"

func _ready() -> void:
	var beacon := Node3D.new()
	beacon.name = "Crystal"
	beacon.position = Vector3(0, 3.9, -0.65)
	add_child(beacon)
	cylinder(Vector3(0, -0.33, 0), 0.0, 0.43, 0.65, Color("319eaa"), 5, 0.55, beacon)
	cylinder(Vector3(0, 0.43, 0), 0.43, 0.0, 0.87, TEAL, 5, 0.75, beacon)
	for i in 3:
		var a := TAU * i / 3.0
		var prong := box(Vector3(sin(a) * 0.68, 3.25, cos(a) * 0.68 - 0.65), Vector3(0.13, 0.95, 0.16), IVORY)
		prong.rotation = Vector3(0.2, a, 0)

