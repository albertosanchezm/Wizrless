# Progression System

> **Status**: In Review
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-20
> **Implements Pillar**: Controlled Ascension (player earns freedom through boss victories)

---

## Overview

The Progression System owns every mechanism by which the player gains capability: movement ability unlocks, spell slot unlocks, and health upgrades. All three are earned through boss defeats and world exploration — never purchased. `GameManager` is the runtime authority for ability state; the Progression System writes to it and defines the full unlock table. Any system that gates behavior on player capability queries `GameManager.has_ability()` — it does not talk to the Progression System directly.

---

## Player Fantasy

Each boss kill answers the question "what can I do now that I couldn't before?" The player enters a boss fight with a specific constraint — one spell slot, no dash, no wall-jump — and leaves with one of those constraints lifted. The world literally opens: a door that was visually present but unreachable is now crossable. The constraint was not difficulty padding — it was anticipation. Lifting it is the reward.

Health upgrades are different: they are found in the world, not granted by bosses. They reward exploration. The wizard who looks in corners is more durable. The wizard who skips the hidden room is more fragile. This is a consequence the player chose.

---

## Detailed Rules

### Ability Unlock Table

All abilities start locked. Each is unlocked by a specific trigger, written to `GameManager.abilities_unlocked` via `GameManager.unlock_ability()`.

| Ability ID | Display Name | Trigger | Zone Unlocked |
|------------|-------------|---------|---------------|
| `&"dash"` | Dash | Defeat Boss 1 (Devium) | Zone 1 → Zone 2 transition |
| `&"wall_jump"` | Wall Jump | Defeat Boss 2 | Zone 2 → Zone 3 transition |
| `&"double_jump"` | Double Jump | Defeat Boss 3 | Zone 3 → Zone 4 transition |
| `&"air_dash"` | Air Dash | Defeat Boss 4 | Zone 4 → Zone 5 transition |

MVP implements only `&"dash"` (unlocked by Devium). All other abilities are stubs: `has_ability()` returns `false` for them at MVP. The unlock table defines the full game arc.

### Spell Slot Unlock Table

The player begins with 1 spell slot. Slots unlock through story milestones, not boss defeats. Each additional slot makes the Spell Alchemy system richer (more potential combinations).

| Slot Count | Unlock Trigger | Milestone |
|-----------|----------------|-----------|
| 1 | Start | Default — wizard begins with one equipped spell |
| 2 | Reach Zone 2 | First zone transition fires `slot_unlock_trigger` |
| 3 | Defeat Boss 3 | Mid-game milestone |
| 4 | Reach Zone 5 | Late-game — four active spells, maximum combo potential |

`SpellSlotSystem.unlock_slot()` is called by the Progression System trigger logic. `SpellSlotSystem` owns the slot array; Progression owns when unlocks fire.

### Health Upgrade Pickups

Health upgrades are `HealthUpgrade` area nodes placed in the world (one per hidden room at MVP). On player contact:

1. If `SaveManager.get_flag("health_upgrade_{id}") == true`: already collected — do nothing.
2. Set flag `"health_upgrade_{id}" = true` via `SaveManager`.
3. Call `GameManager.add_max_health(UPGRADE_INCREMENT)` — increases both `max_health` and `current_health` by `UPGRADE_INCREMENT`.
4. Play pickup SFX and VFX.
5. `queue_free()` the pickup node.

`UPGRADE_INCREMENT = 2`. Four health upgrades in the world. Max health ceiling: 6 + 4×2 = 14 HP (matches health-system.md).

### Boss Defeat Trigger Flow

Boss defeat triggers are the primary source of ability unlocks. The sequence:

1. `BaseBoss.on_death()` calls `GameManager.emit_boss_defeated(id: StringName)`.
2. `GameManager.bosses_defeated.append(id)` and calls `SaveManager.save_game()`.
3. `ProgressionSystem._on_boss_defeated(id)` handler fires (connected to `GameManager.boss_defeated` signal).
4. Handler looks up `id` in the unlock table. If an ability unlock is defined: calls `GameManager.unlock_ability(ability_id)`.
5. Handler checks if a slot unlock is defined for this milestone: calls `SpellSlotSystem.unlock_slot()` if so.
6. Scene transition to next zone is gated by the ability — the player can now access the previously blocked exit.

