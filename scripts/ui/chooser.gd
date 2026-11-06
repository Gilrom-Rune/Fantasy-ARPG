class_name Chooser
extends ColorRect
## A popup list of choices ("pick a skill gem", "pick a passive", ...).

var _title: Label
var _list: VBoxContainer


func _ready() -> void:
	color = Color(0, 0, 0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.window(16))
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_title = UiUtil.title("", 22)
	v.add_child(_title)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var cancel := UiUtil.button("Cancel", close)
	cancel.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cancel)


func close() -> void:
	visible = false


## options: [{ "text", "tip", "color", "disabled", "action": Callable }]
func open(title: String, options: Array) -> void:
	_title.text = title
	UiUtil.clear(_list)
	for o in options:
		var action: Callable = o["action"]
		var on_press := func():
			visible = false
			action.call()
		var b := UiUtil.button(o["text"], on_press, o.get("color", Color.WHITE), o.get("tip", ""))
		b.disabled = o.get("disabled", false)
		_list.add_child(b)
	if options.is_empty():
		_list.add_child(UiUtil.hint("Nothing available. Find more gems from monsters and chests."))
	visible = true
