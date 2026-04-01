extends Area2D

const APPEAR_TIME  := 0.15
const ACTIVE_TIME  := 1.2
const RETRACT_TIME := 0.15
const DAMAGE       := 18


func _ready() -> void:
	($Visual as Polygon2D).polygon = PackedVector2Array([
		Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Vector2(0.0, -34.0)
	])

	# El pivot es la base (y=0 = nivel del suelo); crece hacia arriba
	scale.y = 0.0
	body_entered.connect(_on_body_entered)

	var tween := create_tween()
	tween.tween_property(self, "scale:y", 1.0, APPEAR_TIME)
	tween.tween_interval(ACTIVE_TIME)
	tween.tween_callback(_retract)


func _retract() -> void:
	$CollisionShape2D.set_deferred(&"disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "scale:y", 0.0, RETRACT_TIME)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		GameManager.take_damage(DAMAGE)
