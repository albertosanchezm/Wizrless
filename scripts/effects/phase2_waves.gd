extends Node2D

const OUTER_COLOR := Color(0.45, 0.95, 1.0, 0.9)
const INNER_COLOR := Color(0.9, 1.0, 1.0, 0.95)
const RING_COUNT := 3
const SEGMENTS := 72
const SPOKE_COUNT := 8

var _time := 0.0
var _active := false


func _ready() -> void:
	visible = false
	set_process(false)


func show_waves() -> void:
	_time = 0.0
	_active = true
	visible = true
	set_process(true)
	queue_redraw()


func hide_waves() -> void:
	_active = false
	visible = false
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	scale = Vector2.ONE * (1.0 + sin(_time * 4.0) * 0.03)
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	for i in range(RING_COUNT):
		var phase := _time * 3.0 + float(i) * 0.45
		var radius_x := 26.0 + float(i) * 10.0 + sin(phase * 1.7) * 2.5
		var radius_y := 19.0 + float(i) * 7.0 + cos(phase * 1.3) * 2.0
		var width := 2.0 + float(i) * 0.6
		var color := OUTER_COLOR.lerp(INNER_COLOR, float(i) / float(RING_COUNT))
		color.a = 0.9 - float(i) * 0.18
		_draw_ring(radius_x, radius_y, width, color)

	var spoke_phase := _time * 2.6
	for i in range(SPOKE_COUNT):
		var angle := spoke_phase + float(i) * TAU / float(SPOKE_COUNT)
		var start := Vector2(cos(angle) * 14.0, sin(angle) * 10.0)
		var ending := Vector2(cos(angle) * 48.0, sin(angle) * 34.0)
		var spoke_color := INNER_COLOR
		spoke_color.a = 0.3 + 0.2 * (0.5 + 0.5 * sin(_time * 7.0 + float(i)))
		draw_line(start, ending, spoke_color, 1.6, true)


func _draw_ring(radius_x: float, radius_y: float, width: float, color: Color) -> void:
	var points: PackedVector2Array = []

	for step in range(SEGMENTS + 1):
		var t := float(step) / float(SEGMENTS)
		var angle := t * TAU
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))

	draw_polyline(points, color, width, true)
