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
var mobile_ui: bool = false
var mobile_controls: MobileControls
var movement_test: bool = false
var movement_input := Vector3.ZERO
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
var slow_mode: bool = false
var camera_distance: float = 9.0
var hud_root: Control
var menu_panel: PanelContainer
var menu_body: VBoxContainer
var slow_button: Button
var leaderboard: Label
var event_label: Label
var selected_slot: int = 0
var ui_font: Font
var world_rng := RandomNumberGenerator.new()
var home := Vector3(0, 0, 10)
var hatch_pad := Vector3(0, 0, 13)
var fox_home := Vector3(-10, 0, -9)

func _ready() -> void:
	smoke = "--smoke-test" in OS.get_cmdline_user_args()
	movement_test = "--movement-test" in OS.get_cmdline_user_args()
	preview = "--preview" in OS.get_cmdline_user_args()
	mobile_ui = OS.has_feature("android") or "--mobile-ui" in OS.get_cmdline_user_args()
	get_viewport().msaa_3d = Viewport.MSAA_2X if mobile_ui else Viewport.MSAA_4X
	if mobile_ui: get_viewport().scaling_3d_scale = .75
	ui_font = load("res://assets/fonts/Interface-Bold.ttf")
	world_rng.seed = 42
	_load_progress()
	_build_world()
	_build_player()
	_build_ui()
	for i in pet_count:
		_add_pet(i)
	if smoke:
		call_deferred("_smoke_test")
	if movement_test:
		call_deferred("_movement_test")
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
	if mobile_ui and size.length()<15: mesh.visibility_range_end=75
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

func stud_surface(mesh: MeshInstance3D, color: String, tiled: bool = true) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/studs.gdshader")
	material.set_shader_parameter("base_color",Color(color).srgb_to_linear().lerp(Color(color),.35))
	material.set_shader_parameter("checker",tiled)
	mesh.material_override = material

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1094f0")
	sky_mat.sky_horizon_color = Color("b2e5ff")
	sky_mat.ground_horizon_color = Color("b2e5ff")
	sky_mat.ground_bottom_color = Color("7ac444")
	sky.sky_material = sky_mat
	settings.sky = sky
	settings.background_mode = Environment.BG_SKY
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("ffffff")
	settings.ambient_light_energy = 0.55
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62,-25,0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	add_child(sun)
	var floor_mesh := box("Baseplate 192 x 320",Vector3(0,-.5,-65),Vector3(192,1,320),"88ea24")
	stud_surface(floor_mesh,"81e41a")
	for x in [-96,96]:
		var wall := box("Perimeter wall",Vector3(x,9,-65),Vector3(1,18,320),"d5a46c")
		stud_surface(wall,"d4a670")
		box("Green rim",Vector3(x,18.1,-65),Vector3(1.4,.45,320),"49ef25",null,false)
	for z in [-225,95]:
		var wall := box("End wall",Vector3(0,9,z),Vector3(193,18,1),"d5a46c")
		stud_surface(wall,"d4a670")
		box("Wall rim",Vector3(0,18.1,z),Vector3(193,.4,1.4),"49ef25",null,false)
	# Open animal pens replace the invented buildings from earlier versions.
	for x in [-62,0,62]:
		_build_pen(Vector3(x,0,35),Vector2(42,38),true)
		if x != 0:
			_build_pen(Vector3(x,0,-8),Vector2(42,32),false)
	_build_pen(Vector3(0,0,76),Vector2(42,30),false)
	box("Safe zone boundary",Vector3(0,.025,5),Vector3(190,.045,.24),"f97c6a",null,false)
	_ground_text("SAFE ZONE",Vector3(0,.08,6.0),1.3,Color.WHITE)
	_ground_text("YOUR BASE",Vector3(0,.08,17),.75,Color.WHITE)
	# Original hatch pad retained in front of the player's pen.
	box("Hatch pad",hatch_pad+Vector3(0,.12,0),Vector3(3.2,.22,3.2),"63e9ff")
	_build_treadmill()
	box("Expansion button",Vector3(-9,.14,13),Vector3(3,.25,3),"f9cd34")
	sign_text("UPGRADE BASE\n[E] $250",Vector3(-9,2.4,13),.006)
	# Segmented biomes along the central expedition route.
	# Visual overlays share the baseplate collider: their thin edges must not block walking.
	var biome_names := ["Forest", "Lake", "Desert", "Jungle", "Snow"]
	var biome_colors := ["7bea20","64d5b5","f2d18a","49aa41","e1f0fa"]
	for i in range(5):
		var z: float = -21-i*41
		var terrain := box(biome_names[i],Vector3(0,.02,z),Vector3(96,.08,39),biome_colors[i],null,false)
		stud_surface(terrain,biome_colors[i])
		_ground_text(biome_names[i],Vector3(0,.1,z+13),1.1,Color.WHITE)
		if i > 0:
			box("Biome separator",Vector3(0,.06,z+19.5),Vector3(96,.04,.25),"ffffff",null,false)
		for j in range(7):
			var pos := Vector3(world_rng.randf_range(-42,42),0,z+world_rng.randf_range(-14,10))
			if i == 0 or i == 3:
				var tree := asset("tree",pos)
				tree.scale = Vector3.ONE*world_rng.randf_range(1.1,1.9)
			elif i == 2:
				box("Cactus",pos+Vector3(0,2,0),Vector3(.9,4,.9),"36995a")
			else:
				box("Rock",pos+Vector3(0,.5,0),Vector3(1.8,1,1.5),"b7c6ce")
	_create_nest(Vector3(-10,0,-9),false)
	_create_nest(Vector3(10,0,-10),false)
	_create_nest(Vector3(0,0,-108),true)
	fox = asset("chicken",fox_home)
	fox.scale = Vector3.ONE*1.6
	fox.name = "ForestGuardian"
	# Distant pets fill the surrounding pens, using independently created models.
	var species := ["chicken","crocodile","mammoth","dragon","fox","cat"]
	for i in range(6):
		var x: float = -62 if i<3 else 62
		var z: float = 28+(i%3)*10
		var pet := asset(species[i],Vector3(x+world_rng.randf_range(-7,7),0,z))
		pet.scale = Vector3.ONE*[4.2,4.0,3.2,6.0,3.2,5.0][i]
		pet.rotation.y = world_rng.randf_range(-.6,.6)
		sign_text(species[i].capitalize(),pet.position+Vector3(0,10,0),.009)
	_build_stall(Vector3(26,0,6))
	for i in range(8):
		var pos := Vector3(-90+i*25,24+(i%3)*3,-45)
		box("Cloud",pos,Vector3(13,1.5,5),"ffffff",null,false)
		box("Cloud top",pos+Vector3(-2,1,0),Vector3(7,1.5,4),"ffffff",null,false)

