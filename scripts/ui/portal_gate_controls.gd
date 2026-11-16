extends VBoxContainer

const PortalGate = preload("res://scripts/components/portal_gate.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
var _gate: PortalGate
var _status: Label
var _aperture_label: Label
var _aperture_bar: ProgressBar
var power_button: Button
var pulse_button: Button

func bind(gate: PortalGate) -> void:
	_gate = gate
	add_theme_constant_override("separation", 8)
	_status = InterfaceStyle.label(self, "", 11, Color("c397ff"), Vector2.ZERO)
	_aperture_label = InterfaceStyle.label(self, "", 12, Color("eee1d7"), Vector2.ZERO)
	_aperture_bar = ProgressBar.new()
	_aperture_bar.custom_minimum_size = Vector2(285, 8)
	_aperture_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("a86bf5")
	_aperture_bar.add_theme_stylebox_override("fill", fill)
	add_child(_aperture_bar)
	power_button = Button.new()
	power_button.toggle_mode = true
	power_button.toggled.connect(gate.set_open)
	add_child(power_button)
	InterfaceStyle.style_button(power_button)
	pulse_button = Button.new()
	pulse_button.text = "RESONANCE PULSE"
	pulse_button.tooltip_text = "Send a visible energy ripple through the stable vortex."
	pulse_button.pressed.connect(gate.emit_resonance)
	add_child(pulse_button)
	InterfaceStyle.style_button(pulse_button)
	InterfaceStyle.label(self, "ANCIENT GATE   /   APPROACH SITE 03", 10, Color("aaadb5"), Vector2.ZERO)
	gate.state_changed.connect(_sync)
	_sync()

func _sync() -> void:
	_status.text = _gate.status_text()
	_aperture_label.text = "APERTURE   %03d%%" % roundi(_gate.aperture * 100.0)
	_aperture_bar.value = _gate.aperture * 100.0
	power_button.set_pressed_no_signal(_gate.requested_open)
	power_button.text = "CLOSE GATE" if _gate.requested_open else "OPEN GATE"
	pulse_button.disabled = not _gate.is_open() or _gate.pulse > 0.0
