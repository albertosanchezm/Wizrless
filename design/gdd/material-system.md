# Material System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-03
> **Implements Pillar**: Controlled Ascension (progression currency)

## Overview

The Material System defines the resource economy: what materials exist, how players acquire them, and how they are stored and spent. Materials are the currency for spell upgrades — the only progression mechanic beyond ability unlocks.

Six material types exist, one per spell element. Materials drop from enemies on death and are found in fixed world caches. All drops are deterministic — no randomization. A Sentinel near the ice zone always drops one Frost Crystal; a cache behind a locked door always contains exactly what the designer placed. Power is found and chosen, never randomly granted.

Players auto-collect materials by walking near them. No interaction button required. A `MaterialDrop` scene (Area2D) handles pickup. Materials accumulate in a dictionary in `GameManager` and persist via the Save/Load System. The Spell Upgrade System is the sole consumer — it reads and spends material counts.

## Player Fantasy

Every enemy has something to give.

Killing a fire elemental feels purposeful because it drops something the player can actually use. Walking back through a zone already cleared yields nothing — the materials are gone, the enemies are dead, and the player must move forward. The game always pushes the player toward the new, the undiscovered, the harder.

Finding a hidden material cache behind a breakable wall or past a jump the player barely makes feels like a secret the world kept just for them. The choice of what to upgrade with those materials is the most meaningful economic decision in the game.

## Detailed Design

### Material Types

Six types, one per spell element. Identified by `StringName` in code.

| ID (StringName) | Display Name | Element | Source Enemies | Color |
|-----------------|-------------|---------|----------------|-------|
| `&"ember"` | Ember | Fire | Fire-element enemies | `#FF6633` |
| `&"frost"` | Frost Crystal | Ice | Ice-element enemies | `#88DDFF` |
| `&"radiance"` | Radiance | Light | Light-element enemies | `#FFEEAA` |
| `&"void_shard"` | Void Shard | Shadow | Shadow-element enemies | `#9944CC` |
| `&"aether"` | Aether | Conjure | Conjure-element enemies | `#44FFCC` |
| `&"shatter"` | Shatter | Rupture | Rupture-element enemies | `#FF4466` |

Each material type upgrades only its corresponding spell. Ember upgrades Fireball. Frost Crystal upgrades Ice Shard. Etc. No cross-element spending.

---

### Inventory Model

Stored in `GameManager` as a single dictionary:

```gdscript
var materials: Dictionary = {}
# { StringName → int }
# e.g. { &"ember": 5, &"frost": 2 }
# Keys absent = 0 count (not stored until first pickup)
```

**No inventory cap per type at MVP.** Player accumulates freely. Balance via total available materials in the world (finite — no respawning enemies).

**GameManager additions required:**

```gdscript
signal material_collected(type: StringName, amount: int, new_total: int)

func add_material(type: StringName, amount: int) -> void:
    materials[type] = get_material_count(type) + amount
    material_collected.emit(type, amount, materials[type])

func spend_material(type: StringName, amount: int) -> bool:
    if get_material_count(type) < amount: return false
    materials[type] -= amount
    return true

func get_material_count(type: StringName) -> int:
    return materials.get(type, 0)
```

---

### MaterialDrop Scene

Spawned by enemies on death and placed statically as world caches.

```
MaterialDrop (Area2D)
├─ Sprite2D           -- element-colored gem sprite, bobs gently via AnimationPlayer
├─ CollisionShape2D   -- CircleShape2D, radius 20 px
└─ AnimationPlayer    -- "bob" animation (y offset ±4 px, 0.8 s loop)
```

```gdscript
# scripts/pickups/material_drop.gd
@export var material_type: StringName = &""
@export var amount: int = 1

collision_layer = 0    # passive
collision_mask  = 2    # detects player only

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group(&"player"): return
    GameManager.add_material(material_type, amount)
    queue_free()
```

Pickup is instant and silent (HUD handles visual feedback via `material_collected` signal). Drop despawns on collect.

---

### Enemy Drops

Each enemy exposes two exports on its script:

```gdscript
@export var drop_material: StringName = &""   # empty = no drop
@export var drop_amount:   int        = 1
```