func _ground_text(text: String, pos: Vector3, size: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = ui_font
	label.font_size = 96
	label.pixel_size = .018*size
	label.outline_size = 10
	label.modulate = color
	label.rotation_degrees.x = -90
	add_child(label)
	label.position = pos

func fence_segment(a: Vector3,b: Vector3) -> void:
	var diff := b-a
	var length := diff.length()
	var steps := maxi(1,ceili(length/4.5))
	for i in range(steps+1):
		var pos := a.lerp(b,float(i)/steps)
		box("Fence post",pos+Vector3(0,.85,0),Vector3(.36,1.7,.36),"5c4c43")
		box("Post cap",pos+Vector3(0,1.72,0),Vector3(.46,.16,.46),"786452")
	for i in range(steps):
		var left := a.lerp(b,float(i)/steps)
		var right := a.lerp(b,float(i+1)/steps)
		for y in [.45,1.35]:
			var rail := box("Wooden rail",(left+right)*.5+Vector3(0,y,0),Vector3(left.distance_to(right),.16,.20),"be7835")
			rail.rotation.y = -atan2(diff.z,diff.x)
		for tilt in [-1,1]:
			var rail := box("Cross brace",(left+right)*.5+Vector3(0,.9,0),Vector3(sqrt(pow(left.distance_to(right),2)+.8),.12,.13),"b16a30",null,false)
			rail.rotation.y = -atan2(diff.z,diff.x)
			rail.rotation.z = tilt*atan2(.9,left.distance_to(right))

func _build_pen(center: Vector3,size: Vector2,own: bool) -> void:
	var x := size.x/2
	var z := size.y/2
	var floor_mesh := box("Pen grass",center+Vector3(0,.025,0),Vector3(size.x,.07,size.y),"8cec2b",null,false)
	stud_surface(floor_mesh,"8cec2b")
	fence_segment(center+Vector3(-x,0,-z),center+Vector3(-x,0,z))
	fence_segment(center+Vector3(x,0,-z),center+Vector3(x,0,z))
	fence_segment(center+Vector3(-x,0,z),center+Vector3(x,0,z))
	fence_segment(center+Vector3(-x,0,-z),center+Vector3(-4,0,-z))
	fence_segment(center+Vector3(4,0,-z),center+Vector3(x,0,-z))
	if own:
		sign_text("YOUR BASE" if absf(center.x)<1 else "PET GARDEN",center+Vector3(0,3,z),.007)

func _build_treadmill() -> void:
	box("Treadmill platform",Vector3(9,.15,13),Vector3(3,.3,4.7),"f8d62c")
	box("Belt frame",Vector3(9,.45,13),Vector3(2.2,.35,4.1),"34404d")
	box("Belt",Vector3(9,.65,13),Vector3(1.8,.08,3.8),"172b37")
	for z in range(8):
		box("Belt line",Vector3(9,.70,11.4+z*.45),Vector3(1.7,.02,.04),"657a87",null,false)
	for x in [8.05,9.95]:
		box("Support",Vector3(x,1.5,14.4),Vector3(.15,1.6,.15),"4b7297")
	box("Console",Vector3(9,2.3,14.4),Vector3(2.2,.8,.3),"305779")
	box("Display",Vector3(9,2.3,14.2),Vector3(1.5,.4,.03),"58e5f4",null,false)
	sign_text("Upgrade Treadmill\n[E]",Vector3(11.5,3,13),.005)

func _build_stall(pos: Vector3) -> void:
	for x in [-2,2]:
		box("Stall post",pos+Vector3(x,1.7,0),Vector3(.18,3.4,.18),"d2ab64")
	for i in range(8):
		var stripe := box("Canopy stripe",pos+Vector3(-2.1+i*.6,3.5,0),Vector3(.6,.12,3),"ef4444" if i%2==0 else "fff9dd")
		stripe.rotation.x = .15
	box("Counter",pos+Vector3(0,1,0),Vector3(4.5,1.1,1.2),"c29455")
	sign_text("SELL",pos+Vector3(0,4.3,0),.012)

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
	camera.fov = 70
	add_child(camera)
	camera.position = home + Vector3(0, 5, 9)
	camera.look_at(home + Vector3(0, 1.7, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			paused = not paused
			if paused:
				_open_menu("Settings")
			else:
				menu_panel.hide()
				_resume_touch()
		if event.physical_keycode == KEY_F11:
			_fullscreen()
		if event.physical_keycode == KEY_E and not paused:
			_interact()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(5, camera_distance-1.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(45,camera_distance+1.5)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not paused:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, 0.15, 1.0)

func _physics_process(delta: float) -> void:
	if paused or preview_camera:
		return
	var input := movement_input if movement_test else Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if mobile_controls!=null and not movement_test:
		input += Vector3(mobile_controls.movement.x,0,mobile_controls.movement.y)
	var direction := input.limit_length(1.0).rotated(Vector3.UP, yaw)
	var speed := (6.0 if slow_mode else 8.0 + speed_level * 1.2) * (1.45 if Input.is_physical_key_pressed(KEY_SHIFT) or (mobile_controls!=null and mobile_controls.sprinting) else 1.0) * (0.82 if carried != null else 1.0)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if player.is_on_floor():
		player.velocity.y = 8 if Input.is_physical_key_pressed(KEY_SPACE) or (mobile_controls!=null and mobile_controls.jump_held) else -0.1
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
	if absf(player.position.x) > 95 or player.position.z < -224 or player.position.z > 88 or player.position.y < -5:
		_reset_player()
	_update_game(delta)
	var focus := player.position + Vector3(0, 1.8, 0)
	var offset := Vector3(0, sin(pitch) * camera_distance, cos(pitch) * camera_distance).rotated(Vector3.UP, yaw)
	var query := PhysicsRayQueryParameters3D.create(focus, focus + offset)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var desired: Vector3 = hit.position + hit.normal * 0.35 if not hit.is_empty() else focus + offset
	camera.position = camera.position.lerp(desired, 1.0 - exp(-12.0 * delta))
	camera.look_at(focus)

func _update_game(delta: float) -> void:
	var previous_cycle := floori(elapsed/240.0)
	elapsed += delta
	if floori(elapsed/240.0)>previous_cycle:
		for nest in nests:
			if nest.egg==null:
				nest.timer=0
		_notify("Eggs refreshed!")
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
	pet.position = Vector3(-13+(index%4)*8.5,.05,26+floori(index/4.0)*10)
	var species := ["chicken","cat","crocodile","dragon","fox","mammoth"]
	var creature := asset(species[index%6],Vector3.ZERO,pet)
	creature.scale = Vector3.ONE*(2.2 if index%6!=5 else 2.0)
	creature.rotation.y = PI
	var ring := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 1.3
	shape.bottom_radius = 1.45
	shape.height = .18
	ring.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("946940")
	ring.material_override = material
	pet.add_child(ring)
	ring.position.y = .1
	sign_text("+$12/s",pet.position+Vector3(0,4.8,0),.008)
	pets.append(pet)

func _notify(text: String) -> void:
	message = text
	message_timer = 5

func ink_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",ui_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color("101010"))
	label.add_theme_constant_override("outline_size",maxi(4,font_size/6))
	label.add_theme_constant_override("shadow_offset_y",2)
	return label

func hud_button(text: String,pos: Vector2,size: Vector2,color: Color,action: Callable,anchor: int = Control.PRESET_TOP_LEFT) -> Button:
	var button := Button.new()
	hud_root.add_child(button)
	button.set_anchors_and_offsets_preset(anchor)
	button.position += pos
	button.size = size
	button.text = text
	button.add_theme_font_override("font",ui_font)
	button.add_theme_font_size_override("font_size",30)
	button.add_theme_color_override("font_color",Color.WHITE)
	button.add_theme_color_override("font_outline_color",Color.BLACK)
	button.add_theme_constant_override("outline_size",9)
	for kind in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(.15) if kind=="hover" else color.darkened(.12) if kind=="pressed" else color
		style.set_border_width_all(4)
		style.border_color = Color("201a15")
		style.set_corner_radius_all(5)
		style.shadow_color = Color(0,0,0,.25)
		style.shadow_size = 2
		button.add_theme_stylebox_override(kind,style)
	if text in ["Shop","Index","EGG","PETS"]:
		button.icon = load("res://assets/icons/"+{"Shop":"cart","Index":"book","EGG":"egg","PETS":"paw"}[text]+".svg")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",48)
		button.add_theme_constant_override("h_separation",8)
		if text in ["EGG","PETS"]:
			button.text = ""
	button.pressed.connect(action)
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_root)
	# Compact platform-like navigation. Original icons, no platform branding.
	for i in range(5):
		var nav := hud_button(["≡","☰","…","▣","⚙"][i],Vector2(16+i*58,14),Vector2(50,50),Color("202428"),_open_menu.bind("Settings"))
		for state in ["normal","hover","pressed"]:
			var style := nav.get_theme_stylebox(state) as StyleBoxFlat
			style.set_corner_radius_all(25)
			style.set_border_width_all(0)
	hud_button("Shop",Vector2(18,-116),Vector2(190,76),Color("62e80c"),_open_menu.bind("Shop"),Control.PRESET_CENTER_LEFT)
	hud_button("Index",Vector2(18,-30),Vector2(190,76),Color("14c7f3"),_open_menu.bind("Index"),Control.PRESET_CENTER_LEFT)
	slow_button = hud_button("",Vector2(18,61),Vector2(113,49),Color("43652a"),_toggle_slow,Control.PRESET_CENTER_LEFT)
	var toggle := ColorRect.new()
	toggle.color = Color("8bff00")
	toggle.position = Vector2(9,9)
	toggle.size = Vector2(32,31)
	toggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slow_button.add_child(toggle)
	var slow_text := ink_label("Slow Mode",24)
	hud_root.add_child(slow_text)
	slow_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	slow_text.position += Vector2(145,65)
	# Cash and movement progression at lower left, as in the real layout.
	badge = ink_label("",48,Color("ff4e89"))
	hud_root.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	badge.position += Vector2(82,-146)
	hud = ink_label("",48,Color("46ff21"))
	hud_root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.position += Vector2(82,-77)
	for kind in ["shoe","cash"]:
		var icon := TextureRect.new()
		hud_root.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		icon.position.x = 12
		icon.offset_top = badge.offset_top if kind=="shoe" else hud.offset_top
		icon.size = Vector2(64,64)
		icon.texture = load("res://assets/icons/"+kind+".svg")
		icon.offset_bottom = icon.offset_top+64
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Inventory scales around the bottom center instead of a decorative wide panel.
	for i in range(10):
		var slot := hud_button("",Vector2(-315+i*64,-68),Vector2(59,61),Color(0.12,.16,.1,.6),_select_slot.bind(i),Control.PRESET_CENTER_BOTTOM)
		slot.add_theme_font_size_override("font_size",16)
		slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var number := ink_label(str((i+1)%10),13)
		number.position = Vector2(4,1)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(number)
		var icon := TextureRect.new()
		icon.position = Vector2(12,19)
		icon.size = Vector2(36,36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = load("res://assets/icons/"+["stick","egg","egg","cat","fox","crocodile","mammoth","chicken","dragon","paw"][i]+".svg")
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
	# Right-side inventory tabs.
	hud_button("EGG",Vector2(-100,-68),Vector2(82,82),Color("f06455"),_open_menu.bind("Eggs"),Control.PRESET_CENTER_RIGHT).add_theme_font_size_override("font_size",22)
	hud_button("PETS",Vector2(-100,26),Vector2(82,82),Color("f5b456"),_open_menu.bind("Pets"),Control.PRESET_CENTER_RIGHT).add_theme_font_size_override("font_size",20)
	event_label = ink_label("",30)
	hud_root.add_child(event_label)
	event_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	event_label.position += Vector2(-245,-65)
	# A local leaderboard shows real session data, rather than fabricated players.
	var board := PanelContainer.new()
	hud_root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	board.position += Vector2(-344,16)
	board.size = Vector2(325,76)
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.06,.10,.12,.65)
	board_style.set_corner_radius_all(4)
	board_style.content_margin_left = 14
	board_style.content_margin_top = 9
	board.add_theme_stylebox_override("panel",board_style)
	leaderboard = ink_label("",15)
	board.add_child(leaderboard)
	hint = ink_label("",24)
	hud_root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position += Vector2(-550,-133)
	hint.size = Vector2(1100,48)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_panel = PanelContainer.new()
	hud_root.add_child(menu_panel)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.position += Vector2(-330,-230)
	menu_panel.size = Vector2(660,460)
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color("354450")
	menu_style.set_border_width_all(5)
	menu_style.border_color = Color("1d252b")
	menu_style.set_corner_radius_all(14)
	menu_style.content_margin_left = 30
	menu_style.content_margin_right = 30
	menu_style.content_margin_top = 20
	menu_style.content_margin_bottom = 20
	menu_panel.add_theme_stylebox_override("panel",menu_style)
	menu_body = VBoxContainer.new()
	menu_body.add_theme_constant_override("separation",15)
	menu_panel.add_child(menu_body)
	menu_panel.hide()
	pause_panel = menu_panel
	if mobile_ui:
		mobile_controls = MobileControls.new()
		hud_root.add_child(mobile_controls)
		mobile_controls.interacted.connect(func():
			if not paused: _interact())
		mobile_controls.camera_dragged.connect(func(delta: Vector2):
			if not paused:
				yaw-=delta.x*.004
				pitch=clampf(pitch+delta.y*.003,.15,1.0))
		# Move resources away from the left thumb; keep menus in front of controls.
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		badge.position=Vector2(80,90)
		hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hud.position=Vector2(80,155)
		for child in hud_root.get_children():
			if child is TextureRect:
				child.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				child.position=Vector2(12,90 if child.texture.resource_path.ends_with("shoe.svg") else 155)
				child.size=Vector2(64,64)
		menu_panel.move_to_front()
	_refresh_hud()

func _toggle_slow() -> void:
	slow_mode = not slow_mode
	var toggle := slow_button.get_child(0) as ColorRect
	toggle.position.x = 72 if slow_mode else 9
	_notify("Slow Mode ON" if slow_mode else "Slow Mode OFF")

func _select_slot(index: int) -> void:
	selected_slot = index
	_notify("Selected slot %d" % (index+1))

func _open_menu(kind: String) -> void:
	for child in menu_body.get_children():
		menu_body.remove_child(child)
		child.queue_free()
	menu_body.add_child(ink_label(kind,38))
	if kind == "Shop":
		menu_body.add_child(ink_label("Spend earned coins on upgrades",21))
		for speed in [true,false]:
			var button := Button.new()
			button.text = ("Upgrade Speed  $%d" % (100*(speed_level+1))) if speed else ("Expand Base  $%d" % (250*(base_level+1)))
			button.custom_minimum_size.y = 60
			button.add_theme_font_size_override("font_size",24)
			button.pressed.connect(func(): _upgrade(speed); _open_menu("Shop"))
			menu_body.add_child(button)
	elif kind == "Index" or kind == "Pets":
		menu_body.add_child(ink_label("Owned: %d / %d" % [pet_count,3+base_level*3],25))
		menu_body.add_child(ink_label("Chicken • Cat • Crocodile\nDragon • Fox • Mammoth",24))
		menu_body.add_child(ink_label("Income: $%d / second" % (pet_count*12),25,Color("6eff39")))
	elif kind == "Eggs":
		menu_body.add_child(ink_label("Carrying an egg" if carried!=null else "No egg carried",26))
		menu_body.add_child(ink_label("Find a nest, press E, return to HATCH.\nRare eggs require Speed Lv.3.",22))
	else:
		menu_body.add_child(ink_label("WASD move • Space jump • Shift sprint\nRMB camera • Mouse wheel zoom\nE interact • Esc pause • F11 fullscreen",20))
		var full := Button.new()
		full.text = "Toggle fullscreen"
		full.pressed.connect(_fullscreen)
		menu_body.add_child(full)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 50
	close.pressed.connect(func(): menu_panel.hide(); paused=false; _resume_touch())
	menu_body.add_child(close)
	menu_panel.show()
	if mobile_controls!=null:
		mobile_controls.reset_controls()
		mobile_controls.set_process_unhandled_input(false)
		mobile_controls.hide()

func _fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _refresh_hud() -> void:
	hud.text = "$"+str(coins)
	badge.text = str(speed_level*100+100)
	leaderboard.text = "People                 Money       Speed\nYou                       $%d         %d" % [coins,speed_level*100+100]
	event_label.text = "in %dm %02ds" % [int(240-fmod(elapsed,240))/60,int(240-fmod(elapsed,240))%60]
	hint.text = message if message_timer>0 or carried!=null else ""
	if hatching>0:
		hint.text = "HATCHING... %d" % ceili(hatching)

func _prepare_preview() -> void:
	preview_camera = true
	player.position = Vector3(0,0,34)
	model.rotation.y = PI-.15
	for i in range(6):
		if i>=pets.size():
			_add_pet(i)
	coins = 2450
	pet_count = 6
	base_level = 1
	speed_level = 3
	camera.position = Vector3(7,8.5,47)
	camera.look_at(Vector3(0,1.8,33))
	message_timer = 0
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
	if smoke or preview or movement_test or not FileAccess.file_exists(SAVE_PATH):
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
	if smoke or preview or movement_test:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"coins": coins, "speed": speed_level, "base": base_level, "pets": pet_count}))

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:
		_save_progress()
		if mobile_controls!=null: mobile_controls.reset_controls()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		paused=not paused
		if paused: _open_menu("Settings")
		else: menu_panel.hide(); _resume_touch()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()
		get_tree().quit()

