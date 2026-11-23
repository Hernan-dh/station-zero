extends RefCounted
## The metadata contract used by selection, baked picking and content builders.
## Keep these keys in one place: a typo here must fail loudly, not hide a node.

const DISPLAY_NAME := &"display_name"
const SELECTION_IGNORE := &"selection_ignore"
const ATTACHMENT_PATH := &"attachment_path"
const OCCUPIED := &"occupied"
const BUILD_RADIUS := &"build_radius"
const APPROACH := &"approach"
const TRAVEL_LENGTH := &"travel_length"
const ENTRANCE := &"entrance"
const MERGE_PIVOT := &"merge_pivot"
const MERGE_PROTECTED := &"merge_protected"
const PICKING_MOVING := &"picking_moving"
const PICKING_TERRAIN := &"picking_terrain"
const PICKING_CONCAVE := &"picking_concave"

static func display_name(node: Node) -> String:
	var value: Variant = node.get_meta(DISPLAY_NAME, "")
	return value if value is String else ""

static func has_display_name(node: Node) -> bool:
	return not display_name(node).strip_edges().is_empty()

static func set_display_name(node: Node, value: String) -> void:
	if value.strip_edges().is_empty():
		push_error("Selectable node %s has an empty display_name. Run the content builders again." % node.get_path())
		return
	node.set_meta(DISPLAY_NAME, value)

static func selection_ignored(node: Node) -> bool:
	var value: Variant = node.get_meta(SELECTION_IGNORE, false)
	return value if value is bool else false

static func set_selection_ignored(node: Node, ignored: bool) -> void:
	node.set_meta(SELECTION_IGNORE, ignored)

static func attachment_path(node: Node) -> NodePath:
	var value: Variant = node.get_meta(ATTACHMENT_PATH, NodePath())
	if value is NodePath:
		return value
	push_error("Picking body %s has a non-NodePath attachment_path." % node.get_path())
	return NodePath()

## Checks every contract key that selection or content discovery depends on.
## Returns the number of failures so callers can abort a bake.
static func validate(root: Node) -> int:
	var errors := 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node.has_meta(DISPLAY_NAME):
			var name: Variant = node.get_meta(DISPLAY_NAME)
			if not name is String or (name as String).strip_edges().is_empty():
				push_error("Invalid display_name on %s; selection cannot name this object." % node.get_path())
				errors += 1
		for flag in [SELECTION_IGNORE, MERGE_PIVOT, MERGE_PROTECTED, PICKING_MOVING, PICKING_TERRAIN, PICKING_CONCAVE]:
			if node.has_meta(flag) and not node.get_meta(flag) is bool:
				push_error("%s on %s must be a bool." % [flag, node.get_path()])
				errors += 1
		if node.has_meta(OCCUPIED) and not node.get_meta(OCCUPIED) is bool:
			push_error("occupied on %s must be a bool." % node.get_path())
			errors += 1
		if node.has_meta(BUILD_RADIUS) and not node.get_meta(BUILD_RADIUS) is float:
			push_error("build_radius on %s must be a float." % node.get_path())
			errors += 1
		if node.has_meta(APPROACH) and not node.get_meta(APPROACH) is String:
			push_error("approach on %s must be a string." % node.get_path())
			errors += 1
		if node.has_meta(ENTRANCE):
			var entrance: Variant = node.get_meta(ENTRANCE)
			if not entrance is NodePath or node.get_node_or_null(entrance) == null:
				push_error("entrance on %s does not resolve to a node." % node.get_path())
				errors += 1
		if node.is_in_group("defensive_build_sites"):
			if not has_display_name(node):
				push_error("Defense site %s needs a display_name." % node.get_path())
				errors += 1
			if not node.has_meta(OCCUPIED) or not node.get_meta(OCCUPIED) is bool:
				push_error("Defense site %s needs a bool occupied flag." % node.get_path())
				errors += 1
	return errors
