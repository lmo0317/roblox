extends Node3D

const SAVE_PATH = "user://progress.json"
var coins: int = 100
var speed_level: int = 0
var base_level: int = 0
var pet_count: int = 0
var player: CharacterBody3D
var model: Node3D
var fox: Node3D
var camera: Camera3D
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var nests: Array[Dictionary] = []
var pets: Array[Node3D] = []
var carried: Node3D
var carrying_rare: bool = false
var hatching: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.35
var clock: float = 0.0
var save_clock: float = 0.0
var gait: float = 0.0
var paused: bool = false
var smoke: bool = false
var smoke_failures: int = 0
var hud: Label
var hint: Label
var pause_panel: PanelContainer
var message: String = "Find an egg nest. Press E to grab an egg!"
var message_timer: float = 8.0
var preview: bool = false
var elapsed: float = 0.0
var badge: Label
var quest: Label
var pet_label: Label
var preview_camera: bool = false
var home := Vector3(0, 0, 10)
var hatch_pad := Vector3(0, 0, 13)
var fox_home := Vector3(-10, 0, -9)

func _ready() -> void:
	smoke = "--smoke-test" in OS.get_cmdline_user_args()
	preview = "--preview" in OS.get_cmdline_user_args()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_load_progress()
	_build_world()
	_build_player()
	_build_ui()
	for i in pet_count:
		_add_pet(i)
	if smoke:
		call_deferred("_smoke_test")
	if preview:
		call_deferred("_prepare_preview")

