# Boss System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-04
> **Implements Pillar**: Earned Truth (primary), Spell Alchemy (arena), Controlled Ascension (milestone gate)

## Overview

The Boss System is the framework for all boss encounters in Wizrless. It defines the standard structure every boss follows: a **combat barrier** that seals the room, an **intro sequence** (pre-fight dialogue → trigger → fight start), a **phase architecture** (health-threshold state transitions), a **weighted attack pool**, and a **defeat sequence** (death animation → signal chain → barrier down → world state persisted).

At MVP, one boss exists: **Devium** — an ice-element wizard-turned-sentinel who is the first major gate on the Controlled Ascension path. Devium is the reference implementation. The system is designed for 7 total bosses without re-engineering: each boss extends `BaseEnemy`, fills a `BossConfig` resource, and implements its own LimboHSM states.

Every boss in Wizrless is a person. The Earned Truth pillar requires that the player understand something about who that person was before the fight ends. The Boss System owns the structures that deliver this: the dialogue sequence that runs before combat locks, and the death moment that resolves it. Mechanics are not separate from story — they are the story. A boss that burns you teaches you what fire costs the one who wields it.

**System responsibilities:**
- `BossConfig` resource: data-driven per-boss configuration (HP, phases, attack pool, dialogue key)
- Combat barrier: `CombatBarrier` node that seals the room on intro trigger, lifts on defeat
- Intro sequence: dialogue plays first, then fight-lock trigger, then combat begins
- Phase transitions: ANYSTATE dispatch on HP threshold, configurable per boss
- Attack selection: weighted random pool with no-repeat-last rule, distance bias optional
- Defeat sequence: death animation → `GameManager.boss_defeated` → barrier removal → save flag
- Persistence: defeated boss rooms remain clear across sessions

**Out of scope:** individual boss art, animations, attack projectile scenes, and boss-specific dialogue content — those are art/narrative deliverables. This GDD specifies the code contracts those assets plug into.

## Player Fantasy

Every boss fight is a sentence that began in the dialogue before it.

The player walks into the room knowing something — a name, a fragment, a wrong the wizard cannot yet articulate. The barrier closes. There is no backing out. The boss is not a health pool to drain; it is a question being asked in the language of attack patterns. The player does not read the answer. They live it.

Phase 2 should feel like revelation, not escalation. The boss is not getting harder — the player is seeing something that was hidden. The music shifts. The pattern changes. The wizard realizes he did not know what he was fighting until just now.

When a boss dies, the room should hold the moment. Not long — the wizard is not sentimental. But long enough that the player feels the weight of what just ended. The barrier lifts. The reward drops. The path opens. Something that was in the way is no longer in the way, and the wizard is changed by having removed it.

**The mechanics must serve this:** attack patterns that are learnable, not random. Phase transitions that signal new information, not just harder numbers. A fight that feels authored — someone designed the specific combination of spells and movement that defeats this specific person.

## Detailed Design

### Data Resources

Three nested resource types define a boss entirely in data. No per-boss code needed except LimboHSM state scripts.

```gdscript
# resources/bosses/boss_attack_config.gd
class_name BossAttackConfig
extends Resource

@export var attack_id:              StringName  # &"atk_ice_ball"
@export var state_name:             StringName  # LimboState node name on boss HSM
@export var weight:                 float = 1.0
@export var preferred_dist_min:     float = 0.0    # prefer this attack when dist >= min
@export var preferred_dist_max:     float = 9999.0 # prefer this attack when dist <= max
@export var preference_weight_mult: float = 1.5    # weight multiplier when in preferred range
```

```gdscript
# resources/bosses/boss_phase_config.gd
class_name BossPhaseConfig
extends Resource

@export var phase_id:              StringName          # &"phase1", &"phase2"
@export var health_threshold:      float = 1.0         # 1.0 = phase starts at full HP
@export var attack_pool:           Array[BossAttackConfig]
@export var transition_animation:  StringName = &""    # played on phase enter; empty = none
@export var music_layer:           int = 0             # audio layer to activate (0 = no change)
```

```gdscript
# resources/bosses/boss_config.gd
class_name BossConfig
extends Resource

@export var boss_id:            StringName   # &"devium"
@export var display_name:       String       # "Devium"
@export var max_health:         int          # 200
@export var intro_dialogue_key: StringName   # key into DialogueManager
@export var death_dialogue_key: StringName   # optional — post-defeat moment
@export var element:            SpellElement # boss elemental theme
@export var drop_material:      StringName   # &"frost"
@export var drop_amount:        int          # 8
@export var phases:             Array[BossPhaseConfig]  # ordered by threshold descending
```

