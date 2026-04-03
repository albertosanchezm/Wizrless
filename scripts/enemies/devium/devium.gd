extends CharacterBody2D
class_name Devium

signal died

const MAX_HEALTH := 200
const PHASE2_THRESHOLD := 0.6

const BURN_WINDOW := 2.5
const BURN_DURATION := 4.0
const BURN_TICK := 0.8
const BURN_DAMAGE := 1
const FIREBALL_DAMAGE := 10
const INTRO_DIALOGUE_TEXT := "~ start\nDevium: Hola \"amigo\"\n=> END"

const BURN_INDICATOR_SCENE := preload("res://scenes/effects/burn_indicator.tscn")
const DIALOGUE_MANAGER_SCRIPT := preload("res://addons/dialogue_manager/dialogue_manager.gd")

var health: int = MAX_HEALTH
var is_phase2: bool:
	get: return health <= MAX_HEALTH * PHASE2_THRESHOLD

var _phase2_triggered := false
var _fire_marked := false
var _mark_timer := 0.0
var _burning := false
var _burn_timer := 0.0
var _burn_tick_timer := 0.0
var _burn_indicator: Node2D = null
var _intro_started := false
var _combat_started := false
var _dialogue_manager: Node = null

var player: CharacterBody2D = null

@onready var phase2_waves: Node2D = $Phase2Waves
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

var _hsm: LimboHSM


func _ready() -> void:
	add_to_group(&"boss")
	player = get_tree().get_first_node_in_group(&"player")
	hitbox.collision_mask |= 32
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_setup_hsm()


func _setup_hsm() -> void:
	_hsm = LimboHSM.new()
	_hsm.set_process(false)
	_hsm.set_physics_process(false)
	add_child(_hsm)

	var idle := _make_state("res://scripts/enemies/devium/states/idle_state.gd", "IdleState")
	var levitate := _make_state("res://scripts/enemies/devium/states/levitate_state.gd", "LevitateState")
	var ice_ball := _make_state("res://scripts/enemies/devium/states/ice_ball_state.gd", "IceBallState")
	var ground_spikes := _make_state("res://scripts/enemies/devium/states/ground_spikes_state.gd", "GroundSpikesState")
	var parabolic := _make_state("res://scripts/enemies/devium/states/parabolic_state.gd", "ParabolicState")
	var ice_rocks := _make_state("res://scripts/enemies/devium/states/ice_rocks_state.gd", "IceRocksState")
	var phase2_transition := _make_state("res://scripts/enemies/devium/states/phase2_transition_state.gd", "Phase2TransitionState")
	var death := _make_state("res://scripts/enemies/devium/states/death_state.gd", "DeathState")

	for s in [idle, levitate, ice_ball, ground_spikes, parabolic, ice_rocks, phase2_transition, death]:
		_hsm.add_child(s)

	_hsm.add_transition(idle, levitate, &"levitate")
	_hsm.add_transition(levitate, ice_ball, &"atk_ice_ball")
	_hsm.add_transition(levitate, ice_rocks, &"atk_ice_rocks")
	_hsm.add_transition(levitate, ground_spikes, &"atk_ground_spikes")
	_hsm.add_transition(levitate, parabolic, &"atk_parabolic")
	_hsm.add_transition(ice_ball, levitate, &"end_attack")
	_hsm.add_transition(ice_rocks, levitate, &"end_attack")
	_hsm.add_transition(ground_spikes, levitate, &"end_attack")
	_hsm.add_transition(parabolic, levitate, &"end_attack")
	_hsm.add_transition(_hsm.ANYSTATE, phase2_transition, &"phase2_start")
	_hsm.add_transition(phase2_transition, levitate, &"end_transition")
	_hsm.add_transition(_hsm.ANYSTATE, death, &"die")

	_hsm.initial_state = idle
	_hsm.initialize(self)
	_hsm.set_active(true)


func _make_state(script_path: String, state_name: String) -> LimboState:
	var s: LimboState = load(script_path).new()
	s.name = state_name
	return s


func _physics_process(delta: float) -> void:
	_hsm.update(delta)
	move_and_slide()
	_update_burn(delta)


