extends Camera3D
## Orthographic orbit camera. Unhandled clicks are emitted for scene-specific picking.

signal selection_requested(screen_position: Vector2)

const InterfaceStyle = preload("res://scripts/interface_style.gd")
const CLICK_DISTANCE := 5.0

@export var yaw := 0.62
@export var pitch := 0.48
@export var zoom := 18.0
@export var camera_target := Vector3(0, 0.8, 0)

var dragging := false
var pan_button := MOUSE_BUTTON_NONE
var auto_orbit := false
var orbit_button: Button
var click_origin := Vector2.ZERO
var click_pending := false
var _initial_yaw: float
var _initial_pitch: float
var _initial_zoom: float
var _initial_target: Vector3

func _ready() -> void:
	_initial_yaw = yaw
	_initial_pitch = pitch
	_initial_zoom = zoom
	_initial_target = camera_target
	build_interface()
	update_camera()

func build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position = Vector2(-365, -65)
	controls.add_theme_constant_override("separation", 12)
	ui.add_child(controls)
	orbit_button = Button.new()
	orbit_button.text = "  AUTO ORBIT  "
	orbit_button.toggle_mode = true
	orbit_button.toggled.connect(func(value: bool): auto_orbit = value)
	controls.add_child(orbit_button)
	var reset := Button.new()
	reset.text = "  RESET VIEW  "
	reset.pressed.connect(reset_view)
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

func reset_view() -> void:
	yaw = _initial_yaw
	pitch = _initial_pitch
	zoom = _initial_zoom
	camera_target = _initial_target
	dragging = false
	click_pending = false
	pan_button = MOUSE_BUTTON_NONE
	auto_orbit = false
	orbit_button.button_pressed = false
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				click_pending = false
				if event.shift_pressed:
					pan_button = MOUSE_BUTTON_LEFT
					dragging = false
				elif pan_button == MOUSE_BUTTON_NONE:
					dragging = true
					click_origin = event.position
					click_pending = true
			else:
				if click_pending and event.position.distance_to(click_origin) <= CLICK_DISTANCE:
					selection_requested.emit(event.position)
				click_pending = false
				dragging = false
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			click_pending = false
			pan_button = MOUSE_BUTTON_RIGHT
			dragging = false
		if event.button_index == pan_button and not event.pressed:
			pan_button = MOUSE_BUTTON_NONE
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(12, zoom - 1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(32, zoom + 1)
	if event is InputEventMouseMotion:
		if pan_button != MOUSE_BUTTON_NONE:
			# Move in the camera's screen plane so the outpost follows the drag.
			# Projection accounts for orthographic zoom and viewport aspect ratio.
			camera_target += project_position(Vector2.ZERO, 28.0) - project_position(event.relative, 28.0)
		elif dragging:
			if click_pending and event.position.distance_to(click_origin) <= CLICK_DISTANCE:
				return
			click_pending = false
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch + event.relative.y * 0.004, 0.15, 1.15)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_view()
	update_camera()

func update_camera() -> void:
	global_position = camera_target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 28
	size = zoom
	look_at(camera_target)

func _process(delta: float) -> void:
	if auto_orbit and pan_button == MOUSE_BUTTON_NONE:
		yaw += delta * 0.08
		update_camera()
	# Release reliably even if the cursor crosses a UI control.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		click_pending = false
	if pan_button != MOUSE_BUTTON_NONE and not Input.is_mouse_button_pressed(pan_button):
		pan_button = MOUSE_BUTTON_NONE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		click_pending = false
		pan_button = MOUSE_BUTTON_NONE
