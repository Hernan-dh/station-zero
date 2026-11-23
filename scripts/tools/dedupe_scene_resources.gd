extends SceneTree
## Collapse identical mesh and material subresources in already-baked scenes.
## Generators cache shared resources directly; this tool handles older scenes
## that were authored without a generator:
## godot --headless --path . --script res://scripts/tools/dedupe_scene_resources.gd

const ResourceTransaction = preload("res://scripts/tools/resource_transaction.gd")

const DEFAULT_TARGETS := [
	"res://scenes/models/arc_launcher.tscn",
]
const IGNORED_PROPERTIES := ["resource_path", "resource_name", "resource_local_to_scene", "script"]

func _initialize() -> void:
	var targets := OS.get_cmdline_user_args()
	if targets.is_empty():
		targets = DEFAULT_TARGETS
	var failures := 0
	var transaction := ResourceTransaction.new()
	for path in targets:
		if not _dedupe(path, transaction):
			failures += 1
	if failures == 0:
		var error := transaction.commit()
		if error != OK:
			push_error("Could not commit deduped scenes: %s" % transaction.last_error_message)
			failures += 1
	else:
		transaction.rollback()
	quit(failures)

func _dedupe(path: String, transaction: ResourceTransaction) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Cannot load scene: " + path)
		return false
	var root := packed.instantiate()
	var meshes := {}
	var materials := {}
	var before := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var mesh: Mesh = part.mesh
		if mesh != null:
			before += 1
			var key := _resource_signature(mesh)
			if meshes.has(key):
				part.mesh = meshes[key]
			else:
				meshes[key] = mesh
		var material: Material = part.material_override
		if material != null:
			var key := _resource_signature(material)
			if materials.has(key):
				part.material_override = materials[key]
			else:
				materials[key] = material
	var output := PackedScene.new()
	var error := output.pack(root)
	if error == OK:
		error = transaction.save(output, path)
	root.free()
	if error != OK:
		push_error("Cannot save %s: %s" % [path, transaction.last_error_message])
		return false
	print("%s: %d meshes, %d unique meshes, %d unique materials" % [path, before, meshes.size(), materials.size()])
	return true

func _resource_signature(resource: Resource) -> String:
	if resource is ArrayMesh:
		var parts := ["ArrayMesh"]
		for surface in resource.get_surface_count():
			parts.append(var_to_str(resource.surface_get_arrays(surface)))
		return "|".join(parts)
	var parts := [resource.get_class()]
	for property in resource.get_property_list():
		if (property.usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if property.name in IGNORED_PROPERTIES:
			continue
		parts.append(property.name + "=" + var_to_str(resource.get(property.name)))
	return "|".join(parts)