---

### BaseBoss Class

Sits between `BaseEnemy` and all individual boss scripts. Provides phase management, attack selection, signal emissions, and defeat flow.

```gdscript
# scripts/bosses/base_boss.gd
class_name BaseBoss
extends BaseEnemy

@export var config: BossConfig

var current_phase_index: int = 0
var last_attack_id:      StringName = &""

@onready var _barrier: CombatBarrier = get_node("../CombatBarrier")

func _ready() -> void:
    if GameManager.is_boss_defeated(config.boss_id):
        queue_free()
        get_node_or_null("../BossTrigger")?.queue_free()
        return
    health = config.max_health
    max_health = config.max_health
    super()
    GameManager.boss_appeared.emit(config.boss_id, config.display_name, config.max_health)

func take_damage(amount: int, element: StringName = &"") -> void:
    super(amount, element)
    GameManager.boss_health_changed.emit(health, config.max_health)
    _check_phase_transition()

func _check_phase_transition() -> void:
    var ratio := float(health) / float(config.max_health)
    for i in range(current_phase_index + 1, config.phases.size()):
        if ratio <= config.phases[i].health_threshold:
            current_phase_index = i
            _hsm.dispatch(&"phase_transition")
            break

func select_attack() -> BossAttackConfig:
    var pool := config.phases[current_phase_index].attack_pool
    var dist  := global_position.distance_to(player.global_position)
    var candidates: Array[Dictionary] = []
    for atk: BossAttackConfig in pool:
        if atk.attack_id == last_attack_id: continue
        var w := atk.weight
        if dist >= atk.preferred_dist_min and dist <= atk.preferred_dist_max:
            w *= atk.preference_weight_mult
        candidates.append({ "atk": atk, "weight": w })
    if candidates.is_empty(): candidates = [{"atk": pool[0], "weight": 1.0}]
    var total := candidates.reduce(func(acc, c): return acc + c["weight"], 0.0)
    var roll  := randf() * total
    var sum   := 0.0
    for c in candidates:
        sum += c["weight"]
        if roll <= sum:
            last_attack_id = c["atk"].attack_id
            return c["atk"]
    return pool[0]

func die() -> void:
    GameManager.boss_defeated.emit(config.boss_id)
    GameManager.save_boss_defeated(config.boss_id)
    _barrier.deactivate()
    _spawn_material_drop()
    await get_tree().create_timer(1.5).timeout
    super()

func _spawn_material_drop() -> void:
    if config.drop_material == &"": return
    var drop := MATERIAL_DROP_SCENE.instantiate()
    drop.material_type = config.drop_material
    drop.amount        = config.drop_amount
    drop.global_position = global_position + Vector2(0, -16)
    get_level().add_child(drop)
```

---

### Combat Barrier

`CombatBarrier` is a shared scene placed in every boss room by level designers.

```
CombatBarrier (Node2D)
├─ LeftBarrier  (StaticBody2D)
│   ├─ CollisionShape2D   -- collision_layer: 1 (player) | 3 (enemy projectiles)
│   └─ Sprite2D           -- rune-wall visual
└─ RightBarrier (StaticBody2D)
    ├─ CollisionShape2D
    └─ Sprite2D
```

```gdscript
# scripts/bosses/combat_barrier.gd
func activate() -> void:
    LeftBarrier.show()
    RightBarrier.show()
    LeftBarrier.get_child(0).disabled = false   # CollisionShape2D
    RightBarrier.get_child(0).disabled = false

func deactivate() -> void:
    # fade out over 0.5s then disable collision
    var tween := create_tween()
    tween.tween_property(LeftBarrier,  "modulate:a", 0.0, 0.5)
    tween.parallel().tween_property(RightBarrier, "modulate:a", 0.0, 0.5)
    await tween.finished
    LeftBarrier.get_child(0).disabled  = true
    RightBarrier.get_child(0).disabled = true
```

Barrier is invisible until activated (hidden, collision disabled). On `activate()`: visible + collision on. On `deactivate()`: fade out + collision off.

---

### Intro Sequence

