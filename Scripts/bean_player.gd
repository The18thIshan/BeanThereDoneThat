extends CharacterBody2D

# ==========================================
# --- THE ADAPTATION: MOVEMENT CONSTANTS ---
# ==========================================
const SPEED = 350.0          # Maximum horizontal velocity
const ACCEL = 2500.0         # Rate of acceleration toward SPEED
const FRICTION = 2000.0      # Rate of deceleration when no input is provided
const JUMP_VELOCITY = -800.0 # Instantaneous vertical impulse for jumping

# ==========================================
# --- THE ADAPTATION: MAGNETIC LEVITATION ---
# ==========================================
# The spring has been discarded. The entity now uses velocity interpolation 
# to achieve a perfect, bounce-free magnetic lock at the target altitude.
const BASE_HOVER_HEIGHT = 80.0   # Standard cruising altitude
const CROUCH_HOVER      = 49.0   # Altitude when 'ui_down' is engaged

const HOVER_MAGNETISM   = 10.0   # Multiplier: How aggressively it calculates the return velocity
const HOVER_SMOOTHING   = 14.0   # Lerp weight: How smoothly it applies the calculated velocity

# --- VISUAL & SENSORY CONSTANTS ---
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
@onready var visuals    = $Visuals
@onready var eyes       = $Visuals/Eyes
@onready var right_eye  = $Visuals/Eyes/Sprite2D
@onready var left_eye   = $Visuals/Eyes/Sprite2D2
@onready var camera     = $Camera2D
@onready var ground_ray = $GroundRay # The primary altitude sensor

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

# --- OBSERVABILITY ---
var debug_timer = 0.0 # Tracks time between telemetry pulses

func _ready():
	print("--- SYSTEM BOOT: MAGNETIC LEVITATION PROTOCOL ---")
	if not ground_ray:
		print("CRITICAL ERROR: GroundRay sensor absent.")
	else:
		# [HARDWARE OVERRIDE]: Ensure the sensor is active and scanning the correct dimensions.
		ground_ray.enabled = true
		ground_ray.collision_mask = self.collision_mask 
		ground_ray.target_position = Vector2(0, 2000)
		ground_ray.hit_from_inside = true
		print("Sensor Override Engaged. Scanning Depth: ", ground_ray.target_position.y)
		
	# Calibrate visual rest states
	right_eye_origin   = right_eye.position
	left_eye_origin    = left_eye.position
	eye_scale_open     = right_eye.scale.y
	target_eye_scale_y = eye_scale_open
	visuals.position.y = 0.0 
	_schedule_next_blink()

func _physics_process(delta):
	# ==========================================
	# 0. TELEMETRY PULSE (Executes every 0.5s)
	# ==========================================
	debug_timer += delta
	var do_print = false
	if debug_timer >= 0.5:
		do_print = true
		debug_timer = 0.0
		print("\n--- [TELEMETRY PULSE] ---")

	# ==========================================
	# 1. SENSOR DATA ACQUISITION
	# ==========================================
	var is_detecting_ground = ground_ray.is_colliding()
	var distance_to_floor = 9999.0
	
	if is_detecting_ground:
		# Calculate exact physical distance from the entity's origin to the impact point
		distance_to_floor = ground_ray.get_collision_point().y - global_position.y
		if do_print: print("Surface Detected at distance: ", distance_to_floor)
	elif do_print:
		print("No Surface Detected. Infinite void.")

	# ==========================================
	# 2. ALTITUDE TARGETING (CROUCH LOGIC)
	# ==========================================
	if Input.is_action_pressed("ui_down"):
		# Shift target altitude lower for evasive/crouch maneuvers
		current_hover_target = lerp(current_hover_target, CROUCH_HOVER, 10.0 * delta)
	else:
		# Return to standard cruising altitude
		current_hover_target = lerp(current_hover_target, BASE_HOVER_HEIGHT, 10.0 * delta)

	# ==========================================
	# 3. MANUAL IMPULSE OVERRIDE (JUMP)
	# ==========================================
	# Jump is only permitted if the entity is near the ground.
	if Input.is_action_just_pressed("ui_up") and is_detecting_ground and distance_to_floor < (BASE_HOVER_HEIGHT * 2.0):
		velocity.y = JUMP_VELOCITY
		print(">> IMPULSE GENERATED: Vertical jump executed.")

	# ==========================================
	# 4. MAGNETIC LEVITATION KINEMATICS
	# ==========================================
	# The system engages ONLY if the ground is within range AND the entity is not rapidly ascending.
	# velocity.y >= -200.0 ensures the jump ballistic arc is not prematurely interrupted.
	if is_detecting_ground and distance_to_floor <= (BASE_HOVER_HEIGHT * 2.0) and velocity.y >= -200.0:
		
		# [MATH]: Calculate the delta between current position and desired altitude.
		# Positive value = Entity is too low. Negative value = Entity is too high.
		var distance_error = distance_to_floor - current_hover_target
		
		# [MATH]: Determine the theoretical perfect velocity needed to close the gap instantly.
		var ideal_velocity = distance_error * HOVER_MAGNETISM
		
		# [EXECUTION]: Smoothly overwrite the physics engine's velocity. Gravity is nullified.
		velocity.y = lerp(velocity.y, ideal_velocity, HOVER_SMOOTHING * delta)
		
		if do_print:
			print("STATE: Magnetic Lock Active.")
			print("Target Altitude: ", current_hover_target)
			print("Altitude Error: ", distance_error)
			print("Compensating Velocity (y): ", velocity.y)
	else:
		# [FALLBACK]: If ascending or outside sensor range, the system yields to natural gravity.
		velocity.y += gravity * delta
		if do_print: print("STATE: Freefall / Ballistic Arc. Gravity engaged.")

	# ==========================================
	# 5. LATERAL KINEMATICS
	# ==========================================
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		# Accelerate towards maximum lateral speed
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCEL * delta)
	else:
		# Decelerate to a halt
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# Commit kinematics to the physics engine
	move_and_slide()

