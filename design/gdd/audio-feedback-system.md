# Audio Feedback System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-05
> **Implements Pillar**: Spell Alchemy (interaction audio payoff), Earned Truth (combat feel)

## Overview

The Audio Feedback System is the Presentation Layer system that maps game events to SFX calls. It is the context-aware layer between game state and the Audio System's stateless playback infrastructure.

It owns four categories of audio feedback:

1. **Interaction SFX** — sounds for the five MVP spell combo interactions (Steam Burst, Cryoblast, Extinguish, Amplify, Inferno). Triggered by `SpellInteractionEngine.interaction_triggered`.
2. **Status SFX** — brief audio cues when a status effect is applied or expires (FROZEN snap, BURNING crackle, MARKED sigil hum, SLOWED rush, STUNNED impact). Triggered by `SpellInteractionEngine.status_applied` and `status_expired`.
3. **Combat feedback SFX** — player hurt (GUARANTEED priority), player death (GUARANTEED), enemy death. Triggered by Health System and Enemy Base signals.
4. **Pitch variation** — randomizes `pitch_scale` on repeated SFX to prevent robotic repetition. Applied at call site, not in AudioSystem.

The system does **not** own: projectile launch/flight/impact SFX (those live in individual projectile scenes), music transitions (AudioSystem), UI/menu sounds (AudioSystem UI players), or mana-empty blocked-cast feedback (polish-layer, post-MVP).

**Architecture:** `AudioFeedbackSystem` is a singleton autoload. It subscribes to signals in `_ready()` and routes each to `AudioSystem.play_sfx()` with the appropriate stream, priority, and pitch. It never manages `AudioStreamPlayer` nodes directly — AudioSystem owns the pool.

## Player Fantasy

Sound is the fastest confirmation the player gets.

Before the VFX burst resolves, before a damage number could appear, the ear knows something happened. The crack of Ice Shard hitting an already-burning enemy — a hiss, a steam rush — lands in the same frame as the impact. The player feels clever before they can articulate why. That's the work of this system.

Each interaction sound must carry weight proportional to the mechanical reward. Steam Burst (×2.0 damage, AoE) sounds like something the world noticed. Amplify (×1.5, universal catalyst) sounds satisfying but modest — it should prompt the thought "I should do that again," not "I should stop there." Cryoblast (×3.0, the highest single-hit combo) should make a sound the player remembers the first time they hear it.

Status sounds are quieter — informational. The FROZEN snap on Ice Shard contact tells the player "this enemy is now in a different state." It is not spectacular. It is precise. The MARKED sigil hum during the orb's 5-second window is a ticking clock the ear tracks without conscious attention.

Combat hurt and death sounds are GUARANTEED — they cut through every other SFX because they carry consequence. The player must hear when they were hit. Everything else can occasionally drop in a full pool.

## Detailed Design

### Architecture

`AudioFeedbackSystem` is an autoload singleton. On `_ready()` it connects to signals from `SpellInteractionEngine` and `HealthSystem` (both autoloads). It also subscribes to `died` signals dynamically — any node that enters the scene tree and belongs to group `&"enemies"` **or** `&"boss"` has its `died` signal connected automatically.

`AudioFeedbackSystem` never touches `AudioStreamPlayer` nodes or `AudioServer` directly. Every SFX call goes through `AudioSystem.play_sfx(stream, priority, pitch_scale)`. `AudioFeedbackSystem` is a routing and context layer, not a playback layer.

```
SpellInteractionEngine.interaction_triggered  →  _on_interaction(enemy, interaction_name, final_damage)
SpellInteractionEngine.status_applied         →  _on_status_applied(enemy, status_id)
HealthSystem.player_damaged                   →  _on_player_damaged(amount)
HealthSystem.player_died                      →  _on_player_died()
BaseEnemy.died (per-instance)                 →  _on_enemy_died()
BaseBoss.died (per-instance)                  →  _on_enemy_died()   # same handler — boss death SFX
```