`BossTrigger` is an Area2D placed near the room entrance, sized to span the approach corridor.

```gdscript
# scripts/bosses/boss_trigger.gd
var _fired: bool = false

func _on_body_entered(body: Node2D) -> void:
    if _fired: return
    if not body.is_in_group(&"player"): return
    _fired = true
    _run_intro()

func _run_intro() -> void:
    # 1. Play intro dialogue (non-blocking — DialogueManager handles flow)
    DialogueManager.start(boss_node.config.intro_dialogue_key)
    await DialogueManager.dialogue_finished
    # 2. Seal the room
    combat_barrier.activate()
    # 3. Start the fight
    boss_node._hsm.dispatch(&"fight_start")
    queue_free()   # one-shot
```

`BossTrigger` holds references to `boss_node` and `combat_barrier` as `@export NodePath` fields — wired by level designer in the inspector.

If boss already defeated: `BossTrigger._ready()` calls `queue_free()` immediately (boss `_ready()` also frees it, but the double-free guard on `queue_free()` prevents crashes).

---

### Phase Architecture

`config.phases` array ordered by descending threshold:

```
phases[0]: health_threshold = 1.0   → Phase 1 (always starts here)
phases[1]: health_threshold = 0.6   → Phase 2 (triggers at ≤60% HP)
```

`PhaseTransitionState` is a shared state on all boss HSMs:

```gdscript
# scripts/bosses/states/phase_transition_state.gd
func _enter() -> void:
    _e.set_invincible(true)    # i-frames during transition
    var phase := _e.config.phases[_e.current_phase_index]
    if phase.transition_animation != &"":
        _e.anim.play(phase.transition_animation)
        await _e.anim.animation_finished
    if phase.music_layer > 0:
        AudioManager.activate_layer(phase.music_layer)
    _e.set_invincible(false)
    _hsm.dispatch(&"fight_resume")
```

`BaseBoss.set_invincible(bool)` sets a flag checked at the top of `take_damage()` — projectiles pass through harmlessly during transition.

---

### LimboHSM Fight Loop

All bosses share this HSM structure. States are implemented per-boss.

```
IdleState
  ↓  fight_start
LevitateState  ←──────────────────────────────┐
  │  (each loop iteration)                    │
  └→ select_attack()                          │
  └→ dispatch(selected.state_name)            │
     ↓                                        │
AttackState(N)                                │
  │  windup animation                         │
  │  fire / spawn at cast moment              │
  └→ end_attack ────────────────────────────→ ┘

[ANYSTATE] phase_transition → PhaseTransitionState → fight_resume → LevitateState
[ANYSTATE] die              → DeathState
```

`LevitateState` is the idle-between-attacks state. It does not idle forever — it calls `select_attack()` immediately and dispatches. The pause between attacks is an `@export var cooldown: float = 1.2` timer inside LevitateState.

---

### Devium — Reference Implementation

**BossConfig (devium.tres):**

| Field | Value |
|-------|-------|
| `boss_id` | `&"devium"` |
| `display_name` | `"Devium"` |
| `max_health` | `200` |
| `intro_dialogue_key` | `&"devium_intro"` |
| `death_dialogue_key` | `&"devium_death"` |
| `element` | `ICE` |
| `drop_material` | `&"frost"` |
| `drop_amount` | `8` |

**Phase 1 attack pool (threshold 1.0):**

| Attack ID | State Name | Weight | Preferred Range |
|-----------|-----------|--------|-----------------|
| `atk_ice_ball` | `IceBallState` | 1.0 | dist > 200 px (mult 1.5) |
| `atk_ice_rocks` | `IceRocksState` | 1.0 | dist < 150 px (mult 1.5) |

**Phase 2 attack pool (threshold 0.6 = ≤120 HP):**

| Attack ID | State Name | Weight | Preferred Range |
|-----------|-----------|--------|-----------------|
| `atk_ice_ball` | `IceBallState` | 0.8 | dist > 200 px (mult 1.5) |
| `atk_ice_rocks` | `IceRocksState` | 0.8 | dist < 150 px (mult 1.5) |
| `atk_ground_spikes` | `GroundSpikesState` | 1.2 | dist < 180 px (mult 1.3) |
| `atk_parabolic_spread` | `ParabolicSpreadState` | 1.0 | dist > 180 px (mult 1.3) |

**Devium scene structure:**

