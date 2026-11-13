extends CanvasLayer

const InterfaceStyle = preload("res://scripts/interface_style.gd")
const CameraController = preload("res://scripts/camera_controls.gd")

@export var camera: CameraController
var orbit_button: Button

func _ready() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position = Vector2(-365, -65)
	controls.add_theme_constant_override("separation", 12)
	ui.add_child(controls)
	orbit_button = Button.new()
	orbit_button.text = "  AUTO ORBIT  "
	orbit_button.toggle_mode = true
	orbit_button.toggled.connect(camera.set_auto_orbit)
	controls.add_child(orbit_button)
	var reset := Button.new()
	reset.text = "  RESET VIEW  "
	reset.pressed.connect(camera.reset_view)
	controls.add_child(reset)
	InterfaceStyle.style_button(orbit_button)
	InterfaceStyle.style_button(reset)
	var hint := InterfaceStyle.label(ui, "CLICK TO SELECT   ·   DRAG TO ORBIT   ·   RIGHT DRAG / SHIFT + DRAG TO PAN   ·   SCROLL TO ZOOM", 11, Color("7e99ac"), Vector2.ZERO)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -730
	hint.offset_top = 40
	hint.offset_right = -38
	hint.offset_bottom = 60

	camera.auto_orbit_changed.connect(_sync_orbit)
	_sync_orbit(camera.is_auto_orbit())

func _sync_orbit(enabled: bool) -> void:
	orbit_button.set_pressed_no_signal(enabled)