# ==========================================
# --- VISUAL & AUXILIARY PROCESSING ---
# ==========================================
func _process(delta):
	_update_visuals(delta)
	_update_camera(delta)

func _update_visuals(delta):
	var mouse_pos = get_global_mouse_position()
	var inside    = _is_inside_capsule(mouse_pos)
	
	# Determine facing direction relative to the cursor
	if not inside:
		target_scale_x = -1.0 if mouse_pos.x < global_position.x else 1.0
		
	# Smoothly flip the sensory organs (eyes)
	eyes.scale.x = lerp(eyes.scale.x, target_scale_x, FLIP_SPEED * delta)
	
	_tick_blink(delta)
	
	# Apply blinking squash/stretch deformation
	var sy = lerp(right_eye.scale.y, target_eye_scale_y, BLINK_SPEED * delta)
	right_eye.scale.y = sy
	left_eye.scale.y  = sy
	
	# Update individual pupil tracking
	_update_eye(right_eye, right_eye_origin, mouse_pos, inside, delta)
	_update_eye(left_eye,  left_eye_origin,  mouse_pos, inside, delta)

func _update_camera(delta):
	var move_dir = Input.get_axis("ui_left", "ui_right")
	
	if move_dir != 0:
		# Remember the last lateral direction moved
		facing_direction = sign(move_dir) 
		target_cam_offset = facing_direction * CAM_LOOK_AHEAD
	else:
		# Retract camera slightly when idle, but maintain directional bias
		target_cam_offset = facing_direction * (CAM_LOOK_AHEAD * CAM_IDLE_FRACTION)
		
	# Smoothly interpolate the camera's lens offset
	camera.offset.x = lerp(camera.offset.x, target_cam_offset, CAM_SMOOTHING * delta)

func _tick_blink(delta):
	blink_timer += delta
	if not is_blinking and blink_timer >= next_blink:
		# Initiate blink deformation
		is_blinking        = true
		target_eye_scale_y = 0.0          
		blink_timer        = 0.0
	elif is_blinking and blink_timer >= BLINK_DURATION:
		# Restore to neutral state
		is_blinking        = false
		target_eye_scale_y = eye_scale_open  
		blink_timer        = 0.0
		_schedule_next_blink()

func _schedule_next_blink():
	# Calculate the next randomized interval for the blink sequence
	next_blink = BLINK_INTERVAL + randf_range(-BLINK_VARIANCE, BLINK_VARIANCE)

func _update_eye(eye: Sprite2D, origin: Vector2, mouse_global: Vector2, inside: bool, delta: float):
	var parent = eye.get_parent()
	var target: Vector2
	
	if inside:
		# Cursor is inside the entity; eyes return to resting center
		target = origin
	else:
		# Calculate vector pointing from the eye to the cursor
		var origin_global = parent.to_global(origin)
		var dir           = (mouse_global - origin_global).normalized()
		target            = parent.to_local(origin_global + dir * EYE_MOVE_RADIUS)
		
	# Smoothly track towards the calculated point
	eye.position = eye.position.lerp(target, EYE_LERP_SPEED * delta)

func _is_inside_capsule(mouse_global: Vector2) -> bool:
	# Convert cursor to local space to mathematically verify boundary intersection
	var local     = to_local(mouse_global)
	var half_body = (CAPSULE_HEIGHT / 2.0) - CAPSULE_RADIUS
	var nearest   = Vector2(0.0, clamp(local.y, -half_body, half_body))
	return local.distance_to(nearest) <= CAPSULE_RADIUS