```
Devium (CharacterBody2D, class_name Devium, extends BaseBoss)
├─ AnimatedSprite2D
├─ Hitbox (Area2D + CollisionShape2D)
├─ BurnIndicator (Node2D)       -- flame sprite, shown when BURNING status active
├─ LimboHSM
│   ├─ IdleState
│   ├─ LevitateState
│   ├─ IceBallState
│   ├─ IceRocksState
│   ├─ GroundSpikesState
│   ├─ ParabolicSpreadState
│   ├─ PhaseTransitionState
│   └─ DeathState
└─ @export config: BossConfig   -- devium.tres
```

**Attack behavior summaries:**

| Attack | Wind-up | Behavior |
|--------|---------|----------|
| `IceBallState` | 0.6s | Fire single parabolic ice projectile toward player position at cast moment. Uses parabolic formula from Enemy AI GDD. |
| `IceRocksState` | 0.4s | Spawn 3 ice shards in ±15° spread. Each straight-line, medium speed. |
| `GroundSpikesState` | 0.5s | Ground spike sequence across arena floor, left-to-right, 0.15s between columns. Player must jump. |
| `ParabolicSpreadState` | 0.7s | Fire 5 parabolic projectiles simultaneously in spread angles. Phase 2 pressure attack. |

**Burn mechanic migration:** Devium's legacy `_fire_marked` / `_burn_timer` code removed. `BaseBoss.take_damage()` routes through `SpellInteractionEngine.process_hit()`. BURNING status visual driven by `SpellInteractionEngine.status_applied` signal → `BurnIndicator.show()`.

---

### GameManager Additions

```gdscript
signal boss_appeared(boss_id: StringName, display_name: String, max_health: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_defeated(boss_id: StringName)

var defeated_bosses: Dictionary = {}

func save_boss_defeated(id: StringName) -> void:
    defeated_bosses[id] = true

func is_boss_defeated(id: StringName) -> bool:
    return defeated_bosses.get(id, false)
```

**Save schema (key `"bosses"`):**

```json
{
  "bosses": {
    "defeated_bosses": { "devium": true }
  }
}
```

## Formulas

### Phase Transition Threshold

```
phase_triggers = true when:
  float(health) / float(config.max_health) <= phase.health_threshold

Devium Phase 2:
  threshold = 0.6
  trigger_hp = floor(200 × 0.6) = 120
  triggers at first hit that brings health to ≤ 120
```

### Attack Selection — Weighted Random

```
-- For each attack in pool (excluding last_used):
effective_weight(atk, dist) =
  if preferred_dist_min <= dist <= preferred_dist_max:
    atk.weight × atk.preference_weight_mult
  else:
    atk.weight

total_weight = sum(effective_weight for all candidates)
roll = randf() × total_weight

-- Walk candidates until cumulative weight >= roll → selected

-- Devium Phase 1 example at dist = 250 px (far):
  atk_ice_ball:  1.0 × 1.5 = 1.5  (in preferred range: dist > 200)
  atk_ice_rocks: 1.0        = 1.0  (not in preferred range)
  total = 2.5
  P(ice_ball)  = 1.5 / 2.5 = 60%
  P(ice_rocks) = 1.0 / 2.5 = 40%

-- Devium Phase 1 at dist = 80 px (close):
  atk_ice_ball:  1.0        = 1.0  (not preferred)
  atk_ice_rocks: 1.0 × 1.5 = 1.5  (in preferred range: dist < 150)
  total = 2.5
  P(ice_ball)  = 1.0 / 2.5 = 40%
  P(ice_rocks) = 1.5 / 2.5 = 60%
```

### No-Repeat Last Attack

```
-- Effective pool = full pool − { last_attack_id }
-- If pool has only 1 attack: candidates.is_empty() → fallback to pool[0]
-- No attack can repeat twice in a row; distribution across ≥2 attacks always guaranteed
```

### Parabolic Projectile (IceBall, ParabolicSpread)

```
-- From Enemy AI GDD:
dx = player.x - devium.x
dy = player.y - devium.y  (positive = down in Godot)

T  = max(|dx| / PB_H_SPEED, PB_MIN_TIME)
   = max(|dx| / 130, 0.5)

vx = dx / T
vy = (dy - 0.5 × PB_GRAVITY × T²) / T
   where PB_GRAVITY = 400 px/s²

direction = Vector2(vx, vy).normalized()
speed     = PB_BASE_SPEED = 200.0 px/s

-- ParabolicSpread (5 projectiles):
angles = [-30°, -15°, 0°, +15°, +30°] relative to base direction
each projectile fires with rotated direction at PB_BASE_SPEED
```

