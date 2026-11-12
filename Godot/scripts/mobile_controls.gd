class_name MobileControls
extends Control

signal interacted
signal camera_dragged(delta: Vector2)
var movement := Vector2.ZERO
var jump_held: bool = false
var sprinting: bool = false
var joystick_finger: int = -1
var camera_finger: int = -1
var joystick_center := Vector2.ZERO
var joystick_tip := Vector2.ZERO
var joystick_radius: float = 108.0
var actions: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_action("JUMP", "jump")
	_make_action("USE", "use")
	_make_action("RUN", "run")
	resized.connect(_layout)
	_layout()

func _make_action(caption: String, key: String) -> void:
	var button := TouchScreenButton.new()
	button.name = caption
	button.texture_normal = load("res://assets/icons/touch_"+key+".svg")
	button.texture_pressed = load("res://assets/icons/touch_"+key+"_pressed.svg")
	var shape := CircleShape2D.new()
	shape.radius = 72
	button.shape = shape
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	button.pressed.connect(func():
		if key=="jump": jump_held=true
		elif key=="run": sprinting=not sprinting; queue_redraw()
		else: interacted.emit())
	button.released.connect(func():
		if key=="jump": jump_held=false)
	add_child(button)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font",load("res://assets/fonts/Interface-Bold.ttf"))
	label.add_theme_font_size_override("font_size",27)
	label.add_theme_color_override("font_outline_color",Color("173044"))
	label.add_theme_constant_override("outline_size",5)
	label.position = Vector2(0,52)
	label.size = Vector2(144,42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	actions[key] = button

func _layout() -> void:
	joystick_center = Vector2(220,size.y-240)
	if joystick_finger<0:
		joystick_tip = joystick_center
	var portrait := size.y>size.x
	var positions := {
		"jump":Vector2(size.x-160,size.y-180),
		"use":Vector2(size.x-170,size.y-370),
		"run":Vector2(size.x-345,size.y-180)}
	if portrait:
		positions["use"] = Vector2(size.x-160,size.y-370)
	for key in actions:
		actions[key].position = positions[key]-Vector2(72,72)
	queue_redraw()

func _draw() -> void:
	draw_circle(joystick_center,joystick_radius,Color(0.05,0.10,0.15,.40))
	draw_arc(joystick_center,joystick_radius,0,TAU,64,Color(1,1,1,.65),4,true)
	draw_circle(joystick_tip,45,Color(0.95,0.98,1,.8))
	draw_arc(joystick_tip,45,0,TAU,40,Color(0.1,.2,.25,.7),3,true)
	if sprinting and actions.has("run"):
		draw_arc(actions.run.position+Vector2(72,72),77,0,TAU,48,Color("92ff4c"),5,true)

func _input(event: InputEvent) -> void:
	# Keep an already captured finger when it moves across another UI control.
	if event is InputEventScreenDrag and (event.index==joystick_finger or event.index==camera_finger):
		_unhandled_input(event)
	elif event is InputEventScreenTouch and not event.pressed and (event.index==joystick_finger or event.index==camera_finger):
		_unhandled_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if joystick_finger<0 and event.position.distance_to(joystick_center)<joystick_radius*1.4:
				joystick_finger = event.index
				_update_joystick(event.position)
				get_viewport().set_input_as_handled()
			elif camera_finger<0 and event.position.x>size.x*.4:
				camera_finger = event.index
				get_viewport().set_input_as_handled()
		else:
			if event.index==joystick_finger:
				joystick_finger=-1
				movement=Vector2.ZERO
				joystick_tip=joystick_center
				queue_redraw()
				get_viewport().set_input_as_handled()
			if event.index==camera_finger:
				camera_finger=-1
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index==joystick_finger:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index==camera_finger:
			camera_dragged.emit(event.relative)
			get_viewport().set_input_as_handled()

func _update_joystick(pos: Vector2) -> void:
	var offset := (pos-joystick_center).limit_length(joystick_radius)
	movement = offset/joystick_radius
	if movement.length()<.12:
		movement = Vector2.ZERO
	joystick_tip = joystick_center+offset
	queue_redraw()

func reset_controls() -> void:
	joystick_finger=-1
	camera_finger=-1
	movement=Vector2.ZERO
	jump_held=false
	sprinting=false
	joystick_tip=joystick_center
	queue_redraw()
