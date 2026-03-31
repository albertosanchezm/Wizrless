extends LimboState
## FASE 2. Lanza varias bolas de hielo en abanico parabólico.

var _d: Devium
var _timer  := 0.0
var _fired  := false

const WINDUP    := 0.7
const DURATION  := 1.5
const NUM_BALLS := 5
const ARC_DEGREES := 60.0   # apertura total del abanico en grados


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer = 0.0
	_fired = false
	_d.velocity = Vector2.ZERO
	_d.face_player()
	# TODO: animación de carga parabólica


func _update(delta: float) -> void:
	_timer += delta

	if not _fired and _timer >= WINDUP:
		_fire()
		_fired = true

	if _timer >= DURATION:
		dispatch(&"end_attack")


func _fire() -> void:
	if not _d.player:
		return
	var base_dir := (_d.player.global_position - _d.global_position).normalized()
	var half_arc  := deg_to_rad(ARC_DEGREES / 2.0)
	var step      := deg_to_rad(ARC_DEGREES) / max(NUM_BALLS - 1, 1)

	for i in NUM_BALLS:
		var angle := -half_arc + step * i
		var dir   := base_dir.rotated(angle)
		# TODO: instanciar proyectil de bola de hielo parabólica con dir
		# Ejemplo:
		# var proj = ICE_BALL_SCENE.instantiate()
		# proj.global_position = _d.global_position
		# proj.direction = dir
		# _d.get_parent().add_child(proj)
		pass
