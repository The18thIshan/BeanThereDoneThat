extends CharacterBody2D

# --- MOVEMENT CONSTANTS ---
const SPEED = 200.0
const ACCEL = 2000.0
const FRICTION = 1500.0
const JUMP_VELOCITY = -700.0

# --- HOVER & LANDING CONSTANTS ---
const HOVER_BASE_OFFSET = -200.0 # Standard hover height (Negative is UP)
const HOVER_AMPLITUDE   = 16.0   # How much it bobs up and down
const HOVER_SPEED       = 6.0   # How fast it bobs
const LANDING_DIP       = 100.0  # How far down it squishes when landing
const DIP_DURATION      = 0.08   # Speed of the dip down
const RECOVER_DURATION  = 0.16   # Speed of returning to hover
const CROUCH_OFFSET     = 5.0  # 0 means the visuals touch the floor
const CROUCH_DOWN_SPEED    = 1.5  # Slow, controlled descent to the floor
const CROUCH_RECOVER_SPEED = 3  # Aggressive, fast snap back to hovering

# --- EYE CONSTANTS (Scaled down for 0.1) ---
const EYE_MOVE_RADIUS = 6.4
const EYE_LERP_SPEED  = 8.0
const FLIP_SPEED      = 12.0
const BLINK_SPEED     = 18.0
const BLINK_DURATION  = 0.12
const BLINK_INTERVAL  = 3.0
const BLINK_VARIANCE  = 2.0

const CAPSULE_RADIUS: float = 30.0
const CAPSULE_HEIGHT: float = 97.4

# --- CAMERA CONSTANTS ---
const CAM_LOOK_AHEAD = 200.0  
const CAM_SMOOTHING  = 2.0 
const CAM_IDLE_FRACTION = 0.5   

# --- NODE REFERENCES ---
@onready var visuals   = $Visuals
@onready var eyes      = $Visuals/Eyes
@onready var right_eye = $Visuals/Eyes/Sprite2D
@onready var left_eye  = $Visuals/Eyes/Sprite2D2
@onready var camera    = $Camera2D

# --- INTERNAL STATE ---
var right_eye_origin: Vector2
var left_eye_origin:  Vector2
var eye_scale_open: float  
var target_scale_x      = 1.0
var target_eye_scale_y  = 1.0  
var blink_timer         = 0.0
var next_blink          = 0.0
var is_blinking         = false
var target_cam_offset   = 0.0
var facing_direction = 1.0 # Default to facing right (1.0)
var current_base_offset = HOVER_BASE_OFFSET
var current_amplitude   = HOVER_AMPLITUDE

# Hover states
var time_passed    = 0.0
var landing_offset = 0.0    # Controlled by the Tween
var was_on_floor   = true   # Tracks previous frame's floor status
var landing_tween: Tween

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	right_eye_origin   = right_eye.position
	left_eye_origin    = left_eye.position
	eye_scale_open     = right_eye.scale.y
	target_eye_scale_y = eye_scale_open
	_schedule_next_blink()

func _physics_process(delta):
	var currently_on_floor = is_on_floor()

	# --- LANDING DETECTION ---
	if currently_on_floor and not was_on_floor:
		_play_landing_dip()
		
	was_on_floor = currently_on_floor

	# --- PHYSICS MOVEMENT ---
	if not currently_on_floor:
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_up") and currently_on_floor:
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()

func _process(delta):
	_update_visuals(delta)
	_update_camera(delta)
	_handle_hover(delta)


func _handle_hover(delta):
	time_passed += delta
	
	var is_pressing_down = Input.is_action_pressed("ui_down")
	
	# Determine target height and target bobbing
	var target_base = CROUCH_OFFSET if is_pressing_down else HOVER_BASE_OFFSET
	var target_amp  = 0.0 if is_pressing_down else HOVER_AMPLITUDE
	
	# Determine which speed to use!
	var active_speed = CROUCH_DOWN_SPEED if is_pressing_down else CROUCH_RECOVER_SPEED
	
	# Smoothly transition using the dynamically chosen speed
	current_base_offset = lerp(current_base_offset, target_base, active_speed * delta)
	current_amplitude   = lerp(current_amplitude, target_amp, active_speed * delta)
	
	# Calculate final position
	var bob = sin(time_passed * HOVER_SPEED) * current_amplitude
	visuals.position.y = current_base_offset + bob + landing_offset

