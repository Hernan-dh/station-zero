extends VBoxContainer

const ArcLauncher = preload("res://scripts/components/arc_launcher.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
var _turret: ArcLauncher
var _status: Label
var _bearing_label: Label
var bearing_slider: HSlider
var power_button: Button
var auto_button: Button
var fire_button: Button

func bind(turret: ArcLauncher) -> void:
	_turret = turret
	InterfaceStyle.panel_separation(self)
	_status = InterfaceStyle.status(self, InterfaceStyle.TEAL)
	InterfaceStyle.label(self, "RANGE %.0f m   /   DAMAGE %.0f   /   CYCLE %.1f s" % [turret.attack_range, turret.damage, turret.recharge_time], InterfaceStyle.FONT_CAPTION, InterfaceStyle.MUTED, Vector2.ZERO)
	_bearing_label = InterfaceStyle.label(self, "", InterfaceStyle.FONT_BODY, InterfaceStyle.TEAL, Vector2.ZERO)
	bearing_slider = InterfaceStyle.slider(self, ArcLauncher.MIN_BEARING, ArcLauncher.MAX_BEARING, 1, "Aim manually; stops automatic tracking")
	bearing_slider.value_changed.connect(_turret.set_bearing)
	power_button = InterfaceStyle.button(self, "POWER", true)
	power_button.toggled.connect(_turret.set_powered)
	auto_button = InterfaceStyle.button(self, "AUTO TARGET", true)
	auto_button.toggled.connect(_turret.set_automatic)
	fire_button = InterfaceStyle.button(self, "TEST DISCHARGE")
	fire_button.tooltip_text = "Fire a harmless arc along the current bearing"
	fire_button.pressed.connect(_turret.test_fire)
	InterfaceStyle.bind_state(_turret.state_changed, _sync)

func _sync() -> void:
	_status.text = _turret.status_text()
	_bearing_label.text = "BEARING   %03d°" % roundi(fposmod(_turret.bearing, 360.0))
	bearing_slider.set_value_no_signal(_turret.bearing)
	power_button.set_pressed_no_signal(_turret.powered)
	power_button.text = "POWER ON" if _turret.powered else "POWER OFF"
	auto_button.set_pressed_no_signal(_turret.automatic)
	fire_button.disabled = not _turret.can_fire()
