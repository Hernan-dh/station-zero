extends CanvasLayer

const InterfaceStyle = preload("res://scripts/interface_style.gd")
const BeaconControls = preload("res://scripts/ui/beacon_controls.gd")
const ArrayControls = preload("res://scripts/ui/array_controls.gd")
const SelectionUI = preload("res://scripts/selection_ui.gd")
const Beacon = preload("res://scripts/components/navigation_beacon.gd")
const CommunicationsArray = preload("res://scripts/components/communications_array.gd")
const ArcLauncher = preload("res://scripts/components/arc_launcher.gd")
const ArcLauncherControls = preload("res://scripts/ui/arc_launcher_controls.gd")
const IVORY = Color("eee1d7")
const TEAL = Color("42e0df")

@export var selection_ui: SelectionUI
@export var beacon: Beacon
@export var communications_array: CommunicationsArray
@export var arc_launcher: ArcLauncher

func _ready() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	InterfaceStyle.label(ui, "S T A T I O N   Z E R O", 25, IVORY, Vector2(38, 31))
	InterfaceStyle.label(ui, "SELENE REACH   /   CRYSTAL HIGHLANDS", 11, Color("aaadb5"), Vector2(40, 68))
	var accent := ColorRect.new()
	accent.position = Vector2(40, 25)
	accent.size = Vector2(44, 2)
	accent.color = Color("efac51")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(accent)
	var beacon_controls := BeaconControls.new()
	beacon_controls.bind(beacon)
	selection_ui.add_object_controls(beacon, beacon_controls, -220)
	var array_controls := ArrayControls.new()
	array_controls.bind(communications_array)
	selection_ui.add_object_controls(communications_array, array_controls, -350)
	var arc_controls := ArcLauncherControls.new()
	arc_controls.bind(arc_launcher)
	selection_ui.add_object_controls(arc_launcher, arc_controls, -410)
	var footer := Control.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.position.y = -72
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(footer)
	InterfaceStyle.label(footer, "●  OUTPOST ONLINE", 12, TEAL, Vector2(40, 0))
	InterfaceStyle.label(footer, "SECTOR 00   /   MOONPASS DEFENSE", 11, Color("aaadb5"), Vector2(40, 23))

