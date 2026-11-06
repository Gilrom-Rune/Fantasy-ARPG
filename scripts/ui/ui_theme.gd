class_name UiTheme
extends RefCounted
## The one place that decides how the whole UI looks: colours, fonts, and
## the style of panels, buttons, tooltips, scroll bars and separators.
## Change something here and every screen changes with it.

# --- Palette -----------------------------------------------------------------
const BG := Color(0.055, 0.048, 0.042)        ## window background
const PANEL := Color(0.09, 0.078, 0.066)      ## boxes inside windows
const INSET := Color(0.035, 0.03, 0.026)      ## sunken areas (bars, slots)
const GOLD := Color(0.8, 0.64, 0.36)          ## frames and highlights
const GOLD_DIM := Color(0.46, 0.37, 0.23)     ## quieter frames
const TEXT := Color(0.92, 0.88, 0.8)
const MUTED := Color(0.62, 0.58, 0.52)
const FAINT := Color(0.42, 0.4, 0.37)
const TITLE := Color(0.97, 0.83, 0.53)
const LIFE := Color(0.78, 0.1, 0.08)
const MANA := Color(0.16, 0.38, 0.95)
const XP := Color(0.85, 0.68, 0.25)
const SKILL := Color(0.55, 0.95, 0.6)
const PASSIVE := Color(0.55, 0.8, 1.0)
const SOUL := Color(0.65, 0.88, 1.0)          ## Soul Chains / Enchanter accents

const BODY_FONT := "res://assets/fonts/AlegreyaSans-Regular.ttf"
const BOLD_FONT := "res://assets/fonts/AlegreyaSans-Bold.ttf"
const TITLE_FONT := "res://assets/fonts/Cinzel.ttf"

static var _fonts := {}
static var _applied := false


static func font(path: String) -> Font:
	if not _fonts.has(path):
		var f: Font = load(path)
		_fonts[path] = f if f else ThemeDB.fallback_font
	return _fonts[path]


static func body_font() -> Font:
	return font(BODY_FONT)


static func bold_font() -> Font:
	return font(BOLD_FONT)


static func title_font() -> Font:
	return font(TITLE_FONT)


# --- Style boxes -----------------------------------------------------------------
static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 1, radius: int = 3, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border.a > 0.0:
		s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


## Big windows (inventory, Enchanter's Table, popups): dark, gold frame, soft shadow.
static func window(pad: int = 16) -> StyleBoxFlat:
	var s := flat(Color(BG, 0.97), GOLD, 2, 4, pad)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 14
	return s


## A box inside a window (a skill slot row, a card).
static func box(border: Color = GOLD_DIM, pad: int = 8) -> StyleBoxFlat:
	return flat(PANEL, border, 1, 3, pad)


## A sunken area (bar backgrounds, slot backgrounds).
static func inset(pad: int = 4) -> StyleBoxFlat:
	return flat(Color(INSET, 0.92), Color(GOLD_DIM, 0.7), 1, 3, pad)


# --- Global theme ------------------------------------------------------------------
## Restyles Godot's default theme, so every Control in the game picks it up,
## including tooltips. Call once at startup.
static func apply() -> void:
	if _applied:
		return
	_applied = true
	var t := ThemeDB.get_default_theme()
	t.default_font = body_font()
	t.default_font_size = 16

	t.set_color("font_color", "Label", TEXT)

	# Buttons
	var normal := flat(Color(0.13, 0.11, 0.09), GOLD_DIM, 1, 3, 6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover := flat(Color(0.19, 0.155, 0.11), GOLD, 1, 3, 6)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	var pressed := flat(Color(0.08, 0.07, 0.06), GOLD, 1, 3, 6)
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	var disabled := flat(Color(0.07, 0.065, 0.06), Color(0.24, 0.22, 0.2), 1, 3, 6)
	disabled.content_margin_left = 10
	disabled.content_margin_right = 10
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", hover)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", TITLE)
	t.set_color("font_disabled_color", "Button", FAINT)

	# Panels
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("panel", "Panel", box())

	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", flat(Color(0.05, 0.043, 0.037, 0.97), GOLD, 1, 3, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)

	# Separators
	var line := StyleBoxLine.new()
	line.color = Color(GOLD_DIM, 0.8)
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 12)

	# Scroll bars
	var grab := flat(Color(GOLD_DIM, 0.8), Color(0, 0, 0, 0), 0, 3, 0)
	var grab_hi := flat(GOLD, Color(0, 0, 0, 0), 0, 3, 0)
	var track := flat(Color(INSET, 0.6), Color(0, 0, 0, 0), 0, 3, 0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)

	# Progress bars
	t.set_stylebox("background", "ProgressBar", inset(0))
	t.set_stylebox("fill", "ProgressBar", flat(XP, Color(0, 0, 0, 0), 0, 2, 0))
