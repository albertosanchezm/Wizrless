extends LimboState

var _d: Devium

const FALL_DURATION := 0.85    # s — duración de la caída
const FADE_DELAY    := 0.35    # s — el desvanecimiento empieza tras este retardo
const FADE_DURATION := 0.7     # s — duración del fundido


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_d.velocity = Vector2.ZERO
	_d.set_physics_process(false)
	_d.hitbox.set_deferred(&"monitoring", false)
	_die()


func _die() -> void:
	var target_y := maxf(_d.global_position.y, _d.get_floor_y(_d.global_position.y))

	var tween := _d.create_tween().set_parallel(true)

	# Caída con aceleración (simula gravedad)
	tween.tween_property(_d, "global_position:y", target_y, FALL_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Desvanecimiento retrasado
	tween.tween_property(_d, "modulate:a", 0.0, FADE_DURATION) \
		.set_delay(FADE_DELAY)

	tween.chain().tween_callback(func() -> void:
		_d.die()
		_d.queue_free()
	)
