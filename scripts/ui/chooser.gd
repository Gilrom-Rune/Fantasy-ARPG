class_name Chooser
extends ColorRect
## A popup list of choices ("pick a skill gem", "pick a passive", ...).

var _title: Label
var _list: VBoxContainer


func _ready() -> void:
	color = Color(0, 0, 0, 0.55)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", UiUtil.box(Color(0.09, 0.09, 0.12), Color(0.6, 0.5, 0.3), 6, 14))
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_title = UiUtil.header("")
	v.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	v.add_child(UiUtil.button("Cancel", close))


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
		_list.add_child(UiUtil.label("Nothing available. Find more gems from monsters and chests.", 15, Color(0.6, 0.6, 0.6)))
	visible = true
