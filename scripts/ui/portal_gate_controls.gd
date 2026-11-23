extends VBoxContainer

const PortalGate = preload("res://scripts/components/portal_gate.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
const Layout = preload("res://scripts/world_layout.gd")
var _gate: PortalGate
var _status: Label
var _aperture_label: Label
var _aperture_bar: ProgressBar
var power_button: Button
var pulse_button: Button

func bind(gate: PortalGate) -> void:
	_gate = gate
	InterfaceStyle.panel_separation(self)
	_status = InterfaceStyle.status(self, InterfaceStyle.STATUS_VIOLET)
	_aperture_label = InterfaceStyle.label(self, "", InterfaceStyle.FONT_VALUE, InterfaceStyle.IVORY, Vector2.ZERO)
	_aperture_bar = InterfaceStyle.progress(self, InterfaceStyle.BAR_HEIGHT_SMALL, InterfaceStyle.PORTAL_FILL)
	power_button = InterfaceStyle.button(self, "", true)
	power_button.toggled.connect(gate.set_open)
	pulse_button = InterfaceStyle.button(self, "RESONANCE PULSE")
	pulse_button.tooltip_text = "Send a visible energy ripple through the stable vortex."
	pulse_button.pressed.connect(gate.emit_resonance)
	var site_number := maxi(1, Layout.CLEARING_NODES.find("PortalGate") + 1)
	InterfaceStyle.label(self, "ANCIENT GATE   /   APPROACH SITE %02d" % site_number, InterfaceStyle.FONT_CAPTION, InterfaceStyle.MUTED, Vector2.ZERO)
	InterfaceStyle.bind_state(gate.state_changed, _sync)

func _sync() -> void:
	_status.text = _gate.status_text()
	_aperture_label.text = "APERTURE   %03d%%" % roundi(_gate.aperture * 100.0)
	_aperture_bar.value = _gate.aperture * 100.0
	power_button.set_pressed_no_signal(_gate.requested_open)
	power_button.text = "CLOSE GATE" if _gate.requested_open else "OPEN GATE"
	pulse_button.disabled = not _gate.is_open() or _gate.pulse > 0.0
