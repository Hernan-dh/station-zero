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
	controls.position = InterfaceStyle.CAMERA_BUTTON_OFFSET
	controls.add_theme_constant_override("separation", InterfaceStyle.CAMERA_BUTTON_SEPARATION)
	ui.add_child(controls)
	orbit_button = InterfaceStyle.button(controls, "  AUTO ORBIT  ", true)
	orbit_button.toggled.connect(camera.set_auto_orbit)
	var reset := InterfaceStyle.button(controls, "  RESET VIEW  ")
	reset.pressed.connect(camera.reset_view)
	var hint := InterfaceStyle.label(ui, "CLICK TO SELECT   ·   DRAG TO ORBIT   ·   RIGHT DRAG / SHIFT + DRAG TO PAN   ·   SCROLL TO ZOOM", InterfaceStyle.FONT_BODY, InterfaceStyle.MUTED, Vector2.ZERO)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = InterfaceStyle.CAMERA_HINT_LEFT
	hint.offset_top = InterfaceStyle.CAMERA_HINT_TOP
	hint.offset_right = InterfaceStyle.CAMERA_HINT_RIGHT
	hint.offset_bottom = InterfaceStyle.CAMERA_HINT_BOTTOM

	camera.auto_orbit_changed.connect(_sync_orbit)
	_sync_orbit(camera.is_auto_orbit())

func _sync_orbit(enabled: bool) -> void:
	orbit_button.set_pressed_no_signal(enabled)