func box(label: String, pos: Vector3, size: Vector3, color: String, parent: Node3D = null, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var source := load("res://assets/soft_box.glb") as PackedScene
	var instance := source.instantiate()
	var template := instance.find_child("Unit", true, false) as MeshInstance3D
	mesh.mesh = template.mesh
	mesh.scale = size
	instance.free()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.62
	mesh.material_override = mat
	(parent if parent != null else self).add_child(mesh)
	mesh.position = pos
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = Vector3.ONE
		collision.shape = bounds
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func sign_text(text: String, pos: Vector3, scale_size: float = 0.008) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = scale_size
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.position = pos

func asset(name: String, pos: Vector3, parent: Node3D = null) -> Node3D:
	var scene := load("res://assets/" + name + ".glb") as PackedScene
	var instance := scene.instantiate() as Node3D
	(parent if parent != null else self).add_child(instance)
	instance.position = pos
	return instance

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4e9ddd")
	sky_mat.sky_horizon_color = Color("c2e7fa")
	sky_mat.ground_horizon_color = Color("c2e7fa")
	sky_mat.ground_bottom_color = Color("9bc96a")
	sky_mat.sky_curve = 0.25
	sky.sky_material = sky_mat
	settings.sky = sky
	settings.background_mode = Environment.BG_SKY
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d8e8ff")
	settings.ambient_light_energy = 0.36
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	settings.tonemap_exposure = 0.85
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	sun.shadow_bias = 0.03
	add_child(sun)
	box("Island earth", Vector3(0, -1.2, -2), Vector3(56, 2, 58), "a78456")
	box("Grass", Vector3(0, -0.15, -2), Vector3(55, 0.35, 57), "7bc44d")
	box("Main path", Vector3(0, 0.025, -2), Vector3(5.5, 0.14, 39), "aebfc5")
	box("Crossroad", Vector3(0, 0.035, -4), Vector3(40, 0.14, 4.5), "aebfc5")
	for x in [-2.9, 2.9]:
		box("Path curb", Vector3(x, 0.09, -2), Vector3(0.22, 0.24, 39), "e7e8d7")
	for z in [-6.4, -1.6]:
		box("Crossroad curb", Vector3(0, 0.10, z), Vector3(40, 0.24, 0.22), "e7e8d7")
	# Paving seams and center lane markers add scale to the world.
	for z in range(-19, 16, 2):
		box("Paving joint", Vector3(0, 0.104, z), Vector3(5.4, 0.008, 0.035), "93a8af", null, false)
		if z < 9:
			box("Lane marker", Vector3(0, 0.112, z), Vector3(0.14, 0.012, 0.65), "f4f6dd", null, false)
	_build_base(Vector3(0, 0, 17), "3182db", "YOUR BASE")
	_build_base(Vector3(-18, 0, 4), "e56851", "MAPLE LODGE")
	_build_base(Vector3(18, 0, -15), "956bd2", "VIOLET LODGE")
	box("Hatch glow", hatch_pad + Vector3(0, 0.12, 0), Vector3(3.5, 0.20, 3.5), "1d8dae")
	box("Hatch pad", hatch_pad + Vector3(0, 0.25, 0), Vector3(3.1, 0.12, 3.1), "7aebee")
	for x in [-1, 1]:
		box("Hatch chevron", hatch_pad + Vector3(x * 0.65, 0.32, 0), Vector3(0.35, 0.018, 1.3), "e8ffff", null, false)
	sign_text("HATCH", hatch_pad + Vector3(0, 0.75, 0), 0.005)
	_build_treadmill()
	box("Upgrade pad base", Vector3(-9, 0.18, 13), Vector3(3.2, 0.3, 3.2), "d6982f")
	box("Upgrade pad", Vector3(-9, 0.36, 13), Vector3(2.9, 0.12, 2.9), "ffe58a")
	sign_text("EXPAND BASE", Vector3(-9, 2, 13), 0.0045)
	# Grouped trees, rocks, flower beds and tufts, never a uniform empty plane.
	var rng := RandomNumberGenerator.new()
	rng.seed = 726
	for x in [-24, 24]:
		for z in [-24, -14, -2, 11, 21]:
			var tree := asset("tree", Vector3(x + rng.randf_range(-1, 1), 0, z))
			tree.scale = Vector3.ONE * rng.randf_range(0.9, 1.5)
			tree.rotation.y = rng.randf_range(0, TAU)
	for pos in [Vector3(-15,0,-13), Vector3(-6,0,-17), Vector3(7,0,-17), Vector3(15,0,-4), Vector3(-17,0,19)]:
		asset("tree", pos)
	for i in range(125):
		var x := rng.randf_range(-25,25)
		var z := rng.randf_range(-27,23)
		if absf(x) < 4 or absf(z+4) < 3 or (z > 9 and absf(x) < 14):
			continue
		if i % 4 == 0:
			var rock := box("Pebble", Vector3(x,0.18,z), Vector3(0.5,0.36,0.4), "b1bcb4",null,false)
			rock.rotation.y = rng.randf_range(0,TAU)
		else:
			for j in range(3):
				var blade := box("Grass tuft", Vector3(x+j*0.09,0.16,z),Vector3(0.055,0.32+j*0.07,0.06), "549840",null,false)
				blade.rotation.z = (j-1)*0.3
			if i % 5 == 0:
				box("Flower center",Vector3(x,0.35,z),Vector3(0.11,0.11,0.11),"f4cf63",null,false)
				for j in range(4):
					box("Flower petal",Vector3(x+cos(j*PI/2)*0.12,0.34,z+sin(j*PI/2)*0.12),Vector3(0.16,0.07,0.16),"fff5db",null,false)
	_build_fence(Vector3(-10,0,-9))
	_build_fence(Vector3(10,0,-10))
	box("Desert", Vector3(0, 0.08, -25), Vector3(20,0.15,8), "edd89f")
	for x in [-5.5,5.5]:
		box("Stone gate foot",Vector3(x,0.4,-21),Vector3(1.5,0.8,1.5),"bd9666")
		box("Stone gate",Vector3(x,2.6,-21),Vector3(1,4,1),"e0c58b")
	box("Gate lintel",Vector3(0,4.4,-21),Vector3(12.5,0.65,1.4),"d3ad6a")
	box("Gate sign",Vector3(0,4.1,-20.2),Vector3(5,1,.15),"705846")
	sign_text("RARE MEADOW / LV.3",Vector3(0,4.2,-20),0.004)
	_create_nest(Vector3(-10,0,-9),false)
	_create_nest(Vector3(10,0,-10),false)
	_create_nest(Vector3(0,0,-25),true)
	fox = asset("fox", fox_home)
	fox.name = "FoxGuardian"
	# Distant scenery fills the horizon without blocking the playable area.
	for i in range(9):
		var hill := MeshInstance3D.new()
		var hill_mesh := SphereMesh.new()
		hill_mesh.radial_segments = 16
		hill_mesh.rings = 8
		hill.mesh = hill_mesh
		var hill_mat := StandardMaterial3D.new()
		hill_mat.albedo_color = Color("72a973" if i%2==0 else "88b47c")
		hill.material_override = hill_mat
		add_child(hill)
		hill.position = Vector3(-55+i*14,-3,43+(i%3)*5)
		hill.scale = Vector3(18,9+(i%3)*3,15)
	for i in range(5):
		var cloud_pos := Vector3(-35+i*17,13+(i%2)*4,37+(i%3)*5)
		box("Cloud bank",cloud_pos,Vector3(8,1.1,3),"f8fcff",null,false)
		box("Cloud bank cap",cloud_pos+Vector3(-1,.7,0),Vector3(4.6,1.2,2.8),"ffffff",null,false)
	# Handcrafted chunky clouds.
	for i in range(9):
		var pos := Vector3(-45+i*12,17+(i%3)*2,-35-(i%2)*13)
		box("Cloud",pos,Vector3(8,1.1,3),"eefaff",null,false)
		box("Cloud cap",pos+Vector3(-1,0.7,0),Vector3(4.5,1,2.7),"f6fdff",null,false)

func _build_fence(center: Vector3) -> void:
	for x in [-3.3,-1.1,1.1,3.3]:
		box("Fence post",center+Vector3(x,.65,-2.4),Vector3(.25,1.3,.25),"b5824f")
		box("Post cap",center+Vector3(x,1.34,-2.4),Vector3(.34,.12,.34),"edc68e")
	for y in [.5,1.0]:
		box("Fence rail",center+Vector3(0,y,-2.4),Vector3(6.8,.17,.13),"cda16b")
	box("Nest clearing",center+Vector3(0,.04,0),Vector3(6.5,.12,4.3),"9bc963")

func _build_treadmill() -> void:
	box("Treadmill plinth",Vector3(9,.2,13),Vector3(2.5,.35,4.6),"e3e9e8")
	box("Treadmill frame",Vector3(9,.48,13),Vector3(2,.4,4),"52677c")
	box("Treadmill belt",Vector3(9,.71,13),Vector3(1.55,.08,3.6),"263e50")
	for z in range(7):
		box("Belt stripe",Vector3(9,.76,11.5+z*.5),Vector3(1.4,.02,.04),"607b8a",null,false)
	for x in [8.15,9.85]:
		box("Support",Vector3(x,1.4,14.3),Vector3(.13,1.5,.16),"7592a5")
	box("Console",Vector3(9,2.15,14.3),Vector3(2,.75,.25),"32577b")
	box("Screen",Vector3(9,2.2,14.14),Vector3(1.25,.38,.04),"68e3cf",null,false)
	sign_text("SPEED LAB",Vector3(9,3.1,13.9),0.004)

func _build_base(pos: Vector3, color: String, text: String) -> void:
	box("Foundation",pos+Vector3(0,.15,0),Vector3(13.8,.35,6.8),"9bafba")
	box("Floor",pos+Vector3(0,.38,0),Vector3(13.3,.18,6.3),"e7edef")
	box("Back wall",pos+Vector3(0,2.4,3),Vector3(13,4,.4),"dce8ed")
	box("Wall lower band",pos+Vector3(0,1.0,2.72),Vector3(13,.65,.13),color)
	box("Roof lower",pos+Vector3(0,4.4,0),Vector3(14,.35,7),"d8e6ef")
	box("Roof cap",pos+Vector3(0,4.68,0),Vector3(14.2,.32,7.2),color)
	box("Fascia",pos+Vector3(0,4.25,-3.3),Vector3(13.7,.55,.22),color)
	for x in [-6.2,6.2]:
		box("Column foot",pos+Vector3(x,.55,-2.8),Vector3(.85,.35,.85),color)
		box("Column",pos+Vector3(x,2.5,-2.8),Vector3(.48,3.8,.48),"edf5f5")
		box("Column top",pos+Vector3(x,4,-2.8),Vector3(.72,.3,.72),color)
	box("Sign border",pos+Vector3(0,5,-3.0),Vector3(5.4,1.12,.3),"203c61")
	box("Sign face",pos+Vector3(0,5,-3.19),Vector3(5.15,.87,.1),"f3f7e9")
	sign_text(text,pos+Vector3(0,5.02,-3.55),0.005)
	for x in [-4,-2.4,-.8,.8,2.4,4]:
		box("Pet bay back",pos+Vector3(x,1.6,2.45),Vector3(1.43,2.2,.17),color)
		box("Pet bay floor",pos+Vector3(x,.6,1.5),Vector3(1.5,.25,1.9),"f3f7fc")
		box("Bay canopy",pos+Vector3(x,2.85,1.8),Vector3(1.5,.18,1.6),"f4f8fc")
		for side in [-.75,.75]:
			box("Bay side",pos+Vector3(x+side,1.7,2.1),Vector3(.1,2.3,1.0),"f3f7fc")
		box("Bay pad",pos+Vector3(x,.76,.5),Vector3(1.15,.12,.65),"91dc63")
	# Ceiling strips and planted pots frame the entrance.
	for x in [-4,0,4]:
		box("Ceiling light",pos+Vector3(x,4.17,-.5),Vector3(1.6,.05,.35),"fff6c7",null,false)
	for x in [-7.1,7.1]:
		box("Planter",pos+Vector3(x,.6,-2.4),Vector3(1,1,1),"dfbc84")
		box("Shrub",pos+Vector3(x,1.35,-2.4),Vector3(1.25,.9,1.1),"61ac50",null,false)

func _create_nest(pos: Vector3, rare: bool) -> void:
	asset("nest",pos)
	var nest := {"pos":pos,"rare":rare,"egg":null,"timer":0.0}
	nests.append(nest)
	_spawn_egg(nest)

func _spawn_egg(nest: Dictionary) -> void:
	var egg := asset("egg", nest.pos + Vector3(0,1.0,0))
	if nest.rare:
		egg.scale = Vector3.ONE * 1.2
	nest.egg = egg

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	add_child(player)
	player.position = home
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 3.1
	collider.shape = capsule
	collider.position.y = 1.55
	player.add_child(collider)
	model = asset("avatar", Vector3.ZERO, player)
	arm_left = model.find_child("LeftArm", true, false)
	arm_right = model.find_child("RightArm", true, false)
	leg_left = model.find_child("LeftLeg", true, false)
	leg_right = model.find_child("RightLeg", true, false)
	camera = Camera3D.new()
	camera.fov = 65
	add_child(camera)
	camera.position = home + Vector3(0, 5, 9)
	camera.look_at(home + Vector3(0, 1.7, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			paused = not paused
			pause_panel.visible = paused
		if event.physical_keycode == KEY_E and not paused:
			_interact()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not paused:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, 0.15, 1.0)

func _physics_process(delta: float) -> void:
	if paused or preview_camera:
		return
	var input := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := input.normalized().rotated(Vector3.UP, yaw)
	var speed := (6.0 + speed_level * 1.2) * (1.45 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0) * (0.82 if carried != null else 1.0)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if player.is_on_floor():
		player.velocity.y = 8 if Input.is_physical_key_pressed(KEY_SPACE) else -0.1
	else:
		player.velocity.y -= 22 * delta
	player.move_and_slide()
	if direction.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), delta * 12)
	gait += delta * speed * 1.8
	var swing: float = sin(gait) * 0.45 if input.length_squared() > 0 else 0.0
	leg_left.rotation.x = swing
	leg_right.rotation.x = -swing
	arm_left.rotation.x = -1.0 if carried != null else -swing
	arm_right.rotation.x = -1.0 if carried != null else swing
	if absf(player.position.x) > 26 or player.position.z < -29 or player.position.z > 25 or player.position.y < -5:
		_reset_player()
	_update_game(delta)
	var focus := player.position + Vector3(0, 1.8, 0)
	var offset := Vector3(0, sin(pitch) * 10, cos(pitch) * 10).rotated(Vector3.UP, yaw)
	var query := PhysicsRayQueryParameters3D.create(focus, focus + offset)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var desired: Vector3 = hit.position + hit.normal * 0.35 if not hit.is_empty() else focus + offset
	camera.position = camera.position.lerp(desired, 1.0 - exp(-12.0 * delta))
	camera.look_at(focus)

