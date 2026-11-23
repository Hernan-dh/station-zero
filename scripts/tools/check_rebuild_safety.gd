extends SceneTree
## Deterministic, headless check for the failure paths of the content rebuild.
##
##   godot --headless --path . --script res://scripts/tools/check_rebuild_safety.gd
##
## Every rebuild writes into a staging area and commits all of its files at
## once. This check creates a known previous output, forces a failure at each
## stage (save, validation and commit) and verifies the previous files are
## byte-for-byte unchanged. It uses only tmp/ files and never touches the real
## generated resources.

const ResourceTransaction = preload("res://scripts/tools/resource_transaction.gd")
const ROOT := "res://tmp/rebuild_safety_check"

var _failures := 0

func _initialize() -> void:
	_clear(ROOT)
	_check_generation_failure()
	_check_validation_failure()
	_check_save_failure()
	_check_commit_failure()
	_check_successful_commit()
	_clear(ROOT)
	print("Rebuild safety check: %s." % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(_failures)

func _check_generation_failure() -> void:
	var dir := ROOT + "/generation"
	var final := dir + "/mesh_00.res"
	var stale := dir + "/mesh_99.res"
	var old_final := _seed(dir, final)
	var old_stale := _file(stale)
	var transaction := ResourceTransaction.new()
	transaction.prune(dir)
	_expect(transaction.save(_mesh(Vector3(2, 0, 0)), final, ResourceSaver.FLAG_COMPRESS) == OK, "generation: stage new mesh")
	# A generator that fails before commit only rolls its staging area back.
	transaction.rollback()
	_expect(_same(_file(final), old_final), "generation failure left the previous mesh intact")
	_expect(_same(_file(stale), old_stale), "generation failure left stale meshes intact")

func _check_validation_failure() -> void:
	var dir := ROOT + "/validation"
	var final := dir + "/mesh_00.res"
	var old_final := _seed(dir, final)
	var transaction := ResourceTransaction.new()
	transaction.prune(dir)
	transaction.inject_reload_error = true
	var error := transaction.save(_mesh(Vector3(0, 3, 0)), final, ResourceSaver.FLAG_COMPRESS)
	_expect(error != OK, "validation: failed staged resource is rejected")
	transaction.rollback()
	_expect(_same(_file(final), old_final), "validation failure left the previous mesh intact")

func _check_save_failure() -> void:
	var dir := ROOT + "/save"
	var final := dir + "/mesh_00.res"
	var old_final := _seed(dir, final)
	var transaction := ResourceTransaction.new()
	transaction.inject_save_error = true
	var error := transaction.save(_mesh(Vector3(0, 0, 4)), final, ResourceSaver.FLAG_COMPRESS)
	_expect(error != OK, "save: failure is reported")
	transaction.rollback()
	_expect(_same(_file(final), old_final), "save failure left the previous mesh intact")

func _check_commit_failure() -> void:
	var dir := ROOT + "/commit"
	var final := dir + "/mesh_00.res"
	var extra := dir + "/mesh_01.res"
	var stale := dir + "/mesh_99.res"
	var old_final := _seed(dir, final)
	var old_stale := _file(stale)
	var transaction := ResourceTransaction.new()
	transaction.prune(dir)
	_expect(transaction.save(_mesh(Vector3(5, 0, 0)), final, ResourceSaver.FLAG_COMPRESS) == OK, "commit: stage first mesh")
	_expect(transaction.save(_mesh(Vector3(0, 5, 0)), extra, ResourceSaver.FLAG_COMPRESS) == OK, "commit: stage second mesh")
	# Fail after the first file was already replaced, so restoring is exercised.
	transaction.fail_after_install = 1
	var error := transaction.commit()
	_expect(error != OK, "commit: injected failure is reported")
	_expect(_same(_file(final), old_final), "failed commit restored the replaced mesh")
	_expect(_same(_file(stale), old_stale), "failed commit kept the pruned mesh")
	_expect(not FileAccess.file_exists(extra), "failed commit removed the newly created mesh")

func _check_successful_commit() -> void:
	var dir := ROOT + "/success"
	var final := dir + "/mesh_00.res"
	var stale := dir + "/mesh_99.res"
	var old_final := _seed(dir, final)
	_expect(FileAccess.file_exists(stale), "success: seeded stale mesh")
	var transaction := ResourceTransaction.new()
	transaction.prune(dir)
	_expect(transaction.save(_mesh(Vector3(9, 0, 0)), final, ResourceSaver.FLAG_COMPRESS) == OK, "success: stage mesh")
	_expect(transaction.commit() == OK, "success: commit succeeds")
	_expect(not _same(_file(final), old_final), "success: committed mesh replaced the old one")
	_expect(not FileAccess.file_exists(stale), "success: stale mesh was pruned")

func _seed(dir: String, final: String) -> PackedByteArray:
	_clear(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var error := ResourceSaver.save(_mesh(Vector3(1, 0, 0)), final, ResourceSaver.FLAG_COMPRESS)
	_expect(error == OK, "seed previous output " + final)
	var stale := dir.path_join("mesh_99.res")
	_expect(ResourceSaver.save(_mesh(Vector3(0, 1, 0)), stale, ResourceSaver.FLAG_COMPRESS) == OK, "seed stale output " + stale)
	return _file(final)

func _mesh(offset: Vector3) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.add_vertex(offset)
	tool.add_vertex(offset + Vector3(1, 0, 0))
	tool.add_vertex(offset + Vector3(0, 1, 0))
	tool.generate_normals()
	return tool.commit()

func _file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)

func _same(a: PackedByteArray, b: PackedByteArray) -> bool:
	return a == b

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)

func _clear(path: String) -> void:
	if path.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(path)
	var project_root := ProjectSettings.globalize_path("res://")
	if absolute.is_empty() or absolute == "/" or absolute == project_root:
		return
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := absolute.path_join(name)
			if dir.current_is_dir():
				_clear(child)
			else:
				DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)