### Ground Spike Timing

```
spike_columns        = N  (set by level designer per room width)
spike_interval       = 0.15s between columns
total_spike_duration = N × 0.15s

-- At arena width 320px, tile size 16px → 20 columns:
total_duration = 20 × 0.15 = 3.0s

-- Player must jump within spike_interval window per column:
reaction_window = 0.15s
-- Designed to be readable: spikes sequence left-to-right predictably
```

### Fight Duration Estimate (Devium)

```
-- Player dealing 10 HP/hit at 1.5s cooldown:
hits_to_kill = ceil(200 / 10) = 20 hits
min_fight_time = 20 × 1.5 = 30s (sustained perfect play, no mana issues)

-- Realistic: mana cycles reduce cast rate to ~13.7 casts/min (Spell System GDD)
realistic_hits_per_minute = 13.7
realistic_fight_duration  = 20 / (13.7/60) ≈ 87s ≈ 1.5 min

-- Phase 2 triggers after:
  P1_damage_needed = 200 - 120 = 80 HP
  P1_hits = ceil(80 / 10) = 8 hits minimum
  P1_min_time = 8 × 1.5 = 12s
```

### Minimum Survivable Player HP (Boss Design Target)

```
-- Boss should not one-shot player from full HP (100)
-- Max single-attack damage must be < 100

Devium IceBall damage target: 25 HP (25% of max)
Devium IceRocks per-shard:    12 HP (3 shards = 36 HP if all hit — high pressure, not instant death)
Devium GroundSpike per hit:   20 HP (player should dodge, not tank)
Devium ParabolicSpread:       15 HP per projectile (5 proj = 75 HP max — requires dodge)
```

### Variable Definitions

| Variable | Value | Description |
|----------|-------|-------------|
| `PHASE2_THRESHOLD` | 0.6 | Devium phase 2 HP ratio trigger |
| `max_health` (Devium) | 200 | Devium total HP |
| `levitate_cooldown` | 1.2s | Pause between attacks in LevitateState |
| `invincibility_duration` | 0.8s | i-frames during phase transition |
| `barrier_fade_duration` | 0.5s | CombatBarrier deactivate fade time |
| `death_pause_duration` | 1.5s | Wait after die() before queue_free() |
| `PB_H_SPEED` | 130 px/s | Parabolic projectile horizontal component |
| `PB_MIN_TIME` | 0.5s | Minimum flight time for parabolic arc |
| `PB_GRAVITY` | 400 px/s² | Parabolic arc gravity constant |
| `PB_BASE_SPEED` | 200 px/s | Parabolic projectile speed magnitude |
| `spike_interval` | 0.15s | Ground spike column timing |
| IceBall damage | 25 HP | Single parabolic projectile damage |
| IceRocks damage | 12 HP | Per-shard damage (3 shards) |
| GroundSpike damage | 20 HP | Per spike column hit |
| ParabolicSpread damage | 15 HP | Per projectile (5 total) |

## Edge Cases

**EC-01 — Player enters boss room after boss already defeated.**
`BaseBoss._ready()` checks `GameManager.is_boss_defeated(config.boss_id)`. Returns true → `queue_free()` boss + `queue_free()` BossTrigger. Room is traversable. No barrier, no fight, no dialogue. Correct.

**EC-02 — Player dies mid-fight.**
`GameManager.player_died` fires. Boss does not reset health or position — it continues the fight loop in the now-empty room. On respawn, player re-enters from checkpoint outside the boss room. BossTrigger already fired and freed itself. Player re-enters through the barrier. **Barrier must deactivate on `player_died` to allow re-entry.** CombatBarrier connects to `GameManager.player_died` and calls `deactivate()`. Boss health is NOT reset — fight resumes from current state.

**EC-03 — Player dies during phase transition (i-frames active).**
`player_died` fires. Barrier deactivates (EC-02 rule). Phase transition completes or is interrupted depending on timing. Boss is not reset. On player re-entry, boss is already in Phase 2 if transition completed. If transition was mid-way: `PhaseTransitionState` checks `player == null` each tick and idles safely.