func _update_game(delta: float) -> void:
	message_timer -= delta
	for nest in nests:
		if nest.egg == null:
			nest.timer -= delta
			if nest.timer <= 0:
				_spawn_egg(nest)
		else:
			nest.egg.rotation.y += delta * 0.5
	if hatching > 0:
		hatching -= delta
		if hatching <= 0:
			pet_count += 1
			_add_pet(pet_count - 1)
			if carrying_rare:
				coins += 150
			_notify("New pet! +$12/sec" + (" +$150 rare bonus!" if carrying_rare else ""))
			_save_progress()
	var chase: bool = carried != null and player.position.z < 5
	var target: Vector3 = player.position if chase else fox_home + Vector3(sin(gait * 0.02) * 3, 0, 0)
	target.y = 0
	var diff := target - fox.position
	if diff.length() > 0.1:
		fox.rotation.y = lerp_angle(fox.rotation.y, atan2(-diff.x, -diff.z), delta * 6)
		fox.position = fox.position.move_toward(target, delta * (6.8 if chase else 2.0))
	if chase and fox.position.distance_to(player.position) < 1.6:
		_reset_player()
	clock += delta
	if clock >= 1:
		var ticks := int(clock)
		coins = mini(100000000, coins + pet_count * 12 * ticks)
		clock -= ticks
	save_clock += delta
	if save_clock > 10:
		save_clock = 0
		_save_progress()
	_refresh_hud()

