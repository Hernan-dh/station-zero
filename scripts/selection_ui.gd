extends CanvasLayer
## Picks metadata-tagged objects under selection_root and displays optional custom controls.

signal selection_changed(target: Node3D)

const InterfaceStyle = preload("res://scripts/interface_style.gd")
const TEAL = Color("67eddb")
const IVORY = Color("d7ddcd")

@export var camera: Camera3D
@export var selection_root: Node3D

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
	selection_material.albedo_color = Color(TEAL, 0.3)
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func prepare_selection() -> void:
	# Geometry-accurate colliders keep gaps empty and respect occlusion.
	for node in selection_root.find_children("*", "MeshInstance3D", true, false):
		node.create_trimesh_collision()

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
			if node.has_meta("display_name"):
				target = node as Node3D
				break
			node = node.get_parent()
	set_selection(target)

func set_selection(target: Node3D) -> void:
	if is_instance_valid(selected_object):
		for mesh in selected_object.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = null
	selected_object = target
	selection_panel.visible = target != null
	selection_panel.offset_top = -176
	for object in _object_controls:
		var entry: Dictionary = _object_controls[object]
		entry.control.visible = object == target
		if object == target:
			selection_panel.offset_top = entry.panel_top
	if target != null:
		selection_name.text = target.get_meta("display_name")
		for mesh in target.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = selection_material
	selection_changed.emit(target)

func build_interface() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	selection_panel = PanelContainer.new()
	selection_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	selection_panel.offset_left = 40
	selection_panel.offset_top = -176
	selection_panel.offset_right = 304
	selection_panel.offset_bottom = -96
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("142334")
	panel_style.border_color = TEAL
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	selection_panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(selection_panel)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 5)
	selection_panel.add_child(_info)
	InterfaceStyle.label(_info, "SELECTED OBJECT", 10, TEAL, Vector2.ZERO)
	selection_name = InterfaceStyle.label(_info, "", 18, IVORY, Vector2.ZERO)
	selection_panel.hide()