**EC-04 — Phase transition dispatch fires while boss is already in PhaseTransitionState.**
`_check_phase_transition()` called from `take_damage()`. If player somehow deals damage during i-frames (bug or edge case), `current_phase_index` may already match the threshold. Guard: `_check_phase_transition()` only increments `current_phase_index` — if already at max index, loop finds nothing, no dispatch. No double-transition.

**EC-05 — Attack pool has only one attack (single-attack boss design or P1 fallback).**
`select_attack()` excludes `last_attack_id` — candidates becomes empty. Guard: `if candidates.is_empty(): candidates = [{"atk": pool[0], "weight": 1.0}]`. Same attack repeats. No crash. Acceptable for a single-attack boss; in practice all bosses have ≥2 attacks per phase.

**EC-06 — BossTrigger fires while dialogue is already playing (another dialogue active).**
`DialogueManager.start()` called while in dialogue. Dialogue System GDD defines behavior: new dialogue interrupts current, or queues — depending on DialogueManager implementation. Boss trigger dialogue is high-priority: it should interrupt. Mark `intro_dialogue_key` as `priority = true` in the DialogueManager call.

**EC-07 — Player kills boss during intro dialogue (debug/exploit).**
Boss is in IdleState during dialogue — not yet dispatched to fight. `take_damage()` still works on BaseBoss (not blocked during idle). If health reaches 0: `&"die"` dispatches. DeathState fires. `die()` emits `boss_defeated`, barrier was never activated → `deactivate()` on inactive barrier is a no-op. Save flag written. Correct outcome: boss dead, room clear.

**EC-08 — CombatBarrier `deactivate()` called when barrier already inactive.**
`deactivate()` runs tween on already-transparent/disabled nodes. No crash — tween on `modulate:a = 0.0` on a hidden node is harmless. Collision already disabled: `disabled = true` on already-disabled shape is a no-op. Idempotent.

**EC-09 — Boss projectile still in flight when boss dies.**
Projectiles added to level root (same rule as all enemy projectiles — EC-10 from Enemy AI GDD). They persist after boss `queue_free()`. They continue and can hit player. This is correct — the attack was committed. Projectiles have their own `LifeTimer` and self-destruct.

**EC-10 — `config` is null (BossConfig not assigned in inspector).**
`BaseBoss._ready()` will null-reference on `config.boss_id`. Guard: `assert(config != null, "BaseBoss: BossConfig not assigned on " + name)`. Fail loud in dev. No silent runtime crash in shipped build.

**EC-11 — Phase 2 triggers on same hit that kills Devium.**
`take_damage()` order: (1) reduce health, (2) `boss_health_changed`, (3) `_check_phase_transition()`, (4) check `health == 0` → dispatch `&"die"`. If health hits 0 and ratio ≤ 0.6 simultaneously: `_check_phase_transition()` dispatches `&"phase_transition"` AND then `die` is dispatched. ANYSTATE `die` transition overrides `phase_transition` — death wins. Boss dies, no phase transition plays. Correct.

**EC-12 — Ground spike sequence still running when boss enters DeathState.**
`GroundSpikesState._exit()` must call `_stop_spike_sequence()` to cancel the remaining spike timer. `DeathState` cannot interrupt mid-sequence without cleanup. Rule: all attack states implement `_exit()` that cancels any in-flight timers or deferred spawns.

**EC-13 — Second boss room entered before first boss defeated.**
Two bosses cannot be simultaneously in fight — game is linear at MVP. If somehow reached: each boss manages its own `CombatBarrier` and `BossTrigger`. Two simultaneous `boss_appeared` signals emit — HUD shows last-received boss bar. Not a supported scenario at MVP; linear zone design prevents this.

