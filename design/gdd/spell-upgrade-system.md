# Spell Upgrade System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-04
> **Implements Pillar**: Controlled Ascension (progression reward), Spell Alchemy (deepens emergent interactions)

## Overview

The Spell Upgrade System lets the player permanently strengthen spells by spending elemental materials at in-world **Upgrade Shrines**. Six spells each have three upgrade tiers. Each tier costs materials of the corresponding element — Frost Crystal for Ice Shard, Ember for Fireball, etc. No cross-element spending.

Upgrade Shrines are physical nodes placed in the world by level designers. Upgrading is not a pause-menu action — the player must find and reach the shrine. Each shrine persists across visits; the player can return after gathering more materials.

Upgrades modify runtime behavior via a `spell_upgrades` dictionary in `GameManager` (`{ spell_id: tier_level }`). Projectile scenes read their upgrade level at spawn — no disk mutations, no `.tres` rewrites at runtime.

At MVP, the total materials available per element (~20) are enough to reach **Tier 2 comfortably and Tier 3 only if the player finds hidden caches**. Players cannot fully upgrade every spell in one playthrough. Every upgrade decision is a real choice from a known finite supply — consistent with the Controlled Ascension pillar.

## Player Fantasy

Power earned, not given.

The wizard did not start weak because he lacked ability. He started constrained because no one trusted him with the full shape of what he could do. Every upgrade is the removal of one more leash. The first time Fireball splits into three burning shards on impact, the player should feel that something has been unlocked inside the spell itself — not patched onto it, but revealed.

Upgrade Shrines are quiet, intentional moments. The player has survived, collected, navigated back to the shrine. Standing at it, choosing which spell to evolve, spending hard-won Frost Crystals — this is not a menu transaction. It is a decision about identity. **What kind of wizard am I building?** With finite materials and no grinding, every upgrade path is a statement.

The combat consequence should be immediately visible. Upgrade Ice Shard to T2, enter the next fight — the ice patch left on impact changes how enemies can approach. The player should notice, adapt, explore. Upgraded spells open new interaction possibilities with the Spell Interaction Engine — the system rewards investment with discovery.

## Detailed Design

### Upgrade Shrine Node

In-world interactable placed by level designers. One shrine per zone at MVP (one in the starting area, one per element zone).

```
UpgradeShrine (Area2D)
├─ Sprite2D              -- glowing pedestal, element-neutral visual
├─ CollisionShape2D      -- RectangleShape2D, ~48×64 px
├─ InteractLabel         -- Label2D: "Press [E] to upgrade", hidden when player absent
└─ AnimationPlayer       -- "idle_glow" loop
```

```gdscript
# scripts/interactables/upgrade_shrine.gd
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group(&"player"): return
    InteractLabel.visible = true

func _on_body_exited(body: Node2D) -> void:
    InteractLabel.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if not _player_in_range: return
    if event.is_action_pressed(&"interact"):
        GameManager.open_upgrade_ui.emit()
```

Shrine never disappears — always available to return to.

---

### Upgrade State

Stored in `GameManager`:

```gdscript
# { StringName → int }  spell_id → current tier (0 = no upgrades, max 3)
var spell_upgrades: Dictionary = {}

func get_upgrade_tier(spell_id: StringName) -> int:
    return spell_upgrades.get(spell_id, 0)

func apply_upgrade(spell_id: StringName) -> bool:
    var tier: int = get_upgrade_tier(spell_id)
    if tier >= 3: return false
    var cost: int = _upgrade_cost(spell_id, tier + 1)
    var mat: StringName = _material_for_spell(spell_id)
    if not GameManager.spend_material(mat, cost): return false
    spell_upgrades[spell_id] = tier + 1
    upgrade_applied.emit(spell_id, tier + 1)
    return true

signal upgrade_applied(spell_id: StringName, new_tier: int)
```

---

### Material → Spell Mapping

