extends CharacterBody2D

const FIREBALL_SCENE := preload("res://scenes/projectiles/fireball.tscn")

# ─── Constantes de física (leídas por los estados) ──────────────────────────
const SPEED          := 90.0
const JUMP_VELOCITY  := -260.0
const JUMP_CUT       := 0.4
const GRAVITY        := 900.0
const FALL_GRAVITY   := 1400.0
const MAX_FALL_SPEED := 500.0
const COYOTE_TIME    := 0.12
const JUMP_BUFFER    := 0.10
const DASH_SPEED      := 220.0
const DASH_DURATION   := 0.18
const DASH_COOLDOWN   := 0.6
const ATTACK_COOLDOWN := 1.5

# ─── Estado compartido (escrito/leído por los estados) ───────────────────────
var coyote_timer   := 0.0
var jump_buffer    := 0.0
var dash_cooldown  := 0.0
var attack_cooldown := 0.0
var jumps_left     := 0     # saltos extra disponibles (doble salto)
var skip_gravity   := false # el estado Dash lo activa para anular la gravedad

# ─── Referencias ────────────────────────────────────────────────────────────
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _hsm: LimboHSM


func _ready() -> void:
	add_to_group(&"player")
	GameManager.player_died.connect(_on_player_died)
	_setup_hsm()
	var pcam := get_node_or_null("PhantomCamera2D")
	if pcam:
		pcam.set("follow_target", self)


func _on_player_died() -> void:
	_hsm.dispatch(&"die")


# ─── Setup de la máquina de estados ─────────────────────────────────────────
func _setup_hsm() -> void:
	_hsm = LimboHSM.new()
	# Desactivamos el auto-update para controlarlo desde _physics_process
	_hsm.set_process(false)
	_hsm.set_physics_process(false)
	add_child(_hsm)

	var idle   := _make_state("res://scripts/player/states/idle_state.gd",   "IdleState")
	var run    := _make_state("res://scripts/player/states/run_state.gd",    "RunState")
	var jump   := _make_state("res://scripts/player/states/jump_state.gd",   "JumpState")
	var fall   := _make_state("res://scripts/player/states/fall_state.gd",   "FallState")
	var dash   := _make_state("res://scripts/player/states/dash_state.gd",   "DashState")
	var attack := _make_state("res://scripts/player/states/attack_state.gd", "AttackState")
	var death  := _make_state("res://scripts/player/states/death_state.gd",  "DeathState")

	for s in [idle, run, jump, fall, dash, attack, death]:
		_hsm.add_child(s)

	# Transiciones
	_hsm.add_transition(idle,          run,    &"move")
	_hsm.add_transition(run,           idle,   &"stop")
	_hsm.add_transition(idle,          jump,   &"jump")
	_hsm.add_transition(run,           jump,   &"jump")
	_hsm.add_transition(fall,          jump,   &"jump")   # coyote + doble salto
	_hsm.add_transition(idle,          fall,   &"fall")
	_hsm.add_transition(run,           fall,   &"fall")
	_hsm.add_transition(jump,          fall,   &"fall")
	_hsm.add_transition(fall,          idle,   &"land")
	_hsm.add_transition(idle,          dash,   &"dash")
	_hsm.add_transition(run,           dash,   &"dash")
	_hsm.add_transition(jump,          dash,   &"dash")
	_hsm.add_transition(fall,          dash,   &"dash")
	_hsm.add_transition(dash,          idle,   &"end_dash")
	_hsm.add_transition(idle,          attack, &"attack")
	_hsm.add_transition(run,           attack, &"attack")
	_hsm.add_transition(jump,          attack, &"attack")
	_hsm.add_transition(fall,          attack, &"attack")
	_hsm.add_transition(attack,        idle,   &"stop")
	_hsm.add_transition(attack,        run,    &"move")
	_hsm.add_transition(attack,        fall,   &"fall")
	_hsm.add_transition(_hsm.ANYSTATE, death,  &"die")

	_hsm.initial_state = idle
	_hsm.initialize(self)
	_hsm.set_active(true)

	# Conectar señal del estado de ataque tras initialize (los estados ya existen como nodos)
	var attack_node := _hsm.get_node("AttackState")
	attack_node.attack_fired.connect(_on_attack_fired)


func _make_state(script_path: String, state_name: String) -> LimboState:
	var s: LimboState = load(script_path).new()
	s.name = state_name
	return s


# ─── Loop de física ──────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_buffer_jump(delta)
	if not skip_gravity:
		_apply_gravity(delta)
	_hsm.update(delta)
	move_and_slide()
	_post_move()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return
	var grav := FALL_GRAVITY if velocity.y > 0.0 else GRAVITY
	velocity.y = min(velocity.y + grav * delta, MAX_FALL_SPEED)


func _tick_timers(delta: float) -> void:
	dash_cooldown = max(0.0, dash_cooldown - delta)
	if attack_cooldown > 0.0:
		attack_cooldown = max(0.0, attack_cooldown - delta)
		GameManager.attack_cooldown_changed.emit(attack_cooldown, ATTACK_COOLDOWN)
	if not is_on_floor():
		coyote_timer = max(0.0, coyote_timer - delta)


func _buffer_jump(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer = max(0.0, jump_buffer - delta)


func _post_move() -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME


# ─── Helpers usados por los estados ─────────────────────────────────────────
func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0.0


func reset_air_moves() -> void:
	jumps_left = 1 if GameManager.has_ability("double_jump") else 0


func flip_toward(dir: float) -> void:
	if dir != 0.0:
		anim.flip_h = dir < 0.0


func wants_attack() -> bool:
	return Input.is_action_just_pressed("attack") and attack_cooldown <= 0.0


func wants_dash() -> bool:
	return Input.is_action_just_pressed("dash") \
		and GameManager.has_ability("dash") \
		and dash_cooldown <= 0.0


func _on_attack_fired(pos: Vector2, dir: Vector2) -> void:
	var fb := FIREBALL_SCENE.instantiate()
	fb.direction = dir
	# Desplazar al pecho del personaje y por delante para no solapar el suelo
	fb.global_position = pos + Vector2(dir.x * 16.0, -26.0)
	get_parent().add_child(fb)
