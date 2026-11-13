extends Button

const Beacon = preload("res://scripts/components/navigation_beacon.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
var _beacon: Beacon

func bind(beacon: Beacon) -> void:
	_beacon = beacon
	toggle_mode = true
	custom_minimum_size.y = 36
	InterfaceStyle.style_button(self)
	toggled.connect(_beacon.set_enabled)
	_beacon.state_changed.connect(_sync_state)
	_sync_state()

func _sync_state() -> void:
	var enabled := _beacon.is_enabled()
	set_pressed_no_signal(enabled)
	text = "BEACON ON  ·  TURN OFF" if enabled else "BEACON OFF  ·  TURN ON"
