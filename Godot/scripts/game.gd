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
var arm_left: MeshInstance3D
var arm_right: MeshInstance3D
var leg_left: MeshInstance3D
var leg_right: MeshInstance3D
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
var hud: Label
var hint: Label
var pause_panel: PanelContainer
var message: String = "Find an egg nest. Press E to grab an egg!"
var message_timer: float = 8.0
var home := Vector3(0, 0, 10)
var hatch_pad := Vector3(0, 0, 13)
var fox_home := Vector3(-10, 0, -9)

func _ready() -> void:
	smoke = "--smoke-test" in OS.get_cmdline_user_args()
	_load_progress()
	_build_world()
	_build_player()
	_build_ui()
	for i in pet_count:
		_add_pet(i)
	if smoke:
		call_deferred("_smoke_test")

func box(label: String, pos: Vector3, size: Vector3, color: String, parent: Node3D = null, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.85
	mesh.material_override = mat
	(parent if parent != null else self).add_child(mesh)
	mesh.position = pos
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
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
	add_child(label)
	label.position = pos

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("64b3ef")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	box("Grass", Vector3(0, -0.55, -2), Vector3(54, 1, 56), "65bb40")
	box("Road", Vector3(0, -0.02, -2), Vector3(5, 0.12, 39), "a5afb9")
	box("Crossroad", Vector3(0, -0.01, -4), Vector3(40, 0.12, 4), "a5afb9")
	_build_base(Vector3(0, 0, 17), "2580ea", "YOUR BASE")
	_build_base(Vector3(-17, 0, -17), "ef554b", "RED BASE")
	_build_base(Vector3(17, 0, -17), "9b5bd8", "PURPLE BASE")
	box("Hatch pad", hatch_pad, Vector3(3, 0.2, 3), "63e6ff")
	sign_text("HATCH [E]", hatch_pad + Vector3(0, 1, 0))
	box("Treadmill", Vector3(9, 0.3, 13), Vector3(2, 0.6, 4), "344357")
	box("Screen", Vector3(9, 1.5, 14.5), Vector3(2, 1, 0.3), "2580ea")
	sign_text("SPEED [E]", Vector3(9, 3, 13))
	box("Base upgrade", Vector3(-9, 0.1, 13), Vector3(3, 0.25, 3), "f7c442")
	sign_text("BASE UPGRADE [E]", Vector3(-9, 2, 13), 0.006)
	for x in [-24, 24]:
		for z in [-23, -10, 3, 15]:
			box("Trunk", Vector3(x, 1.5, z), Vector3(1, 3, 1), "8b603e")
			box("Canopy", Vector3(x, 4, z), Vector3(4, 3, 4), "32943b")
	box("Desert", Vector3(0, -0.01, -25), Vector3(20, 0.15, 8), "e7cd85")
	sign_text("RARE EGGS / SPEED LV 3", Vector3(0, 4, -22))
	for x in [-5, 5]:
		box("Gate", Vector3(x, 2, -21), Vector3(0.6, 4, 0.6), "edba36")
	_create_nest(Vector3(-10, 0, -9), false)
	_create_nest(Vector3(10, 0, -10), false)
	_create_nest(Vector3(0, 0, -25), true)
	fox = Node3D.new()
	fox.name = "FoxGuardian"
	add_child(fox)
	fox.position = fox_home
	box("Body", Vector3(0, 1, 0), Vector3(2, 1.4, 2.6), "ea7f20", fox, false)
	box("Head", Vector3(0, 1.9, -1), Vector3(2, 1.6, 1.6), "f29230", fox, false)
	box("Muzzle", Vector3(0, 1.6, -1.9), Vector3(1.4, 0.6, 0.5), "fff2da", fox, false)
	for x in [-0.6, 0.6]:
		box("Ear", Vector3(x, 2.9, -1), Vector3(0.5, 0.7, 0.5), "ea7f20", fox, false)
		box("Eye", Vector3(x, 2.1, -1.83), Vector3(0.18, 0.22, 0.1), "202b39", fox, false)

func _build_base(pos: Vector3, color: String, text: String) -> void:
	box(text + " floor", pos, Vector3(13, 0.2, 6), "cfd8e5")
	box("Back wall", pos + Vector3(0, 2, 3), Vector3(13, 4, 0.4), color)
	box("Roof", pos + Vector3(0, 4, 0), Vector3(13, 0.4, 6), color)
	for x in [-6, 6]:
		box("Column", pos + Vector3(x, 2, -2.5), Vector3(0.5, 4, 0.5), color)
	sign_text(text, pos + Vector3(0, 4.8, -3))

func _create_nest(pos: Vector3, rare: bool) -> void:
	box("Nest", pos + Vector3(0, 0.2, 0), Vector3(2.4, 0.4, 2.4), "9e703f")
	var nest := {"pos": pos, "rare": rare, "egg": null, "timer": 0.0}
	nests.append(nest)
	_spawn_egg(nest)

func _spawn_egg(nest: Dictionary) -> void:
	var egg := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.4
	egg.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e9b3ff" if nest.rare else "b7f1fc")
	egg.material_override = mat
	add_child(egg)
	egg.position = nest.pos + Vector3(0, 1.1, 0)
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
	model = Node3D.new()
	player.add_child(model)
	box("Torso", Vector3(0, 1.65, 0), Vector3(1.2, 1.2, 0.7), "ef443c", model, false)
	box("Head", Vector3(0, 2.65, 0), Vector3.ONE * 0.85, "ffd84a", model, false)
	box("Cap", Vector3(0, 3.08, 0), Vector3(0.9, 0.25, 0.9), "303744", model, false)
	for x in [-0.19, 0.19]:
		box("Eye", Vector3(x, 2.72, -0.44), Vector3(0.09, 0.12, 0.04), "243040", model, false)
	box("Smile", Vector3(0, 2.47, -0.44), Vector3(0.24, 0.05, 0.04), "243040", model, false)
	arm_left = box("Left arm", Vector3(-0.94, 1.6, 0), Vector3(0.55, 1.2, 0.65), "ffd84a", model, false)
	arm_right = box("Right arm", Vector3(0.94, 1.6, 0), Vector3(0.55, 1.2, 0.65), "ffd84a", model, false)
	leg_left = box("Left leg", Vector3(-0.32, 0.5, 0), Vector3(0.58, 1, 0.65), "287ce2", model, false)
	leg_right = box("Right leg", Vector3(0.32, 0.5, 0), Vector3(0.58, 1, 0.65), "287ce2", model, false)
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
	if paused:
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
	pet.position = Vector3(-4 + (index % 6) * 1.6, 0.7, 17 + (index / 6) * 1.7)
	var color := "acbaca" if index % 2 == 0 else "78cf50"
	box("Pet", Vector3.ZERO, Vector3.ONE * 0.9, color, pet, false)
	for x in [-0.24, 0.24]:
		box("Ear", Vector3(x, 0.55, 0), Vector3(0.23, 0.3, 0.3), color, pet, false)
		box("Eye", Vector3(x, 0.1, -0.47), Vector3(0.1, 0.16, 0.05), "202b39", pet, false)
	box("Income pad", pet.position + Vector3(0, -0.5, -0.8), Vector3(1.1, 0.12, 0.6), "83ef35")
	sign_text("+$12/s", pet.position + Vector3(0, 1, 0), 0.004)
	pets.append(pet)

func _notify(text: String) -> void:
	message = text
	message_timer = 5

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(340, 185)
	root.add_child(panel)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 22)
	panel.add_child(hud)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -105
	hint.offset_left = 30
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(hint)
	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(420, 230)
	pause_panel.size = Vector2(440, 230)
	root.add_child(pause_panel)
	var contents := VBoxContainer.new()
	pause_panel.add_child(contents)
	var text := Label.new()
	text.text = "PAUSED\nProgress saves automatically."
	text.add_theme_font_size_override("font_size", 26)
	contents.add_child(text)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func(): paused = false; pause_panel.hide())
	contents.add_child(resume)
	pause_panel.hide()
	_refresh_hud()

