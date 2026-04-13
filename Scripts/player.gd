extends CharacterBody2D

# ==========================================
# --- THE COMMAND TOGGLE (STATE MACHINE) ---
# ==========================================
# True = Magnetic Levitation (Hover) | False = Dirt Bound (Rolling)
@export var hover_unlocked: bool = false

# ==========================================
# --- KINEMATIC CONSTANTS ---
# ==========================================
const SPEED = 350.0          
const ACCEL = 2500.0         
const FRICTION = 2000.0      
const JUMP_VELOCITY = -600 
const GRAVITY = 980

# --- FORM 1: ROLLING CONSTANTS ---
const ROLL_SPEED_MULTIPLIER = 0.015 

# --- FORM 2: HOVER CONSTANTS ---
const BASE_HOVER_HEIGHT = 80.0   
const CROUCH_HOVER      = 49.0   
const HOVER_MAGNETISM   = 10.0   
const HOVER_SMOOTHING   = 14.0   

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

# --- WEAPONRY CONSTANTS (HEAVY PLASMA UPGRADE) ---
const LASER_RANGE = 5000.0
const LASER_COOLDOWN = 0.6  
const LASER_DURATION = 1   # Increased so the beam has time to travel!
const CHARGE_TIME = 0.2    # 0.1s wind-up before firing
const BEAM_SPEED = 2000.0    # How fast the laser travels across the screen

# --- WEAPON TIMERS & MEMORY ---
var laser_cooldown_timer = 0.0
var laser_duration_timer = 0.0
var trigger_reset = true 

# NEW: The State Machine
var weapon_state = "IDLE"    # Can be "IDLE", "CHARGING", or "FIRING"
var charge_timer = 0.0
var current_beam_length = 0.0

# --- CAMERA CONSTANTS ---
const CAM_LOOK_AHEAD = 250.0     
const CAM_SMOOTHING  = 3.0       
const CAM_IDLE_FRACTION = 0.5   
const CAM_PEEK_MAX = 600.0       
const CAM_PEEK_SMOOTHING = 5.0   

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

# --- TWIN-LINKED OPTICS ---
# Make sure these are children of the Visuals node in your scene!
@onready var laser_ray_R     = $Visuals/LaserRayRight
@onready var laser_line_R    = $Visuals/LaserLineRight
@onready var laser_ray_L     = $Visuals/LaserRayLeft
@onready var laser_line_L    = $Visuals/LaserLineLeft

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
var debug_timer = 0.0 

func _ready():
	print("--- UNIFIED MASTER BOOT SEQUENCE ---")
	
	# --- RADAR CALIBRATION ---
	ground_ray.enabled = true
	ground_ray.collision_mask = self.collision_mask 
	ground_ray.target_position = Vector2(0, 2000)
	ground_ray.hit_from_inside = false 
	ground_ray.add_exception(self)     
	
	# --- TWIN WEAPONS OVERRIDE ---
	laser_line_R.top_level = true
	laser_line_R.global_position = Vector2.ZERO 
	
	laser_line_L.top_level = true
	laser_line_L.global_position = Vector2.ZERO 
	
	# --- FRIENDLY FIRE OVERRIDE ---
		
	right_eye_origin   = right_eye.position
	left_eye_origin    = left_eye.position
	eye_scale_open     = right_eye.scale.y
	target_eye_scale_y = eye_scale_open
	visuals.position.y = 0.0 
	_schedule_next_blink()

func _physics_process(delta):
	# --- DIAGNOSTIC TELEMETRY ---
	debug_timer += delta
	var do_print = false
	if debug_timer >= 5:
		do_print = true
		debug_timer = 0.0
		print("\n--- TACTICAL TELEMETRY ---")
		
	if velocity.y > 0:
		gravity = GRAVITY * 1.2
	else:
		gravity = GRAVITY
		
	var is_detecting_ground = ground_ray.is_colliding()
	ground_ray.position.x = self.position.x 
	ground_ray.position.y = self.position.y
	var distance_to_floor = 9999.0
	
	if is_detecting_ground:
		distance_to_floor = ground_ray.get_collision_point().y - global_position.y
		if do_print: print("Radar Ping: Ground at ", distance_to_floor)
	elif do_print:
		print("Radar Ping: VOID (No Ground)")

	# --- THE BRAIN (STATE MACHINE) ---
	if hover_unlocked:
		if do_print: print("State: ASCENDED (Hover)")
		_process_hover_physics(delta, is_detecting_ground, distance_to_floor)
	else:
		if do_print: print("State: GROUNDED (Rolling)")
		_process_rolling_physics(delta)

	# --- LATERAL LOCOMOTION ---
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()

