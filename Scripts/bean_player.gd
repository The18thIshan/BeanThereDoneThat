extends CharacterBody2D

@onready var visuals   = $Visuals
@onready var eyes      = $Visuals/Eyes
@onready var right_eye = $Visuals/Eyes/Sprite2D
@onready var left_eye  = $Visuals/Eyes/Sprite2D2

var right_eye_origin: Vector2
var left_eye_origin:  Vector2
var eye_scale_open: float   # read from scene, preserves your original look
var target_scale_x      = 1.0
var target_eye_scale_y  = 1.0  # will be overwritten in _ready
var blink_timer         = 0.0
var next_blink          = 0.0
var is_blinking         = false

const EYE_MOVE_RADIUS = 64.0
const EYE_LERP_SPEED  = 8.0
const FLIP_SPEED      = 12.0
const BLINK_SPEED     = 18.0
const BLINK_DURATION  = 0.12
const BLINK_INTERVAL  = 3.0
const BLINK_VARIANCE  = 2.0

const CAPSULE_RADIUS: float = 300.0
const CAPSULE_HEIGHT: float = 974.0

func _ready():
	right_eye_origin   = right_eye.position
	left_eye_origin    = left_eye.position
	eye_scale_open     = right_eye.scale.y
	target_eye_scale_y = eye_scale_open
	_schedule_next_blink()

func _process(delta):
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

func _tick_blink(delta):
	blink_timer += delta
	if not is_blinking and blink_timer >= next_blink:
		is_blinking        = true
		target_eye_scale_y = 0.0          # squish shut
		blink_timer        = 0.0
	elif is_blinking and blink_timer >= BLINK_DURATION:
		is_blinking        = false
		target_eye_scale_y = eye_scale_open  # open back to original size
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
