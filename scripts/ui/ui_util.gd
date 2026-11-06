class_name UiUtil
extends RefCounted
## Small helpers for building UI in code. The look itself comes from UiTheme.


## Kept for older code: a simple box with an optional border.
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 4, pad: int = 8) -> StyleBoxFlat:
	return UiTheme.flat(bg, border, 1, radius, pad)


static func label(text: String, size: int = 16, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Small grey help text.
static func hint(text: String) -> Label:
	var l := label(text, 14, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Section heading inside a window (Cinzel font, gold).
static func header(text: String, size: int = 18) -> Label:
	var l := label(text, size, UiTheme.TITLE)
	l.add_theme_font_override("font", UiTheme.title_font())
	return l


## Big window title, with a soft outline.
static func title(text: String, size: int = 26) -> Label:
	var l := header(text, size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	return l


static func button(text: String, on_press: Callable, color: Color = UiTheme.TEXT, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.35))
	b.add_theme_font_size_override("font_size", 16)
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


## A full-screen window: dimmed background + centred framed panel with a
## title bar and a close button. Returns { "root", "body", "title" }.
static func window(title_text: String, close_text: String, on_close: Callable, margin: Vector2 = Vector2(50, 36)) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = margin.x
	panel.offset_top = margin.y
	panel.offset_right = -margin.x
	panel.offset_bottom = -margin.y
	panel.add_theme_stylebox_override("panel", UiTheme.window())
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var top := HBoxContainer.new()
	var t := title(title_text)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	if close_text != "":
		var close := button(close_text, on_close)
		close.alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(close)
	v.add_child(top)
	v.add_child(HSeparator.new())
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	return {"root": root, "body": body, "title": t, "top": top}


static func bar(fill: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.add_theme_stylebox_override("background", UiTheme.inset(0))
	p.add_theme_stylebox_override("fill", UiTheme.flat(fill, Color(0, 0, 0, 0), 0, 2, 0))
	return p


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