**EC-14 — `save_boss_defeated()` called but save not yet committed (player dies before checkpoint).**
`defeated_bosses` dictionary updated in memory. If player dies and checkpoint save rolls back: boss defeat flag exists in memory but not on disk. On reload from checkpoint, boss is alive again (disk state). Flag in memory is stale. **Rule**: boss defeat must trigger an immediate auto-save, not rely on checkpoint. `die()` calls `GameManager.save_game()` after `save_boss_defeated()`. Boss defeat is always persisted immediately.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Enemy Base System** | Extends | `BaseBoss extends BaseEnemy` — `take_damage()`, `die()`, `is_dead`, `health`, `player`, `face_player()`, `died` signal |
| **Enemy AI System** | Pattern | LimboHSM architecture; parabolic projectile formula; attack state pattern |
| **Spell Interaction Engine** | Receives | `process_hit()` replaces legacy Devium burn logic; all boss `take_damage()` routes through it |
| **Dialogue System** | Calls | `DialogueManager.start(intro_dialogue_key)`; `dialogue_finished` signal to unblock barrier activation |
| **Material System** | Sends to | `_spawn_material_drop()` instantiates `MaterialDrop` with `config.drop_material` and `config.drop_amount` |
| **Save/Load System** | Sends to | `defeated_bosses` registered under `"bosses"` key; `save_game()` called immediately on boss defeat |
| **Zone/Room System** | Hosted by | Boss scene lives in a room scene; room structure must include `CombatBarrier` and `BossTrigger` sibling nodes |
| **GameManager** | Reads + writes | `is_boss_defeated()`, `save_boss_defeated()`, `boss_appeared`, `boss_health_changed`, `boss_defeated`, `player_died` signals |

**Reverse dependencies:**

| System | What it needs from Boss System |
|--------|-------------------------------|
| **HUD System** | `boss_appeared`, `boss_health_changed`, `boss_defeated` signals — drives boss health bar |
| **Audio Feedback System** | `boss_appeared` — triggers boss music intro; `boss_defeated` — triggers defeat sting |
| **Boss Dialogue UI** | Boss defeat → optional `death_dialogue_key` post-fight dialogue display |
| **Spell Interaction Engine** | Boss fights are the primary arena for interaction discovery — boss design must include scenarios where interactions are rewarded |

**Hard blockers:**

- `BaseEnemy` class with `take_damage(amount, element)` signature (Spell Interaction Engine migration)
- `LimboHSM` addon active with ANYSTATE support
- `DialogueManager` autoload with `start()` / `dialogue_finished` interface (Dialogue System)
- `GameManager.player_died` signal (needed for barrier deactivation on death)
- `MaterialDrop` scene (Material System)

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `max_health` (Devium) | 200 | 120–300 | Fight length. Below 120: phase 2 barely plays before death. Above 300: attrition without drama. |
| `PHASE2_THRESHOLD` | 0.6 | 0.4–0.75 | Phase 2 entry point. 0.4: long phase 1, short climax. 0.75: phase 2 dominates most of the fight. |
| `levitate_cooldown` | 1.2s | 0.6–2.5s | Pacing between attacks. Below 0.6: relentless, no recovery window. Above 2.5: fight drags. |
| `invincibility_duration` | 0.8s | 0.3–1.5s | Phase transition i-frames. Below 0.3: player can skip transition with rapid fire. Above 1.5: long delay kills momentum. |
| IceBall damage | 25 HP | 15–35 HP | Single-projectile threat. Above 35 approaches one-shot from close range. |
| IceRocks per-shard | 12 HP | 8–20 HP | All 3 landing = 36 HP. Above 20/shard: all-3-hit kills from full HP — too punishing for a spread. |
| GroundSpike damage | 20 HP | 12–28 HP | Punishment for not jumping. Keep below 30 — failure tax, not instant death. |
| ParabolicSpread per-proj | 15 HP | 10–20 HP | 5 landing = 75 HP max. Cap at 20/proj — above that, all-5-hit exceeds player max HP. |
| `spike_interval` | 0.15s | 0.10–0.30s | Reaction window per spike column. Below 0.10: near-unreadable. Above 0.30: trivially easy. |
| P1 `atk_ice_ball` weight | 1.0 | 0.5–2.0 | Higher = more frequent long-range attacks in P1. |
| P2 `atk_ground_spikes` weight | 1.2 | 0.8–2.0 | Above 2.0: spikes dominate P2, fight becomes one-dimensional. |
| `preference_weight_mult` | 1.5 | 1.1–3.0 | Distance bias strength. At 3.0: boss nearly always uses preferred attack — becomes predictable. |
| `drop_amount` (Devium) | 8 | 5–15 | Frost Crystal reward. Calibrated against Material System budget (~20 total per type). |

## Acceptance Criteria

**AC-01 — Intro dialogue plays on room entry.**
Player walks into BossTrigger Area2D. Dialogue starts using `config.intro_dialogue_key`. Player cannot move or cast during dialogue. Verified by: enter boss room, confirm dialogue box opens.

