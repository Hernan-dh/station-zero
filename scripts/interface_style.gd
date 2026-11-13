extends RefCounted

const IVORY = Color("d7ddcd")

static func label(parent: Control, text: String, size: int, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

static func style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", IVORY)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142334")
	style.border_color = Color("375364")
	style.set_border_width_all(1)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("294557")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
