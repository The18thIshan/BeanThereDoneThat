extends StaticBody2D

# --- THE SIGNALS ---
# You will connect these to your doors, platforms, or elevators in the Godot Editor!
signal powered_on
signal powered_off

# --- INTERNAL MEMORY ---
var is_powered: bool = false
var power_timeout: float = 0.0

func _ready():
	print("RECEIVER OFFLINE. Awaiting Laser Link.")
	modulate = Color.DARK_RED # Visual offline state

func _process(delta):
	# If the receiver is powered, it constantly burns down a timer.
	# The laser MUST keep hitting it to keep the timer full!
	if is_powered:
		power_timeout -= delta
		if power_timeout <= 0.0:
			# The laser stopped hitting us! SHUT IT DOWN!
			is_powered = false
			modulate = Color.DARK_RED 
			powered_off.emit()
			print("RECEIVER: Link Severed. Power Lost.")

# ==========================================
# --- THE IMPACT RECEPTOR ---
# ==========================================
# The Bean's laser will call this EXACT function!
func hit_by_laser():
	# Refill the battery! As long as the laser is touching, this stays above 0.
	power_timeout = 0.1 
	
	# If we were previously asleep, WAKE UP and emit the signal ONE TIME!
	if not is_powered:
		is_powered = true
		modulate = Color.CYAN # Visual online state
		powered_on.emit()
		print("RECEIVER: Power Overwhelming! Signal Sent!")
