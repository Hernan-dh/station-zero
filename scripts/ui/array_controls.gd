extends VBoxContainer

const CommunicationsArray = preload("res://scripts/components/communications_array.gd")
const InterfaceStyle = preload("res://scripts/interface_style.gd")
const TEAL = Color("67eddb")
var bearing_slider: HSlider
var elevation_slider: HSlider
var sweep_button: Button
var _bearing_label: Label
var _elevation_label: Label
var _array: CommunicationsArray

func bind(communications_array: CommunicationsArray) -> void:
	_array = communications_array
	add_theme_constant_override("separation", 8)
	_bearing_label = InterfaceStyle.label(self, "", 11, TEAL, Vector2.ZERO)
	bearing_slider = HSlider.new()
	bearing_slider.name = "BaseBearing"
	bearing_slider.min_value = -180
	bearing_slider.max_value = 180
	bearing_slider.step = 1
	bearing_slider.custom_minimum_size = Vector2(240, 20)
	bearing_slider.tooltip_text = "Rotate the base around the deck mount"
	bearing_slider.value_changed.connect(_array.set_bearing)
	add_child(bearing_slider)
	_elevation_label = InterfaceStyle.label(self, "", 11, TEAL, Vector2.ZERO)
	elevation_slider = HSlider.new()
	elevation_slider.name = "DishElevation"
	elevation_slider.max_value = 85
	elevation_slider.step = 1
	elevation_slider.custom_minimum_size.y = 20
	elevation_slider.tooltip_text = "Tilt the dish independently, from horizon to near zenith"
	elevation_slider.value_changed.connect(_array.set_elevation)
	add_child(elevation_slider)
	sweep_button = Button.new()
	sweep_button.text = "AUTO SWEEP"
	sweep_button.toggle_mode = true
	sweep_button.tooltip_text = "Rotate the base continuously while holding dish elevation"
	sweep_button.toggled.connect(_array.set_sweeping)
	add_child(sweep_button)
	InterfaceStyle.style_button(sweep_button)
	_array.state_changed.connect(_sync_state)
	_sync_state()

func _sync_state() -> void:
	var bearing := _array.get_bearing()
	var elevation := _array.get_elevation()
	_bearing_label.text = "BASE BEARING   %03d°" % roundi(fposmod(bearing, 360.0))
	_elevation_label.text = "DISH ELEVATION   %02d°" % roundi(elevation)
	bearing_slider.set_value_no_signal(bearing)
	elevation_slider.set_value_no_signal(elevation)
	sweep_button.set_pressed_no_signal(_array.is_sweeping())
