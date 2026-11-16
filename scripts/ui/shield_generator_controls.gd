extends VBoxContainer

const ShieldGenerator = preload("res://scripts/components/shield_generator.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
var _generator: ShieldGenerator
var _status: Label
var _charge_label: Label
var _charge_bar: ProgressBar
var power_button: Button
var impact_button: Button

func bind(generator: ShieldGenerator) -> void:
	_generator = generator
	add_theme_constant_override("separation", 8)
	_status = InterfaceStyle.label(self, "", 11, Color("42e0df"), Vector2.ZERO)
	_charge_label = InterfaceStyle.label(self, "", 12, Color("eee1d7"), Vector2.ZERO)
	_charge_bar = ProgressBar.new()
	_charge_bar.custom_minimum_size = Vector2(285, 8)
	_charge_bar.show_percentage = false
	_charge_bar.max_value = generator.capacity
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("42e0df")
	_charge_bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("303744")
	_charge_bar.add_theme_stylebox_override("background", background)
	add_child(_charge_bar)
	InterfaceStyle.label(self, "RADIUS %.1f m   /   RECHARGE %.0f / s" % [generator.shield_radius, generator.recharge_rate], 10, Color("aaadb5"), Vector2.ZERO)
	power_button = _button("POWER ON", true)
	power_button.toggled.connect(generator.set_powered)
	impact_button = _button("TEST IMPACT  /  60", false)
	impact_button.tooltip_text = "Apply 60 shield damage. Four hits overload a fully charged field."
	impact_button.pressed.connect(generator.test_impact)
	InterfaceStyle.label(self, "Overload: %.0f s delay, then rebuild to 25%%." % generator.collapse_delay, 10, Color("aaadb5"), Vector2.ZERO)
	generator.state_changed.connect(_sync)
	_sync()

func _button(title: String, toggle: bool) -> Button:
	var button := Button.new()
	button.text = title
	button.toggle_mode = toggle
	add_child(button)
	InterfaceStyle.style_button(button)
	return button

func _sync() -> void:
	_status.text = _generator.status_text()
	_charge_label.text = "SHIELD   %03d / %03d" % [roundi(_generator.charge), roundi(_generator.capacity)]
	_charge_bar.value = _generator.charge
	power_button.set_pressed_no_signal(_generator.powered)
	power_button.text = "POWER ON" if _generator.powered else "POWER OFF"
	impact_button.disabled = not _generator.is_active()
