class_name UiUtil
extends RefCounted
## Small helpers for building UI in code.


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 4, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border.a > 0.0:
		s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size: int = 15, color: Color = Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func header(text: String) -> Label:
	return label(text, 18, Color(0.95, 0.8, 0.5))


static func button(text: String, on_press: Callable, color: Color = Color(0.92, 0.92, 0.92), tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.3))
	b.add_theme_font_size_override("font_size", 15)
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


static func bar(fill: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.add_theme_stylebox_override("background", box(Color(0.05, 0.05, 0.06, 0.9), Color(0.3, 0.3, 0.3), 3, 0))
	p.add_theme_stylebox_override("fill", box(fill, Color(0, 0, 0, 0), 3, 0))
	return p


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
