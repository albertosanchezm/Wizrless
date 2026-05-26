# ADR-0009: Movement System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Player Movement) |
| **Knowledge Risk** | HIGH — LimboAI addon (LimboHSM); `CharacterBody2D.move_and_slide()` API stable but confirm in 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/movement-system.md` |
| **Post-Cutoff APIs Used** | `LimboHSM` / `LimboState` (LimboAI addon) — verify addon version compatible with Godot 4.6. `CharacterBody2D.move_and_slide()` — confirm no breaking changes in 4.4–4.6. `Input.get_axis()` — unchanged. |
| **Verification Required** | (1) Confirm `CharacterBody2D.is_on_floor()` behavior unchanged in Godot 4.6 (returns true only on the frame after collision with floor). (2) Confirm LimboAI addon compatible with Godot 4.6 — check addon release notes. (3) Confirm `Input.get_axis()` with two opposing actions returns `[-1.0, 1.0]` float in 4.6. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Input System — `move_left/right/jump/dash` actions must be registered), ADR-0002 (GameManager — `has_ability()`, `player_died` signal) |
| **Enables** | ADR-0006 (Camera — follows player `global_position`), ADR-0012 (Zone/Room System — monitors player `global_position` for boundary triggers) |
| **Blocks** | No player movement story may start until this ADR is Accepted. LimboAI addon must be installed and activated. |
| **Addon Dependency** | LimboAI addon required. If unavailable, the HSM must be re-implemented manually — document in the implementation story. |

## Context

Movement is specified in the GDD but the architectural contract — velocity ownership, state machine structure, ability gating pattern, physics constants — requires an ADR to prevent competing implementations.

## Decision

Movement System is a set of GDScript classes (`PlayerMovement` as the root, state classes as children) hosted on the player `CharacterBody2D`. It owns `velocity` entirely — no other system writes `velocity.x` or `velocity.y` directly.

### State Machine (LimboHSM)

Seven states. Transitions via named events dispatched on the HSM.

| State | Entry From | Exits To |
|-------|-----------|---------|
| Idle | Land, respawn, dash end | Run (move input), Jump (jump input), Fall (no floor), Dash (dash input) |
| Run | Move input + grounded | Idle (no input), Jump, Fall (no floor), Dash |
| Jump | jump event (ground/coyote/double) | Fall (`velocity.y >= 0`), Dash |
| Fall | No floor + `velocity.y >= 0` | Idle (land), Jump (coyote/double), Dash |
| Dash | dash event (unlocked + off cooldown) | Idle (timer end) |
| Attack | attack input | Idle/Run/Fall (anim end) |
| Death | `die` event (ANYSTATE transition) | Idle (respawn) |

Attack behavior defined in Spell System ADR. Movement owns transitions to/from Attack only.

### Velocity Ownership Rule

```gdscript
# CORRECT — Movement System owns velocity
velocity.x = SPEED * direction
velocity.y += gravity * delta
move_and_slide()

# FORBIDDEN — other systems cannot write velocity
# player.velocity.x = 0  # wrong; signal the HSM instead

# Spell System notifies: enemy.speed_modifier (enemy velocity, not player)
# Other systems that need to suppress movement: dispatch "stop" or "die" event to HSM
```

### Physics Constants

```gdscript
const SPEED:          float = 90.0   # px/s  horizontal run speed
const JUMP_VELOCITY:  float = -325.0 # px/s  initial vertical velocity on jump
const JUMP_CUT:       float = 0.4    # multiplier for variable-height jump
const GRAVITY:        float = 900.0  # px/s² ascent gravity
const FALL_GRAVITY:   float = 1400.0 # px/s² descent gravity (asymmetric)
const MAX_FALL_SPEED: float = 500.0  # px/s  terminal velocity
const COYOTE_TIME:    float = 0.12   # s     ledge forgiveness window
const JUMP_BUFFER:    float = 0.10   # s     pre-land jump input window
const DASH_SPEED:     float = 220.0  # px/s  dash horizontal speed
const DASH_DURATION:  float = 0.18   # s     dash active time
const DASH_COOLDOWN:  float = 0.6    # s     cooldown after dash
```

All constants in `scripts/player/player.gd`, accessible to all state classes via the `agent` reference.

### Gravity Application (per _physics_process)

```gdscript
if not is_on_floor():
    if velocity.y > 0:  # descending
        velocity.y = min(velocity.y + FALL_GRAVITY * delta, MAX_FALL_SPEED)
    else:               # ascending
        velocity.y += GRAVITY * delta
```

### Jump Logic

```gdscript
# Full jump
velocity.y = JUMP_VELOCITY
# Short hop (on jump release while velocity.y < 0)
if Input.is_action_just_released("jump") and velocity.y < 0:
    velocity.y *= JUMP_CUT
# Coyote time: set coyote_timer = COYOTE_TIME on every grounded frame
# Jump buffer: set jump_buffer_timer = JUMP_BUFFER on jump input
```

### Ability Gating

```gdscript
# Queried live every input frame — grant activates without restart
func can_dash() -> bool:
    return GameManager.has_ability(&"dash") and dash_cooldown_timer <= 0.0

func can_double_jump() -> bool:
    return GameManager.has_ability(&"double_jump") and jumps_left > 0
