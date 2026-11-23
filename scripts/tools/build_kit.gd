extends SceneTree
## Shared geometry helpers for the content generators.
##
## Generators inherit this neutral kit instead of inheriting each other, so
## running one generator never builds another generator's output as a side
## effect. Only entry generators override _initialize(); the base just quits.

var armor: Material = preload("res://resources/materials/slate.tres")
var dark: Material = preload("res://resources/materials/ink.tres")
var trim: Material = preload("res://resources/materials/gold.tres")
var pale: Material = preload("res://resources/materials/ivory.tres")
var cyan: Material = preload("res://resources/materials/teal_glow_1.tres")
var amber: Material = preload("res://resources/materials/gold_glow_0_6.tres")
var glass: Material = preload("res://resources/materials/dome_glass.tres")
var deck: Material = preload("res://resources/materials/deck.tres")
var rng := RandomNumberGenerator.new()
var _box_meshes := {}
var _cylinder_meshes := {}
var _ring_meshes := {}
var _armor_meshes := {}
var _material_cache := {}

const SceneMerge = preload("res://scripts/tools/scene_merge.gd")
const Metadata = preload("res://scripts/metadata.gd")
const MODEL_MESH_DIR := "res://resources/models/meshes"
const SCENE_MESH_DIR := "res://resources/scenes"

func _initialize() -> void:
	# Kit scripts are libraries; entry generators override this method.
	quit()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.3f" % [color.to_html(true), emission]
	if not _material_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.94
		if emission > 0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = emission
		_material_cache[key] = mat
	return _material_cache[key]

func attach(root_node: Node, node: Node, node_name: String) -> void:
	node.name = node_name
	root_node.add_child(node)
	node.owner = root_node

