extends Area2D

var appear_time  := 0.15
var active_time  := 1.2
var retract_time := 0.15
const DAMAGE := 20

# Altura total de la sprite (centro en y=-26.5, extiende 26.5px arriba y abajo)
const SPRITE_HEIGHT := 53.0


func _ready() -> void:
	# Empieza con la punta justo a ras del suelo (top de sprite en y=0 local)
	var visual := $Visual as Sprite2D
	var normal_y := visual.position.y                    # -26.5
	var start_y  := normal_y + SPRITE_HEIGHT * 0.5       # punta al ras del suelo

	visual.position.y = start_y

	body_entered.connect(_on_body_entered)

	var tween := create_tween()
	tween.tween_property(visual, "position:y", normal_y, appear_time).set_ease(Tween.EASE_OUT)
	tween.tween_interval(active_time)
	tween.tween_callback(_retract)


func _retract() -> void:
	$CollisionShape2D.set_deferred(&"disabled", true)
	var visual  := $Visual as Sprite2D
	var start_y := visual.position.y + SPRITE_HEIGHT * 0.5
	var tween   := create_tween()
	tween.tween_property(visual, "position:y", start_y, retract_time).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		GameManager.take_damage(DAMAGE)
		DamageNumber.spawn(get_parent(), DAMAGE, body.global_position + Vector2(0.0, -20.0), Color(1.0, 0.25, 0.25, 1.0))