### Ability Gate Enforcement

**Runtime gating** (movement systems): `GameManager.has_ability(ability_id)` called in `_physics_process`. If `false`, the ability input is ignored.

**World gate enforcement** (zone transitions): `RoomExit._on_body_entered()` checks `GameManager.has_ability(required_ability)` if the exit has an `ability_gate: StringName` exported property set. If `false`: exit is locked — `GateLock` visual shown, player physically blocked by a `StaticBody2D` barrier node on the same exit.

The exit barrier is a separate node (`GateLock StaticBody2D`) that exists in the scene but only has collision active when locked. `ProgressionSystem` does not manage barriers — zone/room level design places them. When the ability unlocks, the barrier becomes passable (collision disabled via `GameManager.abilities_unlocked` query on `Room._ready()`).

---

## Formulas

### Max Health Progression

```
max_health(n) = BASE_HEALTH + n × UPGRADE_INCREMENT

BASE_HEALTH       = 6
UPGRADE_INCREMENT = 2
N_UPGRADES        = 4 (world total)
max_health(4)     = 6 + 4 × 2 = 14
```

| n | max_health |
|---|------------|
| 0 | 6 |
| 1 | 8 |
| 2 | 10 |
| 3 | 12 |
| 4 | 14 |

This matches the Health System GDD formula. The Progression System provides the upgrade pickup; the Health System owns the formula.

### Slot Count Progression

```
slot_count(milestone) = BASE_SLOTS + unlocked_via_milestones

BASE_SLOTS = 1
Max slots  = 4
```

| Milestone | Slots | Active Spells |
|-----------|-------|---------------|
| Start | 1 | 1 |
| Zone 2 | 2 | 2 |
| Boss 3 defeated | 3 | 3 |
| Zone 5 | 4 | 4 |

### Variable Definitions

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `BASE_HEALTH` | int | 6 | Starting max health (authoritative: Health System GDD) |
| `UPGRADE_INCREMENT` | int | 2 | HP gained per pickup |
| `N_UPGRADES` | int | 4 | Total health upgrades in the world |
| `BASE_SLOTS` | int | 1 | Starting spell slot count |
| `ability_id` | StringName | see table | Identifies a movement ability for `has_ability()` queries |

---

## Edge Cases

**EC-01 — Boss defeated, ability already unlocked (save loaded after earlier run).**
`GameManager.bosses_defeated` contains the id. On `_ready()`, Progression System replays unlock table — calls `unlock_ability()` even if already true. `Dictionary[StringName, bool]` write is idempotent. No double-fire of gameplay effects.

**EC-02 — Health upgrade collected but pickup still in scene (save file edge case).**
`Room._ready()` checks `SaveManager.get_flag("health_upgrade_{id}")` — if true, pickup `queue_free()`s immediately without granting stats again. Player sees no pickup. Correct.

**EC-03 — Slot unlock fires during active combat.**
`SpellSlotSystem.unlock_slot()` is idempotent if already at target count. `slot_unlocked(new_count)` signal fires — HUD rebuilds slot row (one-frame stutter, acceptable). Slot unlock events only occur at zone transition triggers, not mid-fight. Runtime guard is a safety net.

**EC-04 — Player enters ability-gated room exit without the required ability.**
`RoomExit._on_body_entered()` queries `has_ability(required_ability)` — false. Player is blocked by `GateLock` collision. No state change. Player must backtrack.

**EC-05 — All 4 health upgrades collected before any boss defeated.**
Max health is 14 at base ability level. Possible — encourages exploration before combat. No design conflict.

**EC-06 — Boss defeated signal fires while save is in progress.**
`SaveManager.save_game()` called from `emit_boss_defeated()` (ADR-0002). Signal then fires. `_on_boss_defeated()` runs — unlock + potential second save call. `SaveManager` atomic write guard prevents partial saves; duplicate save calls are safe.

