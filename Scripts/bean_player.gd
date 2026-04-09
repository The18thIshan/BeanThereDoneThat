extends CharacterBody2D

# ==========================================
# --- EVOLUTION STATE ---
# ==========================================
@export var hover_unlocked: bool = true 

# ==========================================
# --- MOVEMENT CONSTANTS ---
# ==========================================
const SPEED = 350.0          
const ACCEL = 2500.0         
const FRICTION = 2000.0      
const JUMP_VELOCITY = -800.0 

# ==========================================
# --- TRUE HOVER CONSTANTS ---
# ==========================================
const BASE_HOVER_HEIGHT = 80.0   
const CROUCH_HOVER      = 49.0   
const HOVER_MAGNETISM   = 10.0   
const HOVER_SMOOTHING   = 14.0   

# ==========================================
# --- ROLLING CONSTANTS ---
# ==========================================
const ROLL_SPEED_MULTIPLIER = 0.015 

# --- SENSORY CONSTANTS ---
const EYE_MOVE_RADIUS = 6.4
const EYE_LERP_SPEED  = 12.0     
const FLIP_SPEED      = 15.0     
const BLINK_SPEED     = 25.0     
const BLINK_DURATION  = 0.12
const BLINK_INTERVAL  = 3.0
const BLINK_VARIANCE  = 2.0

const CAPSULE_RADIUS: float = 30.0
const CAPSULE_HEIGHT: float = 97.4

# --- CAMERA TRACKING CONSTANTS ---
const CAM_LOOK_AHEAD = 250.0     
const CAM_SMOOTHING  = 3.0       
const CAM_IDLE_FRACTION = 0.5   

# ==========================================
# --- HARDWARE REFERENCES ---
# ==========================================
@onready var visuals         = $Visuals
@onready var eyes            = $Visuals/Eyes
@onready var right_eye       = $Visuals/Eyes/Sprite2D
@onready var left_eye        = $Visuals/Eyes/Sprite2D2
@onready var camera          = $Camera2D
@onready var ground_ray      = $GroundRay 
@onready var collision_shape = $CollisionShape2D 

# ==========================================
# --- INTERNAL MEMORY ---
# ==========================================
var right_eye_origin: Vector2
var left_eye_origin:  Vector2
var eye_scale_open: float  
var target_scale_x      = 1.0
var target_eye_scale_y  = 1.0  
var blink_timer         = 0.0
var next_blink          = 0.0
var is_blinking         = false

var target_cam_offset   = 0.0
var facing_direction    = 1.0 

var current_hover_target = BASE_HOVER_HEIGHT
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	print("--- SYSTEM BOOT: METAMORPHOSIS PROTOCOL ---")
	if not ground_ray:
		print("CRITICAL ERROR: GroundRay sensor absent.")
	else:
		ground_ray.enabled = true
		ground_ray.collision_mask = self.collision_mask 
		ground_ray.target_position = Vector2(0, 2000)
		ground_ray.hit_from_inside = true
		
	right_eye_origin   = right_eye.position
	left_eye_origin    = left_eye.position
	eye_scale_open     = right_eye.scale.y
	target_eye_scale_y = eye_scale_open
	visuals.position.y = 0.0 
	_schedule_next_blink()

func _physics_process(delta):
	var is_detecting_ground = ground_ray.is_colliding()
	var distance_to_floor = 9999.0
	
	if is_detecting_ground:
		distance_to_floor = ground_ray.get_collision_point().y - global_position.y

	# --- STATE MACHINE FORWARDING ---
	if hover_unlocked:
		_process_hover_physics(delta, is_detecting_ground, distance_to_floor)
	else:
		_process_rolling_physics(delta)

	# --- LATERAL KINEMATICS ---
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()

# ==========================================
# STATE 1: THE GROUNDED BEAN (ROLLING)
# ==========================================
func _process_rolling_physics(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

# ==========================================
# STATE 2: THE MAGNETIC HOVERCRAFT
# ==========================================
func _process_hover_physics(delta, is_detecting_ground, distance_to_floor):
	if Input.is_action_pressed("ui_down"):
		current_hover_target = lerp(current_hover_target, CROUCH_HOVER, 10.0 * delta)
		
	else:
		current_hover_target = lerp(current_hover_target, BASE_HOVER_HEIGHT, 10.0 * delta)

	if Input.is_action_just_pressed("ui_up") and is_detecting_ground and distance_to_floor < (BASE_HOVER_HEIGHT * 2.0):
		velocity.y = JUMP_VELOCITY

	if is_detecting_ground and distance_to_floor <= (BASE_HOVER_HEIGHT * 2.0) and velocity.y >= -200.0:
		var distance_error = distance_to_floor - current_hover_target
		var ideal_velocity = distance_error * HOVER_MAGNETISM
		velocity.y = lerp(velocity.y, ideal_velocity, HOVER_SMOOTHING * delta)
	else:
		velocity.y += gravity * delta

# ==========================================
# --- VISUAL & AUXILIARY PROCESSING ---
# ==========================================
func _process(delta):
	_update_visuals(delta)
	_update_camera(delta)

func _update_visuals(delta):
	# --- METAMORPHOSIS VISUALS & PHYSICS ---
	
	if hover_unlocked:
		var upright_angle = lerp_angle(visuals.rotation, 0.0, 10.0 * delta)
		visuals.rotation = upright_angle
		collision_shape.rotation = lerp_angle(collision_shape.rotation, 0.0, 10.0 * delta)
		visuals.position.y = 0.0  # Hover: no offset needed
	else:
		var spin_amount = velocity.x * ROLL_SPEED_MULTIPLIER * delta
		visuals.rotation += spin_amount

		var righting_strength = 10.0
		visuals.rotation = lerp_angle(visuals.rotation, 0.0, righting_strength * abs(cos(visuals.rotation)) * delta)

		collision_shape.rotation = 0.0
		visuals.position.y = 0.0

		# [FIX]: Keep collision UPRIGHT (0°) so the body sits at full capsule height.
		# Rotating it to 90° was the root cause — it dropped the center too low.
		collision_shape.rotation = lerp_angle(collision_shape.rotation, 0.0, 10.0 * delta)

		# [THE GROUNDING FORMULA]: Pin the visual bottom to the floor as the bean spins.
		# As the sprite rotates to its side, we push visuals DOWN to compensate for
		# the shrinking vertical extent. This creates natural rolling contact bobbing.
		var half_h: float = (CAPSULE_HEIGHT / 2.0)   # 18.7px
		visuals.position.y = half_h * (1.0 - abs(cos(visuals.rotation)))

	# --- EYE TRACKING ---
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
		facing_direction = sign(move_dir) 
		target_cam_offset = facing_direction * CAM_LOOK_AHEAD
	else:
		target_cam_offset = facing_direction * (CAM_LOOK_AHEAD * CAM_IDLE_FRACTION)
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