func _interact() -> void:
	var pos := player.position
	if carried != null and pos.distance_to(hatch_pad) < 3:
		if pet_count >= 3 + base_level * 3:
			_notify("Base full! Upgrade on the yellow pad.")
			return
		carried.queue_free()
		carried = null
		hatching = 3
		_notify("Hatching...")
		return
	if pos.distance_to(Vector3(9, 0, 13)) < 3:
		_upgrade(true)
		return
	if pos.distance_to(Vector3(-9, 0, 13)) < 3:
		_upgrade(false)
		return
	if carried != null or hatching > 0:
		return
	for nest in nests:
		if nest.egg == null or pos.distance_to(nest.pos) > 3:
			continue
		if nest.rare and speed_level < 3:
			_notify("Rare eggs require speed level 3!")
			return
		if pet_count >= 3 + base_level * 3:
			_notify("Base full! Upgrade on the yellow pad.")
			return
		carried = nest.egg
		carrying_rare = nest.rare
		nest.egg = null
		nest.timer = 8.0
		carried.reparent(model)
		carried.position = Vector3(0, 1.9, -1)
		_notify("Run to your blue HATCH pad! Press E to hatch.")
		return

func _upgrade(speed: bool) -> void:
	var level: int = speed_level if speed else base_level
	if level >= (10 if speed else 3):
		_notify("Maximum upgrade reached.")
		return
	var cost: int = (100 if speed else 250) * (level + 1)
	if coins < cost:
		_notify("Not enough coins! Need $%d" % cost)
		return
	coins -= cost
	if speed:
		speed_level += 1
	else:
		base_level += 1
	_notify("Upgrade complete!")
	_save_progress()