func _smoke_test() -> void:
	# Integration test using real scene nodes and gameplay methods.
	if mobile_controls!=null:
		await _mobile_regression()
	await get_tree().process_frame
	for child in hud_root.get_children():
		if child is Button and child.text=="Shop":
			child.pressed.emit()
	_check(menu_panel.visible,"Shop button did not open the menu")
	menu_panel.hide()
	_toggle_slow()
	_check(slow_mode,"Slow mode button failed")
	_toggle_slow()
	_check(not slow_mode,"Slow mode toggle failed")
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
		print("EGG_DASH_SMOKE_PASS: pickup, hatch, income, upgrades, rare gate, rare bonus, guardian, UI menus, slow mode")
	get_tree().quit(0 if smoke_failures == 0 else 1)

func _check(condition: bool, error: String) -> void:
	# Keep integration checks active in exported release binaries.
	if not condition:
		smoke_failures += 1
		push_error("EGG_DASH_SMOKE_FAIL: " + error)

func _walk_regression(label: String, start: Vector3, direction: Vector3, seconds: float, must_reach: bool = true) -> void:
	movement_input = Vector3.ZERO
	player.position = start + Vector3(0,.25,0)
	player.velocity = Vector3.ZERO
	for i in range(20):
		await get_tree().physics_frame
	var origin := player.position
	movement_input = direction
	for i in range(ceili(seconds*60)):
		await get_tree().physics_frame
	movement_input = Vector3.ZERO
	var progress := (player.position-origin).dot(direction)
	var expected := seconds*6.0
	var passed := progress>expected-1.0 if must_reach else progress<expected*.7
	if not passed:
		for i in range(player.get_slide_collision_count()):
			var hit := player.get_slide_collision(i)
			var collider := hit.get_collider() as Node
			print("MOVEMENT_BLOCKER ",collider.get_parent().name if collider!=null else "unknown"," normal=",hit.get_normal())
	_check(passed,"Movement route "+label+" progress="+str(progress)+" expected="+str(expected))
	print("MOVEMENT_ROUTE ",label," progress=",snappedf(progress,.01)," passed=",passed)