# ==========================================
# --- FORM 1: MUD ROLLING ---
# ==========================================
func _process_rolling_physics(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

# ==========================================
# --- FORM 2: MAGNETIC LEVITATION ---
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
# --- AUXILIARY SYSTEMS ---
# ==========================================
func _process(delta):
	_update_visuals(delta)
	_update_camera(delta)
	_tick_weapons(delta)

func _update_visuals(delta):
	if hover_unlocked:
		visuals.rotation = lerp_angle(visuals.rotation, 0.0, 10.0 * delta)
		collision_shape.rotation = lerp_angle(collision_shape.rotation, 0.0, 10.0 * delta)
		visuals.position.y = 0.0
	else:
		if is_on_floor() or abs(velocity.y) < 10.0:
			var spin_amount = velocity.x * ROLL_SPEED_MULTIPLIER * delta
			visuals.rotation += spin_amount
			
		collision_shape.rotation = lerp_angle(collision_shape.rotation, deg_to_rad(90.0), 10.0 * delta)
		var max_gap = (CAPSULE_HEIGHT / 2.0) - CAPSULE_RADIUS 
		var anti_clip_lift = - (1.0 - abs(sin(visuals.rotation))) * max_gap
		visuals.position.y = anti_clip_lift

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

## ==========================================
# --- WEAPONS SUBSYSTEM (DYNAMIC GROWTH RAY) ---
# ==========================================
func _tick_weapons(delta):
	# 1. HEAT SINK COOLING
	if laser_cooldown_timer > 0.0:
		laser_cooldown_timer -= delta

	# 2. TRIGGER PULLED (START CHARGE)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and laser_cooldown_timer <= 0.0 and weapon_state == "IDLE" and trigger_reset:
		weapon_state = "CHARGING"
		charge_timer = CHARGE_TIME
		trigger_reset = false 
		
		# Turn the emitters angry red!
		right_eye.modulate = Color.RED
		left_eye.modulate = Color.RED
		print(">> WEAPONS: Plasma Emitters Charging...")

	# 3. CHARGING PHASE
	if weapon_state == "CHARGING":
		charge_timer -= delta
		if charge_timer <= 0.0:
			# Charge complete! Enter firing mode!
			weapon_state = "FIRING"
			laser_duration_timer = LASER_DURATION
			current_beam_length = 0.0 # Start the beam at length 0!
			
			laser_line_R.visible = true
			laser_line_L.visible = true
			print(">> WEAPONS: BOOM! Beam unfurling!")
			
			# Emitters turn super-hot Cyan while discharging!
			right_eye.modulate = Color.CYAN
			left_eye.modulate = Color.CYAN

	# 4. FIRING PHASE
	
	elif weapon_state == "FIRING":
		laser_duration_timer -= delta
		right_eye.modulate = Color.RED
		left_eye.modulate = Color.RED
		
		# GROW THE BEAM MATHEMATICALLY!
		current_beam_length += BEAM_SPEED * delta
		if current_beam_length > LASER_RANGE:
			current_beam_length = LASER_RANGE # Cap it at max range
			
		var mouse_pos = get_global_mouse_position()
		
		# Notice we now pass 'current_beam_length' into the processor!
		_process_beam(laser_line_R, right_eye, mouse_pos, current_beam_length)
		_process_beam(laser_line_L, left_eye, mouse_pos, current_beam_length)
		
		# Stop firing if duration ends OR if player lets go of the mouse!
		if laser_duration_timer <= 0.0 or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_shut_down_weapons()

	# 5. TRIGGER DISCONNECT & CANCEL
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		trigger_reset = true
		if weapon_state == "CHARGING":
			# They let go of the trigger before the charge finished! Cancel it!
			_shut_down_weapons()

func _shut_down_weapons():
	weapon_state = "IDLE"
	laser_line_R.visible = false
	laser_line_L.visible = false
	laser_cooldown_timer = LASER_COOLDOWN
	
	# Reset the eyes back to normal white!
	right_eye.modulate = Color.WHITE
	left_eye.modulate = Color.WHITE

func _process_beam(line: Line2D, eye_sprite: Sprite2D, target_pos: Vector2, current_length: float):
	# 1. Establish initial firing coordinates
	var start_pos = eye_sprite.global_position
	var aim_direction = (target_pos - start_pos).normalized()
	
	# THE MAGIC SAUCE: The beam only calculates physics up to its current length!
	var distance_remaining = current_length 
	
	# 2. Fire the primary physics ray
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, start_pos + (aim_direction * distance_remaining))
	query.exclude = [self]
	
	var hit_data = space_state.intersect_ray(query)
	
	# 3. Anchor the start of the visual beam
	line.clear_points()
	line.add_point(start_pos)
	
	if hit_data:
		var hit_pos = hit_data.position
		line.add_point(hit_pos)
		
		var target = hit_data.collider
		if target.has_method("hit_by_laser"):
			target.hit_by_laser()
			
		# [THE DELEGATION PROTOCOL]
		if target.has_method("reflect_beam"):
			var new_dist = distance_remaining - start_pos.distance_to(hit_pos)
			target.reflect_beam(line, hit_pos, aim_direction, hit_data.normal, new_dist, 1)
			
	else:
		line.add_point(start_pos + (aim_direction * distance_remaining))

# ==========================================
# --- UTILITY SUBSYSTEMS ---
# ==========================================
func _update_camera(delta):
	if camera == null:
		return
		
	# --- TACTICAL FREE-LOOK OVERRIDE ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var local_mouse = get_local_mouse_position()
		var peek_target = local_mouse.limit_length(CAM_PEEK_MAX)
		camera.offset = camera.offset.lerp(peek_target, CAM_PEEK_SMOOTHING * delta)
		
	# --- STANDARD AUTO-FOLLOW MODE ---
	else:
		var move_dir = Input.get_axis("ui_left", "ui_right")
		if move_dir != 0:
			facing_direction = sign(move_dir) 
			target_cam_offset = facing_direction * CAM_LOOK_AHEAD
		else:
			target_cam_offset = facing_direction * (CAM_LOOK_AHEAD * CAM_IDLE_FRACTION)
			
		var standard_target = Vector2(target_cam_offset, 0.0)
		camera.offset = camera.offset.lerp(standard_target, CAM_SMOOTHING * delta)

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
	
func player():
	pass
	
