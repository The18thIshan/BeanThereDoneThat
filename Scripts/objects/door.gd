extends AnimatableBody2D

# ==========================================
# --- HARDWARE REFERENCES ---
# ==========================================
@onready var sprite_left = $LeftDoor
@onready var sprite_right = $RightDoor
@onready var collision_shape = $CollisionShape2D

# --- INTERNAL MEMORY ---
var is_open: bool = false

func _ready():
	print("ANIMATED DOOR: Locked and loaded.")
	# Ensure the door starts on the very first frame of the animation
	sprite_left.frame = 0
	sprite_right.frame = 0

# ==========================================
# --- THE SIGNAL RECEPTORS ---
# ==========================================

func open_door():
	# Only trigger if the door is currently closed!
	if not is_open:
		is_open = true
		print("ANIMATED DOOR: Access Granted! Playing opening sequence!")
		
		# Play the animation forward
		sprite_left.play("open")
		sprite_right.play("open")
		
		# [THE PHYSICS BYPASS]: Safely disable the collision block so the Bean can roll through!
		collision_shape.set_deferred("disabled", true)

func close_door():
	# Only trigger if the door is currently open!
	if is_open:
		is_open = false
		print("ANIMATED DOOR: Power Lost! Reversing animation!")
		
		# Play the exact same animation, but in REVERSE to close it!
		sprite_left.play_backwards("open") 
		sprite_right.play_backwards("open")
		
		# [THE PHYSICS BYPASS]: Safely turn the collision block back on!
		collision_shape.set_deferred("disabled", false)


func _on_laser_reciever_powered_on() -> void:
	pass # Replace with function body.
