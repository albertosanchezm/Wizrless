# Hazard System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-03
> **Implements Pillar**: Controlled Ascension (environmental pressure)

## Overview

The Hazard System defines every non-enemy environmental threat: ground spikes, damage zones, and kill zones (pits). Hazards deal damage or instant death to the player on contact. They are placed by level designers in each room's `Hazards` node and require no code changes per placement — all behavior is configured through exported variables in the Godot inspector.

Three hazard types cover the full MVP design space. **GroundSpike** is timed — it appears, deals damage on contact during its active window, then retracts and despawns. It already exists as a scene and script. **DamageZone** is persistent — a static area that damages the player on entry and optionally on tick while overlapping. **KillZone** removes all player HP instantly — used for bottomless pits and death voids. All hazards share one collision layer (16) and mask only the player (layer 2). Damage routes through `GameManager.take_damage()` — no hazard directly modifies player state.

Boss-spawned hazards (e.g. Devium's ground spike wave) instantiate the same `GroundSpike` scene with overridden timing. The Hazard System does not own boss attack logic — it only defines the reusable hazard primitives bosses can use.

## Player Fantasy

Hazards teach the player to read the room before they move.

A spike that telegraphs its appearance is not punishment — it is a conversation. The player learns the rhythm, finds the gap, and passes through it. A damage zone with a visible boundary is not unfair — it is a cost the player chooses to pay or not. A pit is not a surprise — it is a clear absence of ground that any paying-attention player sees coming.

Wizrless hazards should never feel like traps. They should feel like rules. Rules the player learns, internalizes, and eventually ignores because they have mastered them.

## Detailed Design

### Hazard Taxonomy

Three types. All extend `Area2D`.

| Type | Script | Scene | Behavior | Damage |
|------|--------|-------|----------|--------|
| GroundSpike | `scripts/hazards/ground_spike.gd` | `scenes/hazards/ground_spike.tscn` | Timed: appear → active → retract → despawn | `DAMAGE = 20` on `body_entered` during active window |
| DamageZone | `scripts/hazards/damage_zone.gd` | `scenes/hazards/damage_zone.tscn` | Persistent: always active, damages on enter + optional tick | Configurable via `@export` |
| KillZone | `scripts/hazards/kill_zone.gd` | `scenes/hazards/kill_zone.tscn` | Persistent: instant-kill on contact (pit void, insta-death surfaces) | `GameManager.take_damage(MAX_INT)` → triggers death |

---

### Collision Architecture

All hazards share one layer/mask assignment.

```
collision_layer = 16   (bit 4 — "Hazard" layer)
collision_mask  = 2    (bit 1 — detects Player only)
```

No hazard touches enemies, terrain, or projectiles. The mask is intentionally minimal: hazards react to the player and nothing else.

---

### GroundSpike (existing — reference spec)

Lifecycle: `Appear → Active → Retract → queue_free()`

```
GroundSpike (Area2D)
├─ Visual (Sprite2D)           -- texture: spike_root.png, y-offset −26.5
└─ CollisionShape2D            -- RectangleShape2D 18×46 px, y-offset −23.0
```

**Timing phases:**

| Phase | Duration | Collision active? |
|-------|----------|------------------|
| Appear | `appear_time` (default 0.15 s) | No — spike rising |
| Active | `active_time` (default 1.2 s) | Yes — damages on enter |
| Retract | `retract_time` (default 0.15 s) | No — spike falling |

**Exported variables:**
```gdscript
@export var appear_time:  float = 0.15
@export var active_time:  float = 1.2
@export var retract_time: float = 0.15
```

Damage: `GameManager.take_damage(DAMAGE)` where `DAMAGE = 20` (class constant, not exported — change requires code edit or subclass).

One damage instance per overlap entry. Player standing on active spike and exiting then re-entering is hit again. No invulnerability frame handling in hazard code — that is the Health System's concern.

---

### DamageZone (new)

Persistent `Area2D`. Damages player on `body_entered`. Optionally ticks damage at interval while player stays inside.

```
DamageZone (Area2D)
└─ CollisionShape2D           -- shape set per-instance (rect, circle, polygon)
```

**Exported variables:**
```gdscript
@export var damage_on_enter:   int   = 5
@export var tick_damage:       int   = 0      # 0 = no tick
@export var tick_interval:     float = 1.0    # seconds between ticks
@export var visual_color:      Color = Color(1.0, 0.4, 0.0, 0.35)  # shown as modulated ColorRect child
```

**Behavior:**
- `body_entered`: if player → `GameManager.take_damage(damage_on_enter)`
- While player inside and `tick_damage > 0`: timer fires every `tick_interval` → `GameManager.take_damage(tick_damage)`
- `body_exited`: timer stops

Use cases: lava floor (enter + tick), cursed ground (enter only), acid pool (heavy tick).

---

### KillZone (new)

Instant-kill area. Pit floors, death voids, bottomless drops. Player enters → immediate death.

```
KillZone (Area2D)
└─ CollisionShape2D           -- shape covers pit opening or void area
```

No exported variables — behavior is fixed. On `body_entered`:
```gdscript
GameManager.take_damage(GameManager.max_health)
```

This reduces HP to 0 (or triggers death if Health System interprets floor-at-0 as death). KillZone does not call a bespoke "instant kill" API — it routes through the standard damage path so the Health System's death logic handles it identically.

**Note:** Debug invulnerability (`current_health = max(1, ...)` in GameManager) prevents KillZone from killing during development. This must be lifted before KillZone is testable for real.

---

### Static Hazard Placement Rules

All hazards placed manually as children of the room's `Hazards` node in the Godot scene editor.

```
Room (Node2D)
├─ TileMap
├─ Enemies (Node2D)
├─ Hazards (Node2D)         ← hazards placed here
│  ├─ GroundSpike           ← static placed — designer configures timing in inspector
│  ├─ DamageZone
│  └─ KillZone
└─ ...
```

**GroundSpike placed statically:** The spike triggers once on room load via its internal timer. For looping environmental spikes (geyser rhythm), the level designer places multiple spikes with staggered `appear_time` offsets and wraps them in a repeating trigger. MVP does not include a looping spike orchestrator — static one-shot placement only.

**No runtime spawner at MVP.** Hazard spawning from scripts is boss-exclusive (ground_spikes_state.gd). Environmental designers place all static hazards in the scene editor.

---

### Damage Routing

All hazards share one damage call path:

```
Hazard (body_entered)
  → GameManager.take_damage(amount)
    → current_health -= amount  (clamped, signals emitted)
    → health_changed.emit(current, max)   → HUD update
    → player_took_damage.emit()           → player SFX
  → DamageNumber.spawn(parent, amount, position, color)
```

Hazard responsibility ends at `take_damage()`. Knockback, invincibility frames, death — all owned by Health System and player scripts.

---

### Visual Feedback Contract

Each hazard type must provide a visible cue before it can harm the player.

| Hazard | Cue | Minimum warning time |
|--------|-----|---------------------|
| GroundSpike | Sprite rising from ground during `appear_time` | 0.15 s (tunable) |
| DamageZone | Semi-transparent tinted `ColorRect` overlay | Always visible |
| KillZone | No floor tile — visual void | Always visible |

DamageZone renders a modulated `ColorRect` as a visual child. Color defaults to `Color(1, 0.4, 0, 0.35)` — orange-translucent. Level designers can override `visual_color` per zone. KillZone has no visual script — the art (absent tilemap tiles) is the cue.

## Formulas

### GroundSpike Total Cycle Time

```
T_cycle = appear_time + active_time + retract_time

Default: 0.15 + 1.2 + 0.15 = 1.5 s
```

Spike despawns at T_cycle. One-shot: no repeat.

### Reaction Window

```
reaction_window = appear_time

Default: 0.15 s
```

Minimum recommended: 0.10 s (1–2 frames at 60fps). Below 0.10 s: no reasonable reaction time — invalid for player-placed environmental spikes (acceptable for boss-scripted attacks where animation telegraphs the wave).

### DamageZone Total Damage (player stays full duration)

```
D_total = damage_on_enter + floor(T_stay / tick_interval) × tick_damage

Example (lava floor, stay 3 s, tick_damage=5, tick_interval=1.0):
  D_total = 5 + floor(3 / 1.0) × 5 = 5 + 15 = 20
```

### Hit Budget per Hazard Contact (design guideline)

```
Player max HP = 100 (reference — Health System GDD owns this)
GroundSpike:  20 / 100 = 20% per hit → 5 hits to die
DamageZone:    5 enter + ticking → zone controls pressure, not burst
KillZone:    100% — instant
```

### Variable Definitions

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `appear_time` | float | 0.15 s | GroundSpike rise duration |
| `active_time` | float | 1.2 s | GroundSpike damage window |
| `retract_time` | float | 0.15 s | GroundSpike retract duration |
| `DAMAGE` | int | 20 | GroundSpike damage constant |
| `damage_on_enter` | int | 5 | DamageZone entry damage |
| `tick_damage` | int | 0 | DamageZone per-tick damage (0 = off) |
| `tick_interval` | float | 1.0 s | DamageZone tick period |
| `visual_color` | Color | orange 35% | DamageZone overlay tint |

## Edge Cases

**EC-01 — Player enters DamageZone then immediately dashes out.**
`body_entered` fires → `damage_on_enter` applied. `body_exited` fires → tick timer stops. Player takes entry hit only. Correct.

**EC-02 — Player enters DamageZone, GroundSpike rises through it.**
GroundSpike and DamageZone are independent Area2Ds. Both fire `body_entered` for the player simultaneously. Player takes both hits. Design should avoid overlapping hazard types unless intentional.

**EC-03 — Player killed by GroundSpike mid-appear phase.**
Collision shape is monitoring=false during appear/retract phases (guarded by `_set_monitoring(false)` in those tweens). Body_entered cannot fire. No false kill during windup.

**EC-04 — KillZone fires during debug invulnerability.**
`GameManager.take_damage(max_health)` still reduces HP to 1 (debug floor). Player doesn't die. **Known limitation during dev.** Remove debug floor before shipping.

**EC-05 — Player respawns inside a DamageZone.**
Respawn position is set by Checkpoint System. Level designer responsibility: checkpoint positions must not overlap DamageZones. No engine-level guard — document constraint for level design.

**EC-06 — GroundSpike collision shape active after retract.**
Tween callback disables `CollisionShape2D.disabled = true` before retract tween starts. `body_entered` cannot fire during retract or after. Verified by: confirm monitoring=false flag timing in script.

**EC-07 — Multiple DamageZones stacked (same area).**
Each Area2D fires independently. Player takes `damage_on_enter` from each zone. Stacking zones amplifies damage. Valid level design pattern (double-hazard gauntlet). Not a bug.

**EC-08 — DamageZone tick fires on the frame player is killed.**
Health System may set `is_dead = true` before tick fires. `GameManager.take_damage()` should guard `if is_dead: return` to prevent post-death damage events. **Constraint on Health System** — not Hazard System's responsibility to check.

**EC-09 — GroundSpike placed by boss attack enters a room with no terrain below.**
`_detect_floor_y()` raycast finds nothing → falls back to `y = 350.0`. Spike spawns at fallback position. In most rooms this is off-screen — harmless. In pathological cases (infinite void), spike spawns invisible. Acceptable edge case for boss arena design.

**EC-10 — KillZone has wrong collision shape size (too small for pit).**
Player falls through without triggering. Level design authoring error — no runtime guard. Document minimum KillZone width rule: cover full pit opening + 8 px margin on each side.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Health System** | Sends to | `GameManager.take_damage(amount)` — Hazard System's only output. Health System owns what happens after. |
| **Zone/Room System** | Owned by | All hazards live under room's `Hazards` node. Room unload destroys all hazards. Boss-spawned spikes added to level root, not room node. |
| **Checkpoint/Respawn System** | Constraint | Checkpoint positions must not overlap DamageZones (EC-05). No code dependency — design constraint only. |
| **Boss System** | Consumer | Boss attack states instantiate `GroundSpike` scenes and override timing. Boss System depends on this GDD's spec for valid exported variable names. |
| **Camera System** | None | Camera shake during boss spike wave is owned by boss attack state, not Hazard System. |

**Reverse dependencies (systems that depend on this GDD):**
- Boss System uses `GroundSpike` scene as attack primitive.
- Level designers author room layouts referencing hazard type specs here.

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `appear_time` | 0.15 s | 0.10–1.0 s | Reaction window before spike is deadly. Below 0.10: unreactionable (boss use only). Above 1.0: predictable but slow-paced. |
| `active_time` | 1.2 s | 0.3–3.0 s | How long spike threatens. Below 0.3: barely a threat. Above 3.0: spike dominates room for too long. |
| `retract_time` | 0.15 s | 0.05–0.5 s | Cosmetic — affects rhythm feel, not gameplay threat. |
| `DAMAGE` (GroundSpike) | 20 | 10–40 | 20 = 1/5 of HP. 10 = minor chip. 40 = punishing. Scale with zone difficulty. |
| `damage_on_enter` | 5 | 1–30 | DamageZone entry burst. 5 = minor entry tax. 30 = strong entry deterrent. |
| `tick_damage` | 0 | 0–10 | Per-tick DamageZone punishment. 0 = no tick. 10/s drains 100% HP in 10 s — extremely punishing. |
| `tick_interval` | 1.0 s | 0.5–3.0 s | DamageZone tick frequency. 0.5 = aggressive. 3.0 = almost unnoticeable. Pair with `tick_damage` to set pressure. |
| `visual_color` | Orange 35% | Any | DamageZone visual hint. Alpha must stay 25–50%: readable but not obscuring. |

## Acceptance Criteria

**AC-01 — GroundSpike lifecycle.**
Static GroundSpike placed in room: on room load, spike rises (`appear_time`), stays active (`active_time`), retracts (`retract_time`), then `queue_free()`. Sprite animates through all three phases. Verified by: place spike in room, observe full cycle.

**AC-02 — GroundSpike damages player in active window only.**
Player standing on spike during active window takes 20 damage (damage number appears, health bar decreases). Player standing on rising or retracting spike takes no damage. Verified by: step on spike at each phase.

**AC-03 — DamageZone entry damage.**
Player entering DamageZone (tick_damage=0) takes `damage_on_enter` once. Exiting and re-entering takes it again. Timer does not run. Verified by: enter, exit, re-enter zone.

**AC-04 — DamageZone tick damage.**
Player inside DamageZone with `tick_damage=5`, `tick_interval=1.0` takes 5 damage on entry + 5 damage each second while inside. Exiting stops the tick. Verified by: enter zone, observe damage log over 3 seconds.

**AC-05 — KillZone instant kill.**
Player entering KillZone loses all HP and triggers death sequence. Debug invulnerability must be disabled for this test. Verified by: disable HP floor in GameManager, walk into KillZone, confirm death.

**AC-06 — Collision layer isolation.**
Hazard Area2D does not fire `body_entered` for enemies, projectiles, or terrain bodies — only the player. Verified by: enemy pathfinding through hazard zone causes no hazard events.

**AC-07 — GroundSpike no collision during windup/retract.**
`CollisionShape2D.disabled = true` during appear and retract phases. Confirmed by: step on spike during first 0.15 s and last 0.15 s — no damage taken. `monitoring = false` guard verified in script.

**AC-08 — Boss-spawned GroundSpike with overridden timing.**
`ground_spikes_state.gd` spawns GroundSpike with `appear_time = WAVE_T`, `active_time = WAVE_T`, `retract_time = WAVE_T`. Spike behaves with overridden timing — fast cycle matching boss attack rhythm. Verified by: observe boss spike wave in Devium fight.

**AC-09 — Room unload destroys static hazards.**
Room `queue_free()` destroys all children including `Hazards` node and all child hazards. No dangling Area2D nodes after room unload. Verified by: transition rooms, confirm no orphan nodes in scene tree.

**AC-10 — DamageZone visual overlay present.**
Every DamageZone scene instance renders a semi-transparent `ColorRect` child matching `visual_color` and covering the collision shape bounds. No DamageZone is invisible to the player. Verified by: inspect all DamageZone placements in room1 and test room.
