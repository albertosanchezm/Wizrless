extends LimboState

var _d: Devium

const ACTIVATION_DISTANCE := 200.0


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_d.velocity = Vector2.ZERO
	_d.sprite.play(&"idle")


func _update(_delta: float) -> void:
	if not _d.player:
		return
	var dist := _d.global_position.distance_to(_d.player.global_position)
	if dist <= ACTIVATION_DISTANCE:
		GameManager.boss_appeared.emit("Devium", _d.MAX_HEALTH)
		dispatch(&"levitate")
