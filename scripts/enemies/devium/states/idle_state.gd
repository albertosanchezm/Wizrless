extends LimboState

var _d: Devium
var _timer := 0.0
const DURATION := 1.5


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer = 0.0
	# TODO: reproducir animación idle


func _update(delta: float) -> void:
	_timer += delta
	if _timer >= DURATION:
		dispatch(&"levitate")