func _reset_player() -> void:
	if carried != null:
		carried.queue_free()
		carried = null
	player.position = home
	player.velocity = Vector3.ZERO
	_notify("Returned to base. Grab another egg!")

func _add_pet(index: int) -> void:
	var pet := Node3D.new()
	add_child(pet)
	pet.position = Vector3(-4 + (index % 6) * 1.6, 0.72, 18.4 - (index / 6) * 1.7)
	asset("cat" if index % 2 == 0 else "dragon", Vector3.ZERO, pet)
	sign_text("+$12/s", pet.position + Vector3(0,1.7,-0.2),0.003)
	pets.append(pet)

func _notify(text: String) -> void:
	message = text
	message_timer = 5

func ui_panel(pos: Vector2, size: Vector2, color: Color, parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_bottom = 3
	style.border_color = color.darkened(0.35)
	style.shadow_color = Color(0.03,0.1,0.18,0.20)
	style.shadow_size = 7
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

func ui_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var logo := ui_panel(Vector2(24,22),Vector2(254,88),Color("173653"),root)
	var logo_rows := VBoxContainer.new()
	logo_rows.add_theme_constant_override("separation",-4)
	logo.add_child(logo_rows)
	logo_rows.add_child(ui_label("EGG DASH",32,Color("fff4ce")))
	logo_rows.add_child(ui_label("PET RESCUE • MEADOW",11,Color("95c3d5")))
	var cash := ui_panel(Vector2(996,22),Vector2(260,62),Color("173653"),root)
	hud = ui_label("",28,Color("ffe08b"))
	cash.add_child(hud)
	var income := ui_panel(Vector2(1056,94),Vector2(200,42),Color("ecf7e8"),root)
	badge = ui_label("",16,Color("347145"))
	income.add_child(badge)
	var task := ui_panel(Vector2(24,128),Vector2(254,106),Color("f7f2df"),root)
	var tasks := VBoxContainer.new()
	task.add_child(tasks)
	tasks.add_child(ui_label("YOUR NEXT ADVENTURE",11,Color("738269")))
	quest = ui_label("Bring home an egg",18,Color("244459"))
	tasks.add_child(quest)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(214,8)
	progress.value = 35
	progress.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ebbb55")
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	progress.add_theme_stylebox_override("fill",fill)
	tasks.add_child(progress)
	for i in range(3):
		var item := ui_panel(Vector2(24,258+i*68),Vector2(114,56),Color(["487bab","d59845","8669ae"][i]),root)
		item.add_child(ui_label(["PETS","SHOP","INDEX"][i],17))
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet_label = ui_label("",13,Color("d4e8ee"))
	pet_label.position = Vector2(25,483)
	root.add_child(pet_label)
	var keys := ui_panel(Vector2(423,620),Vector2(434,70),Color("173653"),root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	keys.add_child(row)
	for text in ["1  PETS","2  EGGS","3  BASE","E  USE"]:
		var tile := ui_panel(Vector2.ZERO,Vector2(88,44),Color("35566e"),row)
		tile.add_child(ui_label(text,13,Color("f4f6e9")))
	var sprint := ui_panel(Vector2(1084,626),Vector2(172,62),Color("e66d4d"),root)
	sprint.add_child(ui_label("SHIFT  RUN",20))
	hint = ui_label("",17)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(310,567)
	hint.size = Vector2(660,44)
	hint.add_theme_color_override("font_shadow_color",Color("183d51"))
	hint.add_theme_constant_override("shadow_offset_y",2)
	root.add_child(hint)
	var controls := ui_label("WASD  MOVE    SPACE  JUMP    RMB  CAMERA    ESC  PAUSE",11,Color("ecf7f6"))
	controls.position = Vector2(427,700)
	root.add_child(controls)
	pause_panel = ui_panel(Vector2(420,230),Vector2(440,230),Color("173653"),root)
	var contents := VBoxContainer.new()
	pause_panel.add_child(contents)
	contents.add_child(ui_label("PAUSED",30))
	contents.add_child(ui_label("Progress saves automatically.",18))
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func(): paused=false; pause_panel.hide())
	contents.add_child(resume)
	pause_panel.hide()
	_refresh_hud()

func _refresh_hud() -> void:
	hud.text = "$  " + str(coins)
	badge.text = "+$%d / SEC   •   LV.%d" % [pet_count*12,speed_level+1]
	pet_label.text = "COLLECTION  %d / %d" % [pet_count,3+base_level*3]
	quest.text = "Return to your base" if carried != null else "Bring home an egg"
	var status := message if message_timer>0 or carried != null else "Explore the meadow. Find your next pet."
	if hatching>0:
		status = "HATCHING... %d" % ceili(hatching)
	hint.text = status

func _prepare_preview() -> void:
	# Preview uses the actual game scene, models, renderer and HUD.
	# Stage an egg-carrying moment without loading or saving player progress.
	preview_camera = true
	player.position = Vector3(0,0,7)
	model.rotation.y = PI - 0.38
	arm_left.rotation.x = -1.0
	arm_right.rotation.x = -1.0
	leg_left.rotation.x = 0.35
	leg_right.rotation.x = -0.35
	carried = nests[0].egg
	nests[0].egg = null
	carried.reparent(model)
	carried.position = Vector3(0,1.85,-1.02)
	fox.position = Vector3(3.8,0,5.2)
	fox.look_at(Vector3(0,0,7))
	var companion := asset("dragon",Vector3(1.4,0,6.5))
	companion.rotation.y = PI - 0.38
	for i in range(3):
		if i >= pets.size():
			_add_pet(i)
	coins = 2450
	pet_count = 3
	speed_level = 2
	camera.position = Vector3(-8.5,5.4,0)
	camera.look_at(Vector3(0,1.7,10.3))
	message = "Bring your egg home. A new friend is waiting!"
	_refresh_hud()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	var destination := OS.get_environment("EGG_DASH_CAPTURE")
	if destination.is_empty():
		destination = "user://gameplay-preview.png"
	screenshot.save_png(destination)
	print("GAMEPLAY_CAPTURE_SAVED "+destination)
	get_tree().quit()

func _load_progress() -> void:
	if smoke or preview or not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	coins = clampi(int(data.get("coins", 100)), 0, 100000000)
	speed_level = clampi(int(data.get("speed", 0)), 0, 10)
	base_level = clampi(int(data.get("base", 0)), 0, 3)
	pet_count = clampi(int(data.get("pets", 0)), 0, 3 + base_level * 3)

func _save_progress() -> void:
	if smoke or preview:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"coins": coins, "speed": speed_level, "base": base_level, "pets": pet_count}))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()
		get_tree().quit()