Enemy/boss subscription flow: `AudioFeedbackSystem._ready()` calls `get_tree().node_added.connect(_on_node_added)`. `_on_node_added(node)` checks `node.is_in_group(&"enemies") or node.is_in_group(&"boss")`. If true, `node.died.connect(_on_enemy_died)`.

---

### SFX Routing Table

One authoritative table maps each event to an `AudioStream` resource path, priority tier, and pitch variance. `AudioFeedbackSystem` reads this table at runtime — no SFX routing is hardcoded in handler methods.

#### Category 1 — Interaction SFX

| Interaction | Resource Path | Priority | Base Pitch | Pitch Variance |
|-------------|--------------|----------|------------|----------------|
| `steam_burst` | `res://assets/audio/sfx/sfx_steam_burst.ogg` | HIGH | 1.0 | ±0.05 |
| `cryoblast` | `res://assets/audio/sfx/sfx_cryoblast.ogg` | HIGH | 1.0 | ±0.04 |
| `extinguish` | `res://assets/audio/sfx/sfx_extinguish.ogg` | NORMAL | 1.0 | ±0.06 |
| `amplify` | `res://assets/audio/sfx/sfx_amplify.ogg` | NORMAL | 1.0 | ±0.05 |
| `inferno` | `res://assets/audio/sfx/sfx_inferno.ogg` | NORMAL | 1.0 | ±0.07 |

Interaction SFX is the primary audio payoff for Spell Alchemy. `steam_burst` and `cryoblast` are HIGH priority — they represent the two most spectacular mechanics and must be heard. The other three are NORMAL: they are meaningful but less spectacular and can be evicted in a full pool.

#### Category 2 — Status SFX

Status SFX plays on `status_applied` only. No separate expire sound at MVP (SLOWED and STUNNED have no apply sound — their audio payoff is embedded in the interaction SFX that created them).

| Status | Resource Path | Priority | Base Pitch | Pitch Variance |
|--------|--------------|----------|------------|----------------|
| `frozen` | `res://assets/audio/sfx/sfx_status_frozen.ogg` | NORMAL | 1.0 | ±0.04 |
| `burning` | `res://assets/audio/sfx/sfx_status_burning.ogg` | LOW | 1.0 | ±0.08 |
| `marked` | `res://assets/audio/sfx/sfx_status_marked.ogg` | LOW | 1.0 | ±0.03 |

`frozen` is NORMAL — it primes the highest-damage interactions (Cryoblast ×3.0) and is informational-critical. `burning` and `marked` are LOW — they fire on every primer hit, so they will be frequent; LOW lets them be dropped in busy combat without losing critical information.

Status SFX on refresh (status re-applied while already active): play the apply sound again. The sound is brief; repetition is acceptable and confirms the player's primer is registering.

#### Category 3 — Combat Feedback SFX

| Event | Resource Path | Priority | Base Pitch | Pitch Variance |
|-------|--------------|----------|------------|----------------|
| `player_hurt` | `res://assets/audio/sfx/sfx_player_hurt.ogg` | GUARANTEED | 1.0 | ±0.04 |
| `player_death` | `res://assets/audio/sfx/sfx_player_death.ogg` | GUARANTEED | 1.0 | 0.0 |
| `enemy_death` | `res://assets/audio/sfx/sfx_enemy_death.ogg` | NORMAL | 1.0 | ±0.08 |

`player_hurt` and `player_death` are GUARANTEED — they must always be heard. They cannot be evicted by any other SFX. `player_death` has no pitch variance: it should be a fixed, recognisable sound. `enemy_death` is NORMAL — regular-enemy deaths may be dropped when the SFX pool is busy.

---

### Pitch Variation

On every `play_sfx()` call, `AudioFeedbackSystem` computes a randomised `pitch_scale`:

```
pitch_scale = base_pitch + randf_range(-variance, variance)
```

`randf_range` uses Godot's global RNG (no seeded RNG needed for SFX). The computed pitch is clamped to `[0.5, 2.0]` before passing to `AudioSystem.play_sfx()`.