```

`has_ability()` uses `StringName` keys per ADR-0002. Abilities: `&"dash"`, `&"double_jump"`.

### Dash State

- Horizontal only; direction = input axis at dash moment OR current facing if no input
- `skip_gravity = true` during dash (no `velocity.y` change)
- On DashState `_exit()`: `skip_gravity = false`
- `dash_cooldown_timer = DASH_COOLDOWN` on Dash entry
- `velocity.x = DASH_SPEED * dash_dir` each frame while active

### Death Integration

`player_died` signal from GameManager → dispatches `die` event on HSM → **ANYSTATE** transition → Death state.

Death state entry: play death animation, freeze velocity. `_exit()` on any state (including Dash) clears `skip_gravity = false`.

Respawn: Checkpoint System calls `GameManager.respawn()` → dispatches `respawn` event → Death→Idle.

### Air Move Reset

On every landing (transition to Idle/Run from Jump/Fall/Dash):
```gdscript
func _on_land() -> void:
    jumps_left = 1 if GameManager.has_ability(&"double_jump") else 0
    coyote_timer = 0.0
```

### Architecture Diagram

```
InputContextManager.get_stick_vector() + Input.is_action_*()
  └── PlayerMovement (CharacterBody2D)
        └── LimboHSM
              ├── IdleState
              ├── RunState
              ├── JumpState
              ├── FallState
              ├── DashState (requires has_ability(&"dash"))
              ├── AttackState (delegates to Spell System)
              └── DeathState

PlayerMovement.velocity → move_and_slide() → global_position
  ├── Camera System reads global_position (follow target)
  └── Zone/Room System monitors global_position (boundary/trigger detection)

GameManager.player_died signal → die event → DeathState
GameManager.has_ability() → queried live per input frame
```

## Alternatives Considered

### Alternative A: Flat _physics_process() Without HSM

No LimboHSM — a single `_physics_process()` with large if-else chain.

- **Pros**: No addon dependency.
- **Cons**: Attack state interop becomes complex; death + dash interaction hard to test; GDD specifies state machine.
- **Rejected**: GDD explicitly specifies LimboHSM. State machine is required for Attack/Death separation.

### Alternative B: Signals Instead of Velocity Direct Writes

Other systems signal PlayerMovement to set velocity; PlayerMovement retains ownership.

- **Pros**: Clean boundary — nothing external writes velocity.
- **Cons**: Event bus pattern for real-time physics is inappropriate; velocity must update every physics frame.
- **Current approach**: Movement owns velocity. Other systems dispatch HSM events (`die`, `respawn`) rather than writing velocity. This is already the specified pattern.

## Consequences

### Positive
- Single velocity owner — no race conditions between systems
- Ability gating is live — Progression grants abilities without system restart
- ANYSTATE death transition is robust — dash, jump, fall all transition correctly

### Negative
- LimboAI addon is a hard dependency — if addon breaks in 4.6, all state classes need rewriting
- `skip_gravity = false` must be set in `_exit()` of DashState — forgetting it causes floating enemies/player after death mid-dash

### Risks

- **LimboAI compatibility**: Verify addon builds against Godot 4.6 before implementation story starts. If incompatible, the ADR must be revised to use a manual HSM.
- **`is_on_floor()` one-frame lag**: `CharacterBody2D.is_on_floor()` returns true after `move_and_slide()` resolves. Coyote timer must be set in `_post_move()` (after `move_and_slide()`), not in `_pre_move()`.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-movement-001 | movement-system.md | CharacterBody2D with move_and_slide(); velocity owned by Movement System | Velocity Ownership Rule section |
| TR-movement-002 | movement-system.md | LimboHSM state machine with 7 states | State Machine section |
| TR-movement-003 | movement-system.md | Asymmetric gravity (900 ascent / 1400 descent), variable-height jump (JUMP_CUT=0.4), coyote time (0.12s), jump buffer (0.10s) | Physics Constants + Jump Logic |
| TR-movement-004 | movement-system.md | Ability gating via GameManager.has_ability() queried live | Ability Gating section (also in ADR-0001) |
| TR-movement-005 | movement-system.md | Dash: horizontal only, gravity suspended, ANYSTATE accessible | Dash State section |
| TR-movement-006 | movement-system.md | Death via player_died → die event → ANYSTATE Death transition | Death Integration section |
| TR-movement-007 | movement-system.md | Double jump: requires ability gate + jumps_left > 0, reset on land | Air Move Reset + can_double_jump() |

## Performance Implications

- **CPU**: Physics constants are constant — no dynamic lookup. `move_and_slide()` cost is Godot engine's.
- **CPU**: `has_ability()` called per input frame — Dictionary StringName lookup. < 0.001 ms.
- **Memory**: LimboHSM + 7 state objects. Negligible.

## Validation Criteria

- AC-01/02/03: Run, jump height, short hop verified by QA
- AC-04/05: Coyote time, jump buffer functional
- AC-06/07/08/09: Dash locked when no ability; unlocked with correct behavior and cooldown
- AC-10/11/12: Double jump locked; unlocked; charge resets on land
- AC-13: Death interrupts dash (gravity resumes)
- AC-15: Asymmetric gravity — fall visibly faster than ascent

## Related Decisions

- ADR-0003: Input System — `move_left/right/jump/dash` actions
- ADR-0002: GameManager — `has_ability()`, `player_died` signal, `respawn()` call
- ADR-0006: Camera System — follows player `global_position`
- ADR-0012: Zone/Room System — monitors `global_position`
- `design/gdd/movement-system.md` — full GDD
