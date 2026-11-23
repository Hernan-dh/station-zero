extends RefCounted
## Failure-safe output for the content generators.
##
## Generated resources are written to a staging directory first and only moved
## into their final paths when the whole rebuild commits. A failed generation,
## validation or save therefore leaves the previous output untouched. If the
## commit itself fails part-way through, every replaced or pruned file is
## restored from a backup before the error is reported.
##
## Paths are res:// paths because packed scenes must reference the final path.

const STAGE_ROOT := "res://tmp/rebuild_transaction"

var last_error_message := ""

var _stage_dir := ""
var _backup_dir := ""
var _entries: Dictionary = {}
var _pruned: Dictionary = {}
var _committed := false

## Test hooks used by check_rebuild_safety.gd. They make the failure paths
## deterministic without needing an unwritable disk or a corrupt source file.
var inject_save_error := false
var inject_reload_error := false
## Fail after this many staged files have been installed (negative is off).
var fail_after_install := -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _committed:
		rollback()

func save(resource: Resource, final_path: String, flags := 0) -> Error:
	return OK if _stage(resource, final_path, flags) != null else ERR_FILE_CANT_WRITE

func save_and_load(resource: Resource, final_path: String, flags := 0) -> Resource:
	return _stage(resource, final_path, flags)

## Remove generated files of this type that the rebuild no longer produces.
## Nothing is deleted until commit, so a failed rebuild keeps the old files.
func prune(directory: String) -> void:
	_pruned[directory] = true

func commit() -> Error:
	if _committed:
		return OK
	if _entries.is_empty() and _pruned.is_empty():
		rollback()
		return OK
	var stage := _ensure_stage_root()
	_backup_dir = stage + "_backup"
	_remove_tree(_backup_dir)
	if _dir_error(_backup_dir) != OK:
		return _fail("Could not create the rebuild backup directory.")
	var backups := {}
	var replaced: Dictionary = {}
	var all_final := _entry_paths()
	for path in _pruned:
		for existing in _directory_files(path):
			if not _entries.has(existing):
				all_final.append(existing)
	for path in all_final:
		if not FileAccess.file_exists(path):
			continue
		var backup := _backup_name(path)
		var error := DirAccess.copy_absolute(_global(path), _global(backup))
		if error != OK:
			_restore(backups, {})
			return _fail("Could not back up %s before rebuilding." % path)
		backups[path] = backup
	# Install the new files with their final paths. The scene was packed while
	# their resources already pointed at these paths, so the references stay valid.
	var installed := 0
	for path in _entries:
		var entry: Dictionary = _entries[path]
		_dir_error(path.get_base_dir())
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(_global(path))
		var error := _install(entry.temp, path)
		if error != OK:
			_restore(backups, replaced)
			return _fail("Could not write %s." % path)
		replaced[path] = true
		installed += 1
		if fail_after_install >= 0 and installed >= fail_after_install:
			_restore(backups, replaced)
			return _fail("Simulated commit failure.")
	for path in all_final:
		if _entries.has(path):
			continue
		DirAccess.remove_absolute(_global(path))
	_committed = true
	_remove_tree(_backup_dir)
	_remove_tree(_stage_dir)
	_entries.clear()
	_pruned.clear()
	return OK

func rollback() -> void:
	_remove_tree(_stage_dir)
	_remove_tree(_backup_dir)
	_entries.clear()
	_pruned.clear()

func _stage(resource: Resource, final_path: String, flags: int) -> Resource:
	last_error_message = ""
	if _committed:
		last_error_message = "Cannot stage %s after the rebuild committed." % final_path
		return null
	if inject_save_error:
		last_error_message = "Simulated save failure for %s." % final_path
		return null
	var root := _ensure_stage_root()
	if _dir_error(root) != OK:
		last_error_message = "Could not create the rebuild staging directory."
		return null
	var temp := "%s/%s_%s" % [root, final_path.md5_text(), final_path.get_file()]
	var error := ResourceSaver.save(resource, temp, flags)
	if error != OK:
		last_error_message = "Could not save staged %s: %s" % [final_path, error_string(error)]
		return null
	if inject_reload_error:
		last_error_message = "Simulated validation failure for %s." % final_path
		return null
	var reloaded := ResourceLoader.load(temp, "", ResourceLoader.CACHE_MODE_IGNORE)
	if reloaded == null:
		last_error_message = "Could not reload staged %s for validation." % final_path
		return null
	# Claim the final path now so packed scenes serialize the path they will
	# actually have after the commit.
	reloaded.take_over_path(final_path)
	_entries[final_path] = {"temp": temp}
	return reloaded

func _ensure_stage_root() -> String:
	if _stage_dir.is_empty():
		_stage_dir = "%s_%d_%d" % [STAGE_ROOT, OS.get_process_id(), Time.get_ticks_usec()]
	return _stage_dir

func _entry_paths() -> Array[String]:
	var result: Array[String] = []
	for path in _entries:
		result.append(path)
	return result

func _directory_files(directory: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(_global(directory))
	if dir == null:
		return result
	for name in dir.get_files():
		if name.ends_with(".res"):
			result.append(directory.path_join(name))
	return result

func _backup_name(path: String) -> String:
	return "%s/%s_%s" % [_backup_dir, path.md5_text(), path.get_file()]

func _install(temp: String, final_path: String) -> Error:
	var error := DirAccess.rename_absolute(_global(temp), _global(final_path))
	if error == OK:
		return OK
	error = DirAccess.copy_absolute(_global(temp), _global(final_path))
	if error == OK:
		DirAccess.remove_absolute(_global(temp))
	return error

## Restore every file an attempted commit touched. Paths with a backup are put
## back exactly; files that did not exist before are removed again.
func _restore(backups: Dictionary, replaced: Dictionary) -> void:
	for path in replaced:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(_global(path))
	for path in backups:
		var backup: String = backups[path]
		_dir_error(path.get_base_dir())
		DirAccess.copy_absolute(_global(backup), _global(path))
	_remove_tree(_backup_dir)
	_remove_tree(_stage_dir)
	_entries.clear()
	_pruned.clear()

func _dir_error(path: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(_global(path))
	return error

func _fail(message: String) -> Error:
	last_error_message = message
	return ERR_FILE_CANT_WRITE

func _global(path: String) -> String:
	if path.is_empty():
		return ""
	return ProjectSettings.globalize_path(path)

## Guarded recursive delete: an empty or project-root path must never remove
## the workspace. All temporary paths live below res://tmp.
func _remove_tree(path: String) -> void:
	if path.is_empty():
		return
	var absolute := _global(path)
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
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)