Pitch variance is per-SFX, defined in the routing table. `player_death` has `0.0` variance — always plays at 1.0.

---

### Signal Requirements on Upstream Systems

Two signals must be added to `SpellInteractionEngine` before `AudioFeedbackSystem` can be implemented. These are dependency requirements this GDD places on that system:

**`interaction_triggered` parameter change:** Current signature is `(enemy, element, final_damage)`. Required signature: `(enemy, interaction_name: StringName, final_damage: int)`. `interaction_name` is the key from `INTERACTION_REGISTRY` (e.g., `&"steam_burst"`). AudioFeedbackSystem needs the name, not the element, to look up the correct SFX.

**`status_applied(enemy: BaseEnemy, status_id: StringName)`:** New signal. Emitted by `_apply_status_if_primer()` after writing to `enemy.active_statuses`. Fires on both first apply and refresh. AudioFeedbackSystem uses this to play Category 2 status SFX.

## Formulas

**F1 — Pitch Scale Computation**

```
pitch_scale = clamp(base_pitch + randf_range(-variance, variance), 0.5, 2.0)
```

Variables:
- `base_pitch` — per-SFX constant from routing table, default `1.0`
- `variance` — per-SFX constant from routing table (half-range), e.g., `0.05`
- `randf_range(-variance, variance)` — uniform random in `[-variance, variance]`
- `clamp(..., 0.5, 2.0)` — safety floor/ceiling; prevents inaudibly low or chipmunk-high playback

Example (Steam Burst, base=1.0, variance=±0.05):
- Roll `randf_range(-0.05, 0.05)` → `-0.031`
- `pitch_scale = 1.0 + (-0.031) = 0.969`
- `clamp(0.969, 0.5, 2.0) = 0.969` ✓

Example (player_death, variance=0.0):
- `pitch_scale = 1.0 + 0.0 = 1.0` always

## Edge Cases

**E1 — Interaction and status SFX fire in same frame**
An interaction fires (e.g., Steam Burst) and its primer (FROZEN) was just applied this frame. Both `interaction_triggered` and `status_applied` fire in the same frame. Rule: both SFX calls are dispatched to AudioSystem independently. If the pool has room, both play. If not, the interaction SFX (HIGH) wins over the status SFX (NORMAL/LOW) through normal pool eviction. No special-case suppression needed — pool priority handles it.

**E2 — Steam Burst AoE kills multiple enemies simultaneously**
One interaction SFX plays (from `interaction_triggered`). Multiple `enemy.died` signals fire in the same frame. Rule: one `enemy_death` SFX per `died` signal, all dispatched as NORMAL. AudioSystem pool eviction handles surplus — not all will play if the pool is full. Interaction SFX fires first (dispatched before AoE damage resolves).

**E3 — Player takes damage during active interaction SFX**
`player_damaged` fires. Rule: GUARANTEED priority — always acquires a slot regardless of current pool state. The interaction SFX continues playing in its own slot; GUARANTEED does not evict non-GUARANTEED slots, it claims a reserved one.

**E4 — DOT tick (BURNING) kills an enemy**
`BaseEnemy.died` fires. `_on_enemy_died()` plays `enemy_death` SFX. No `player_damaged` signal — DOT damage flows through `enemy.take_damage()`, not `HealthSystem`. Correct: no player hurt SFX.

**E5 — Player dies from a hit that also triggers an interaction**
Both `player_died` and `interaction_triggered` fire in the same frame. Rule: both SFX dispatched — `player_death` (GUARANTEED) always plays; interaction SFX plays if a slot is available (or an evictable one exists). `player_death` takes precedence in any eviction scenario.

**E6 — Enemy enters scene tree before AudioFeedbackSystem._ready() completes**
Not possible: Autoloads initialise before scene nodes in Godot 4. `_ready()` connection to `node_added` is established before any gameplay node's `_ready()` fires.

