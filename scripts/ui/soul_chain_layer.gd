class_name SoulChainLayer
extends Control
## Draws the pale blue Soul Chains between slot nodes on the Enchanter's
## Table, plus the chain you are currently dragging.

const CHAIN_COLOR := Color(0.7, 0.9, 1.0, 0.65)
const GLOW_COLOR := Color(0.55, 0.85, 1.0, 0.16)

var ui: EnchanterUI


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if ui == null or ui.player == null:
		return
	var weapon := ui.player.inv.weapon
	for pair in weapon.links:
		var a := _node_center(pair[0])
		var b := _node_center(pair[1])
		if a != Vector2.INF and b != Vector2.INF:
			_draw_chain(a, b, 1.0)
	if ui.drag_from >= 0:
		var start := _node_center(ui.drag_from)
		if start != Vector2.INF:
			_draw_chain(start, get_local_mouse_position(), 0.7)


func _node_center(index: int) -> Vector2:
	if index >= ui.nodes.size() or not is_instance_valid(ui.nodes[index]):
		return Vector2.INF
	var n: Control = ui.nodes[index]
	return n.get_global_rect().get_center() - get_global_rect().position


## A curved chain bowing out to the right, drawn as a glow plus small links.
func _draw_chain(a: Vector2, b: Vector2, strength: float) -> void:
	var bow := 45.0 + absf(b.y - a.y) * 0.3
	var ctrl := (a + b) * 0.5 + Vector2(bow, 0)
	var pts := PackedVector2Array()
	var steps := 32
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	var shimmer := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	draw_polyline(pts, Color(GLOW_COLOR, GLOW_COLOR.a * strength * shimmer), 16.0, true)
	draw_polyline(pts, Color(CHAIN_COLOR, 0.35 * strength), 2.0, true)
	# Chain links: small rings spaced along the curve.
	var length := 0.0
	var next_link := 0.0
	for i in range(1, pts.size()):
		length += pts[i].distance_to(pts[i - 1])
		if length >= next_link:
			draw_arc(pts[i], 6.0, 0, TAU, 14, Color(CHAIN_COLOR, CHAIN_COLOR.a * strength * shimmer), 2.5, true)
			next_link += 12.0
