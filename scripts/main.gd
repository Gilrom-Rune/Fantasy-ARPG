extends Node3D
## Entry point. Builds the arena and the camp, lets you pick a class, then
## spawns monster packs that get stronger as you kill more.
##
## Command line options (after a "--"), used for automated testing:
##   --autoplay          a bot plays the game (picks a random class)
##   --class=ID          skip class selection (warrior, ranger, mage, rogue)
##   --level=N           start at character level N
##   --seconds=N         quit after N seconds and print a summary
##   --screenshot=PATH   save a screenshot near the end of the run
##   --ui-shot=NAME      open a window before the screenshot: inventory, enchanter or classes

const ARENA_HALF := 40.0
const CAM_OFFSET := Vector3(0, 11, 8)

var player: Player
var camera: Camera3D
var hud: Hud
var obstacles: Array = []  ## [{ "pos": Vector3, "r": float }]
var spawn_timer := 1.5
var kills_for_next_level := 25
var elapsed := 0.0
var run_seconds := 0.0
var screenshot_path := ""
var ui_shot := ""
var start_class := ""
var start_level := 1
var chest_timer := 20.0
var class_select: ClassSelectUI
var _screenshot_done := false
var _bot_timer := 0.0
var _deaths := 0


func _ready() -> void:
	DB.ensure_loaded()
	UiTheme.apply()
	Game.reset()
	Game.world = self
	_setup_input()
	_parse_args()
	_build_environment()
	_build_arena()
	_build_camp()
	for i in 2:
		_spawn_chest()
	camera = Camera3D.new()
	camera.fov = 45
	camera.far = 200
	add_child(camera)
	camera.global_position = CAM_OFFSET
	camera.look_at(Vector3.ZERO, Vector3.UP)

	if start_class == "" and Game.autoplay:
		start_class = DB.classes.keys().pick_random()
	if start_class != "" and ui_shot != "classes":
		_start_game(start_class)
	else:
		class_select = ClassSelectUI.new()
		add_child(class_select)
		class_select.chosen.connect(_start_game)


func _start_game(class_id: String) -> void:
	if class_select:
		class_select.queue_free()
		class_select = null
	player = Player.new()
	player.name = "Player"
	player.class_id = class_id
	player.level = clampi(start_level, 1, Player.MAX_LEVEL)
	add_child(player)
	Game.player = player

	camera.global_position = player.global_position + CAM_OFFSET
	camera.look_at(player.global_position, Vector3.UP)
	player.camera = camera

	hud = Hud.new()
	add_child(hud)
	Game.hud = hud
	hud.setup(player)
	hud.respawn_requested.connect(_on_respawn)
	Game.message("Welcome, %s! Walk to the Enchanter's Table and press F to cut your gems." % player.class_name_text(), Color(1.0, 0.9, 0.6))
	Game.message("You are in the camp - monsters can't enter it.", Color(0.7, 0.85, 1.0))


func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("skill_1", [], [MOUSE_BUTTON_LEFT])
	_bind("skill_2", [], [MOUSE_BUTTON_RIGHT])
	_bind("skill_3", [KEY_Q])
	_bind("skill_4", [KEY_E])
	for n in 6:
		_bind("skill_%d" % (n + 5), [KEY_1 + n])
	_bind("interact", [KEY_F])
	_bind("inventory", [KEY_I, KEY_TAB])
	_bind("respawn", [KEY_R])


func _bind(action: String, keys: Array, buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			Game.autoplay = true
		elif a.begins_with("--seconds="):
			run_seconds = float(a.get_slice("=", 1))
		elif a.begins_with("--ui-shot="):
			ui_shot = a.get_slice("=", 1)
		elif a.begins_with("--class="):
			start_class = a.get_slice("=", 1)
		elif a.begins_with("--level="):
			start_level = int(a.get_slice("=", 1))
		elif a.begins_with("--screenshot="):
			screenshot_path = a.get_slice("=", 1)


# --- World building ----------------------------------------------------------
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.12)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)


