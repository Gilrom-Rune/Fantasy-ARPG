extends SceneTree
## Renders a grid of animation poses for checking retargeted animations.
## Rows = animations, columns = moments in the animation.
##   xvfb-run godot --path . --script res://tests/tools/anim_frames.gd -- --model=q_ranger --out=/path/frames.png

const TIMES := [0.0, 0.25, 0.5, 0.75]


func _initialize() -> void:
	DB.ensure_loaded()
	var out := "/tmp/frames.png"
	var model_id := "q_ranger"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--model="):
			model_id = a.get_slice("=", 1)
	var d := DB.model(model_id)
	var acts: Dictionary = d.get("actions", {})
	var rows: Array = [d.get("idle", "Idle"), d.get("run", "Running_A"), acts.get("melee", ""), acts.get("spell", ""), acts.get("ranged", "")]

	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.12, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 1.4
	root.add_child(sun)

	var models := []
	for r in rows.size():
		for c in TIMES.size():
			var m := CharacterModel.create(model_id)
			root.add_child(m)
			m.position = Vector3((c - 1.5) * 1.6, (rows.size() - 1 - r) * 2.1, 0)
			m.rotation.y = PI - deg_to_rad(35)  # three-quarter view, facing the camera
			models.append([m, rows[r], TIMES[c]])
	await process_frame
	for e in models:
		var m: CharacterModel = e[0]
		if m.anim and m.anim.has_animation(e[1]):
			var length: float = m.anim.get_animation(e[1]).length
			m.anim.play(e[1])
			m.anim.seek(length * float(e[2]), true)
			m.anim.pause()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows.size() * 2.1 + 0.4
	root.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(0, rows.size() * 2.1 * 0.5 - 0.2, 10))
	for i in 10:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	print("saved ", out, "  rows: ", rows)
	quit()