func _smoke_test() -> void:
	# Integration test using real scene nodes and gameplay methods.
	player.position = nests[0].pos
	_interact()
	_check(carried != null, "Egg pickup failed")
	player.position = hatch_pad
	_interact()
	_check(carried == null and hatching > 0, "Hatch did not start")
	_update_game(3.1)
	_check(pet_count == 1 and pets.size() == 1, "Pet hatch failed")
	var before := coins
	_update_game(1.0)
	_check(coins >= before + 12, "Passive income failed")
	coins = 1000
	_upgrade(true)
	_check(speed_level == 1 and coins == 900, "Speed purchase failed")
	_upgrade(false)
	_check(base_level == 1 and coins == 650, "Base purchase failed")
	player.position = nests[2].pos
	_interact()
	_check(carried == null, "Rare egg gate failed")
	speed_level = 3
	_interact()
	_check(carried != null and carrying_rare, "Rare egg pickup failed")
	player.position = hatch_pad
	_interact()
	before = coins
	_update_game(3.1)
	_check(pet_count == 2 and coins >= before + 150, "Rare bonus failed")
	player.position = nests[1].pos
	_interact()
	fox.position = player.position
	_update_game(0.01)
	_check(carried == null and player.position == home, "Guardian catch failed")
	if smoke_failures == 0:
		print("EGG_DASH_SMOKE_PASS: pickup, hatch, income, upgrades, rare gate, rare bonus, guardian")
	get_tree().quit(0 if smoke_failures == 0 else 1)

func _check(condition: bool, error: String) -> void:
	# Keep integration checks active in exported release binaries.
	if not condition:
		smoke_failures += 1
		push_error("EGG_DASH_SMOKE_FAIL: " + error)