func _build_arena() -> void:
	# Ground
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_HALF * 2 + 10, ARENA_HALF * 2 + 10)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.3, 0.27)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.72, 0.7))
	ramp.set_color(1, Color(1.0, 0.98, 0.94))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = ramp
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	gm.albedo_texture = tex
	gm.uv1_scale = Vector3(6, 6, 1)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)

	var stone := Color(0.42, 0.4, 0.38)
	# Outer walls
	var h := ARENA_HALF
	_add_block(Vector3(0, 1.5, -h - 1), Vector3(h * 2 + 4, 3, 2), stone)
	_add_block(Vector3(0, 1.5, h + 1), Vector3(h * 2 + 4, 3, 2), stone)
	_add_block(Vector3(-h - 1, 1.5, 0), Vector3(2, 3, h * 2 + 4), stone)
	_add_block(Vector3(h + 1, 1.5, 0), Vector3(2, 3, h * 2 + 4), stone)

	# Ruined pillars and low walls, same layout every run.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var placed := 0
	var tries := 0
	while placed < 22 and tries < 500:
		tries += 1
		var pos := Vector3(rng.randf_range(-h + 4, h - 4), 0, rng.randf_range(-h + 4, h - 4))
		if pos.length() < 8.0:
			continue
		var ok := true
		for o in obstacles:
			if o["pos"].distance_to(pos) < 6.0:
				ok = false
				break
		if not ok:
			continue
		placed += 1
		if rng.randf() < 0.65:
			var r := rng.randf_range(0.6, 1.2)
			var height := rng.randf_range(1.5, 4.5)
			_add_block(pos + Vector3(0, height * 0.5, 0), Vector3(r * 2, height, r * 2), stone.darkened(rng.randf_range(0, 0.25)), true)
			obstacles.append({"pos": pos, "r": r + 0.5})
			if placed % 4 == 0:
				_add_torch(pos + Vector3(0, height + 0.3, 0))
		else:
			var length := rng.randf_range(3.0, 6.0)
			var wall := _add_block(pos + Vector3(0, 0.6, 0), Vector3(length, 1.2, 0.8), stone.darkened(0.15))
			wall.rotation.y = rng.randf_range(0, PI)
			obstacles.append({"pos": pos, "r": length * 0.5 + 0.5})


## The safe camp in the middle of the arena, with the Enchanter's Table.
func _build_camp() -> void:
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Game.CAMP_RADIUS
	disc.bottom_radius = Game.CAMP_RADIUS
	disc.height = 0.04
	disc.radial_segments = 48
	ground.mesh = disc
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.24, 0.2, 0.15)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	ground.position.y = 0.01
	var border := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Game.CAMP_RADIUS - 0.15
	torus.outer_radius = Game.CAMP_RADIUS + 0.15
	torus.rings = 64
	border.mesh = torus
	border.scale = Vector3(1, 0.3, 1)
	border.material_override = Fx.glow_mat(Color(0.3, 0.5, 0.8), 0.5)
	add_child(border)
	# Posts around the edge, every other one with a torch.
	for i in 8:
		var a := TAU * i / 8.0
		var pos := Vector3(cos(a), 0, sin(a)) * (Game.CAMP_RADIUS + 0.4)
		_add_block(pos + Vector3(0, 0.6, 0), Vector3(0.35, 1.2, 0.35), Color(0.35, 0.24, 0.14))
		if i % 2 == 0:
			_add_torch(pos + Vector3(0, 1.4, 0))
	var table := EnchanterTable.new()
	add_child(table)
	table.global_position = Vector3(0, 0, -3.0)


func _spawn_chest() -> void:
	for attempt in 40:
		var pos := Vector3(randf_range(-ARENA_HALF + 4, ARENA_HALF - 4), 0, randf_range(-ARENA_HALF + 4, ARENA_HALF - 4))
		if Game.in_camp(pos, 5.0) or _blocked(pos, 1.5):
			continue
		var chest := Chest.new()
		chest.level = Game.area_level
		add_child(chest)
		chest.global_position = pos
		chest.rotation.y = randf() * TAU
		return


