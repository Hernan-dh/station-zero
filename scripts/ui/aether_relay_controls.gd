extends VBoxContainer

const AetherRelay = preload("res://scripts/components/aether_relay.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
var _relay: AetherRelay
var _status: Label
var _charge: ProgressBar
var power_button: Button
var pulse_button: Button

func bind(relay: AetherRelay) -> void:
	_relay = relay
	add_theme_constant_override("separation", 8)
	_status = InterfaceStyle.label(self, "", 11, Color("69e4fa"), Vector2.ZERO)
	InterfaceStyle.label(self, "CRYSTAL LATTICE ATTUNEMENT", 11, Color("eee1d7"), Vector2.ZERO)
	_charge = ProgressBar.new()
	_charge.custom_minimum_size = Vector2(285, 10)
	_charge.show_percentage = false
	add_child(_charge)
	power_button = Button.new()
	power_button.toggle_mode = true
	power_button.toggled.connect(relay.set_enabled)
	add_child(power_button)
	InterfaceStyle.style_button(power_button)
	pulse_button = Button.new()
	pulse_button.text = "TRANSMIT RESONANCE"
	pulse_button.tooltip_text = "Emit a visible pulse from the attuned crystal lattice."
	pulse_button.pressed.connect(relay.emit_resonance)
	add_child(pulse_button)
	InterfaceStyle.style_button(pulse_button)
	InterfaceStyle.label(self, "AETHER RELAY   /   CRYSTAL OBELISK NETWORK", 10, Color("aaadb5"), Vector2.ZERO)
	relay.state_changed.connect(_sync)
	_sync()

func _sync() -> void:
	_status.text = _relay.status_text()
	_charge.value = _relay.attunement * 100.0
	power_button.set_pressed_no_signal(_relay.enabled)
	power_button.text = "POWER DOWN RELAY" if _relay.enabled else "ATTUNE RELAY"
	pulse_button.disabled = not _relay.enabled or _relay.attunement < 1.0 or _relay.pulse > 0.0
