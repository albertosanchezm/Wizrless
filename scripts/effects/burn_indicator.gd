extends Node2D
## Icono de llama que acompana al enemigo mientras tiene estado de quemadura.


func _ready() -> void:
	scale = Vector2.ONE * 0.5

	var outer := Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(5.0, -7.0),
		Vector2(7.0, -2.0),
		Vector2(4.0, 4.0),
		Vector2(0.0, 7.0),
		Vector2(-4.0, 4.0),
		Vector2(-7.0, -2.0),
		Vector2(-5.0, -7.0),
	])
	outer.color = Color(1.0, 0.4, 0.05, 1.0)
	add_child(outer)

	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(0.0, -7.0),
		Vector2(3.0, -2.0),
		Vector2(2.0, 3.0),
		Vector2(0.0, 4.5),
		Vector2(-2.0, 3.0),
		Vector2(-3.0, -2.0),
	])
	inner.color = Color(1.0, 0.92, 0.2, 1.0)
	add_child(inner)

	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 2.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y + 2.0, 0.4).set_trans(Tween.TRANS_SINE)