func _add_block(pos: Vector3, size: Vector3, color: Color, round_shape: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	if round_shape:
		var cs := CylinderShape3D.new()
		cs.radius = size.x * 0.5
		cs.height = size.y
		shape.shape = cs
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.45
		cm.bottom_radius = size.x * 0.5
		cm.height = size.y
		cm.radial_segments = 10
		mi.mesh = cm
	else:
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	body.add_child(shape)
	body.add_child(mi)
	add_child(body)
	body.global_position = pos
	return body


func _add_torch(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 2.0
	light.omni_range = 9.0
	add_child(light)
	light.global_position = pos + Vector3(0, 0.4, 0)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.35
	flame.mesh = sm
	flame.material_override = Fx.glow_mat(Color(1.0, 0.55, 0.15), 5.0)
	add_child(flame)
	flame.global_position = pos


# --- Game loop -----------------------------------------------------------------
func _process(delta: float) -> void:
	elapsed += delta
	if player == null:
		if ui_shot == "classes" and screenshot_path != "" and not _screenshot_done and elapsed > 1.0:
			_screenshot_done = true
			_take_screenshot()
		return
	var target := player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
	camera.look_at(camera.global_position - CAM_OFFSET + Vector3(0, 0.5, 0), Vector3.UP)

	if Game.autoplay:
		_bot_timer -= delta
		if _bot_timer <= 0.0:
			_bot_timer = 2.0
			_bot_manage_inventory()
		if player.dead and elapsed > 0.0:
			_deaths += 1
			_on_respawn()
	if screenshot_path != "" and not _screenshot_done and elapsed >= maxf(3.0, run_seconds - 1.0):
		_screenshot_done = true
		_take_screenshot()
	if run_seconds > 0.0 and elapsed >= run_seconds:
		_print_summary()
		get_tree().quit()


func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		return
	chest_timer -= delta
	if chest_timer <= 0.0:
		chest_timer = 25.0
		if get_tree().get_nodes_in_group("chests").size() < 3:
			_spawn_chest()
	if Game.kills >= kills_for_next_level:
		Game.area_level += 1
		kills_for_next_level += 20 + 5 * Game.area_level
		Game.message("The monsters grow stronger... (Area level %d)" % Game.area_level, Color(1, 0.5, 0.4))
	spawn_timer -= delta
	var cap := mini(10 + Game.area_level * 3, 45)
	if spawn_timer <= 0.0 and get_tree().get_nodes_in_group("enemies").size() < cap:
		spawn_timer = randf_range(2.0, 3.5)
		_spawn_pack()


func _spawn_pack() -> void:
	var center := Vector3.ZERO
	var found := false
	for i in 30:
		var angle := randf() * TAU
		var dist := randf_range(15.0, 24.0)
		center = player.global_position + Vector3(cos(angle), 0, sin(angle)) * dist
		if absf(center.x) > ARENA_HALF - 4 or absf(center.z) > ARENA_HALF - 4:
			continue
		if _blocked(center, 2.5) or Game.in_camp(center, 6.0):
			continue
		found = true
		break
	if not found:
		return
	var r := randf()
	var leader_rarity := 2 if r < 0.06 else (1 if r < 0.3 else 0)
	var count := randi_range(3, 6)
	for i in count:
		var roll := randf()
		var kind := "caster" if roll < 0.25 else ("minion" if roll < 0.55 else "brute")
		var rarity := leader_rarity if i == 0 else (1 if randf() < 0.08 else 0)
		var pos := center + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		if _blocked(pos, 1.0):
			pos = center
		var e := Enemy.new()
		e.setup(kind, Game.area_level, rarity)
		add_child(e)
		e.global_position = pos


func _blocked(pos: Vector3, margin: float) -> bool:
	for o in obstacles:
		if Game.flat_distance(o["pos"], pos) < o["r"] + margin:
			return true
	return false


func _on_respawn() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for p in get_children():
		if p is Projectile:
			p.queue_free()
	player.respawn()
	camera.global_position = player.global_position + CAM_OFFSET
	spawn_timer = 2.0
	hud.hide_death()


# --- Automated testing helpers ---------------------------------------------------
func _bot_manage_inventory() -> void:
	var inv := player.inv
	while not inv.uncut.is_empty():
		var u: Dictionary = inv.uncut[0]
		var ids := DB.player_skill_ids() if u["kind"] == "skill" else DB.support_ids()
		inv.cut(0, ids.pick_random())
	var open := player.unlocked_slots()
	for i in open:
		var slot: Dictionary = inv.weapon.slots[i]
		if slot["active"] == null and not inv.skill_gems.is_empty():
			inv.set_active(i, 0)
		if slot["active"] != null and slot["passive"] == "":
			for pid in inv.passive_gems.duplicate():
				if inv.set_passive(i, pid) == "":
					break
	if open >= 2 and inv.weapon.links.is_empty():
		inv.toggle_chain(0, 1)
	for i in range(inv.bag.size() - 1, -1, -1):
		var item: Item = inv.bag[i]
		var current: Item = inv.equipment[item.slot]
		if current == null or item.rarity > current.rarity:
			inv.equip_from_bag(i)
	# Exercise both windows so UI errors show up in automated runs.
	hud.inventory_ui.visible = true
	hud.inventory_ui.refresh()
	hud.inventory_ui.visible = false
	hud.enchanter_ui.visible = true
	hud.enchanter_ui.exercise()
	hud.enchanter_ui.visible = false


func _take_screenshot() -> void:
	var opened_menu := false
	if ui_shot == "inventory":
		hud.toggle_inventory()
		opened_menu = true
	elif ui_shot == "enchanter":
		hud.open_enchanter()
		opened_menu = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(screenshot_path)
		print("Saved screenshot to ", screenshot_path)
	if opened_menu or player == null:
		# The game is paused while a window is open, so quit from here.
		_print_summary()
		get_tree().quit()


func _print_summary() -> void:
	print("=== AUTOPLAY SUMMARY ===")
	if player == null:
		print("(no class chosen)")
		return
	var inv := player.inv
	print("class: %s  time: %.1fs  kills: %d  player level: %d  area level: %d  deaths: %d" % [player.class_id, elapsed, Game.kills, player.level, Game.area_level, _deaths])
	var equipped := []
	for slot in inv.equipment:
		if inv.equipment[slot]:
			equipped.append("%s=%s" % [slot, inv.equipment[slot].name])
	print("equipped: ", ", ".join(equipped))
	print("bag items: %d  pouch skills: %d  pouch passives: %d  uncut: %d  chains: %s" % [inv.bag.size(), inv.skill_gems.size(), inv.passive_gems.size(), inv.uncut.size(), inv.weapon.links])
	for i in player.unlocked_slots():
		var slot: Dictionary = inv.weapon.slots[i]
		var g: SkillGem = slot["active"]
		if g:
			var c: Dictionary = player.compiled[i]
			print("slot %s: %s  passives %s  avg hit %.1f" % [Player.SLOT_KEYS[i], g.display_name(), c["supports"], c["average_hit"]])