On death (in `BaseEnemy.die()` or enemy death state):

```gdscript
func _on_die() -> void:
    if drop_material != &"":
        var drop := MATERIAL_DROP_SCENE.instantiate()
        drop.material_type = drop_material
        drop.amount        = drop_amount
        drop.global_position = global_position + Vector2(0, -8)
        get_level().add_child(drop)     # level root, not enemy parent — survives room cleanup
```

Drop added to level root (same rule as enemy projectiles — EC-10 from Hazard System GDD).

**MVP drop table:**

| Enemy | Type | `drop_material` | `drop_amount` |
|-------|------|-----------------|--------------|
| Sentinel (melee) | Regular | Assigned per room's element | 1 |
| Warden (ranged) | Regular | Assigned per room's element | 1 |
| Devium (boss) | Boss | `&"frost"` (ice theme) | 8 |

Bosses drop their material on the death state's `_on_die()` call, not mid-fight. Level designers assign `drop_material` per enemy instance in the inspector — same enemy type can drop different materials in different rooms based on zone theme.

---

### World Caches

Static `MaterialCache` nodes placed by level designers in rooms. One-time collectibles — do not respawn.

```
MaterialCache (Area2D)
├─ Sprite2D           -- glowing chest or crystal formation
├─ CollisionShape2D   -- RectangleShape2D, fits sprite
└─ ParticleEffect     -- ambient glow particles (CPUParticles2D)
```

```gdscript
# scripts/pickups/material_cache.gd
@export var cache_id:       String    = ""     # unique per world, e.g. "room3_ice_cache"
@export var material_type:  StringName = &""
@export var amount:         int       = 3      # caches give more than single drops

func _ready() -> void:
    if GameManager.is_cache_collected(cache_id):
        queue_free()
        return
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group(&"player"): return
    GameManager.add_material(material_type, amount)
    GameManager.mark_cache_collected(cache_id)
    # play collect VFX, then queue_free
    queue_free()
```

**GameManager additions for cache persistence:**

```gdscript
var collected_caches: Dictionary = {}   # { cache_id: bool }

func mark_cache_collected(id: String) -> void:
    collected_caches[id] = true

func is_cache_collected(id: String) -> bool:
    return collected_caches.get(id, false)
```

Cache state saves alongside materials in the `"materials"` save slice.

---

### Save Schema

Registered under key `"materials"` with the Save/Load System:

```json
{
  "materials": {
    "ember": 3,
    "frost": 7,
    "radiance": 0
  },
  "collected_caches": {
    "room3_ice_cache": true,
    "room5_fire_cache": true
  }
}
```

Only non-zero material counts need to be stored; missing keys read as 0 on load. Collected caches must be fully stored (absence ≠ not collected — on load, a missing key is treated as not collected, allowing collection again). All collected caches must be persisted.

---

### Spend Interface

The Spell Upgrade System calls `GameManager.spend_material()` to consume on upgrade purchase:

```gdscript
# Spell Upgrade System (defined in spell-upgrade-system.gd):
if GameManager.spend_material(&"ember", cost):
    _apply_fireball_upgrade(level)
else:
    # insufficient — show error feedback in upgrade UI
```

`spend_material()` returns false if insufficient — caller handles UI feedback. No overdraft.

---

### No Respawn Rule

Enemies in Wizrless do not respawn after a room is cleared (per Zone/Room System GDD). Material drops from enemies are therefore **finite and non-renewable**. World caches are also one-time. The total materials available in the game world is fixed and known — level designers can calculate exact upgrade paths available per playthrough.

This is a deliberate constraint from the Controlled Ascension pillar. Players cannot grind. Every upgrade decision is made from a known total supply.

## Formulas

### Total Materials Available (Design Guideline)

