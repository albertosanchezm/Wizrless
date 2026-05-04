# Enemy AI System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: Controlled Ascension (support)

## Overview

The Enemy AI System defines the behavioral architecture for all non-player combatants: the state machine pattern, perception model, standard regular-enemy behavior states, and shared AI utilities. It does not define boss AI in detail — boss behavior is designed per-boss in the Boss System GDD. It provides the patterns bosses may reference but does not constrain their implementation.

All enemy AI uses LimboHSM — the same addon used for the player and Devium. States extend `LimboState` and access the enemy via `agent`. This consistency means all enemies share the same authoring model, debugging approach, and physics integration.

Regular enemies at MVP follow a four-state machine: **Patrol → Aggro → Attack → Return**. Behavior is configured entirely through exported variables on the state nodes — no subclassing needed to create different enemy types. A melee guard and a ranged archer are the same FSM with different `patrol_speed`, `aggro_radius`, `attack_range`, and `attack_scene` values.

Perception is distance-based at MVP. An optional line-of-sight raycast can be enabled per enemy to prevent aggro through walls. Boss AI (Devium's Levitate/IceBall/GroundSpikes states) is the reference implementation of complex AI — the Enemy AI System documents its patterns but does not restrict it.

## Player Fantasy

Regular enemies should never surprise the player with their intelligence. They should surprise the player with their placement.

A guard patrolling a narrow corridor is not a puzzle — it is a clock. A ranged enemy positioned behind a gap the wizard cannot yet cross without the dash ability is not a blocker — it is a preview. The wizard learns what is coming from how enemies are arranged, not from what they decide to do. Their decisions are simple. The room that contains them is the design.

## Detailed Design

### AI Architecture

All enemies use LimboHSM. States extend `LimboState`. Enemy body accessed via `agent as BaseEnemy` (or subclass). Physics: enemy `_physics_process` → `_hsm.update(delta)` → `move_and_slide()` — identical pattern to player and Devium.

State scripts attach as children of the HSM node. All behavior values are `@export` on state scripts — tuning happens in the Godot inspector per scene, not in code.

---

### Regular Enemy State Machine

Four states. All regular enemies use this template; per-enemy variation comes from exported config.

```
Patrol ──aggro──▶ Aggro ──in_range──▶ Attack
  ▲                  │                    │
  └──lose_target─────┘◀────end_attack─────┘
```

| State | Behavior | Exits when |
|-------|----------|------------|
| **Patrol** | Move between patrol points; idle in place if none set. Flip sprite at each endpoint. | Player enters `aggro_radius` → Aggro |
| **Aggro** | Move toward player at `chase_speed`. Face player each frame. | Player in `attack_range` → Attack; player outside `lose_radius` → Return |
| **Attack** | Stop moving. Play attack animation. Spawn `attack_scene` at `cast_frame`. Wait `attack_duration`. | Animation ends → Aggro (re-evaluate distance) |
| **Return** | Move back to patrol origin at `patrol_speed`. | Reaches origin → Patrol; player re-enters `aggro_radius` → Aggro |

---

### Perception Model

**Distance check (always active, each frame):**
```
dist = global_position.distance_to(player.global_position)
dist <= aggro_radius  →  aggro
dist >  lose_radius   →  return to patrol
```

**Line-of-sight (optional, per enemy):**
```
@export var use_los: bool = false

If use_los: raycast from enemy center to player center
  exclude: self, other enemies
  if ray hits terrain before player: not visible → no aggro
```

One raycast per frame per LOS enemy. Target: ≤ 20 regular enemies per room — negligible performance cost.

---

### Exported Config (all behavior values)

```
-- PatrolState
@export patrol_speed:     float = 40.0
@export patrol_points:    Array[NodePath] = []  # Marker2D refs; empty = idle in place
@export use_los:          bool  = false

-- AggroState
@export chase_speed:      float = 70.0
@export aggro_radius:     float = 150.0   # px — enter aggro
@export lose_radius:      float = 250.0   # px — lose target (always > aggro_radius)

-- RegularEnemyAttackState
@export attack_range:     float = 60.0    # px — trigger attack
@export attack_scene:     PackedScene     # projectile or melee hitbox
@export attack_damage:    int   = 10
@export attack_duration:  float = 1.0     # s — full attack cycle
@export cast_frame:       int   = 3       # animation frame to spawn attack_scene
@export attack_animation: StringName = &"attack"
```

---

### MVP Enemy Types

**Sentinel (melee):**
- Patrols platform; aggros on proximity
- Spawns short-range `Area2D` hitbox at `cast_frame`
- Config: `patrol_speed=35`, `chase_speed=60`, `aggro_radius=120`, `attack_range=40`

**Warden (ranged):**
- Patrols or idles; aggros on proximity; stops to fire
- Fires slow projectile toward player at `cast_frame`
- Config: `patrol_speed=25`, `chase_speed=0`, `aggro_radius=200`, `attack_range=180`

Same four-state HSM for both. Only exported values and `attack_scene` differ.

---

### Boss AI Pattern (Reference)

Devium uses the same LimboHSM pattern with bespoke states:
- Idle → proximity trigger → intro sequence → Levitate
- Levitate → timed attack selection (weighted random, distance-biased, no-repeat last attack) → attack state
- Attack state → windup → fire → `end_attack` → Levitate
- ANYSTATE → Phase2Transition at health threshold
- ANYSTATE → Death

Attack selection pool and distance bias are configurable per boss. Pattern is recommended but not mandated for future bosses.

---

### Interactions with Other Systems

| System | Direction | Exchange |
|--------|-----------|---------|
| Enemy Base System | AI reads | `health`, `is_dead`, `player`, `face_player()`, `velocity` via `agent` |
| Movement System | Parallel | AI sets `agent.velocity`; `move_and_slide()` in enemy `_physics_process` |
| Zone/Room System | Room owns enemies | Enemy instances in `Enemies` node; HSM starts on `_ready()` |
| Spell System | Spell → AI | Projectile calls `take_damage()` — no hit-stun reaction at MVP |
| Player | AI reads | `player.global_position` each frame for distance, facing, targeting |

## Formulas

### Perception Radii

```
-- Aggro hysteresis (lose_radius > aggro_radius prevents oscillation):
recommended: lose_radius >= aggro_radius × 1.5

Sentinel: aggro=120, lose=180  (ratio 1.5×)
Warden:   aggro=200, lose=300  (ratio 1.5×)
```

### Chase Pursuit

```
-- Simple direct pursuit: move toward player.global_position each frame.
-- No prediction or lead targeting needed.

-- Speed comparison:
chase_speed = 70 px/s  vs  player SPEED = 90 px/s
→ Player always faster. Enemy pressures; cannot trap a running player.
   Correct for traversal-enemy design intent.
```

### Parabolic Projectile (Devium reference)

```
T  = max(|dx| / PB_H_SPEED, PB_MIN_TIME)
   = max(|dx| / 130, 0.5)

vx = dx / T
vy = (dy - 0.5 × PB_GRAVITY × T²) / T
   where PB_GRAVITY = 400 px/s²

direction = Vector2(vx, vy) / PB_BASE_SPEED
   where PB_BASE_SPEED = 200.0
```

### Attack Timing

```
fire_time       = cast_frame / animation_fps
reaction_window = attack_duration - fire_time

Example (frame 3, 8fps, duration 1.0s):
  fire_time       = 3 / 8 = 0.375s
  reaction_window = 1.0 - 0.375 = 0.625s
```

### Boss Attack Selection (Devium)

```
pool = all attacks except last_used
if dist > 200 and randf() < 0.65 → prefer atk_ice_ball
if dist < 120 and randf() < 0.65 → prefer atk_ice_rocks
else pool.shuffle()[0]

Phase 2 pool adds: atk_ground_spikes, atk_parabolic
```

### Variable Definitions

| Variable | Default | Description |
|----------|---------|-------------|
| `patrol_speed` | 35–40 px/s | Patrol movement speed |
| `chase_speed` | 60–70 px/s | Aggro pursuit speed |
| `aggro_radius` | 120–200 px | Perception distance |
| `lose_radius` | 180–300 px | Deaggro distance |
| `attack_range` | 40–180 px | Distance to trigger attack |
| `attack_duration` | 1.0 s | Full attack state duration |

## Edge Cases

**EC-01 — Player null when AI checks distance.**
All perception checks guard `if not _e.player: return`. Enemy stays in current state. Idles safely.

**EC-02 — Enemy killed mid-state-update.**
`take_damage()` dispatches `&"die"` → ANYSTATE → Death. Current state tick may finish — harmless since `is_dead` blocks further damage calls.

**EC-03 — Player kills enemy mid-attack.**
Death ANYSTATE transition fires. In-flight projectile already spawned continues and can hit the player. Correct: the attack was committed before death.

**EC-04 — Patrol points array is empty.**
Enemy idles in place — `velocity = Vector2.ZERO`, idle animation plays. Aggro check still active. No crash.

**EC-05 — lose_radius ≤ aggro_radius.**
Oscillation risk. Guard in `_setup()`: `lose_radius = max(lose_radius, aggro_radius + 50.0)`. Data authoring error, not a runtime crash.

**EC-06 — Player edge-pokes aggro boundary.**
Hysteresis from `lose_radius` prevents rapid flip. Once aggroed, enemy stays aggroed until player reaches `lose_radius`.

**EC-07 — Player closes to attack range while enemy is in Return state.**
Return does not check `attack_range`. Player must re-enter `aggro_radius` first. No attack-bait exploit from behind a returning enemy.

**EC-08 — LOS raycast hits terrain before player.**
Player not visible. Enemy stays in Patrol. Aggro triggers on next frame once LOS clears. ≤1 frame latency. No persistent blind-spot bug.

**EC-09 — chase_speed = 0 in Aggro state.**
Warden design: enemy faces player but does not move. Player can always close to attack range. Enemy does not kite. Correct by design.

**EC-10 — Room unloads while enemy mid-attack.**
Room `queue_free()` destroys all room children. In-flight projectiles added to the level root (not the room's `Enemies` node) survive. **Rule**: all enemy projectiles added to `get_level()`, not the enemy's parent. Already implemented in Devium.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Enemy Base System** | Reads | `agent.health`, `agent.is_dead`, `agent.player`, `agent.face_player()`, `agent.velocity` — all per-enemy access via `agent` reference |
| **Movement System** | Parallel | AI writes `agent.velocity`; `move_and_slide()` called in enemy `_physics_process` after `_hsm.update(delta)` — same pattern as player |
| **Zone/Room System** | Owned by | Enemies live under Room's `Enemies` node; HSM starts on `_ready()`; room unload destroys all enemies cleanly |
| **Spell System** | Receives | Spell projectiles call `agent.take_damage(amount)` — AI not consulted, damage is applied directly to Enemy Base |
| **Player** | Reads | `agent.player.global_position` each frame for distance, direction, and attack targeting |
| **LimboHSM addon** | Requires | All states extend `LimboState`; HSM node drives tick loop; without this addon no enemy AI state machine runs |

**Reverse dependencies (systems that depend on this GDD):**
- Boss System reads the four-state pattern and attack selection formula defined here as its recommended authoring model.

## Tuning Knobs

All values are `@export` on the relevant state script. Tuning happens in the Godot inspector per enemy scene — no code changes required.

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `patrol_speed` | 35–40 px/s | 15–60 px/s | Below 15: functionally stationary, feels broken. Above 60: patrol feels frantic, hard to read. |
| `chase_speed` | 60–70 px/s | 40–85 px/s | **Must stay below player speed (90 px/s).** Above 90: enemy can trap a running player — breaks traversal-enemy intent. At 0: Warden stationary-aggro design. |
| `aggro_radius` | 120–200 px | 80–280 px | Below 80: player consistently sneaks past (can be intentional). Above 280: enemy always reactive at room scale — stressful, anti-exploration. |
| `lose_radius` | 180–300 px | `aggro_radius × 1.5` min, 400 px max | Too close to `aggro_radius`: oscillation (EC-06). Too large: enemy never stops chasing. Rule: `lose_radius = max(desired, aggro_radius + 50)` enforced in `_setup()`. |
| `attack_range` | 40–180 px | 30–220 px | Melee: 30–60. Ranged: 120–220. Must be < `aggro_radius` or enemy attacks before entering chase. |
| `attack_duration` | 1.0 s | 0.5–2.5 s | Below 0.5 s: reaction window < 0.125 s at cast_frame 3 — effectively unreadable. Above 2.5 s: attack cycle too slow, enemies feel unresponsive. |
| `cast_frame` | 3 | 1 – (fps × duration – 1) | Must fire before animation ends. `cast_frame / animation_fps` = wind-up time. Governs reaction window (see Formulas). |
| `attack_damage` | 10 | 5–30 | Calibrate against player max HP. At player HP=100: 10 dmg = 10% per hit, 30 = 30% per hit. High values require longer `attack_duration` to be fair. |
| `use_los` | false | true/false | false: aggros through walls (most rooms). true: prevents wall-aggro, adds LOS raycast cost (negligible at ≤20 enemies/room). Use on ambush-placement enemies. |

## Acceptance Criteria

**AC-01 — Patrol behavior.**
Enemy placed with two `patrol_points` walks between them at `patrol_speed` and flips sprite at each endpoint. Enemy with `patrol_points = []` idles in place with idle animation playing. Verified by: place Sentinel in room, observe loop.

**AC-02 — Aggro transition.**
Player entering `aggro_radius` causes enemy to switch to chase state within one physics frame. Enemy faces player and moves at `chase_speed` each frame. Verified by: step into radius, observe immediate pursuit.

**AC-03 — Attack trigger.**
Enemy in Aggro state that closes to within `attack_range` stops movement, plays `attack_animation`, and spawns `attack_scene` on `cast_frame`. Verified by: let Sentinel close to melee range, confirm hitbox spawns.

**AC-04 — Attack → re-evaluate.**
After `attack_duration` elapses, enemy returns to Aggro and re-evaluates distance. If player is in range again, another attack triggers. Verified by: stay in attack range through full attack cycle.

**AC-05 — Return behavior.**
Player moving beyond `lose_radius` causes enemy to exit chase/attack and return to patrol origin at `patrol_speed`. Enemy re-aggros if player re-enters `aggro_radius` during return. Verified by: aggro enemy then run away past `lose_radius`.

**AC-06 — LOS raycast gating.**
Enemy with `use_los = true` does NOT aggro when player is in `aggro_radius` but behind terrain. Enemy DOES aggro when LOS clears. Enemy with `use_los = false` aggros through walls. Verified by: place wall between enemy and player, compare `use_los` true/false.

**AC-07 — Chase speed ceiling.**
At `chase_speed = 70` (default), player running at full speed (90 px/s) always opens distance. Enemy cannot catch a player who is actively running. Verified by: measure positions over 3 seconds of active fleeing.

**AC-08 — Death from any state.**
`take_damage()` reducing health to 0 triggers death transition from Patrol, Aggro, Attack, or Return. Enemy stops all behavior, plays death animation, then `queue_free()`. No further damage can be applied post-death. Verified by: kill enemy in each state.

**AC-09 — Projectile survives room unload (EC-10).**
In-flight projectile added to level root, not room's `Enemies` node. After room `queue_free()`, projectile continues and can hit player. Verified by: fire projectile, transition to adjacent room, confirm projectile follows through.

**AC-10 — Edge case guards (EC-01, EC-04, EC-05).**
Enemy with `player = null` stays in current state and does not crash. Empty `patrol_points` idles without error. `lose_radius < aggro_radius + 50` is auto-corrected at setup — log warning, no crash. Verified by: null player reference test, empty patrol array test, misconfigured radii test.
