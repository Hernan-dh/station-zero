extends "res://scripts/models/procedural_model.gd"

var array_base: Node3D
var dish_pivot: Node3D

# Local +Z is the dish's boresight. The deck mount stays fixed while the
# azimuth bearing carries a separate X-axis elevation hinge and reflector.
func _ready() -> void:
	cylinder(Vector3(0, 0.10, 0), 0.82, 0.72, 0.2, INK)
	cylinder(Vector3(0, 0.23, 0), 0.70, 0.70, 0.08, IVORY)
	cylinder(Vector3(0, 0.32, 0), 0.59, 0.59, 0.10, TEAL, 12, 0.7)
	for i in 8:
		var a := TAU * i / 8.0
		cylinder(Vector3(sin(a) * 0.62, 0.285, cos(a) * 0.62), 0.045, 0.045, 0.04, GOLD, 6)
	array_base = Node3D.new()
	array_base.name = "AzimuthBearing"
	add_child(array_base)
	cylinder(Vector3(0, 0.44, 0), 0.63, 0.48, 0.16, SLATE, 12, 0, array_base)
	cylinder(Vector3(0, 0.93, 0), 0.35, 0.24, 0.85, IVORY, 8, 0, array_base)
	box(Vector3(0, 0.85, 0.30), Vector3(0.14, 0.39, 0.055), INK, 0, array_base)
	box(Vector3(0, 0.96, 0.335), Vector3(0.07, 0.16, 0.025), TEAL, 1.0, array_base)
	for x in [-0.49, 0.49]:
		box(Vector3(x, 1.37, -0.18), Vector3(0.17, 0.96, 0.26), SLATE, 0, array_base)
		var axle := cylinder(Vector3(x, 1.82, -0.18), 0.20, 0.20, 0.24, GOLD, 8, 0, array_base)
		axle.rotation.z = PI / 2
	dish_pivot = Node3D.new()
	dish_pivot.name = "ElevationHinge"
	dish_pivot.position = Vector3(0, 1.82, -0.18)
	array_base.add_child(dish_pivot)
	cylinder(Vector3(0, 0, -0.17), 0.30, 0.23, 0.26, INK, 8, 0, dish_pivot).rotation.x = PI / 2
	build_reflector(IVORY, 0.0)
	build_reflector(SLATE, -0.07)
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		array_strut(Vector3(cos(a), sin(a), 0.38), Vector3(cos(b), sin(b), 0.38), 0.035, GOLD)
		if i % 2 == 0:
			array_strut(Vector3(0, 0, -0.12), Vector3(cos(a), sin(a), 0.28), 0.028, INK)
	# Three delicate feed spars frame a luminous crystal receiver.
	for i in 3:
		var a := TAU * i / 3.0 + PI / 2
		array_strut(Vector3(cos(a) * 0.91, sin(a) * 0.91, 0.32), Vector3(0, 0, 0.98), 0.025, SLATE)
	var receiver := cylinder(Vector3(0, 0, 0.96), 0.13, 0.13, 0.20, GOLD, 6, 0, dish_pivot)
	receiver.rotation.x = PI / 2
	var crystal := cylinder(Vector3(0, 0, 1.13), 0.13, 0.0, 0.22, TEAL, 5, 0.8, dish_pivot)
	crystal.rotation.x = PI / 2

func build_reflector(color: Color, depth_offset: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 4:
		for segment in 16:
			var points: Array[Vector3] = []
			for corner in [Vector2(ring, segment), Vector2(ring + 1, segment), Vector2(ring + 1, segment + 1), Vector2(ring, segment + 1)]:
				var radius: float = corner.x / 4.0
				var angle: float = corner.y * TAU / 16.0
				points.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.38 * radius * radius + depth_offset))
			for index in ([0, 2, 1] if ring == 0 else [0, 2, 1, 0, 3, 2]):
				var point := points[index]
				surface.set_normal(Vector3(-0.76 * point.x, -0.76 * point.y, 1).normalized())
				surface.add_vertex(point)
	var mat := material(color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node(surface.commit(), Vector3.ZERO, mat, dish_pivot)

func array_strut(start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var strut := cylinder((start + end) * 0.5, radius, radius, start.distance_to(end), color, 6, 0, dish_pivot)
	strut.quaternion = Quaternion(Vector3.UP, (end - start).normalized())

