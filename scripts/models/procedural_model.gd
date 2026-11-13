extends Node3D
## Geometry helpers use an explicit parent; each model owns its construction scope.

const INK = Color("172935")
const SLATE = Color("3c5665")
const DECK = Color("657b87")
const IVORY = Color("d7ddcd")
const TEAL = Color("67eddb")
const GOLD = Color("efb771")

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func mesh_node(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func box(pos: Vector3, size: Vector3, color: Color, glow: float = 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(mesh, pos, material(color, glow), parent)

func cylinder(pos: Vector3, bottom: float, top: float, height: float, color: Color, sides: int = 8, glow: float = 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh_node(mesh, pos, material(color, glow), parent)

