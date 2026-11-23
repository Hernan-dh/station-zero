extends CanvasLayer
## Picks metadata-tagged objects under selection_root and displays optional custom controls.

signal selection_changed(target: Node3D)

const InterfaceStyle = preload("res://scripts/interface_style.gd")
const Metadata = preload("res://scripts/metadata.gd")
const TEAL = InterfaceStyle.TEAL
const IVORY = InterfaceStyle.IVORY

@export var camera: Camera3D
@export var selection_root: Node3D
@export var picking_geometry: PackedScene

var _picking_prepared := false

var selected_object: Node3D
var selection_panel: PanelContainer
var selection_name: Label
var selection_material: StandardMaterial3D
var _info: VBoxContainer
var _object_controls: Dictionary = {}

func _ready() -> void:
	build_interface()
	selection_material = StandardMaterial3D.new()
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.albedo_color = Color(TEAL, InterfaceStyle.SELECTION_OVERLAY_ALPHA)
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func prepare_selection() -> void:
	if _picking_prepared or picking_geometry == null:
		return
	# Offline-baked bodies are already consolidated. Attach them to their original
	# branches so ancestry selection and animated parts keep working unchanged.
	var baked := picking_geometry.instantiate()
	for body in baked.get_children():
		var path := Metadata.attachment_path(body)
		if path.is_empty():
			continue
		var attachment := selection_root.get_node_or_null(path)
		if attachment == null:
			push_error("Stale picking bake: missing %s. Run scripts/tools/bake_picking.gd." % path)
			continue
		body.owner = null
		baked.remove_child(body)
		attachment.add_child(body)
	baked.free()
	_picking_prepared = true

func add_object_controls(target: Node3D, controls: Control, panel_top: float) -> void:
	_info.add_child(controls)
	_object_controls[target] = {"control": controls, "panel_top": panel_top}
	controls.visible = target == selected_object

func select_at(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * camera.far)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node3D = null
	if not hit.is_empty():
		var node: Node = hit.collider
		while node != null and node != selection_root and selection_root.is_ancestor_of(node):
			if Metadata.has_display_name(node):
				target = node as Node3D
				break
			node = node.get_parent()
	set_selection(target)

func set_selection(target: Node3D) -> void:
	if target != null and not Metadata.has_display_name(target):
		push_error("Selectable node %s has no valid display_name metadata." % target.get_path())
		target = null
	if is_instance_valid(selected_object):
		for mesh in selected_object.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = null
	selected_object = target
	selection_panel.visible = target != null
	selection_panel.offset_top = InterfaceStyle.SELECTION_TOP
	for object in _object_controls:
		var entry: Dictionary = _object_controls[object]
		entry.control.visible = object == target
		if object == target:
			selection_panel.offset_top = entry.panel_top
	if target != null:
		selection_name.text = Metadata.display_name(target)
		for mesh in target.find_children("*", "MeshInstance3D", true, false):
			if Metadata.selection_ignored(mesh):
				continue
			mesh.material_overlay = selection_material
	selection_changed.emit(target)

func build_interface() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	selection_panel = PanelContainer.new()
	selection_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	selection_panel.offset_left = InterfaceStyle.SELECTION_LEFT
	selection_panel.offset_top = InterfaceStyle.SELECTION_TOP
	selection_panel.offset_right = InterfaceStyle.SELECTION_RIGHT
	selection_panel.offset_bottom = InterfaceStyle.SELECTION_BOTTOM
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = InterfaceStyle.PANEL_BG
	panel_style.border_color = TEAL
	panel_style.set_border_width_all(InterfaceStyle.SELECTION_BORDER_WIDTH)
	panel_style.content_margin_left = InterfaceStyle.PANEL_PADDING
	panel_style.content_margin_right = InterfaceStyle.PANEL_PADDING
	panel_style.content_margin_top = InterfaceStyle.SELECTION_CONTENT_MARGIN
	panel_style.content_margin_bottom = InterfaceStyle.SELECTION_CONTENT_MARGIN
	selection_panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(selection_panel)
	_info = VBoxContainer.new()
	_info.custom_minimum_size.x = InterfaceStyle.CONTROL_WIDTH
	_info.add_theme_constant_override("separation", InterfaceStyle.SELECTION_SEPARATION)
	selection_panel.add_child(_info)
	InterfaceStyle.label(_info, "SELECTED OBJECT", InterfaceStyle.FONT_CAPTION, TEAL, Vector2.ZERO)
	selection_name = InterfaceStyle.label(_info, "", InterfaceStyle.FONT_NAME, IVORY, Vector2.ZERO)
	selection_panel.hide()