func _play_landing_dip():
	# Kill the old tween if it's still running so they don't fight
	if landing_tween and landing_tween.is_valid():
		landing_tween.kill()
		
	# Create a new animation sequence
	landing_tween = create_tween().set_trans(Tween.TRANS_SINE)
	
	# Step 1: Push the visuals down (positive Y)
	landing_tween.tween_property(self, "landing_offset", LANDING_DIP, DIP_DURATION).set_ease(Tween.EASE_OUT)
	# Step 2: Bounce them back up to 0
	landing_tween.tween_property(self, "landing_offset", 0.0, RECOVER_DURATION).set_ease(Tween.EASE_IN_OUT)

func _update_visuals(delta):
	var mouse_pos = get_global_mouse_position()
	var inside    = _is_inside_capsule(mouse_pos)

	if not inside:
		target_scale_x = -1.0 if mouse_pos.x < global_position.x else 1.0

	eyes.scale.x = lerp(eyes.scale.x, target_scale_x, FLIP_SPEED * delta)

	_tick_blink(delta)
	var sy = lerp(right_eye.scale.y, target_eye_scale_y, BLINK_SPEED * delta)
	right_eye.scale.y = sy
	left_eye.scale.y  = sy

	_update_eye(right_eye, right_eye_origin, mouse_pos, inside, delta)
	_update_eye(left_eye,  left_eye_origin,  mouse_pos, inside, delta)

func _update_camera(delta):
	var move_dir = Input.get_axis("ui_left", "ui_right")
	
	if move_dir != 0:
		# 1. Update our memory to the new direction (-1 or 1)
		# We use sign() just in case you are using analog sticks that return 0.8
		facing_direction = sign(move_dir) 
		
		# 2. Push to full look-ahead while moving
		target_cam_offset = facing_direction * CAM_LOOK_AHEAD
	else:
		# 3. Fall back to the fractional distance when idling
		target_cam_offset = facing_direction * (CAM_LOOK_AHEAD * CAM_IDLE_FRACTION)
		
	# Smoothly execute the order
	camera.offset.x = lerp(camera.offset.x, target_cam_offset, CAM_SMOOTHING * delta)

func _tick_blink(delta):
	blink_timer += delta
	if not is_blinking and blink_timer >= next_blink:
		is_blinking        = true
		target_eye_scale_y = 0.0          
		blink_timer        = 0.0
	elif is_blinking and blink_timer >= BLINK_DURATION:
		is_blinking        = false
		target_eye_scale_y = eye_scale_open  
		blink_timer        = 0.0
		_schedule_next_blink()

func _schedule_next_blink():
	next_blink = BLINK_INTERVAL + randf_range(-BLINK_VARIANCE, BLINK_VARIANCE)

func _update_eye(eye: Sprite2D, origin: Vector2, mouse_global: Vector2, inside: bool, delta: float):
	var parent = eye.get_parent()
	var target: Vector2

	if inside:
		target = origin
	else:
		var origin_global = parent.to_global(origin)
		var dir           = (mouse_global - origin_global).normalized()
		target            = parent.to_local(origin_global + dir * EYE_MOVE_RADIUS)

	eye.position = eye.position.lerp(target, EYE_LERP_SPEED * delta)

func _is_inside_capsule(mouse_global: Vector2) -> bool:
	var local     = to_local(mouse_global)
	var half_body = (CAPSULE_HEIGHT / 2.0) - CAPSULE_RADIUS
	var nearest   = Vector2(0.0, clamp(local.y, -half_body, half_body))
	return local.distance_to(nearest) <= CAPSULE_RADIUS
