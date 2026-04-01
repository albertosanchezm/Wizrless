extends Area2D

const SPEED  := 150.0
const DAMAGE := 5

var direction := Vector2.RIGHT
var _hit      := false


func _ready() -> void:
	($Visual as Polygon2D).polygon = PackedVector2Array([
		Vector2(0.0, -5.0), Vector2(4.0, 3.0), Vector2(-4.0, 3.0)
	])

	body_entered.connect(_on_body_entered)
	$LifeTimer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	_hit = true
	if body.is_in_group(&"player"):
		GameManager.take_damage(DAMAGE)
	queue_free()
