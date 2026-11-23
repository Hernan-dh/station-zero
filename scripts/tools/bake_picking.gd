extends SceneTree
## Rebuild after changing outpost geometry, transforms, or selection metadata:
## godot --headless --path . --script res://scripts/tools/bake_picking.gd
## The source scene is instantiated off-tree so gameplay and animation never run.

const Metadata = preload("res://scripts/metadata.gd")
const OUTPUT := "res://resources/picking/outpost_picking.scn"
const TERRAIN_SECTION_SIZE := 16.0
const DECORATION_SIZE := 0.35
const CONVEX_FACE_THRESHOLD := 240

var _source: Node3D
var _baked := Node3D.new()
var _groups: Dictionary = {}
var _transforms: Dictionary = {}
var _face_cache: Dictionary = {}
var _mesh_count := 0
var _proxy_count := 0

func _initialize() -> void:
	_source = load("res://scenes/outpost.tscn").instantiate()
	var contract_errors := Metadata.validate(_source)
	if contract_errors > 0:
		push_error("Picking bake aborted: %d metadata or layout contract failures." % contract_errors)
		_source.free()
		_baked.free()
		quit(1)
		return
	_baked.name = "BakedPicking"
	_collect(_source, Transform3D.IDENTITY, _source, _source)
	for key in _groups:
		var group: Dictionary = _groups[key]
		var faces: PackedVector3Array = group.faces
		if faces.is_empty():
			continue
		if _use_convex(group.anchor, faces):
			_add_shape(group.body, _convex_shape(faces))
		else:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			_add_shape(group.body, shape)
	var packed := PackedScene.new()
	var error := packed.pack(_baked)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	print("Baked %d meshes into %d bodies, %d shapes (%d primitive proxies)." % [
		_mesh_count, _baked.get_child_count(), _baked.find_children("*", "CollisionShape3D", true, false).size(), _proxy_count])
	_source.free()
	_baked.free()
	if error != OK:
		push_error("Picking bake failed: %s" % error_string(error))
	quit(error)

func _collect(node: Node, parent_transform: Transform3D, target: Node3D, anchor: Node3D) -> void:
	if node is Node3D and node != _source and not node.visible:
		return
	var transform := parent_transform
	if node is Node3D and node != _source:
		transform *= node.transform
	_transforms[node] = transform
	if Metadata.has_display_name(node) or (node.get_parent() == _source and node is Node3D):
		target = node
		anchor = node
	if node.get_meta(Metadata.PICKING_MOVING, false):
		anchor = node
	if node is MeshInstance3D and not Metadata.selection_ignored(node) and node.mesh != null and node.visible:
		_bake_mesh(node, target, anchor, transform)
	for child in node.get_children():
		_collect(child, transform, target, anchor)

func _group(anchor: Node3D, section: String = "") -> Dictionary:
	var path := _source.get_path_to(anchor)
	var key := str(path) + section
	if not _groups.has(key):
		var body := StaticBody3D.new()
		body.name = "Pick%03d" % _groups.size()
		body.collision_mask = 0
		body.set_meta(Metadata.ATTACHMENT_PATH, path)
		_baked.add_child(body)
		body.owner = _baked
		_groups[key] = {"body": body, "anchor": anchor, "faces": PackedVector3Array()}
	return _groups[key]

## Solid leaf owners can use their convex hull. Enclosures keep concave
## geometry so their interiors and child selectables remain reachable.
func _use_convex(anchor: Node3D, faces: PackedVector3Array) -> bool:
	if faces.size() / 3 < CONVEX_FACE_THRESHOLD or anchor.get_meta(Metadata.PICKING_TERRAIN, false) or anchor.get_meta(Metadata.PICKING_CONCAVE, false):
		return false
	for node in anchor.find_children("*", "Node3D", true, false):
		if Metadata.has_display_name(node):
			return false
	return true

func _convex_shape(faces: PackedVector3Array) -> ConvexPolygonShape3D:
	var source := ConvexPolygonShape3D.new()
	source.points = faces
	var hull := source.get_debug_mesh()
	var unique := {}
	for surface in hull.get_surface_count():
		var arrays := hull.surface_get_arrays(surface)
		for point in arrays[Mesh.ARRAY_VERTEX]:
			unique[point] = true
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(unique.keys())
	return shape

func _bake_mesh(part: MeshInstance3D, target: Node3D, anchor: Node3D, world: Transform3D) -> void:
	_mesh_count += 1
	var local: Transform3D = _transforms[anchor].affine_inverse() * world
	var bounds := part.mesh.get_aabb()
	var world_size := (world * bounds).size
	# Bolts, indicator beads and other tiny solid primitives need no triangle BVH.
	# Retain their individual transforms; never fill an object's gaps with one hull.
	if world_size[world_size.max_axis_index()] <= DECORATION_SIZE and (part.mesh is BoxMesh or part.mesh is SphereMesh or part.mesh is CylinderMesh):
		var proxy: Shape3D
		if part.mesh is SphereMesh and is_equal_approx(part.mesh.height, part.mesh.radius * 2.0):
			var sphere := SphereShape3D.new()
			sphere.radius = part.mesh.radius
			proxy = sphere
		elif part.mesh is CylinderMesh and is_equal_approx(part.mesh.top_radius, part.mesh.bottom_radius):
			var cylinder := CylinderShape3D.new()
			cylinder.radius = part.mesh.top_radius
			cylinder.height = part.mesh.height
			proxy = cylinder
		else:
			var box := BoxShape3D.new()
			box.size = bounds.size.max(Vector3.ONE * 0.001)
			local.origin += local.basis * bounds.get_center()
			proxy = box
		var section := ""
		if target.get_meta(Metadata.PICKING_TERRAIN, false):
			section = _section_key(local * bounds.get_center())
		_add_shape(_group(anchor, section).body, proxy, local)
		_proxy_count += 1
		return
	if not _face_cache.has(part.mesh):
		_face_cache[part.mesh] = part.mesh.get_faces()
	var faces: PackedVector3Array = _face_cache[part.mesh]
	var terrain: bool = target.get_meta(Metadata.PICKING_TERRAIN, false)
	if not terrain:
		var group := _group(anchor)
		var combined: PackedVector3Array = group.faces
		combined.append_array(local * faces)
		group.faces = combined
		return
	# Partition triangles, including large ground meshes, rather than just mesh origins.
	for i in range(0, faces.size(), 3):
		var a := local * faces[i]
		var b := local * faces[i + 1]
		var c := local * faces[i + 2]
		var center := (a + b + c) / 3.0
		var section := _section_key(center)
		var group := _group(anchor, section)
		var combined: PackedVector3Array = group.faces
		combined.append_array(PackedVector3Array([a, b, c]))
		group.faces = combined

func _section_key(center: Vector3) -> String:
	return ":%d:%d" % [floori(center.x / TERRAIN_SECTION_SIZE), floori(center.z / TERRAIN_SECTION_SIZE)]

func _add_shape(body: StaticBody3D, shape: Shape3D, transform := Transform3D.IDENTITY) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Shape%03d" % body.get_child_count()
	collision.shape = shape
	collision.transform = transform
	body.add_child(collision)
	collision.owner = _baked