**E7 — Enemy spawned at runtime after scene loads**
`get_tree().node_added` fires for the new enemy node. `_on_node_added` checks `is_in_group(&"enemies") or is_in_group(&"boss")` — connects `died` signal if either group matches. Covers both regular enemies and the boss node. Correct: all dynamically spawned combat nodes are covered.

**E8 — Player hurt during i-frame window**
HealthSystem blocks the damage, emits no `player_damaged` signal. No SFX fires. Correct: the player should not hear a hurt sound for hits they are immune to.

**E9 — status_applied fires but AudioStream resource is missing (file not yet created)**
`AudioSystem.play_sfx(null, ...)` called with a null stream. Rule: AudioSystem must guard against null stream input and return `false` without crashing. AudioFeedbackSystem does not guard — it is the audio designer's responsibility to have all resource paths populated before shipping. A `@warning_ignore("assert")` assertion in `AudioFeedbackSystem._ready()` should validate all routing table paths exist.

**E10 — Same interaction fires for two enemies hit by one AoE projectile**
Each enemy resolves `process_hit()` independently. Two `interaction_triggered` signals fire (one per enemy). Two interaction SFX dispatched. If both fit in the pool, both play. If pool is full, one may be evicted. No deduplication at AudioFeedbackSystem level — two separate combat events should be audible if possible.

## Dependencies

**Upstream (systems AudioFeedbackSystem depends on):**

| System | What AudioFeedbackSystem needs |
|--------|-------------------------------|
| AudioSystem (Foundation) | `play_sfx(stream, priority, pitch_scale)` — the only playback method used |
| SpellInteractionEngine (Feature) | `interaction_triggered(enemy, interaction_name, final_damage)` — requires parameter change from current `element` to `interaction_name`; `status_applied(enemy, status_id)` — new signal required |
| HealthSystem (Core) | `player_damaged(amount)` and `player_died` signals |
| BaseEnemy (Core) | `died` signal on each instance; `is_in_group(&"enemies")` returns true |

**Downstream (systems that depend on AudioFeedbackSystem):**
None. AudioFeedbackSystem is a terminal Presentation-layer system — nothing depends on it.

**Breaking change required on SpellInteractionEngine:**
`interaction_triggered` second parameter must change from `element: StringName` to `interaction_name: StringName`. The HUD and VFX systems may also subscribe to `interaction_triggered` — they must be updated simultaneously. This is a co-ordinated change across the Presentation layer: AudioFeedbackSystem, SpellVFXSystem, and HUDSystem.

**Bidirectional dependency note:**
AudioSystem GDD (Section Dependencies, Downstream) already lists AudioFeedbackSystem as a downstream consumer. No update needed there. SpellInteractionEngine GDD must be updated to document the two new signals (`interaction_triggered` parameter change, `status_applied`) when this GDD is approved.

## Tuning Knobs

All knobs are constants in `AudioFeedbackSystem.gd` in the routing table. They are not exposed to the Settings System.

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| Interaction SFX priority (steam_burst, cryoblast) | HIGH | NORMAL–GUARANTEED | Whether high-value interaction sounds can be evicted. Do not lower below NORMAL. |
| Interaction SFX priority (extinguish, amplify, inferno) | NORMAL | LOW–HIGH | Acceptable to lower to LOW if pool contention is measured in playtesting. |
| Status SFX priority (frozen) | NORMAL | LOW–HIGH | Raise to HIGH if players report missing frozen confirmation during busy combat. |
| Status SFX priority (burning, marked) | LOW | LOW–NORMAL | Raise only if players report consistently missing primer confirmation. |
| Enemy death SFX priority | NORMAL | LOW–HIGH | Raise if player reports mass-enemy deaths feel silent. |
| Pitch variance (interaction SFX) | ±0.04–0.07 | 0.0–0.15 | Amount of pitch variation. 0.0 = robotic, >0.15 = noticeably off-pitch. |
| Pitch variance (status SFX) | ±0.03–0.08 | 0.0–0.12 | Same. Status SFX is quiet and brief; wider variance is acceptable. |
| Pitch variance (player_death) | 0.0 | 0.0 only | Never vary. Player death must be instantly recognisable. |
| `pitch_clamp_min` | 0.5 | 0.5–0.8 | Floor on computed pitch_scale. Below 0.5 sounds like a monster, not a spell. |
| `pitch_clamp_max` | 2.0 | 1.5–2.0 | Ceiling on computed pitch_scale. Above 2.0 sounds like chipmunks. |

