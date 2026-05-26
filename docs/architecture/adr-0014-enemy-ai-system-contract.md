# ADR-0014: Enemy AI System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Feature (Enemy Behavior) |
| **Knowledge Risk** | HIGH — LimboAI addon; CharacterBody2D unchanged |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/enemy-ai-system.md` |
| **Post-Cutoff APIs Used** | `LimboHSM` / `LimboState` (LimboAI addon) — same dependency as ADR-0009 and ADR-0011 |
| **Verification Required** | Same as ADR-0009: verify LimboAI addon compatible with Godot 4.6 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0011 (BaseEnemy — `agent.health`, `agent.velocity`, `agent.player`), ADR-0012 (Zone/Room — enemies live in room `Enemies` node), ADR-0009 (Movement — `move_and_slide()` same pattern) |
| **Enables** | ADR-0020 (Boss System — uses attack selection pattern defined here) |
| **Blocks** | No enemy behavior story may start until LimboAI addon is verified and this ADR is Accepted |

## Context

All regular enemies share a four-state patrol pattern. Boss AI extends the same LimboHSM pattern with bespoke states per boss. This ADR documents the shared architecture, exported config contract, and parabolic projectile formula that both regular and boss enemies use.

## Decision

All enemies use `LimboHSM`. States extend `LimboState`. Enemy body accessed via `agent as BaseEnemy`. Enemy `_physics_process` calls `_hsm.update(delta)` then `move_and_slide()`.

### Regular Enemy State Machine

```
Patrol ──aggro──▶ Aggro ──in_range──▶ Attack
  ▲                 │                     │
  └──lose_target────┘◀────end_attack──────┘
```

| State | Entry From | Exits To |
|-------|-----------|---------|
| Patrol | Land, Return | Aggro (player enters `aggro_radius`) |
| Aggro | Patrol, Return | Attack (player in `attack_range`); Return (player beyond `lose_radius`) |
| Attack | Aggro | Aggro (animation ends, re-evaluate) |
| Return | Aggro | Patrol (reached origin); Aggro (player re-aggros) |

Death is an ANYSTATE transition (inherited from BaseEnemy, dispatched from `take_damage()`).

### Exported Config (all values)

```gdscript
# PatrolState
@export var patrol_speed:    float = 40.0
@export var patrol_points:   Array[NodePath] = []   # Marker2D refs; empty = idle in place
@export var use_los:         bool  = false           # line-of-sight raycast gate

# AggroState
@export var chase_speed:     float = 70.0            # MUST be < player SPEED (90)
@export var aggro_radius:    float = 150.0
@export var lose_radius:     float = 250.0           # always > aggro_radius

# RegularEnemyAttackState
@export var attack_range:    float = 60.0
@export var attack_scene:    PackedScene              # projectile or melee Area2D
@export var attack_damage:   int   = 10
@export var attack_duration: float = 1.0
@export var cast_frame:      int   = 3
@export var attack_animation: StringName = &"attack"
```

All tuning happens in the Godot inspector per-enemy scene. No subclassing needed for different regular enemy types.

### Chase Speed Invariant

`chase_speed` MUST remain below `player.SPEED = 90.0 px/s`. Enforced at `AggroState._enter()`:
```gdscript
if chase_speed >= 90.0:
    push_warning("AggroState: chase_speed %f >= player SPEED 90 — enemy can trap player" % chase_speed)
    chase_speed = 85.0   # auto-correct; log for designer review
```

### Perception Model

**Distance (always active):**
```gdscript
var dist := agent.global_position.distance_to(agent.player.global_position)
if dist <= aggro_radius: _hsm.dispatch(&"aggro")
if dist >  lose_radius:  _hsm.dispatch(&"lose_target")
```

**LOS (optional, `use_los = true`):**
```gdscript
var query := PhysicsRayQueryParameters2D.create(
    agent.global_position,
    agent.player.global_position,
    0b_0001  # terrain layer only
)
query.exclude = [agent.get_rid()]
var result := agent.get_world_2d().direct_space_state.intersect_ray(query)
var can_see := result.is_empty()  # ray hit nothing → clear LOS
```

### Loss Radius Guard

```gdscript
func _setup() -> void:
    lose_radius = max(lose_radius, aggro_radius + 50.0)
