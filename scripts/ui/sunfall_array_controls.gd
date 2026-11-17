extends VBoxContainer

const SunfallArray = preload("res://scripts/components/sunfall_array.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
var _array: SunfallArray
var _status: Label
var _charge: ProgressBar
var power_button: Button
var fire_button: Button

func bind(array: SunfallArray) -> void:
	_array = array
	add_theme_constant_override("separation", 8)
	_status = InterfaceStyle.label(self, "", 11, Color("ffd081"), Vector2.ZERO)
	InterfaceStyle.label(self, "SOLAR FLUX CAPACITOR", 11, Color("eee1d7"), Vector2.ZERO)
	_charge = ProgressBar.new()
	_charge.custom_minimum_size = Vector2(285, 10)
	_charge.show_percentage = false
	add_child(_charge)
	power_button = Button.new()
	power_button.toggle_mode = true
	power_button.toggled.connect(array.set_enabled)
	add_child(power_button)
	InterfaceStyle.style_button(power_button)
	fire_button = Button.new()
	fire_button.text = "FIRE ORBITAL BEAM"
	fire_button.tooltip_text = "Discharge the solar core into a visible orbital uplink. Recharges in 6 seconds."
	fire_button.pressed.connect(array.fire_beam)
	add_child(fire_button)
	InterfaceStyle.style_button(fire_button)
	InterfaceStyle.label(self, "SUNFALL ARRAY   /   ORBITAL BEAM PYLON", 10, Color("aaadb5"), Vector2.ZERO)
	array.state_changed.connect(_sync)
	_sync()

func _sync() -> void:
	_status.text = _array.status_text()
	_charge.value = _array.charge * 100.0
	power_button.set_pressed_no_signal(_array.enabled)
	power_button.text = "POWER DOWN ARRAY" if _array.enabled else "ACTIVATE ARRAY"
	fire_button.disabled = not _array.enabled or _array.charge < 1.0 or _array.discharge > 0.0
