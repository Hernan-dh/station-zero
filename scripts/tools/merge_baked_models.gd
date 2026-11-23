extends "res://scripts/tools/build_kit.gd"
## Merge static meshes in hand-authored model scenes that do not have generators:
## godot --headless --path . --script res://scripts/tools/merge_baked_models.gd

const TARGETS := ["arc_launcher", "communications_array", "solar_array", "service_crate", "communications_antenna"]

func _initialize() -> void:
	for file in TARGETS:
		var path := "res://scenes/models/%s.tscn" % file
		var packed := load(path) as PackedScene
		if packed == null:
			fail("Could not load %s" % path)
			return
		var root := packed.instantiate() as Node3D
		SceneMerge.merge_model(root)
		own_children(root, root)
		externalize_model_meshes(root, file)
		var merged := PackedScene.new()
		var error := merged.pack(root)
		if error != OK:
			fail("Could not pack %s: %s" % [path, error_string(error)])
			return
		error = ResourceSaver.save(merged, path)
		if error != OK:
			fail("Could not save %s: %s" % [path, error_string(error)])
			return
		root.free()
		print("Merged static meshes in ", path)
	quit()
