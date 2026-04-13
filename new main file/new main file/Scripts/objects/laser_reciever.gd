extends StaticBody2D

# --- THE SIGNALS ---
signal powered_on

# --- ENGINEERING PARAMETERS ---
const CHARGE_TIME = 0.5 # Seconds required to permanently activate

# --- HARDWARE REFERENCES ---
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- INTERNAL MEMORY ---
var current_charge: float = 0.0
var is_powered: bool = false
var contact_timeout: float = 0.0

func _ready():
	print("RECEIVER: Capacitor offline. Awaiting charge.")
	
	# Calibrate the visual UI gauge
	progress_bar.max_value = CHARGE_TIME
	progress_bar.value = 0.0

func _process(delta):
	# 1. PERMANENT POWER OVERRIDE
	# If the receiver is already fully activated, stop doing math!
	if is_powered:
		return

	# 2. THE CHARGING SEQUENCE
	if contact_timeout > 0.0:
		# The laser is hitting us! Fill the battery.
		contact_timeout -= delta
		current_charge += delta
	else:
		# The laser missed! Drain the battery.
		current_charge -= delta

	# 3. CAPACITOR LIMITS
	# Keep the charge exactly between 0.0 and our max CHARGE_TIME
	current_charge = clamp(current_charge, 0.0, CHARGE_TIME)
	progress_bar.value = current_charge

	# 4. THE ACTIVATION THRESHOLD
	if current_charge >= CHARGE_TIME:
		is_powered = true
		progress_bar.value = CHARGE_TIME # Lock visual bar to full
		
		# Play the animation and send the signal EXACTLY ONCE
		animated_sprite.play()
		powered_on.emit()
		print("RECEIVER: Capacitor Full! Permanent Activation!")

# ==========================================
# --- THE IMPACT RECEPTOR ---
# ==========================================
func hit_by_laser():
	# If the switch is already permanently on, ignore the laser completely.
	if is_powered:
		return
		
	# The laser is touching! Give it a tiny grace period before it starts draining.
	contact_timeout = 0.05
