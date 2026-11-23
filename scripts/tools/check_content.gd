extends SceneTree

const Metadata = preload("res://scripts/metadata.gd")

const MAIN_SCENE_SETTING := "application/run/main_scene"
const PICKING_SCENE := "res://resources/picking/outpost_picking.scn"
const SCENE_ROOTS := ["res://scenes"]
const TEXT_ROOTS := ["res://scenes", "res://resources"]
const SCRIPT_ROOT := "res://scripts"
const MESH_ROOTS := [
	"res://resources/models/meshes",
	"res://resources/scenes",
	"res://resources/meshes",
	"res://resources/moon",
]
const BOOL_METADATA := [
	Metadata.SELECTION_IGNORE,
	Metadata.OCCUPIED,
	Metadata.MERGE_PIVOT,
	Metadata.MERGE_PROTECTED,
	Metadata.PICKING_MOVING,
	Metadata.PICKING_TERRAIN,
	Metadata.PICKING_CONCAVE,
]

var _failures := 0
var _checks := 0
var _failures_before := 0

var _scene_files: Array[String] = []
var _text_files: Array[String] = []
var _dependencies := {}
var _references := {}
var _display_paths: Array[String] = []

var _ext_type := RegEx.new()
var _ext_path := RegEx.new()
var _preload := RegEx.new()

func _initialize() -> void:
	_ext_type.compile("type=\"([^\"]+)\"")
	_ext_path.compile("path=\"(res://[^\"]+)\"")
	_preload.compile("preload\\(\\s*\"(res://[^\"]+)\"\\s*\\)")

	_scene_files = _find_files(SCENE_ROOTS, ".tscn")
	_text_files = _find_files(TEXT_ROOTS, ".tscn")
	_text_files.append_array(_find_files(TEXT_ROOTS, ".tres"))
	_text_files.sort()

	print("Station Zero content check")
	_read_dependencies()
	_check_scene_dependencies()

	var source := _load_main_scene()
	_check_external_meshes()
	if source != null:
		_check_selection_metadata(source)
		_check_baked_picking(source)
		source.free()
	else:
		_fail("Selection metadata and baked picking could not be checked because the main scene did not instantiate.")
		_fail("Rebuild the main scene before running the content check again.")

	var verdict := "PASS" if _failures == 0 else "%d FAILURE(S)" % _failures
	print("Content check: %s (%d checks)." % [verdict, _checks])
	quit(_failures)