```
T_materials(type) = sum(enemy drops of that type across all rooms)
                  + sum(cache amounts of that type across all rooms)

Design target per type: enough to purchase 2–3 upgrades of that spell.
(Upgrade costs defined in Spell Upgrade System GDD.)

Reference (Frost Crystal, MVP):
  Devium boss drop:    8
  Ice room enemies:   ~6 (6 Wardens × 1 each, estimated)
  Ice cache(s):        6 (2 caches × 3 each, estimated)
  Total:             ~20 Frost Crystals available

If Spell Upgrade System sets upgrade costs at 5/8/12 for tiers 1/2/3:
  T1 cost: 5  → player can afford after ~5 enemies
  T2 cost: 8  → affordable after boss + some extras
  T3 cost: 12 → requires finding both caches
```

### Pickup Radius

```
MaterialDrop CollisionShape2D: CircleShape2D, radius = 20 px
Player CharacterBody2D half-width: ~8 px

Effective pickup trigger: player center within ~28 px of drop center.
At player speed 90 px/s: player passes through pickup zone in ~0.6 s.
Auto-collect is reliable without stopping.
```

### Variable Definitions

| Variable | Default | Description |
|----------|---------|-------------|
| `drop_material` | `&""` | Enemy export: material type to drop on death |
| `drop_amount` | 1 | Enemy export: quantity dropped |
| `cache_id` | `""` | Cache export: unique ID for persistence |
| `amount` (cache) | 3 | Cache export: quantity in cache |
| Pickup radius | 20 px | MaterialDrop collision circle radius |
| Boss drop amount | 8 | Devium Frost Crystal drop on defeat |

## Edge Cases

**EC-01 — Enemy killed off-screen (projectile, hazard).**
`_on_die()` fires regardless of visibility. Drop spawns at `global_position`. If off-screen, drop is in the world waiting. Player walks to the drop's position to collect. Correct.

**EC-02 — MaterialDrop spawned, then room unloads before player collects.**
Drop added to level root — not the room node. Survives room unload. If player transitions to adjacent room and back, drop is still present. Player can collect retroactively. Correct.

**EC-03 — `drop_material` is empty string on enemy.**
Guard: `if drop_material != &"": spawn drop`. No drop spawned. No crash. Used for enemies that intentionally give no materials (e.g., summoned minions, tutorial enemies).

**EC-04 — MaterialCache `cache_id` is empty string.**
`is_cache_collected("")` returns false → cache collects normally. `mark_cache_collected("")` writes `{ "": true }`. All caches with empty ID share the same persistence key — collecting one marks all others as collected. **Level design authoring error.** Guard in `_ready()`: `assert(cache_id != "", "MaterialCache has no cache_id set")`. Fail loud in dev.

**EC-05 — Player has insufficient materials for upgrade.**
`spend_material()` returns false. Upgrade not applied. Caller shows insufficient funds feedback. No partial spend. Materials unchanged.

**EC-06 — materials dictionary not in save file (old save).**
`GameManager.materials = {}` on load (default). All materials read as 0. Player starts with empty inventory. No crash.

**EC-07 — collected_caches not in save file (old save).**
All caches treated as not collected. Player can re-collect them. Minor windfall if this occurs post-launch. Acceptable for MVP.

**EC-08 — MaterialDrop still in world when player loads a save from before it spawned.**
Drop is a scene node — not persisted to save file. Save file restores material counts as of last save. If player earned materials from a drop but hasn't saved since: on load, those materials are lost AND the enemy is dead (boss death is persisted). Boss deaths and material counts must save together. **Rule: checkpoint activation (which triggers save) should be placed after major enemy encounters, not before.** Level design responsibility.

**EC-09 — Two MaterialDrops overlap exactly (multi-drop on same position).**
Each Area2D fires `body_entered` independently. Player collects both in one pass. Correct. Two add_material() calls for potentially different types. No conflict.

**EC-10 — Player dies mid-collection animation.**
`queue_free()` on pickup is instant — no animation. If player presses into pickup and dies on same frame: pickup fires `body_entered` → material added → player death fires. Material is added before death. On respawn, material is retained in GameManager (not rolled back). Correct: player earned it before dying.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Enemy Base System** | Drop trigger | Enemy `_on_die()` spawns MaterialDrop. Enemy base must provide a death hook. |
| **Save/Load System** | Sends to | `materials` and `collected_caches` must be registered as save providers under `"materials"` key |
| **Zone/Room System** | Context | No enemy respawn means finite materials per playthrough. MaterialCaches placed in room scenes by level designers. |
| **Spell Upgrade System** | Consumer | Reads `get_material_count()`, calls `spend_material()`. Spell Upgrade System GDD defines costs. |
| **Player** | Proximity trigger | Player `collision_mask` must include layer 2 so MaterialDrop's `collision_mask = 2` fires correctly |
| **HUD System** | Subscriber | Subscribes to `material_collected` signal to display pickup feedback. HUD System GDD defines the display spec. |

