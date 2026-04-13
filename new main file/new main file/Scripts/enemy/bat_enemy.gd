extends Node2D

# ==========================================
# --- SENTRY KINEMATICS (PURE MATH) ---
# ==========================================
const SPEED = 150.0  # Pixels per second
var current_direction = 1 # 1 = Right, -1 = Left

# ==========================================
# --- HARDWARE REFERENCES ---
# ==========================================
@onready var detection_area = $Area2D
@onready var sprite = $AnimatedSprite2D

func _ready():
	print("SENTRY DRONE (NODE2D): Booting up. Commencing patrol sequence.")
	
	# Hardwire the sensor to the brain
	detection_area.body_entered.connect(_on_bumper_hit)

func _physics_process(delta):
	# 1. MANUAL PROPULSION
	# Because this is a Node2D, we must move it by manually altering its coordinates.
	# Multiplying by 'delta' ensures it moves exactly 150 pixels per second, regardless of framerate.
	global_position.x += current_direction * SPEED * delta
	
	# 2. VISUAL & SENSOR ALIGNMENT
	if current_direction == 1:
		sprite.flip_h = false
		# Lock bumper to the right
		detection_area.position.x = abs(detection_area.position.x) 
	elif current_direction == -1:
		sprite.flip_h = true
		# Lock bumper to the left
		detection_area.position.x = -abs(detection_area.position.x)

# ==========================================
# --- THE PROXIMITY INTERROGATOR ---
# ==========================================
func _on_bumper_hit(body: Node2D):
	# I.F.F. INTERROGATION: Is this the Player?
	if body.is_in_group("player"):
		print("SENTRY: Player detected! Ignoring collision!")
		return 
		
	# If it's a wall, floor, or door...
	print("SENTRY: Obstacle detected. Reversing course.")
	current_direction *= -1