func _movement_test() -> void:
	slow_mode = true
	await _walk_regression("safe_zone_to_forest",Vector3(0,0,3),Vector3.FORWARD,2.0)
	await _walk_regression("forest_to_safe_zone",Vector3(0,0,-9),Vector3.BACK,2.0)
	await _walk_regression("pen_entry",Vector3(3,0,10),Vector3.BACK,2.0)
	await _walk_regression("pen_exit",Vector3(3,0,22),Vector3.FORWARD,2.0)
	for edge in [-40.5,-42.5,-81.5,-83.5,-122.5,-124.5,-163.5,-165.5]:
		await _walk_regression("biome_"+str(edge),Vector3(0,0,edge+3),Vector3.FORWARD,1.0)
	await _walk_regression("fence_stays_solid",Vector3(18,0,35),Vector3.RIGHT,2.0,false)
	await _walk_regression("outer_wall_stays_solid",Vector3(91,0,70),Vector3.RIGHT,2.0,false)
	if smoke_failures==0:
		print("EGG_DASH_MOVEMENT_PASS: 14 physical walking routes")
	get_tree().quit(0 if smoke_failures==0 else 1)

func _resume_touch() -> void:
	if mobile_controls!=null:
		mobile_controls.set_process_unhandled_input(true)
		mobile_controls.show()