**Reverse dependencies:**
- Spell Upgrade System: depends entirely on `spend_material()` and `get_material_count()` defined here.
- HUD System: displays material counts using `get_material_count()` per type.
- Save/Load System: must include `materials` and `collected_caches` in its save schema.

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `drop_amount` (regular enemy) | 1 | 1–3 | 1 = tight economy, every kill matters. 3 = loose economy, upgrades feel cheap. Set to 1 at MVP, raise if playtesting finds progression too slow. |
| `drop_amount` (boss) | 8 | 5–15 | Boss kill feels significant at 8. Below 5: anticlimactic. Above 15: oversupplies the economy. |
| `amount` (world cache) | 3 | 2–8 | Caches should feel like a meaningful find. 3 = solid reward. 8 = major stash (hidden/hard-to-reach only). |
| Pickup radius | 20 px | 12–36 px | Below 12: player must nearly stand on it. Above 36: collects when walking past at distance (can feel unintentional). 20 is clean. |
| Total per-type supply | ~20 | design-time | Calibrate against upgrade cost tiers. Level designers sum `T_materials(type)` spreadsheet per zone. |

## Acceptance Criteria

**AC-01 — Enemy drops material on death.**
Enemy with `drop_material = &"ember"`, `drop_amount = 1` killed → MaterialDrop spawns at enemy position with correct type and amount. MaterialDrop visible in scene tree at level root. Verified by: kill ember enemy, check scene tree.

**AC-02 — Auto-collect on proximity.**
Player walks into MaterialDrop collision radius (20 px). `GameManager.materials[&"ember"]` increments by 1. MaterialDrop node freed. No input required. Verified by: walk into drop, check GameManager.materials in debugger.

**AC-03 — material_collected signal fires.**
`GameManager.material_collected` emits with correct `(type, amount, new_total)` on each pickup. Verified by: connect signal in test script, collect material, confirm emission.

**AC-04 — MaterialCache one-time collect.**
Player collects MaterialCache. Cache node freed. `collected_caches["room3_ice_cache"] = true`. Re-entering room: cache does not reappear (freed in `_ready()` guard). Verified by: collect cache, exit room, re-enter, confirm absent.

**AC-05 — No enemy respawn = finite supply.**
Room cleared of all enemies. Re-entering room: no enemies, no new drops. Material count does not increase from re-entry. Verified by: clear room, re-enter, confirm no new drops.

**AC-06 — spend_material returns false when insufficient.**
`GameManager.materials[&"frost"] = 2`. Call `spend_material(&"frost", 5)` → returns false. `materials[&"frost"]` still equals 2. Verified by: unit test or debugger call.

**AC-07 — spend_material deducts on success.**
`GameManager.materials[&"frost"] = 10`. Call `spend_material(&"frost", 5)` → returns true. `materials[&"frost"]` equals 5. Verified by: debugger call.

**AC-08 — Materials persist across checkpoint save.**
Player collects 5 ember. Activates checkpoint (triggers save). Closes game. Reopens. `GameManager.materials[&"ember"]` equals 5. *(Blocked until SaveManager.save_game() implemented.)*

**AC-09 — Devium drops 8 Frost Crystal on defeat.**
Devium health reaches 0. Death sequence completes. 8 MaterialDrop nodes with `material_type = &"frost"` spawn near Devium's death position at level root. Player collects all 8. Verified by: defeat Devium, collect drops, confirm count.

**AC-10 — Empty drop_material enemy spawns no drop.**
Enemy with `drop_material = &""` dies → no MaterialDrop spawned. No crash. Verified by: kill enemy with empty drop config, check scene tree for orphan drops.
