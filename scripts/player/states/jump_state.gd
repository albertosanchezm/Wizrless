extends LimboState

var _p: CharacterBody2D
var _cut_applied := false


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_p.velocity.y  = _p.JUMP_VELOCITY
	_p.jump_buffer = 0.0
	_p.coyote_timer = 0.0
	_cut_applied   = false
	_p.anim.play("jump")


func _update(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	_p.velocity.x = dir * _p.SPEED
	_p.flip_toward(dir)

	# Variable height: soltar salto recorta el arco
	if not _cut_applied and Input.is_action_just_released("jump") and _p.velocity.y < 0.0:
		_p.velocity.y *= _p.JUMP_CUT
		_cut_applied = true

	if _p.wants_dash():
		dispatch(&"dash")
		return

	if Input.is_action_just_pressed("attack"):
		dispatch(&"attack")
		return

	# Comenzamos a caer
	if _p.velocity.y >= 0.0:
		dispatch(&"fall")
