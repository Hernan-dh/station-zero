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
	add_theme_constant_override("separation", 8)
	_status = InterfaceStyle.label(self, "", 11, Color("67eddb"), Vector2.ZERO)
	InterfaceStyle.label(self, "RANGE %.0f m   /   DAMAGE %.0f   /   CYCLE %.1f s" % [turret.attack_range, turret.damage, turret.recharge_time], 10, Color("7e99ac"), Vector2.ZERO)
	_bearing_label = InterfaceStyle.label(self, "", 11, Color("67eddb"), Vector2.ZERO)
	bearing_slider = HSlider.new()
	bearing_slider.min_value = -180
	bearing_slider.max_value = 180
	bearing_slider.step = 1
	bearing_slider.custom_minimum_size = Vector2(285, 20)
	bearing_slider.tooltip_text = "Aim manually; stops automatic tracking"
	bearing_slider.value_changed.connect(_turret.set_bearing)
	add_child(bearing_slider)
	power_button = _button("POWER", true)
	power_button.toggled.connect(_turret.set_powered)
	auto_button = _button("AUTO TARGET", true)
	auto_button.toggled.connect(_turret.set_automatic)
	fire_button = _button("TEST DISCHARGE", false)
	fire_button.tooltip_text = "Fire a harmless arc along the current bearing"
	fire_button.pressed.connect(_turret.test_fire)
	_turret.state_changed.connect(_sync)
	_sync()

func _button(title: String, toggle: bool) -> Button:
	var button := Button.new()
	button.text = title
	button.toggle_mode = toggle
	add_child(button)
	InterfaceStyle.style_button(button)
	return button

func _sync() -> void:
	_status.text = _turret.status_text()
	_bearing_label.text = "BEARING   %03d°" % roundi(fposmod(_turret.bearing, 360.0))
	bearing_slider.set_value_no_signal(_turret.bearing)
	power_button.set_pressed_no_signal(_turret.powered)
	power_button.text = "POWER ON" if _turret.powered else "POWER OFF"
	auto_button.set_pressed_no_signal(_turret.automatic)
	fire_button.disabled = not _turret.can_fire()
