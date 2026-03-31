extends CharacterBody2D
class_name Devium

signal died

# ─── Stats ───────────────────────────────────────────────────────────────────
const MAX_HEALTH       := 100
const PHASE2_THRESHOLD := 0.6   # 60% vida para fase 2

var health: int = MAX_HEALTH
var is_phase2: bool:
	get: return health <= MAX_HEALTH * PHASE2_THRESHOLD

# ─── Referencia al player ─────────────────────────────────────────────────────
var player: CharacterBody2D = null

# ─── Referencias ──────────────────────────────────────────────────────────────
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D      = $Sprite2D
@onready var hitbox: Area2D        = $Hitbox

var _hsm: LimboHSM


func _ready() -> void:
	player = get_tree().get_first_node_in_group(&"player")
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_setup_hsm()


func _setup_hsm() -> void:
	_hsm = LimboHSM.new()
	_hsm.set_process(false)
	_hsm.set_physics_process(false)
	add_child(_hsm)

	var idle          := _make_state("res://scripts/enemies/devium/states/idle_state.gd",          "IdleState")
	var levitate      := _make_state("res://scripts/enemies/devium/states/levitate_state.gd",      "LevitateState")
	var ice_ball      := _make_state("res://scripts/enemies/devium/states/ice_ball_state.gd",      "IceBallState")
	var ground_spikes := _make_state("res://scripts/enemies/devium/states/ground_spikes_state.gd", "GroundSpikesState")
	var parabolic     := _make_state("res://scripts/enemies/devium/states/parabolic_state.gd",     "ParabolicState")
	var ice_rocks     := _make_state("res://scripts/enemies/devium/states/ice_rocks_state.gd",     "IceRocksState")
	var death         := _make_state("res://scripts/enemies/devium/states/death_state.gd",         "DeathState")

	for s in [idle, levitate, ice_ball, ground_spikes, parabolic, ice_rocks, death]:
		_hsm.add_child(s)

	# Transiciones
	_hsm.add_transition(idle,          levitate,      &"levitate")
	_hsm.add_transition(levitate,      ice_ball,      &"atk_ice_ball")
	_hsm.add_transition(levitate,      ice_rocks,     &"atk_ice_rocks")
	_hsm.add_transition(levitate,      ground_spikes, &"atk_ground_spikes")
	_hsm.add_transition(levitate,      parabolic,     &"atk_parabolic")
	_hsm.add_transition(ice_ball,      levitate,      &"end_attack")
	_hsm.add_transition(ice_rocks,     levitate,      &"end_attack")
	_hsm.add_transition(ground_spikes, levitate,      &"end_attack")
	_hsm.add_transition(parabolic,     levitate,      &"end_attack")
	_hsm.add_transition(_hsm.ANYSTATE, death,         &"die")

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


func take_damage(amount: int) -> void:
	if _hsm.get_active_state().name == "DeathState":
		return
	health = max(0, health - amount)
	if health == 0:
		_hsm.dispatch(&"die")


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"player_hitbox"):
		take_damage(10)


func face_player() -> void:
	if player:
		sprite.flip_h = player.global_position.x < global_position.x