func _refresh_hud() -> void:
	hud.text = " EGG DASH\n $%s  |  +$%d/s\n Pets %d/%d  |  Speed Lv.%d\n Speed $%d  /  Base $%d" % [str(coins), pet_count * 12, pet_count, 3 + base_level * 3, speed_level, 100 * (speed_level + 1), 250 * (base_level + 1)]
	var status := message if message_timer > 0 or carried != null else "Collect eggs, hatch pets, upgrade your base!"
	if hatching > 0:
		status = "HATCHING... %d" % ceili(hatching)
	hint.text = status + "\nWASD Move | Space Jump | Shift Sprint | Hold RMB: Camera\nE: Pick up / Hatch / Upgrade | Esc: Pause"

func _load_progress() -> void:
	if smoke or not FileAccess.file_exists(SAVE_PATH):
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
	if smoke:
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
	assert(carried != null, "Egg pickup failed")
	player.position = hatch_pad
	_interact()
	assert(carried == null and hatching > 0, "Hatch did not start")
	_update_game(3.1)
	assert(pet_count == 1 and pets.size() == 1, "Pet hatch failed")
	var before := coins
	_update_game(1.0)
	assert(coins >= before + 12, "Passive income failed")
	coins = 1000
	_upgrade(true)
	assert(speed_level == 1 and coins == 900, "Speed purchase failed")
	_upgrade(false)
	assert(base_level == 1 and coins == 650, "Base purchase failed")
	player.position = nests[2].pos
	_interact()
	assert(carried == null, "Rare egg gate failed")
	speed_level = 3
	_interact()
	assert(carried != null and carrying_rare, "Rare egg pickup failed")
	player.position = hatch_pad
	_interact()
	before = coins
	_update_game(3.1)
	assert(pet_count == 2 and coins >= before + 150, "Rare bonus failed")
	player.position = nests[1].pos
	_interact()
	fox.position = player.position
	_update_game(0.01)
	assert(carried == null and player.position == home, "Guardian catch failed")
	print("EGG_DASH_SMOKE_PASS: pickup, hatch, income, upgrades, rare gate, rare bonus, guardian")
	get_tree().quit(0)
