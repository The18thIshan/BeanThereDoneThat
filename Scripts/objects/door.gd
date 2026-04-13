extends AnimatableBody2D

# ==========================================
# --- HARDWARE REFERENCES ---
# ==========================================
@onready var sprite_left = $LeftDoor
@onready var sprite_right = $RightDoor
@onready var collision_shape = $CollisionShape2D

# [THE HARDWIRE UPLINK]
# This creates the slot in your Inspector so you can assign the Red or Blue Receiver!
@export var target_receiver: Node2D 

# --- INTERNAL MEMORY ---
var is_open: bool = false

func _ready():
	print("ANIMATED DOOR: Locked and loaded.")
	sprite_left.frame = 0
	sprite_right.frame = 0
	
	# ==========================================
	# --- SIGNAL AUTO-CONNECT SEQUENCE ---
	# ==========================================
	if target_receiver:
		print("ANIMATED DOOR: Comms established with Receiver!")
		# Weld the receiver's 'powered_on' signal directly to our 'open_door' function!
		target_receiver.powered_on.connect(open_door)
		
		# [SARGE'S WARNING]: If your Receiver is a PERMANENT switch, it does NOT have a powered_off signal!
		# If you are using old receivers that DO turn off, uncomment the line below.
		# target_receiver.powered_off.connect(close_door)
	else:
		print("WARNING: No Receiver linked! This door is deaf to the world! Assign it in the Inspector!")

# ==========================================
# --- THE SIGNAL RECEPTORS ---
# ==========================================

func open_door():
	if not is_open:
		is_open = true
		print("ANIMATED DOOR: Access Granted! Playing opening sequence!")
		
		sprite_left.play("open")
		sprite_right.play("open")
		collision_shape.set_deferred("disabled", true)

func close_door():
	if is_open:
		is_open = false
		print("ANIMATED DOOR: Power Lost! Reversing animation!")
		
		sprite_left.play_backwards("open") 
		sprite_right.play_backwards("open")
		collision_shape.set_deferred("disabled", false)
