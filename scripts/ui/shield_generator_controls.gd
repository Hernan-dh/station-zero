extends VBoxContainer

const ShieldGenerator = preload("res://scripts/components/shield_generator.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
const ComponentStyle = preload("res://scripts/component_style.gd")
var _generator: ShieldGenerator
var _status: Label
var _charge_label: Label
var _charge_bar: ProgressBar
var power_button: Button
var impact_button: Button

func bind(generator: ShieldGenerator) -> void:
	_generator = generator
	InterfaceStyle.panel_separation(self)
	_status = InterfaceStyle.status(self, InterfaceStyle.TEAL)
	_charge_label = InterfaceStyle.label(self, "", InterfaceStyle.FONT_VALUE, InterfaceStyle.IVORY, Vector2.ZERO)
	_charge_bar = InterfaceStyle.progress(self, InterfaceStyle.BAR_HEIGHT_SMALL, InterfaceStyle.TEAL, InterfaceStyle.BAR_BG)
	_charge_bar.max_value = generator.capacity
	InterfaceStyle.label(self, "RADIUS %.1f m   /   RECHARGE %.0f / s" % [generator.shield_radius, generator.recharge_rate], InterfaceStyle.FONT_CAPTION, InterfaceStyle.MUTED, Vector2.ZERO)
	power_button = InterfaceStyle.button(self, "POWER ON", true)
	power_button.toggled.connect(generator.set_powered)
	var impact := int(ComponentStyle.SHIELD_IMPACT_AMOUNT)
	impact_button = InterfaceStyle.button(self, "TEST IMPACT  /  %d" % impact)
	impact_button.tooltip_text = "Apply %d shield damage." % impact
	impact_button.pressed.connect(generator.test_impact)
	InterfaceStyle.label(self, "Overload: %.0f s delay, then rebuild to %d%%." % [generator.collapse_delay, roundi(ComponentStyle.SHIELD_RESTORE_FRACTION * 100)], InterfaceStyle.FONT_CAPTION, InterfaceStyle.MUTED, Vector2.ZERO)
	InterfaceStyle.bind_state(generator.state_changed, _sync)

func _sync() -> void:
	_status.text = _generator.status_text()
	_charge_label.text = "SHIELD   %03d / %03d" % [roundi(_generator.charge), roundi(_generator.capacity)]
	_charge_bar.value = _generator.charge
	power_button.set_pressed_no_signal(_generator.powered)
	power_button.text = "POWER ON" if _generator.powered else "POWER OFF"
	impact_button.disabled = not _generator.is_active()
