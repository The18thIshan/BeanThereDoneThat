extends CharacterBody2D

# --- MOVEMENT & PHYSICS ---
@export var speed = 50
@export var patrol_speed = 30
@export var patrol_range = 50
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- STATE VARIABLES ---
var player = null
var start_x : float
var direction = 1 
var is_dead = false 

@onready var sprite = $AnimatedSprite2D

func _ready():
	start_x = global_position.x

func _physics_process(delta):
	# 1. ADD GRAVITY (Bug Fix #1)
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	if is_dead:
		move_and_slide() # Allow it to fall while dying, but no horizontal movement
		return

	if player:
		# --- CHASE BEHAVIOR ---
		var move_direction = (player.global_position - global_position).normalized()
		velocity.x = move_direction.x * speed
		sprite.flip_h = velocity.x < 0
	else:
		# --- PATROL BEHAVIOR ---
		velocity.x = direction * patrol_speed
		
		if direction == 1 and global_position.x >= start_x + patrol_range:
			direction = -1
		elif direction == -1 and global_position.x <= start_x - patrol_range:
			direction = 1
		
		sprite.flip_h = direction < 0

	# --- ANIMATION CONTROL ---
	if abs(velocity.x) > 0:
		if sprite.animation != "right":
			sprite.play("right")
	else:
		sprite.stop()
	
	move_and_slide()

func hit_by_laser():
	die()

func die():
	if is_dead: return
	is_dead = true
	
	# Stop horizontal movement but keep vertical for gravity
	velocity.x = 0
	if Global:
		Global.handle_enemy_death()
	
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		# BUG FIX #2: If the slime isn't destroying, check if "death" is LOOPING.
		# This await only continues if the animation stops.
		await sprite.animation_finished 
	
	queue_free() 

func _on_detection_area_body_entered(body):
	if is_dead: return
	if body.has_method("player"):
		# BUG FIX #3: Kill the player first, then kill the slime
		if body.has_method("die"):
			body.die() 
		
		die() # Slime pops after hitting player
		player = body

func _on_detection_area_body_exited(body): 
	if body.has_method("player"):
		player = null
		start_x = global_position.x
