extends VBoxContainer

const CommunicationsArray = preload("res://scripts/components/communications_array.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
const TEAL = InterfaceStyle.TEAL
var bearing_slider: HSlider
var elevation_slider: HSlider
var sweep_button: Button
var _bearing_label: Label
var _elevation_label: Label
var _array: CommunicationsArray

func bind(communications_array: CommunicationsArray) -> void:
	_array = communications_array
	InterfaceStyle.panel_separation(self)
	_bearing_label = InterfaceStyle.label(self, "", InterfaceStyle.FONT_BODY, TEAL, Vector2.ZERO)
	bearing_slider = InterfaceStyle.slider(self, CommunicationsArray.MIN_BEARING, CommunicationsArray.MAX_BEARING, 1, "Rotate the base around the deck mount")
	bearing_slider.name = "BaseBearing"
	bearing_slider.value_changed.connect(_array.set_bearing)
	_elevation_label = InterfaceStyle.label(self, "", InterfaceStyle.FONT_BODY, TEAL, Vector2.ZERO)
	elevation_slider = InterfaceStyle.slider(self, CommunicationsArray.MIN_ELEVATION, CommunicationsArray.MAX_ELEVATION, 1, "Tilt the dish independently, from horizon to near zenith")
	elevation_slider.name = "DishElevation"
	elevation_slider.value_changed.connect(_array.set_elevation)
	sweep_button = InterfaceStyle.button(self, "AUTO SWEEP", true)
	sweep_button.tooltip_text = "Rotate the base continuously while holding dish elevation"
	sweep_button.toggled.connect(_array.set_sweeping)
	InterfaceStyle.bind_state(_array.state_changed, _sync_state)

func _sync_state() -> void:
	var bearing := _array.get_bearing()
	var elevation := _array.get_elevation()
	_bearing_label.text = "BASE BEARING   %03d°" % roundi(fposmod(bearing, 360.0))
	_elevation_label.text = "DISH ELEVATION   %02d°" % roundi(elevation)
	bearing_slider.set_value_no_signal(bearing)
	elevation_slider.set_value_no_signal(elevation)
	sweep_button.set_pressed_no_signal(_array.is_sweeping())