```gdscript
const SPELL_MATERIAL: Dictionary = {
    &"fireball":        &"ember",
    &"ice_shard":       &"frost",
    &"light_bolt":      &"radiance",
    &"shadow_tendril":  &"void_shard",
    &"conjure":         &"aether",
    &"rupture":         &"shatter",
}

func _material_for_spell(spell_id: StringName) -> StringName:
    return SPELL_MATERIAL.get(spell_id, &"")
```

---

### Upgrade Cost Schedule

```gdscript
const UPGRADE_COSTS: Array[int] = [0, 5, 8, 12]
# Index = tier being purchased. [0] unused (tier 0 = base, no cost).

func _upgrade_cost(spell_id: StringName, target_tier: int) -> int:
    return UPGRADE_COSTS[target_tier]
```

Costs are identical across all spells at MVP. Balance passes adjust per-spell if needed.

---

### How Projectiles Read Upgrade Tier

No SpellResource mutation. Each projectile scene calls `GameManager.get_upgrade_tier()` in `_ready()`:

```gdscript
# scripts/projectiles/fireball.gd
var _tier: int = 0

func _ready() -> void:
    _tier = GameManager.get_upgrade_tier(&"fireball")
    # apply tier-specific behavior below
```

This keeps `.tres` SpellResource files immutable at runtime and avoids save/load complexity.

---

### Upgrade Tier Effects

#### Fireball (ember)

| Tier | Effect |
|------|--------|
| 0 | Base: 20 damage, straight projectile, destroys on contact |
| 1 | Damage → 28 |
| 2 | On impact: small explosion deals 10 damage to enemies within 32 px of hit point |
| 3 | On wall-hit or lifetime expiry: splits into 3 shards at ±25° and forward, each 10 damage |

#### Ice Shard (frost)

| Tier | Effect |
|------|--------|
| 0 | Base: 15 damage, slow enemy 50% for 0.5s on hit |
| 1 | Damage → 22; slow duration → 1.0s |
| 2 | On hit: spawns `IcePatch` Area2D at impact point (1.5s lifetime); enemies in patch slowed 50% continuously |
| 3 | Freeze: fully stops enemy movement and action for 0.8s (bosses: still only slow, not freeze) |

#### Light Bolt (radiance)

| Tier | Effect |
|------|--------|
| 0 | Base: 18 damage, fast (300 px/s), passes through terrain |
| 1 | Damage → 26; speed → 380 px/s |
| 2 | Chain: on first enemy hit, spawns secondary bolt toward nearest enemy within 120 px (12 damage, no further chain) |
| 3 | Blind: hit enemy cannot attack or fire projectiles for 1.2s |

#### Shadow Tendril (void_shard)