```

Prevents hysteresis oscillation at edge.

### Projectile Placement (level root, not enemy parent)

All enemy projectiles and spawned nodes added to level root:
```gdscript
func _get_level() -> Node:
    return get_tree().current_scene

# In attack state, fire:
var proj := attack_scene.instantiate()
proj.global_position = agent.global_position
_get_level().add_child(proj)
```

Ensures projectiles survive room `queue_free()` if fired just before transition.

### Parabolic Projectile Formula (Boss Reference)

```gdscript
# Used by Devium IceBallState and ParabolicSpreadState
# PB constants live on BaseBoss or boss config:
const PB_H_SPEED: float   = 130.0  # px/s horizontal component
const PB_MIN_TIME: float   = 0.5   # s minimum flight time
const PB_GRAVITY:  float   = 400.0 # px/s² arc gravity
const PB_BASE_SPEED: float = 200.0 # px/s direction magnitude

func _calc_parabolic_direction(from: Vector2, to: Vector2) -> Vector2:
    var dx := to.x - from.x
    var dy := to.y - from.y
    var T  := max(abs(dx) / PB_H_SPEED, PB_MIN_TIME)
    var vx := dx / T
    var vy := (dy - 0.5 * PB_GRAVITY * T * T) / T
    return Vector2(vx, vy).normalized()
```

### MVP Enemy Types

| Enemy | Type | `chase_speed` | `aggro_radius` | `attack_range` | Drop |
|-------|------|-------------|--------------|--------------|------|
| Sentinel | Melee | 60 | 120 | 40 | assigned per room |
| Warden | Ranged | 0 | 200 | 180 | assigned per room |

Warden: `chase_speed=0` means enemy faces player in Aggro but does not move; player must close to trigger Attack.

### Architecture Diagram

```
Enemy _physics_process(delta)
  → _hsm.update(delta)
  → PatrolState / AggroState / AttackState / ReturnState
       ├── reads: agent.player.global_position (distance)
       ├── writes: agent.velocity
       └── spawns: attack_scene at level root (not room)
  → move_and_slide()
  → SIE.process_hit() ← called by projectile on body_entered

[ANYSTATE] die → DeathState (inherited from BaseEnemy)
```

## Consequences

### Positive
- All tuning is inspector data — designers change behavior without code changes
- Same LimboHSM pattern across player, enemies, bosses — consistent debugging

### Negative
- LimboAI hard dependency — if addon breaks, all enemy AI requires rewrite
- LOS raycast per enemy per frame: acceptable at ≤20 enemies/room; monitor at higher counts

### Risks

- **`use_los` raycasts hitting own CollisionShape2D**: `query.exclude` must contain the agent's RID. Missing exclude → enemy always sees "terrain" and never aggros.
- **`is_on_floor()` not needed for enemies**: Enemies do not jump. No coyote/buffer needed. Keep physics simple.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-ai-001 | enemy-ai-system.md | Per-enemy state machine via LimboHSM: Patrol → Aggro → Attack → Return | State Machine section |
| TR-ai-002 | enemy-ai-system.md | All AI tuning exposed via @export properties | Exported Config section |
| TR-ai-003 | enemy-ai-system.md | chase_speed must remain below player SPEED (90 px/s) | Chase Speed Invariant |
| TR-ai-004 | enemy-ai-system.md | Weighted attack selection with no-repeat-last rule | Documented in ADR-0020 (Boss System uses this pattern) |
| TR-ai-005 | enemy-ai-system.md | Parabolic projectile spawn formula for arc attacks | Parabolic Projectile Formula section |

## Related Decisions

- ADR-0011: BaseEnemy class — `agent` properties accessed by all states
- ADR-0020: Boss System — extends this pattern with weighted attack selection
- `design/gdd/enemy-ai-system.md` — full GDD