**AC-02 — Barrier activates after dialogue ends.**
Intro dialogue completes. CombatBarrier `activate()` called. Left and right barrier walls become visible and solid. Player cannot exit through either side. Verified by: complete dialogue, attempt to walk through barrier, confirm blocked.

**AC-03 — Fight starts after barrier activates.**
Boss transitions from IdleState to LevitateState on `fight_start` dispatch. Devium begins attack cycle within `levitate_cooldown` seconds. Verified by: complete intro, confirm boss begins attacking.

**AC-04 — Boss health bar appears on fight start.**
`GameManager.boss_appeared` fires in `BaseBoss._ready()`. HUD boss health bar visible at full 200 HP. Verified by: enter boss room, confirm bar present.

**AC-05 — Boss health bar tracks damage.**
Deal 25 damage to Devium. Health bar decreases by 12.5% (25/200). `boss_health_changed` emitted with correct values. Verified by: hit Devium, confirm bar reduction.

**AC-06 — Attack pool selection excludes last attack.**
Observe 10 consecutive attack selections. No two identical attacks appear back-to-back. Verified by: log `last_attack_id` per LevitateState iteration, confirm no adjacent repeats.

**AC-07 — Distance bias works.**
Player stands > 200 px from Devium (Phase 1). Over 20 selections: `atk_ice_ball` chosen ≥ 55% of the time. Player stands < 150 px: `atk_ice_rocks` chosen ≥ 55% of the time. Verified by: logged selection counts at controlled distances.

**AC-08 — Phase 2 triggers at correct HP threshold.**
Devium at 121 HP — no transition. Next hit deals ≥2 damage. Phase transition fires: animation plays, Phase 2 attack pool active (GroundSpikes and ParabolicSpread available). Verified by: track HP, confirm trigger at exactly ≤120.

**AC-09 — Phase transition grants i-frames.**
During `PhaseTransitionState`: 10 projectiles hit Devium. HP unchanged. After transition: projectiles deal damage normally. Verified by: rapid-fire during transition, confirm no damage taken.

**AC-10 — Ground spikes fire left-to-right with correct interval.**
`GroundSpikesState` activated. Spike columns emerge left-to-right. Interval between columns ≈ 0.15s. Player jumping over each column avoids damage. Verified by: trigger attack, time interval, confirm jumpable.

**AC-11 — ParabolicSpread fires 5 projectiles.**
`ParabolicSpreadState` activated. Exactly 5 projectiles spawn in spread pattern at ±30° max. Each deals 15 damage on hit. Verified by: trigger attack, count projectiles in scene tree.

**AC-12 — Devium defeat sequence executes in order.**
Reduce Devium to 0 HP. Death animation plays (2–3s). After animation: `boss_defeated` fires → CombatBarrier fades → 8 Frost Crystal drops spawn → Devium freed after 1.5s. Verified by: kill Devium, confirm each step in sequence.

**AC-13 — Boss health bar disappears on defeat.**
`boss_defeated` fires. HUD boss health bar hides within one frame. Verified by: defeat Devium, confirm bar gone.

**AC-14 — Boss defeat persists across save/load.**
Defeat Devium. Auto-save triggers immediately. Quit. Reload. Re-enter boss room. Devium absent, BossTrigger absent, barrier absent. Room traversable. Verified by: defeat → quit → reload → re-enter.

**AC-15 — Barrier deactivates on player death.**
Player dies mid-fight. `player_died` fires. CombatBarrier deactivates within 0.5s. Player can re-enter boss room after respawn. Boss HP unchanged from when player died. Verified by: die mid-fight, respawn, re-enter, confirm HP state.

**AC-16 — No fight replay after defeat.**
Defeat Devium. Re-enter boss room. No dialogue triggers, no barrier activates, no boss present. Verified by: defeat, re-enter, confirm zero intro elements fire.

**AC-17 — Spell interactions work on boss.**
Hit Devium with Ice Shard (FROZEN applied). Follow with Fireball. Steam Burst fires: Devium takes `floor(fireball_base × 2.0)` damage. `interaction_triggered` emits. Verified by: freeze Devium, fire Fireball, confirm double damage via health change.

**AC-18 — Invincible flag scoped to phase transition only.**
`set_invincible(false)` confirmed after `PhaseTransitionState` exits. HP reduces correctly in all other states. Verified by: confirm damage lands in LevitateState and all attack states.