func take_damage(amount: int, color: Color = Color.WHITE) -> void:
	if _hsm.get_active_state().name == "DeathState":
		return
	health = max(0, health - amount)
	DamageNumber.spawn(get_level(), amount, global_position + Vector2(randf_range(-12.0, 12.0), -40.0), color)
	GameManager.boss_health_changed.emit(health, MAX_HEALTH)
	if is_phase2 and not _phase2_triggered:
		_phase2_triggered = true
		_hsm.dispatch(&"phase2_start")
	elif health == 0:
		_hsm.dispatch(&"die")


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"player_hitbox"):
		take_damage(10)
	elif area.is_in_group(&"player_projectile"):
		take_damage(FIREBALL_DAMAGE)
		on_fire_hit()
		area.queue_free()


func on_fire_hit() -> void:
	if _burning:
		_burn_timer = BURN_DURATION
		return
	if _fire_marked:
		_fire_marked = false
		_burning = true
		_burn_timer = BURN_DURATION
		_burn_tick_timer = BURN_TICK
		_show_burn_indicator()
	else:
		_fire_marked = true
		_mark_timer = BURN_WINDOW


func _show_burn_indicator() -> void:
	if _burn_indicator:
		return
	_burn_indicator = BURN_INDICATOR_SCENE.instantiate()
	_burn_indicator.position = Vector2(0.0, -42.0)
	add_child(_burn_indicator)


func _hide_burn_indicator() -> void:
	if _burn_indicator:
		_burn_indicator.queue_free()
		_burn_indicator = null


func _update_burn(delta: float) -> void:
	if _fire_marked:
		_mark_timer -= delta
		if _mark_timer <= 0.0:
			_fire_marked = false

	if not _burning:
		return

	_burn_timer -= delta
	if _burn_timer <= 0.0:
		_burning = false
		_hide_burn_indicator()
		return

	_burn_tick_timer -= delta
	if _burn_tick_timer <= 0.0:
		_burn_tick_timer = BURN_TICK
		take_damage(BURN_DAMAGE, Color(1.0, 0.55, 0.1, 1.0))


func die() -> void:
	hide_phase2_aura()
	died.emit()
	GameManager.boss_defeated.emit()


func face_player() -> void:
	if player:
		sprite.flip_h = player.global_position.x < global_position.x


func get_level() -> Node:
	return get_parent().get_parent().get_parent()


func get_floor_y(default_y: float = global_position.y) -> float:
	var level := get_level()
	if level is Room:
		return level.get_floor_y(default_y)
	return default_y


func get_floor_y_at(global_x: float, default_y: float = global_position.y) -> float:
	var level := get_level()
	if level is Room:
		return level.get_floor_y_at(global_x, default_y)
	return default_y


func show_phase2_aura() -> void:
	phase2_waves.call("show_waves")


func hide_phase2_aura() -> void:
	phase2_waves.call("hide_waves")


func start_intro_sequence() -> void:
	if _intro_started:
		return
	_intro_started = true
	velocity = Vector2.ZERO
	_play_intro_sequence()


func _play_intro_sequence() -> void:
	sprite.play(&"idle")

	var dialogue_manager := _get_dialogue_manager()
	if dialogue_manager != null:
		var resource = dialogue_manager.create_resource_from_text(INTRO_DIALOGUE_TEXT)
		if resource != null:
			var balloon = dialogue_manager.show_dialogue_balloon(resource)
			if is_instance_valid(balloon):
				await balloon.tree_exited

	_start_combat()


func _start_combat() -> void:
	if _combat_started:
		return
	_combat_started = true
	GameManager.boss_appeared.emit("Devium", MAX_HEALTH)
	_hsm.dispatch(&"levitate")


func _get_dialogue_manager() -> Node:
	if is_instance_valid(_dialogue_manager):
		return _dialogue_manager

	if Engine.has_singleton("DialogueManager"):
		_dialogue_manager = Engine.get_singleton("DialogueManager") as Node
		return _dialogue_manager

	_dialogue_manager = DIALOGUE_MANAGER_SCRIPT.new()
	get_tree().root.add_child(_dialogue_manager)
	return _dialogue_manager