func _send_touch(index: int, pos: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.position=pos
	event.pressed=down
	get_viewport().push_input(event,true)

func _send_drag(index: int,pos: Vector2,delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index
	event.position=pos
	event.relative=delta
	get_viewport().push_input(event,true)

func _mobile_regression() -> void:
	await get_tree().process_frame
	_resume_touch()
	var center := mobile_controls.joystick_center

	_send_touch(0,center,true)
	_send_drag(0,center+Vector2(60,-70),Vector2(60,-70))
	await get_tree().process_frame
	_check(mobile_controls.movement.y<-.3 and mobile_controls.movement.x>.3,"Touch joystick direction")
	var old_yaw := yaw
	_send_touch(1,Vector2(1000,330),true)
	_send_drag(1,Vector2(1040,350),Vector2(40,20))
	await get_tree().process_frame
	_check(yaw!=old_yaw and mobile_controls.movement.length()>.3,"Simultaneous move/camera touch")
	_send_touch(1,Vector2(1040,350),false)
	var jump_center: Vector2=mobile_controls.actions.jump.position+Vector2(72,72)
	_send_touch(2,jump_center,true)
	await get_tree().process_frame
	_check(mobile_controls.jump_held,"Touch jump press")
	_send_touch(2,jump_center,false)
	_send_touch(0,center,false)
	await get_tree().process_frame
	_check(not mobile_controls.jump_held and mobile_controls.movement==Vector2.ZERO,"Touch release resets controls")
	var run_center: Vector2=mobile_controls.actions.run.position+Vector2(72,72)
	_send_touch(3,run_center,true)
	_send_touch(3,run_center,false)
	await get_tree().process_frame
	_check(mobile_controls.sprinting,"Touch run toggle")
	mobile_controls.reset_controls()
	yaw=0
	if smoke_failures==0:
		print("EGG_DASH_TOUCH_PASS: joystick, simultaneous camera, jump, run, release")