func _check_scene_dependencies() -> void:
	_failures_before = _failures
	var missing := {}
	for dependency in _dependencies:
		_checks += 1
		if FileAccess.file_exists(dependency):
			continue
		missing[dependency] = _references.get(dependency, [])
	for dependency in missing:
		_fail("Missing scene dependency %s referenced by %s. Restore the file or update the reference." % [
			dependency, _source_list(missing[dependency])])

	var unreadable := 0
	for dependency in _dependencies:
		var kind: String = _dependencies[dependency]
		if missing.has(dependency) or _is_mesh_type(kind):
			continue
		_checks += 1
		var loaded := ResourceLoader.load(dependency, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded == null:
			_fail("Dependency %s failed to load. Restore or regenerate it." % dependency)
			unreadable += 1
		elif kind != "preload" and not kind.is_empty() and not loaded.is_class(kind):
			_fail("Dependency %s is a %s but is referenced as %s. Update the ext_resource type." % [
				dependency, loaded.get_class(), kind])
	for scene in _scene_files:
		_checks += 1
		var packed := ResourceLoader.load(scene, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
		if packed == null or not packed is PackedScene:
			_fail("Scene %s failed to load as a PackedScene. Check its ext_resource paths and syntax." % scene)
			unreadable += 1
	if _failures == _failures_before:
		print("PASS: %d scene dependencies resolve across %d text resources; %d scenes load." % [
			_dependencies.size(), _text_files.size(), _scene_files.size()])
	elif unreadable == 0:
		print("Checked %d scene dependencies across %d text resources and %d scenes." % [
			_dependencies.size(), _text_files.size(), _scene_files.size()])

func _check_external_meshes() -> void:
	_failures_before = _failures
	var candidates := {}
	for path in _find_files(MESH_ROOTS, ".res"):
		candidates[path] = true
	for dependency in _dependencies:
		var kind: String = _dependencies[dependency]
		if _is_mesh_type(kind):
			candidates[dependency] = true

	var checked := 0
	for path in candidates:
		_checks += 1
		checked += 1
		var generated := _is_generated_mesh_path(path)
		if generated and not _references.has(path):
			_fail("External mesh %s is not referenced by any scene or resource. Rerun its generator or remove the stale file." % path)
		if not FileAccess.file_exists(path):
			continue
		var mesh := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if mesh == null:
			_fail("External mesh %s failed to load. Rerun its generator." % path)
			continue
		if not mesh is Mesh:
			_fail("External mesh %s loaded as %s, not a Mesh. Rerun its generator." % [path, mesh.get_class()])
			continue
		var kind: String = _dependencies.get(path, "")
		if not kind.is_empty() and kind != "preload" and not mesh.is_class(kind):
			_fail("External mesh %s is a %s but is referenced as %s. Update the ext_resource type." % [
				path, mesh.get_class(), kind])
			continue
		var problem := _mesh_problem(mesh)
		if not problem.is_empty():
			_fail("External mesh %s %s. Rerun its generator." % [path, problem])
	if _failures == _failures_before:
		print("PASS: %d external mesh resources load and are referenced." % checked)

func _check_selection_metadata(root: Node) -> void:
	_failures_before = _failures
	_display_paths.clear()
	var selectable_count := 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		var path := _node_path(root, node)

		if node.has_meta(Metadata.DISPLAY_NAME):
			_checks += 1
			var value: Variant = node.get_meta(Metadata.DISPLAY_NAME)
			if not value is String or (value as String).strip_edges().is_empty():
				_fail("Selection metadata: %s has an empty or non-string display_name. Restore a name or run the content builders." % path)
			elif not node is Node3D:
				_fail("Selection metadata: %s has display_name but is not a Node3D, so selection cannot use it." % path)
			else:
				selectable_count += 1
				_display_paths.append(path)

		for key in BOOL_METADATA:
			if node.has_meta(key):
				_checks += 1
				if not node.get_meta(key) is bool:
					_fail("Selection metadata: %s on %s must be a bool." % [key, path])
		if node.has_meta(Metadata.BUILD_RADIUS):
			_checks += 1
			if not node.get_meta(Metadata.BUILD_RADIUS) is float:
				_fail("Selection metadata: build_radius on %s must be a float." % path)
		if node.has_meta(Metadata.APPROACH):
			_checks += 1
			if not node.get_meta(Metadata.APPROACH) is String:
				_fail("Selection metadata: approach on %s must be a string." % path)
		if node.has_meta(Metadata.TRAVEL_LENGTH):
			_checks += 1
			if not node.get_meta(Metadata.TRAVEL_LENGTH) is float:
				_fail("Selection metadata: travel_length on %s must be a float." % path)
		if node.has_meta(Metadata.ENTRANCE):
			_checks += 1
			var entrance: Variant = node.get_meta(Metadata.ENTRANCE)
			if not entrance is NodePath or node.get_node_or_null(entrance) == null:
				_fail("Selection metadata: entrance on %s does not resolve to a node." % path)
		if node.has_meta(Metadata.ATTACHMENT_PATH):
			_checks += 1
			var attachment: Variant = node.get_meta(Metadata.ATTACHMENT_PATH)
			if not attachment is NodePath or node.get_node_or_null(attachment) == null:
				_fail("Selection metadata: attachment_path on %s does not resolve to a node." % path)
		if node.is_in_group("defensive_build_sites"):
			_checks += 1
			if not Metadata.has_display_name(node):
				_fail("Selection metadata: defense site %s needs a display_name." % path)
			if not node.has_meta(Metadata.OCCUPIED) or not node.get_meta(Metadata.OCCUPIED) is bool:
				_fail("Selection metadata: defense site %s needs a bool occupied flag." % path)
	if _failures == _failures_before:
		print("PASS: %d selectable owners follow the selection metadata contract." % selectable_count)

func _check_baked_picking(source: Node) -> void:
	_failures_before = _failures
	_checks += 1
	if not FileAccess.file_exists(PICKING_SCENE):
		_fail("Baked picking %s is missing. Run scripts/tools/bake_picking.gd." % PICKING_SCENE)
		return
	var packed := ResourceLoader.load(PICKING_SCENE, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	if packed == null or not packed is PackedScene:
		_fail("Baked picking %s failed to load. Run scripts/tools/bake_picking.gd." % PICKING_SCENE)
		return
	var baked := (packed as PackedScene).instantiate()
	if baked == null:
		_fail("Baked picking %s did not instantiate. Run scripts/tools/bake_picking.gd." % PICKING_SCENE)
		return

	var bodies := 0
	var shapes := 0
	var attachment_paths: Array[String] = []
	for child in baked.get_children():
		_checks += 1
		bodies += 1
		var body_path := _node_path(baked, child)
		if not child is StaticBody3D:
			_fail("Baked picking body %s is a %s, not a StaticBody3D. Run scripts/tools/bake_picking.gd." % [
				body_path, child.get_class()])
		var attachment: Variant = child.get_meta(Metadata.ATTACHMENT_PATH, null)
		if not attachment is NodePath or str(attachment).is_empty():
			_fail("Baked picking body %s has no valid attachment_path. Run scripts/tools/bake_picking.gd." % body_path)
		else:
			var target := source.get_node_or_null(attachment)
			if target == null:
				_fail("Stale picking bake: %s attaches to missing %s. Run scripts/tools/bake_picking.gd." % [
					body_path, attachment])
			elif not target is Node3D:
				_fail("Baked picking body %s attaches to %s, which is not a Node3D. Run scripts/tools/bake_picking.gd." % [
					body_path, attachment])
			elif not (Metadata.has_display_name(target) or target.get_meta(Metadata.PICKING_MOVING, false) or target.get_parent() == source):
				_fail("Stale picking bake: %s attaches to %s, which is no longer a selection anchor. Run scripts/tools/bake_picking.gd." % [
					body_path, attachment])
			else:
				attachment_paths.append(str(attachment))

		var body_shapes := 0
		for shape_node in child.get_children():
			if not shape_node is CollisionShape3D:
				continue
			body_shapes += 1
			shapes += 1
			var shape: Shape3D = (shape_node as CollisionShape3D).shape
			if shape == null:
				_fail("Baked picking body %s has a CollisionShape3D without a shape. Run scripts/tools/bake_picking.gd." % body_path)
				continue
			var problem := _shape_problem(shape)
			if not problem.is_empty():
				_fail("Baked picking body %s has a %s that %s. Run scripts/tools/bake_picking.gd." % [
					body_path, shape.get_class(), problem])
		if body_shapes == 0:
			_fail("Baked picking body %s has no CollisionShape3D. Run scripts/tools/bake_picking.gd." % body_path)

	for display_path in _display_paths:
		_checks += 1
		var covered := false
		for attachment_path in attachment_paths:
			if _covers(display_path, attachment_path):
				covered = true
				break
		if not covered:
			_fail("Selectable %s has no baked picking body. Run scripts/tools/bake_picking.gd." % display_path)

	if baked.get_child_count() == 0:
		_fail("Baked picking %s contains no bodies. Run scripts/tools/bake_picking.gd." % PICKING_SCENE)
	baked.free()
	if _failures == _failures_before:
		print("PASS: baked picking has %d bodies, %d shapes and attachments for %d selectable owners." % [
			bodies, shapes, _display_paths.size()])

func _load_main_scene() -> Node:
	_checks += 1
	var main_scene: Variant = ProjectSettings.get_setting(MAIN_SCENE_SETTING, "")
	if not main_scene is String or (main_scene as String).is_empty():
		_fail("Project setting %s is missing or empty." % MAIN_SCENE_SETTING)
		return null
	var path: String = main_scene
	if not FileAccess.file_exists(path):
		_fail("Main scene %s is missing." % path)
		return null
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	if packed == null or not packed is PackedScene:
		_fail("Main scene %s failed to load as a PackedScene." % path)
		return null
	var source := (packed as PackedScene).instantiate()
	if source == null:
		_fail("Main scene %s did not instantiate." % path)
		return null
	print("PASS: main scene %s loads and instantiates." % path)
	return source

func _read_dependencies() -> void:
	for file in _text_files:
		var text := FileAccess.get_file_as_string(file)
		for line in text.split("\n"):
			if not line.begins_with("[ext_resource"):
				continue
			var path_match := _ext_path.search(line)
			if path_match == null:
				_fail("Scene dependency: %s has an ext_resource without a res:// path." % file)
				continue
			var path := path_match.get_string(1)
			var type_match := _ext_type.search(line)
			_dependencies[path] = type_match.get_string(1) if type_match != null else ""
			_add_reference(path, file)
	for file in _find_files([SCRIPT_ROOT], ".gd"):
		var text := FileAccess.get_file_as_string(file)
		for match in _preload.search_all(text):
			var path := match.get_string(1)
			_dependencies[path] = "preload"
			_add_reference(path, file)

func _add_reference(path: String, source: String) -> void:
	if not _references.has(path):
		_references[path] = []
	var sources: Array = _references[path]
	if not sources.has(source):
		sources.append(source)

func _find_files(roots: Array, suffix: String) -> Array[String]:
	var seen := {}
	var pending: Array[String] = []
	for root in roots:
		pending.append(root)
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		var access := DirAccess.open(directory)
		if access == null:
			continue
		for name in access.get_files():
			if name.ends_with(suffix):
				seen[directory.path_join(name)] = true
		for name in access.get_directories():
			if not name.begins_with("."):
				pending.append(directory.path_join(name))
	var result: Array[String] = []
	result.assign(seen.keys())
	result.sort()
	return result

func _is_mesh_type(type: String) -> bool:
	return type == "Mesh" or (type.ends_with("Mesh") and type != "MultiMesh")

func _is_generated_mesh_path(path: String) -> bool:
	for root in MESH_ROOTS:
		if path.begins_with(root + "/"):
			return true
	return false

func _mesh_problem(mesh: Mesh) -> String:
	if mesh is ArrayMesh:
		var surface_count: int = (mesh as ArrayMesh).get_surface_count()
		if surface_count == 0:
			return "has no surfaces"
		for index in surface_count:
			var arrays := (mesh as ArrayMesh).surface_get_arrays(index)
			if arrays.is_empty():
				return "has an empty surface at index %d" % index
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if not vertices is PackedVector3Array or (vertices as PackedVector3Array).is_empty():
				return "has no vertices on surface %d" % index
	if mesh.get_aabb().size.length_squared() <= 0.0:
		return "has empty bounds"
	return ""

func _shape_problem(shape: Shape3D) -> String:
	if shape is ConcavePolygonShape3D:
		if (shape as ConcavePolygonShape3D).get_faces().size() < 3:
			return "has no triangles"
	elif shape is ConvexPolygonShape3D:
		if (shape as ConvexPolygonShape3D).points.size() < 4:
			return "has fewer than four points"
	elif shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			return "has a non-positive size"
	elif shape is SphereShape3D:
		if (shape as SphereShape3D).radius <= 0.0:
			return "has a non-positive radius"
	elif shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		if cylinder.radius <= 0.0 or cylinder.height <= 0.0:
			return "has a non-positive radius or height"
	elif shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		if capsule.radius <= 0.0 or capsule.height <= 0.0:
			return "has a non-positive radius or height"
	return ""

func _covers(owner_path: String, attachment_path: String) -> bool:
	if owner_path == ".":
		return true
	return attachment_path == owner_path or attachment_path.begins_with(owner_path + "/")

func _node_path(root: Node, node: Node) -> String:
	var path := root.get_path_to(node)
	return str(path) if not path.is_empty() else "."

func _source_list(sources: Array) -> String:
	var names: Array[String] = []
	for source in sources:
		names.append(str(source))
	if names.size() <= 3:
		return ", ".join(names)
	return "%s and %d more" % [", ".join(names.slice(0, 3)), names.size() - 3]

func _fail(message: String) -> void:
	_failures += 1
	print("FAIL: " + message)
