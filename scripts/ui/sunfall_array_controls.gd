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
	InterfaceStyle.panel_separation(self)
	_status = InterfaceStyle.status(self, InterfaceStyle.STATUS_GOLD)
	InterfaceStyle.label(self, "SOLAR FLUX CAPACITOR", InterfaceStyle.FONT_BODY, InterfaceStyle.IVORY, Vector2.ZERO)
	_charge = InterfaceStyle.progress(self, InterfaceStyle.BAR_HEIGHT)
	power_button = InterfaceStyle.button(self, "", true)
	power_button.toggled.connect(array.set_enabled)
	fire_button = InterfaceStyle.button(self, "FIRE ORBITAL BEAM")
	fire_button.tooltip_text = "Discharge the solar core into a visible orbital uplink. Recharges in %.0f seconds." % array.recharge_seconds
	fire_button.pressed.connect(array.fire_beam)
	InterfaceStyle.label(self, "SUNFALL ARRAY   /   ORBITAL BEAM PYLON", InterfaceStyle.FONT_CAPTION, InterfaceStyle.MUTED, Vector2.ZERO)
	InterfaceStyle.bind_state(array.state_changed, _sync)

func _sync() -> void:
	_status.text = _array.status_text()
	_charge.value = _array.charge * 100.0
	power_button.set_pressed_no_signal(_array.enabled)
	power_button.text = "POWER DOWN ARRAY" if _array.enabled else "ACTIVATE ARRAY"
	fire_button.disabled = not _array.enabled or _array.charge < 1.0 or _array.discharge > 0.0