## Acceptance Criteria

**AC-AFB-001 — Interaction SFX plays on interaction_triggered**
Cast Ice Shard at an enemy, then Fireball. `interaction_triggered` fires (Steam Burst). A non-silent SFX plays within one frame of the signal. No crash if the pool is empty (play_sfx returns false silently).

**AC-AFB-002 — Correct SFX per interaction**
Test all five interactions in sequence. Each fires a distinct SFX. No two interactions share the same audio file (verify by ear and by routing table inspection).

**AC-AFB-003 — Pitch varies between repeated interaction SFX calls**
Fire Amplify (MARKED + any) five consecutive times. Record pitch_scale values passed to AudioSystem.play_sfx(). No two consecutive values may be identical. All values must be within [base ± variance] and within [0.5, 2.0].

**AC-AFB-004 — player_hurt SFX plays on player_damaged — GUARANTEED**
Fill the SFX pool with 16 GUARANTEED slots manually. Trigger player_damaged. player_hurt SFX must play (GUARANTEED cannot be denied even by a full GUARANTEED pool — if pool is full, verify this edge case is logged). Under normal conditions (pool not exhausted with GUARANTEED): must always play.

**AC-AFB-005 — player_death SFX plays on player_died**
Let the player die. player_death SFX plays within one frame of player_died signal. player_death pitch_scale is always exactly 1.0.

**AC-AFB-006 — No player_hurt SFX during i-frame**
Take damage to trigger i-frames. During the i-frame window, apply a second hit (bypass via HealthSystem direct call in test). HealthSystem blocks — no `player_damaged` signal fires — no SFX plays. Verify by monitoring play_sfx calls.

**AC-AFB-007 — Status SFX plays on status_applied**
Hit an enemy with Ice Shard. `status_applied(enemy, &"frozen")` fires. sfx_status_frozen plays within one frame.

**AC-AFB-008 — Status SFX on refresh plays again**
Hit a frozen enemy with Ice Shard again (before freeze expires). `status_applied` fires again. sfx_status_frozen plays again. No suppression on refresh.

**AC-AFB-009 — Enemy death SFX plays on enemy.died**
Kill an enemy. `enemy.died` fires. sfx_enemy_death plays within one frame.

**AC-AFB-010 — Dynamic enemy subscription works for runtime-spawned enemies**
Load a scene with no enemies. Spawn an enemy dynamically via script. Kill the spawned enemy. sfx_enemy_death plays. Confirms `node_added` subscription is live.

**AC-AFB-011 — No direct AudioServer or AudioStreamPlayer calls outside AudioSystem**
Grep codebase for `AudioServer.` and `new AudioStreamPlayer` references inside `audio_feedback_system.gd`. Result must be zero matches.

**AC-AFB-012 — Routing table resource paths valid at boot**
On `_ready()`, AudioFeedbackSystem iterates all resource paths in the routing table and asserts each path loads successfully via `load()`. In release builds this assertion is stripped — it is a dev-time check. No null stream is passed to AudioSystem.play_sfx() under normal gameplay.

**AC-AFB-013 — DOT kill does not play player_hurt SFX**
Apply BURNING to an enemy. Wait for an enemy to kill the player via DOT (or simulate: tick BURNING damage onto player via HealthSystem directly). `player_damaged` fires. `player_hurt` SFX plays. — Wait, this is correct: if the enemy deals DOT damage and the player's HealthSystem processes it via take_damage(), player_damaged fires. Correct behavior. What must NOT happen: DOT on an enemy should not fire player_damaged. Clarification: BURNING ticks damage on the enemy, not the player — `player_damaged` cannot fire from enemy DOT. Confirmed correct by architecture.
