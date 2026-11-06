class_name PortraitOrb
extends Control
## The character's face in a gold ring, with a crescent-shaped LIFE bar
## curving around the left side and a MANA bar around the right side.
## The bars fill from the bottom up.

const SIZE := Vector2(250, 236)
const PORTRAIT_R := 66.0      ## radius of the face circle
const GAP := 7.0              ## space between the face ring and the crescents
const THICK := 26.0           ## crescent thickness at its widest (middle)
const END_ANGLE := 0.42       ## how far (radians) the crescents stop short of top/bottom
const STEPS := 48

var player: Player
var portrait: TextureRect
var _front: Control
var _life_shown := 1.0   ## smoothed values so the bars slide instead of jumping
var _mana_shown := 1.0
var _drain_shown := 1.0  ## lags behind life to show recent damage


func setup(p: Player) -> void:
	player = p
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	portrait = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var d := PORTRAIT_R * 2.0
	portrait.position = _center() - Vector2(PORTRAIT_R, PORTRAIT_R)
	portrait.size = Vector2(d, d)
	var mat := ShaderMaterial.new()
	mat.shader = _circle_shader()
	portrait.material = mat
	add_child(portrait)
	portrait.texture = PortraitCamera.render(self, String(DB.player_class(p.class_id).get("model", "")))

	# Things drawn on top of the face: gold ring and level badge.
	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.size = SIZE
	_front.draw.connect(_draw_front)
	add_child(_front)


func _center() -> Vector2:
	return Vector2(SIZE.x * 0.5, PORTRAIT_R + THICK + GAP + 4.0)


func _process(delta: float) -> void:
	if player == null:
		return
	var life_frac := clampf(player.life / maxf(1.0, player.max_life), 0.0, 1.0)
	var mana_frac := clampf(player.mana / maxf(1.0, player.max_mana), 0.0, 1.0) if player.max_mana > 0.0 else 0.0
	var k := 1.0 - exp(-14.0 * delta)
	_life_shown = lerpf(_life_shown, life_frac, k)
	_mana_shown = lerpf(_mana_shown, mana_frac, k)
	_drain_shown = maxf(_life_shown, lerpf(_drain_shown, _life_shown, 1.0 - exp(-2.5 * delta)))
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	var c := _center()
	var r_in := PORTRAIT_R + GAP
	# Dark disc behind the face (shows through transparent parts of the render).
	draw_circle(c, PORTRAIT_R + 2.0, Color(0.1, 0.085, 0.07))
	draw_circle(c, PORTRAIT_R - 6.0, Color(0.16, 0.13, 0.1))

	# LIFE: left side, bottom -> top. MANA: right side, bottom -> top.
	var l0 := PI * 0.5 + END_ANGLE
	var l1 := PI * 1.5 - END_ANGLE
	var m0 := PI * 0.5 - END_ANGLE
	var m1 := -PI * 0.5 + END_ANGLE
	var low := player != null and _life_shown < 0.3
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008) if low else 0.0
	var life_col := UiTheme.LIFE.lightened(0.25 * pulse)

	_crescent_bar(c, r_in, l0, l1, _life_shown, _drain_shown, life_col)
	_crescent_bar(c, r_in, m0, m1, _mana_shown, _mana_shown, UiTheme.MANA)

	if player:
		var f := UiTheme.bold_font()
		var y := c.y + PORTRAIT_R + THICK + 2.0
		_text(f, Vector2(c.x - 74, y), "%d / %d" % [ceili(player.life), roundi(player.max_life)], Color(1.0, 0.72, 0.7))
		_text(f, Vector2(c.x + 74, y), "%d / %d" % [floori(player.mana), roundi(player.max_mana)], Color(0.72, 0.82, 1.0))


func _text(f: Font, pos: Vector2, s: String, col: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var p := Vector2(pos.x - w * 0.5, pos.y)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.85))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


## One crescent: empty background, a pale "recent damage" part, the fill, a
## shine along the inner edge, and a gold outline.
func _crescent_bar(c: Vector2, r_in: float, a0: float, a1: float, frac: float, drain: float, col: Color) -> void:
	draw_colored_polygon(_crescent(c, r_in, a0, a1, 0.0, 1.0), Color(UiTheme.INSET, 0.92))
	if drain > frac + 0.002:
		draw_colored_polygon(_crescent(c, r_in, a0, a1, frac, drain), Color(1.0, 0.85, 0.6, 0.55))
	if frac > 0.002:
		draw_colored_polygon(_crescent(c, r_in, a0, a1, 0.0, frac), col.darkened(0.25))
		draw_colored_polygon(_crescent(c, r_in, a0, a1, 0.0, frac, 0.55), col)
		draw_colored_polygon(_crescent(c, r_in + 2.0, a0, a1, 0.0, frac, 0.18), Color(col.lightened(0.55), 0.7))
	var outline := _crescent(c, r_in, a0, a1, 0.0, 1.0)
	outline.append(outline[0])
	draw_polyline(outline, UiTheme.GOLD_DIM, 1.6, true)


## Points of a crescent between angles a0..a1, covering the part from u_from
## to u_to (0..1). It is thickest in the middle and tapers at both ends.
## `inner_share` < 1 only fills the inner part of the thickness (for shading).
func _crescent(c: Vector2, r_in: float, a0: float, a1: float, u_from: float, u_to: float, inner_share: float = 1.0) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := maxi(2, int(STEPS * (u_to - u_from)) + 2)
	for i in n:
		var u := lerpf(u_from, u_to, float(i) / (n - 1))
		var a := lerpf(a0, a1, u)
		var t := THICK * maxf(0.1, pow(sin(PI * u), 0.55)) * inner_share
		var dir := Vector2(cos(a), sin(a))
		outer.append(c + dir * (r_in + t))
		inner.append(c + dir * r_in)
	inner.reverse()
	outer.append_array(inner)
	return outer


func _draw_front() -> void:
	var c := _center()
	# Double gold ring around the face.
	_front.draw_arc(c, PORTRAIT_R, 0, TAU, 64, Color(0.05, 0.04, 0.03), 6.0, true)
	_front.draw_arc(c, PORTRAIT_R, 0, TAU, 64, UiTheme.GOLD, 2.5, true)
	_front.draw_arc(c, PORTRAIT_R - 4.0, 0, TAU, 64, Color(UiTheme.GOLD_DIM, 0.8), 1.0, true)
	# Little gold studs at the top and the sides.
	for a in [-PI * 0.5, PI, 0.0]:
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * PORTRAIT_R
		_front.draw_circle(p, 4.5, UiTheme.GOLD_DIM)
		_front.draw_circle(p, 2.5, UiTheme.TITLE)
	# Level badge at the bottom of the ring.
	if player:
		var b := c + Vector2(0, PORTRAIT_R)
		_front.draw_circle(b, 17.0, Color(0.07, 0.06, 0.05))
		_front.draw_arc(b, 17.0, 0, TAU, 40, UiTheme.GOLD, 2.0, true)
		var f := UiTheme.title_font()
		var s := str(player.level)
		var size := 18 if player.level < 100 else 14
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_front.draw_string(f, b + Vector2(-w * 0.5, size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiTheme.TITLE)


static func _circle_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
// Cuts the square portrait into a soft-edged circle.
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	col.a *= 1.0 - smoothstep(0.47, 0.5, d);
	COLOR = col;
}
"""
	return s