| Tier | Effect |
|------|--------|
| 0 | Base: 12 damage, arc curves downward, short range |
| 1 | Damage → 18; arc travels 20% further before falling |
| 2 | Vampiric: player restores 5 HP per enemy hit |
| 3 | Entangle: roots enemy (velocity = 0, can't move) for 1.5s; bosses rooted 0.4s |

#### Conjure (aether)

| Tier | Effect |
|------|--------|
| 0 | Base: stationary orb at cast point, 3s lifetime, no direct damage — interaction trigger only |
| 1 | Lifetime → 5s; orb pulse visual radius +25% (cosmetic, aids visibility) |
| 2 | Orb emits damage pulse every 1.5s: 8 damage to enemies within 40 px |
| 3 | Orb orbits player at 64 px radius (clockwise, 1 full rotation per 3s); interaction trigger still fires based on orb position |

#### Rupture (shatter)

| Tier | Effect |
|------|--------|
| 0 | Base: 25 damage, slow (120 px/s), short lifetime, forced horizontal |
| 1 | Damage → 35; speed → 150 px/s |
| 2 | On impact: shockwave deals 20 damage to all enemies within 48 px of hit point |
| 3 | Delayed detonation: embeds in first enemy hit, detonates after 0.8s for 2× base damage (50/70 at T3); enemy can move during delay |

---

### Upgrade UI

Opened via `GameManager.open_upgrade_ui` signal. Simple full-screen overlay — not a separate scene transition.

Layout:
- 6 spell rows. Each row: spell icon | spell name | current tier pip display (○○○) | upgrade cost + material icon | Upgrade button (greyed if insufficient or max tier)
- Current material counts shown per type at top of screen
- Press interact or Escape to close

No animated transitions at MVP. Functional over flashy.

---

### Save Schema

Added to `GameManager` save slice under key `"upgrades"`:

```json
{
  "upgrades": {
    "fireball": 2,
    "ice_shard": 1
  }
}
```

Missing keys load as tier 0. On load, `spell_upgrades` restored before first room physics frame so projectile `_ready()` reads correct tiers immediately.

## Formulas

### Upgrade Cost Schedule

```
UPGRADE_COSTS = [0, 5, 8, 12]   -- index = target tier

cost_to_fully_upgrade_one_spell = 5 + 8 + 12 = 25

-- MVP materials available per type ≈ 20
-- T1 always affordable (5 cost, ~5 enemies)
-- T2 affordable after boss kill (boss drops 8; T1+T2 = 13 total)
-- T3 requires finding both world caches (13 + 12 = 25 > 20 without caches)
-- T3 reachable only with full exploration
```

### Damage Scaling by Tier

```
-- Fireball
base_damage(fireball, tier) =
  tier == 0 → 20
  tier >= 1 → 28

-- Ice Shard
base_damage(ice_shard, tier) =
  tier == 0 → 15
  tier >= 1 → 22

-- Light Bolt
base_damage(light_bolt, tier) =
  tier == 0 → 18
  tier >= 1 → 26

-- Shadow Tendril
base_damage(shadow_tendril, tier) =
  tier == 0 → 12
  tier >= 1 → 18

-- Rupture
base_damage(rupture, tier) =
  tier == 0 → 25
  tier >= 1 → 35
  tier == 3 (detonation) → base_damage × 2 = 70

-- Conjure: no direct damage at any tier
-- T2 pulse: 8 damage per 1.5s tick
-- T3 pulse: same, now orbiting player
```

### T3 Rupture Detonation

```
detonation_damage = base_damage(rupture, 3) × 2.0
                  = 35 × 2.0
                  = 70

embed_duration    = 0.8s
-- Enemy moves freely during embed — positioning matters
-- If enemy dies before detonation: detonation still fires at death position
```

### T2 Fireball Explosion Radius

```
explosion_radius = 32 px
explosion_damage = 10

-- At standard enemy size (~24 px wide):
-- Two adjacent enemies separated by 24 px both take explosion damage
-- Effective splash: enemies within ~(32 + 12) = 44 px of hit point center
```

### T2 Light Bolt Chain Range

```
chain_search_radius = 120 px
chain_damage        = 12  (flat, does not scale with primary bolt damage)

-- Primary bolt hits enemy A
-- System queries: nearest other enemy within 120 px of A's position
-- If found: spawns LightBoltSecondary aimed at that enemy
-- Chain is one hop only — no further chaining
```

### T2 Conjure Pulse

```
pulse_interval = 1.5s
pulse_damage   = 8
pulse_radius   = 40 px

damage_per_second = pulse_damage / pulse_interval = 5.33 dps
-- Low sustained damage; primary value is area denial + interaction trigger
```

### T3 Conjure Orbit

```
orbit_radius        = 64 px
orbit_period        = 3.0s   -- one full revolution
angular_velocity    = (2π) / orbit_period ≈ 2.094 rad/s

-- Orb position each frame:
angle += angular_velocity * delta
orb.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
```

### T3 Ice Shard Freeze vs Boss

```
freeze_duration_normal = 0.8s  -- enemy velocity = 0, no actions
freeze_duration_boss   = 0.0s  -- freeze not applied; slow still applies (T0 mechanic)
slow_duration_boss     = 1.0s  -- T1 slow duration, always used against bosses
```

### Variable Definitions

| Variable | Value | Description |
|----------|-------|-------------|
| `UPGRADE_COSTS[1]` | 5 | Tier 1 material cost |
| `UPGRADE_COSTS[2]` | 8 | Tier 2 material cost |
| `UPGRADE_COSTS[3]` | 12 | Tier 3 material cost |
| `explosion_radius` | 32 px | Fireball T2 blast radius |
| `explosion_damage` | 10 | Fireball T2 splash damage |
| `chain_radius` | 120 px | Light Bolt T2 chain search range |
| `chain_damage` | 12 | Light Bolt T2 secondary bolt damage |
| `ice_patch_lifetime` | 1.5s | Ice Shard T2 ground patch duration |
| `freeze_duration` | 0.8s | Ice Shard T3 non-boss freeze |
| `vampiric_heal` | 5 HP | Shadow Tendril T2 heal per hit |
| `entangle_duration` | 1.5s | Shadow Tendril T3 non-boss root |
| `entangle_boss` | 0.4s | Shadow Tendril T3 boss root |
| `pulse_damage` | 8 | Conjure T2/T3 pulse damage |
| `pulse_interval` | 1.5s | Conjure T2/T3 pulse period |
| `orbit_radius` | 64 px | Conjure T3 orbit distance from player |
| `orbit_period` | 3.0s | Conjure T3 full revolution time |
| `embed_duration` | 0.8s | Rupture T3 delay before detonation |
| `shockwave_radius` | 48 px | Rupture T2 shockwave range |
| `shockwave_damage` | 20 | Rupture T2 shockwave damage |

## Edge Cases

**EC-01 — Player attempts upgrade with insufficient materials.**
`GameManager.spend_material()` returns false. `apply_upgrade()` returns false. No tier change. No materials deducted. Upgrade UI shows button greyed with material count in red. No crash.

**EC-02 — Player attempts upgrade on already-maxed spell (tier 3).**
`apply_upgrade()` checks `tier >= 3`, returns false immediately without calling `spend_material()`. UI shows "MAX" instead of upgrade button. No interaction possible.

**EC-03 — Player opens upgrade UI mid-combat.**
UI pauses game input routing — player cannot move or cast while UI is open. `get_tree().paused = true` while UI is visible. Time-stop applies to projectiles and enemies. Closing UI resumes. Shrine interaction is intentionally safe — no ambush penalty.

**EC-04 — Upgrade applied to a spell not currently equipped.**
`spell_upgrades` stores tier by spell ID regardless of slot state. Upgrade applies. Next time that spell is cast and projectile spawns, `_ready()` reads updated tier. Correct — upgrades are persistent, not slot-dependent.

**EC-05 — Conjure orb (T3 orbit) active when player teleports or respawns.**
Orb's position updates each `_process()` frame via player `global_position`. On respawn, player position resets — orb snaps to new orbit position next frame. No interpolation needed. No orphan orb at old position.

**EC-06 — Rupture T3 embeds in enemy that then enters another room before detonation.**
Detonation timer is owned by the Rupture projectile node, which is parented to the level root (same rule as all projectiles). If enemy crosses a room boundary, the detonation still fires at the projectile's current position (which is attached to the enemy via `remote_transform` or position-tracking). Implementation detail: projectile follows embedded enemy via `_process()` position update, not physics attachment.

**EC-07 — Rupture T3 embeds in enemy that dies before detonation.**
Enemy dies. Detonation timer still runs on the projectile node. After 0.8s, detonation fires at last known position (enemy's death position). Area2D damage check runs — may hit other nearby enemies. Projectile then frees. Correct.

**EC-08 — Light Bolt T2 chain fires when no second enemy in range.**
`chain_search_radius` query returns empty. No secondary bolt spawned. Primary bolt damage applies normally. No crash, no visual artifact.

**EC-09 — Ice Shard T3 freeze applied to boss.**
Boss script checks `is_in_group(&"boss")` in the status-effect handler. Freeze status blocked; slow (T0 slow duration, upgraded by T1 to 1.0s) applied instead. Boss-specific logic lives in the boss script's `apply_status()` method — Ice Shard projectile passes the status, boss decides what to honor.

**EC-10 — Shadow Tendril T2 vampiric heal when player already at max HP.**
`player.heal(5)` clamps to `MAX_HP`. No overflow. No signal spam. Correct.

**EC-11 — Upgrade UI opened before any spell is unlocked.**
At game start only Fireball is known. UI shows 6 rows but 5 rows are locked (greyed, "Locked" text replacing cost). Upgrade button disabled. Material spend impossible for locked spells. Spell Slot System's unlock state determines which rows are interactive.

**EC-12 — save file contains tier > 3 (corrupted save).**
On load: `spell_upgrades[id] = clamp(loaded_value, 0, 3)`. Clamp applied per entry. No out-of-bounds tier can propagate to projectile `_ready()`. Silent correction.

**EC-13 — Two upgrade shrines exist in same zone.**
Both functional. Both open the same `GameManager` upgrade state. Purchasing at one shrine is reflected immediately if player walks to the second. No desynced state — single source of truth in `GameManager`.

**EC-14 — Player upgrades spell, then immediately enters room and casts before `_ready()` completes on projectile.**
`_ready()` runs synchronously when scene is instantiated via `instantiate()` before `add_child()`. Tier is read before the node's first frame. No frame gap. Correct.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Material System** | Reads + spends | `GameManager.spend_material()`, `GameManager.get_material_count()` — upgrade purchase deducts materials |
| **Spell System** | Reads | `SpellResource` spell IDs and element mapping; projectile scenes read `GameManager.get_upgrade_tier()` in `_ready()` |
| **Spell Slot System** | Context | Determines which spells are unlocked — UI must not allow upgrading locked spells |
| **Save/Load System** | Sends to | `spell_upgrades` dictionary registered under `"upgrades"` key; must load before first physics frame |
| **Input System** | Reads | `interact` action in InputMap for shrine activation |
| **Zone/Room System** | Context | Level designers place `UpgradeShrine` nodes in rooms; shrine placement is a level design responsibility |

**Reverse dependencies:**

| System | What it needs from Spell Upgrade |
|--------|----------------------------------|
| **Spell Interaction Engine** | None — upgrades change spell behavior but element identity is unchanged; interactions fire on element, not tier |
| **Boss System** | Must implement `apply_status()` with boss-specific overrides (freeze → slow, long root → short root); boss script owns this logic |
| **HUD System** | Subscribes to `GameManager.upgrade_applied` to show upgrade confirmation toast |
| **Save/Load System** | Must include `"upgrades"` key in save schema |

**Hard blockers (must exist before Spell Upgrade System is testable):**

- `GameManager.spend_material()` and `get_material_count()` implemented (Material System)
- At least one `SpellResource` `.tres` with correct `id` field exists (Spell System)
- `GameManager.spell_upgrades` dictionary and `get_upgrade_tier()` added
- `interact` action registered in InputMap (Input System)

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `UPGRADE_COSTS[1]` | 5 | 3–8 | T1 accessibility. Below 3: trivially cheap after first room. Above 8: feels gated behind boss, removes early reward. |
| `UPGRADE_COSTS[2]` | 8 | 6–12 | T2 pacing. Should require meaningful enemy clearing beyond T1 spend. |
| `UPGRADE_COSTS[3]` | 12 | 10–18 | T3 exclusivity. Above 18: unreachable without both caches — makes T3 feel impossible, not rare. |
| Fireball T1 damage | 28 | 24–34 | +40% from base. Below 24: negligible upgrade feel. Above 34: T1 trivializes early enemies. |
| Fireball T2 explosion radius | 32 px | 20–48 px | Below 20: rarely clips second enemy. Above 48: splash becomes dominant damage source, trivializes grouping. |
| Fireball T2 explosion damage | 10 | 6–18 | Secondary damage. Keep below primary hit damage (28) — explosion is bonus, not primary. |
| Ice Shard T2 patch lifetime | 1.5s | 0.8–3.0s | Below 0.8: patch expires before enemy crosses it. Above 3.0: trivial area denial on small rooms. |
| Ice Shard T3 freeze duration | 0.8s | 0.4–1.5s | Below 0.4: barely distinguishable from slow. Above 1.5: free damage window too long — removes challenge. |
| Light Bolt T2 chain radius | 120 px | 80–200 px | Below 80: rarely fires in normal spacing. Above 200: chains across half the screen, removes targeting skill. |
| Light Bolt T2 chain damage | 12 | 8–20 | Flat secondary damage. Keep below primary (26) — chain is bonus hit, not primary kill vector. |
| Light Bolt T3 blind duration | 1.2s | 0.6–2.0s | Below 0.6: enemy recovers before player can exploit. Above 2.0: effectively removes enemy threat for free. |
| Shadow Tendril T2 heal | 5 HP | 2–10 HP | Below 2: negligible sustain. Above 10: vampiric becomes dominant survival mechanic, removes tension. |
| Shadow Tendril T3 entangle | 1.5s | 0.8–2.5s | Root window. Above 2.5: guaranteed free full combo without skill. |
| Shadow Tendril T3 boss entangle | 0.4s | 0.2–0.8s | Boss root. Should feel impactful but not trivializing. |
| Conjure T2 pulse interval | 1.5s | 0.8–3.0s | Below 0.8: pulse becomes dominant damage, overshadows interaction purpose. Above 3.0: area denial feel disappears. |
| Conjure T2 pulse radius | 40 px | 24–64 px | Below 24: orb must be placed precisely on enemy. Above 64: passive damage too reliable. |
| Conjure T3 orbit radius | 64 px | 48–96 px | Interaction setup range. Below 48: orbit clips player hitbox. Above 96: orb roams too far from intended target. |
| Conjure T3 orbit period | 3.0s | 2.0–5.0s | Below 2.0: orb moves too fast, hard to predict for interaction setups. Above 5.0: barely perceptible orbit. |
| Rupture T2 shockwave radius | 48 px | 32–72 px | AoE range. Above 72: Rupture + any group = trivial clear. |
| Rupture T2 shockwave damage | 20 | 12–30 | Secondary AoE. Keep below primary (35) — shockwave rewards positioning, not primary kill tool. |
| Rupture T3 embed delay | 0.8s | 0.4–1.5s | Below 0.4: barely feels like delayed — just hits immediately. Above 1.5: enemy nearly always escapes detonation window. |

## Acceptance Criteria

**AC-01 — Shrine activates on interact.**
Player enters shrine collision area. Interact label appears. Press `interact` action. Upgrade UI opens. Game pauses. Verified by: walk to shrine, press E, confirm UI visible and player cannot move.

**AC-02 — Upgrade UI shows correct material counts.**
Player has 7 Frost Crystals. Open upgrade UI. Ice Shard row shows "7 / 8" (cost 8 for T2, current 7). Count matches `GameManager.get_material_count(&"frost")`. Verified by: debugger check + visual confirmation.

**AC-03 — Successful upgrade deducts materials and advances tier.**
Player has 5 ember, Fireball at tier 0. Purchase T1 (cost 5). `GameManager.spell_upgrades[&"fireball"]` = 1. `GameManager.materials[&"ember"]` = 0. Verified by: debugger state after purchase.

**AC-04 — Upgrade button disabled when insufficient materials.**
Player has 3 ember, T1 costs 5. Upgrade button greyed, unclickable. No material change on click attempt. Verified by: check button state + attempt click with insufficient funds.

**AC-05 — Maxed spell shows MAX, no further purchase possible.**
Fireball at tier 3. Upgrade button replaced with "MAX" label. `apply_upgrade(&"fireball")` returns false. No material spend. Verified by: reach T3, confirm UI state and no deduction.

**AC-06 — Projectile reads correct tier on spawn.**
Fireball upgraded to T1 (damage 28). Cast fireball. Projectile hits enemy. Enemy takes 28 damage (not 20). Verified by: hit enemy with known HP pool, confirm kill threshold matches T1 damage.

**AC-07 — Fireball T2 explosion hits adjacent enemy.**
Two enemies within 32 px of each other. Fireball hits first enemy. Second enemy takes 10 explosion damage. Verified by: place enemies in known positions, confirm second enemy HP reduction.

**AC-08 — Ice Shard T2 leaves ice patch on ground.**
Upgrade Ice Shard to T2. Fire at wall or enemy. `IcePatch` Area2D node visible in scene tree at impact position. Lifetime 1.5s then freed. Enemy walking through patch slowed. Verified by: scene tree inspection + enemy behavior.

**AC-09 — Ice Shard T3 freezes non-boss enemy.**
Upgrade to T3. Hit regular enemy. Enemy velocity = 0 for 0.8s, no actions taken. After 0.8s, resumes. Verified by: observe enemy behavior, time freeze window.

**AC-10 — Ice Shard T3 does NOT freeze boss.**
Hit Devium with T3 Ice Shard. Devium slows (T1 slow) but does not fully stop. `is_in_group(&"boss")` check respected. Verified by: hit Devium, confirm boss continues moving (slowly).

**AC-11 — Light Bolt T2 chains to second enemy.**
Two enemies within 120 px. Fire Light Bolt at first. Second bolt spawns toward second enemy. Second enemy takes 12 damage. Verified by: two-enemy setup, confirm chain bolt fires.

**AC-12 — Light Bolt T2 does not chain when no second enemy in range.**
Only one enemy in room. Fire Light Bolt T2. No secondary bolt spawned. No crash. Verified by: single-enemy room, fire, inspect scene tree.

**AC-13 — Shadow Tendril T2 restores HP on hit.**
Player at partial HP. Upgrade Shadow Tendril to T2. Hit enemy. Player HP increases by 5. Capped at MAX_HP. Verified by: track HP before and after hit.

**AC-14 — Shadow Tendril T3 roots non-boss enemy.**
Hit regular enemy with T3 Shadow Tendril. Enemy velocity = 0 for 1.5s. Cannot move or attack during root. Verified by: observe enemy behavior during root window.

**AC-15 — Conjure T2 pulses damage.**
Place Conjure orb near enemy. After 1.5s, enemy takes 8 damage. After 3.0s, enemy takes another 8 damage. Verified by: track enemy HP over 3s with orb adjacent.

**AC-16 — Conjure T3 orb orbits player.**
Upgrade Conjure to T3. Cast orb. Orb moves in clockwise circle around player at 64 px radius. One revolution per 3s. Verified by: visual inspection + distance check from player center.

**AC-17 — Rupture T2 shockwave hits nearby enemy.**
Two enemies within 48 px of each other. Rupture hits first enemy. Second enemy takes 20 shockwave damage. Verified by: positioned enemy pair, confirm second HP reduction.

**AC-18 — Rupture T3 embeds and detonates.**
Upgrade Rupture to T3. Hit enemy. Projectile stops at enemy, no immediate destruction. After 0.8s, detonation fires for 70 damage. Enemy dies from detonation if HP ≤ 70. Verified by: enemy with known HP, time detonation.

**AC-19 — Rupture T3 detonates at death position if enemy dies first.**
Enemy at 10 HP hit by Rupture T3. Enemy dies immediately from embed impact (does the projectile deal damage on embed? — yes, base impact damage of 35 still applies on contact). Detonation fires 0.8s later at death position. Any surviving nearby enemy takes 70 detonation damage. Verified by: multi-enemy setup, confirm detonation at correct position.

**AC-20 — Upgrade state persists across save/load.**
Purchase Fireball T1. Activate checkpoint (save). Quit game. Reload. `GameManager.spell_upgrades[&"fireball"]` = 1. Cast fireball — 28 damage confirmed. *(Blocked until SaveManager implemented.)*

**AC-21 — Locked spells cannot be upgraded.**
Game start: only Fireball unlocked. Open upgrade UI. Ice Shard row shows "Locked". Upgrade button absent/disabled. No spend possible. Verified by: fresh save, open UI, attempt interaction on locked row.
