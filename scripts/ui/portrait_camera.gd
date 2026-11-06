class_name PortraitCamera
extends RefCounted
## Renders a still, angled close-up of a character model's face into a
## texture (used by the HUD portrait). The model gets its own little 3D world
## with studio lighting, so the game's lighting never affects it.

const EYE := Vector3(-0.85, 1.5, -2.3)   ## camera position (front-left of the face)
const LOOK := Vector3(0.0, 1.22, 0.0)       ## the point it looks at (the face)


## Builds the mini-scene under `owner_node` and returns its texture.
static func render(owner_node: Node, model_id: String, pixels: int = 256) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(pixels, pixels)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	owner_node.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.6)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()  # warm main light from the front-left
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.5
	vp.add_child(key)
	key.transform = Transform3D(Basis.looking_at(LOOK - Vector3(-2.0, 2.5, -2.0), Vector3.UP), Vector3.ZERO)
	var rim := DirectionalLight3D.new()  # cool edge light from behind
	rim.light_color = Color(0.55, 0.7, 1.0)
	rim.light_energy = 1.2
	vp.add_child(rim)
	rim.transform = Transform3D(Basis.looking_at(LOOK - Vector3(1.5, 1.5, 2.5), Vector3.UP), Vector3.ZERO)

	var model := CharacterModel.create(model_id)
	if model:
		vp.add_child(model)
	var d := DB.model(model_id)
	var eye := _vec(d.get("portrait_eye", []), EYE)
	var look := _vec(d.get("portrait_look", []), LOOK)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)

	# Let the idle pose settle, then freeze it and stop re-rendering (it's a still image).
	_freeze_later(vp, model)
	return vp.get_texture()


static func _freeze_later(vp: SubViewport, model: CharacterModel) -> void:
	if not vp.is_inside_tree():
		await vp.tree_entered
	var tree := vp.get_tree()
	for i in 6:
		await tree.process_frame
	if not is_instance_valid(vp):
		return
	if is_instance_valid(model) and model.anim:
		model.anim.pause()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


static func _vec(a: Array, fallback: Vector3) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a.size() == 3 else fallback