---

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **GameManager** | Writes to | `unlock_ability()`, `add_max_health()`, `bosses_defeated` array, `abilities_unlocked` dict |
| **SpellSlotSystem** | Calls | `unlock_slot()` on milestone triggers |
| **SaveManager** | Uses | `get_flag`/`set_flag` for health upgrade collection state |
| **Zone/Room System** | Constraint | `RoomExit` uses `GameManager.has_ability()` to enforce world gates |
| **Boss System** | Subscribes to | `GameManager.boss_defeated` signal — primary ability unlock trigger |
| **Movement System** | Consumer | Queries `GameManager.has_ability()` before allowing dash/wall-jump |
| **Health System** | Consumer | Receives `add_max_health()` calls from health upgrade pickups |

**Reverse dependencies:**
- Movement System depends on this system defining which ability IDs are valid.
- Zone/Room System depends on this system's ability table to know which gates exist.
- Spell Slot System depends on this system's milestone table to know when to unlock slots.

---

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `UPGRADE_INCREMENT` | 2 | 1–4 | HP gained per pickup. 1 = slow health ramp, every pick matters. 4 = large jumps, fewer pickups needed for same ceiling. |
| `N_UPGRADES` | 4 | 2–6 | Total pickups in world. Fewer = each feels rarer. More = encourages thorough exploration. |
| `BASE_HEALTH` | 6 | 4–8 | Starting fragility. 4 = extremely punishing early game. 8 = forgiving start reduces tension. Authoritative in Health System GDD. |
| `BASE_SLOTS` | 1 | 1 | Fixed at 1 — single-spell start is the Controlled Ascension constraint. Do not increase. |
| `BOSS_BAR_REVEAL_DURATION` | 0.5s | — | Owned by HUD System — listed here for design visibility. |
| Ability unlock assignment | Per table | — | Which ability unlocks on which boss defeat. Adjust to control world access pacing. |

---

## Acceptance Criteria

**AC-01 — Dash locked at start.**
New game. `GameManager.has_ability(&"dash")` returns `false`. Player input for dash ignored. Verified by: start new game, attempt dash, confirm no movement.

**AC-02 — Dash unlocks after Devium defeat.**
Defeat Devium. `GameManager.abilities_unlocked[&"dash"] == true`. `GameManager.has_ability(&"dash")` returns `true`. Player can now dash. Verified by: defeat Devium, attempt dash.

**AC-03 — Ability persists across sessions.**
Defeat Devium. Save and reload. `GameManager.has_ability(&"dash")` still `true`. Verified by: defeat Devium, save, quit, reload, confirm dash works.

**AC-04 — Health upgrade grants +2 max HP and +2 current HP.**
Current HP = 4, max HP = 6. Collect health upgrade. `max_health == 8`, `current_health == 6` (clamped). `health_changed` signal fired. HUD shows 8-pip row with 6 filled. Verified by: collect pickup at 4/6 HP, check HUD.

**AC-05 — Health upgrade collected once only.**
Collect health upgrade in room. Exit, return. Pickup absent. `max_health` not incremented again. Verified by: collect, leave, re-enter room, confirm no pickup and no HP change.

**AC-06 — Ability gate blocks untrained player.**
Find ability-gated exit (requires `&"dash"`). Before Devium defeat. `GateLock` barrier active. Player cannot pass. Verified by: approach gated exit pre-boss, confirm block.

**AC-07 — Ability gate opens after unlock.**
After Devium defeat, return to same gated exit. `GateLock` collision disabled. Player passes through. Verified by: return to gated exit after Devium kill.

**AC-08 — Slot unlock fires on milestone.**
Reach Zone 2 for first time. `SpellSlotSystem.slot_count == 2`. `slot_unlocked(2)` signal fired. HUD shows 2-frame slot row. Verified by: reach Zone 2, check HUD.

**AC-09 — Slot unlock persists.**
Unlock slot 2. Save and reload. `SpellSlotSystem.slot_count == 2`. Verified by: unlock, save, reload, check HUD.
