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
	InterfaceStyle.panel_separation(self)
	_status = InterfaceStyle.status(self, InterfaceStyle.STATUS_BLUE)
	InterfaceStyle.label(self, "CRYSTAL LATTICE ATTUNEMENT", InterfaceStyle.FONT_BODY, InterfaceStyle.IVORY, Vector2.ZERO)
	_charge = InterfaceStyle.progress(self, InterfaceStyle.BAR_HEIGHT)
	power_button = InterfaceStyle.button(self, "", true)
	power_button.toggled.connect(relay.set_enabled)
	pulse_button = InterfaceStyle.button(self, "TRANSMIT RESONANCE")
	pulse_button.tooltip_text = "Emit a visible pulse from the attuned crystal lattice."
	pulse_button.pressed.connect(relay.emit_resonance)
	InterfaceStyle.label(self, "AETHER RELAY   /   CRYSTAL OBELISK NETWORK", InterfaceStyle.FONT_CAPTION, InterfaceStyle.MUTED, Vector2.ZERO)
	InterfaceStyle.bind_state(relay.state_changed, _sync)

func _sync() -> void:
	_status.text = _relay.status_text()
	_charge.value = _relay.attunement * 100.0
	power_button.set_pressed_no_signal(_relay.enabled)
	power_button.text = "POWER DOWN RELAY" if _relay.enabled else "ATTUNE RELAY"
	pulse_button.disabled = not _relay.enabled or _relay.attunement < 1.0 or _relay.pulse > 0.0
