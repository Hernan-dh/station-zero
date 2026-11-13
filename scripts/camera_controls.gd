extends Camera3D
## Orthographic orbit camera. Unhandled clicks are emitted for scene-specific picking.

signal selection_requested(screen_position: Vector2)
signal auto_orbit_changed(enabled: bool)

const CLICK_DISTANCE := 5.0

@export var yaw := 0.62
@export var pitch := 0.48
@export var zoom := 18.0
@export var camera_target := Vector3(0, 0.8, 0)

var dragging := false
var pan_button := MOUSE_BUTTON_NONE
var _auto_orbit := false
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
	update_camera()

func reset_view() -> void:
	yaw = _initial_yaw
	pitch = _initial_pitch
	zoom = _initial_zoom
	camera_target = _initial_target
	dragging = false
	click_pending = false
	pan_button = MOUSE_BUTTON_NONE
	set_auto_orbit(false)
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
	if _auto_orbit and pan_button == MOUSE_BUTTON_NONE:
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

func set_auto_orbit(enabled: bool) -> void:
	_auto_orbit = enabled
	auto_orbit_changed.emit(enabled)

func is_auto_orbit() -> bool:
	return _auto_orbit