func group(parent: Node3D, title: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = title
	n.position = pos
	if parent != null: parent.add_child(n, true)
	return n

func mesh(parent: Node3D, title: String, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = title
	n.mesh = shape
	n.position = pos
	n.material_override = mat
	parent.add_child(n, true)
	return n

func mesh_node(root_node: Node, node_name: String, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	return mesh(root_node as Node3D, node_name, shape, pos, mat)

func box(p: Node3D, title: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	if not _box_meshes.has(size):
		var shape := BoxMesh.new()
		shape.size = size
		_box_meshes[size] = shape
	return mesh(p, title, _box_meshes[size], pos, mat)

func cylinder(p: Node3D, title: String, pos: Vector3, top: float, bottom: float, height: float, mat: Material, sides := 12) -> MeshInstance3D:
	var key := [top, bottom, height, sides]
	if not _cylinder_meshes.has(key):
		var shape := CylinderMesh.new()
		shape.top_radius = top
		shape.bottom_radius = bottom
		shape.height = height
		shape.radial_segments = sides
		shape.rings = 1
		_cylinder_meshes[key] = shape
	return mesh(p, title, _cylinder_meshes[key], pos, mat)

func beam(p: Node3D, title: String, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var n := box(p, title, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), mat)
	n.quaternion = Quaternion(Vector3.BACK, (b - a).normalized())
	return n

func ring(p: Node3D, title: String, pos: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
	var key := Vector2(radius, width)
	if not _ring_meshes.has(key):
		var shape := TorusMesh.new()
		shape.inner_radius = radius - width
		shape.outer_radius = radius + width
		shape.rings = 48
		shape.ring_segments = 6
		_ring_meshes[key] = shape
	return mesh(p, title, _ring_meshes[key], pos, mat)

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

## Chamfered silhouette in the XY plane, extruded along Z.
func armor_box(p: Node3D, title: String, pos: Vector3, size: Vector3, bevel: float, mat: Material) -> MeshInstance3D:
	var key := [size, bevel]
	if _armor_meshes.has(key):
		return mesh(p, title, _armor_meshes[key], pos, mat)
	var x := size.x * .5
	var y := size.y * .5
	var z := size.z * .5
	var outline := [Vector2(-x + bevel, y), Vector2(x - bevel, y), Vector2(x, y - bevel), Vector2(x, -y + bevel), Vector2(x - bevel, -y), Vector2(-x + bevel, -y), Vector2(-x, -y + bevel), Vector2(-x, y - bevel)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in 8:
		var a := Vector3(outline[i].x, outline[i].y, z)
		var b := Vector3(outline[(i + 1) % 8].x, outline[(i + 1) % 8].y, z)
		var c := Vector3(b.x, b.y, -z)
		var d := Vector3(a.x, a.y, -z)
		triangle(st, Vector3(0, 0, z), a, b)
		triangle(st, Vector3(0, 0, -z), c, d)
		triangle(st, a, d, c)
		triangle(st, a, c, b)
	st.generate_normals()
	_armor_meshes[key] = st.commit()
	return mesh(p, title, _armor_meshes[key], pos, mat)

func own_children(n: Node, owner_node: Node) -> void:
	for child in n.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			own_children(child, owner_node)

func save_model(n: Node3D, file: String) -> void:
	SceneMerge.merge_model(n)
	own_children(n, n)
	externalize_model_meshes(n, file)
	var packed := PackedScene.new()
	var error := packed.pack(n)
	if error != OK:
		fail("Could not pack model %s: %s" % [file, error_string(error)])
		return
	error = ResourceSaver.save(packed, "res://scenes/models/" + file + ".tscn")
	if error != OK:
		fail("Could not save model %s: %s" % [file, error_string(error)])
		return
	n.free()

## Persist every owned mesh once and reference it from the saved scene. This
## keeps large generated ArrayMeshes compressed and out of the text scene.
func externalize_model_meshes(root: Node, file: String) -> void:
	externalize_meshes(root, MODEL_MESH_DIR + "/" + file)

func externalize_scene_meshes(root: Node, path: String) -> void:
	externalize_meshes(root, SCENE_MESH_DIR + "/" + path.get_basename().get_file())

func externalize_meshes(root: Node, directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var dir := DirAccess.open(directory)
	if dir != null:
		for name in dir.get_files():
			if name.ends_with(".res"):
				dir.remove(name)
	var meshes := {}
	var index := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.owner != root or part.mesh == null or not part.mesh.resource_path.is_empty():
			continue
		var key := part.mesh.get_instance_id()
		if meshes.has(key):
			part.mesh = meshes[key]
			continue
		var path := "%s/mesh_%02d.res" % [directory, index]
		var error := ResourceSaver.save(part.mesh, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			fail("Could not save mesh %s: %s" % [path, error_string(error)])
			return
		var external := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Mesh
		if external == null:
			fail("Could not reload mesh %s" % path)
			return
		part.mesh = external
		meshes[key] = external
		index += 1

func instance(p: Node3D, file: String, title: String, pos: Vector3) -> Node3D:
	var n: Node3D = load("res://scenes/models/" + file + ".tscn").instantiate()
	n.name = title
	n.position = pos
	p.add_child(n, true)
	return n

func stairs(p: Node3D, pos: Vector3, width: float, count: int, rise: float, run: float) -> void:
	var g := group(p, "Stairs", pos)
	for i in count:
		var h := (count - i) * rise
		box(g, "Tread%02d" % i, Vector3(0, h * .5, i * run), Vector3(width, h, run + .015), deck)
		box(g, "Nosing%02d" % i, Vector3(0, h, i * run + run * .43), Vector3(width, .035, .065), pale)
	for side in [-1, 1]:
		beam(g, "AmberRail", Vector3(side * (width * .5 + .06), count * rise + .04, -run * .4), Vector3(side * (width * .5 + .06), .12, count * run), .12, trim)

func save_scene(node: Node, path: String) -> void:
	own_children(node, node)
	externalize_scene_meshes(node, path)
	var scene := PackedScene.new()
	var error := scene.pack(node)
	if error != OK:
		fail("Could not pack scene %s: %s" % [path, error_string(error)])
		return
	error = ResourceSaver.save(scene, path)
	if error != OK:
		fail("Could not save scene %s: %s" % [path, error_string(error)])
		return
	node.free()

## Persist a procedural mesh as an external resource so scenes reference it
## instead of embedding a second copy of the vertex data.
func external_mesh(shape: ArrayMesh, path: String) -> ArrayMesh:
	var error := ResourceSaver.save(shape, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		fail("Could not save mesh %s: %s" % [path, error_string(error)])
		return shape
	var external := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	if external == null:
		fail("Could not reload mesh %s" % path)
		return shape
	return external

