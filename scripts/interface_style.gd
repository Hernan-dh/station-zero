extends RefCounted
## Shared visual language and panel metrics for the outpost interface.

const IVORY = Color("eee1d7")
const TEAL = Color("42e0df")
const MUTED = Color("aaadb5")
const ACCENT = Color("efac51")
const STATUS_BLUE = Color("69e4fa")
const STATUS_VIOLET = Color("c397ff")
const STATUS_GOLD = Color("ffd081")

const PANEL_BG = Color("1b1e25")
const BUTTON_BG = Color("1b1e25")
const BUTTON_BORDER = Color("89704c")
const BUTTON_HOVER_BG = Color("353431")
const BUTTON_HOVER_BORDER = Color("efac51")
const PORTAL_FILL = Color("a86bf5")
const BAR_BG = Color("303744")

const FONT_CAPTION := 10
const FONT_BODY := 11
const FONT_VALUE := 12
const FONT_NAME := 18
const FONT_TITLE := 25
const BUTTON_HEIGHT := 36
const BUTTON_SEPARATION := 8
const BUTTON_BORDER_WIDTH := 1
const BUTTON_CONTENT_MARGIN := 10
const CONTROL_WIDTH := 285.0
const PANEL_PADDING := 16.0
const PANEL_WIDTH := CONTROL_WIDTH + PANEL_PADDING * 2.0
const SLIDER_HEIGHT := 20.0
const BAR_HEIGHT := 10.0
const BAR_HEIGHT_SMALL := 8.0

const SELECTION_LEFT := 40.0
const SELECTION_TOP := -176.0
const SELECTION_RIGHT := SELECTION_LEFT + PANEL_WIDTH
const SELECTION_BOTTOM := -96.0
const SELECTION_SEPARATION := 5
const SELECTION_OVERLAY_ALPHA := 0.3
const SELECTION_BORDER_WIDTH := 1
const SELECTION_CONTENT_MARGIN := 12

const PANEL_TOP_BEACON := -220.0
const PANEL_TOP_ARRAY := -350.0
const PANEL_TOP_ARC := -410.0
const PANEL_TOP_SHIELD := -365.0
const PANEL_TOP_PORTAL := -335.0
const PANEL_TOP_RELAY := -335.0
const PANEL_TOP_SUNFALL := -335.0

const HEADER_POSITION := Vector2(38, 31)
const SUBTITLE_POSITION := Vector2(40, 68)
const ACCENT_POSITION := Vector2(40, 25)
const ACCENT_SIZE := Vector2(44, 2)
const FOOTER_Y := -72.0
const FOOTER_LEFT := 40.0
const FOOTER_TEXT_Y := 0.0
const FOOTER_SUBTITLE_Y := 23.0

const CAMERA_BUTTON_OFFSET := Vector2(-365, -65)
const CAMERA_BUTTON_SEPARATION := 12
const CAMERA_HINT_LEFT := -730.0
const CAMERA_HINT_TOP := 40.0
const CAMERA_HINT_RIGHT := -38.0
const CAMERA_HINT_BOTTOM := 60.0

static func label(parent: Control, text: String, size: int, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

static func panel_separation(panel: Control) -> void:
	panel.add_theme_constant_override("separation", BUTTON_SEPARATION)

static func status(parent: Control, color: Color) -> Label:
	return label(parent, "", FONT_BODY, color, Vector2.ZERO)

static func progress(parent: Control, height: float, fill_color := Color.TRANSPARENT, background_color := Color.TRANSPARENT) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(CONTROL_WIDTH, height)
	bar.show_percentage = false
	if fill_color.a > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = fill_color
		bar.add_theme_stylebox_override("fill", fill)
	if background_color.a > 0.0:
		var background := StyleBoxFlat.new()
		background.bg_color = background_color
		bar.add_theme_stylebox_override("background", background)
	parent.add_child(bar)
	return bar

static func button(parent: Control, title: String, toggle := false) -> Button:
	var b := Button.new()
	b.text = title
	b.toggle_mode = toggle
	parent.add_child(b)
	style_button(b)
	return b

static func slider(parent: Control, minimum: float, maximum: float, step := 1.0, tooltip := "") -> HSlider:
	var bar := HSlider.new()
	bar.min_value = minimum
	bar.max_value = maximum
	bar.step = step
	bar.custom_minimum_size = Vector2(CONTROL_WIDTH, SLIDER_HEIGHT)
	bar.tooltip_text = tooltip
	parent.add_child(bar)
	return bar

static func bind_state(state_changed: Signal, sync: Callable) -> void:
	state_changed.connect(sync)
	sync.call()
	sync.call_deferred()

static func style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", FONT_BODY)
	button.add_theme_color_override("font_color", IVORY)
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_BG
	style.border_color = BUTTON_BORDER
	style.set_border_width_all(BUTTON_BORDER_WIDTH)
	style.content_margin_top = BUTTON_CONTENT_MARGIN
	style.content_margin_bottom = BUTTON_CONTENT_MARGIN
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = BUTTON_HOVER_BG
	hover.border_color = BUTTON_HOVER_BORDER
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
