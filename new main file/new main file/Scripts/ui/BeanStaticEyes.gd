extends Node2D

@export var max_offset: float = 64
@export var bean_half_w: float = 80.0
@export var bean_half_h: float = 120.0

@export var blink_interval_min: float = 1.5
@export var blink_interval_max: float = 4.0
@export var blink_speed: float = 18.0

@onready var bean_root: Node2D = get_parent().get_parent()
@onready var right_eye: Node2D = $RightEye
@onready var left_eye: Node2D  = $LeftEye

var base_position: Vector2

var blink_timer: float = 0.0
var next_blink: float = 0.0
var is_blinking: bool = false
var blink_phase: int = 0
var blink_scale_y: float = 1.0

func _ready() -> void:
	base_position = position
	next_blink = randf_range(blink_interval_min, blink_interval_max)

func _process(delta: float) -> void:
	var mouse_global := get_global_mouse_position()
	var bean_center  := bean_root.global_position

	# ── Cursor-inside-bean check ─────────────────────────────────────────
	var dx := (mouse_global.x - bean_center.x) / bean_half_w
	var dy := (mouse_global.y - bean_center.y) / bean_half_h
	var inside_bean: bool = (dx * dx + dy * dy) <= 1.0

	# ── Eye tracking / reset ─────────────────────────────────────────────
	if inside_bean:
		position = position.lerp(base_position, 10.0 * delta)
	else:
		var direction := (mouse_global - global_position).normalized()
		position = base_position + direction * max_offset

	# ── Horizontal flip ───────────────────────────────────────────────────
	scale.x = -1.0 if mouse_global.x < bean_center.x else 1.0

	# ── Blinking ──────────────────────────────────────────────────────────
	blink_timer += delta
	if not is_blinking and blink_timer >= next_blink:
		is_blinking = true
		blink_phase = 0

	if is_blinking:
		match blink_phase:
			0:
				blink_scale_y = move_toward(blink_scale_y, 0.0, blink_speed * delta)
				if blink_scale_y <= 0.0:
					blink_phase = 1
			1:
				blink_scale_y = move_toward(blink_scale_y, 2.0, blink_speed * delta)
				if blink_scale_y >= 2.0:
					is_blinking = false
					blink_timer = 0.0
					next_blink  = randf_range(blink_interval_min, blink_interval_max)
	else:
		blink_scale_y = 2.0

	# Apply blink to each eye individually so they squish from their own center
	right_eye.scale.y = blink_scale_y
	left_eye.scale.y  = blink_scale_y
