# Zone/Room System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: Controlled Ascension (primary), Earned Truth (support)

## Overview

The Zone/Room System owns the spatial structure of the game world: room definition, zone grouping, room transitions, ability gates, room state persistence, and checkpoint/respawn management. Seven other systems depend on it — it is the second bottleneck in the design order, after the Spell System.

A **room** is the atomic unit of the world. It is a self-contained scene (`Room extends Node2D`) loaded one at a time into the game kernel's `RoomContainer`. Each room contains terrain (`TileMapLayer`), enemies, hazards, collectibles, spawn points (`Marker2D`), exits (`RoomExit extends Area2D`), and optional triggers. The player persists at game level and is never part of a room scene — it is repositioned to the correct spawn point after each room load.

A **zone** is a named grouping of rooms sharing aesthetic, music, and narrative context. Zones are defined by `ZoneResource` data files. The system tracks the current zone and fires `GameManager.zone_entered` on first visit to a new zone. Zone identity drives music selection, ambient sound, and palette context — but no zone-level loading. Zones are logical, not technical containers.

**Ability gates** are `RoomExit` nodes that check `GameManager.has_ability()` before allowing transition. If the required ability is absent, the exit is inert — visually blocked, input silent. When the ability is unlocked, the exit becomes traversable without room reload.

Room state persistence is minimal at MVP: boss room clear flags are saved (via Save/Load System) so boss rooms stay empty after defeat. Regular enemy state is not persisted — rooms reset on reload. Collectible state (spells, materials) is persisted per item via Save/Load.

## Player Fantasy

The world was built for him before it decided to kill him. He knows these corridors. He knows which doors were locked for initiates and which were locked for him specifically. The distinction matters now.

Movement through zones should feel like reading a sentence backward — recognizing the words but understanding now what they meant all along. The training ground is familiar. The archive is unfamiliar in the way that a room you were forbidden is unfamiliar: not unknown, just withheld. The inner sanctum is both.

Ability gates should not feel like obstacles. They should feel like the world catching up to what the wizard has become. The door he walked past for six years as a student opens now not because the door changed. He did.

## Detailed Design

### Room Structure

Every room is a scene inheriting from `room_base.tscn` (`class_name Room extends Node2D`). Required child node structure:

```
Room (Node2D)
  Terrain         (TileMapLayer)   — collision + visuals
  SpawnPoints     (Node2D)
    PlayerSpawn   (Marker2D)       — default spawn; required
    [named]       (Marker2D)       — named spawns for directional entries
  Exits           (Node2D)
    [RoomExit]    (Area2D)         — one per connection to another room
  Enemies         (Node2D)         — enemy instances (optional)
  Hazards         (Node2D)         — hazard instances (optional)
  Collectibles    (Node2D)         — spells, materials (optional)
  Triggers        (Node2D)         — zone triggers, dialogue triggers (optional)
```

`room_id: String` is an exported property set per-scene. Stable identifier used by Save/Load. **Must be unique across the entire game** — enforced by convention, validated by `/consistency-check`.

`_on_enter()` is a virtual method called from `_ready()`. Room subclasses override it for room-specific logic (boss room activates barrier, etc.).

---

### Zone Structure

A zone is a `ZoneResource (Resource)`:

```
ZoneResource
  zone_id:              StringName    # e.g. &"training_grounds"
  display_name:         String        # "The Training Grounds"
  music_track:          AudioStream   # looping background music
  ambient_sfx:          AudioStream   # optional ambient sound layer
  rooms:                Array[String] # room_ids belonging to this zone
  first_visit_dialogue: String        # optional dialogue key on first entry
```

Current zone determined by looking up `GameManager.current_room` in all `ZoneResource` room lists. Lookup happens in `Room._ready()` after `room_id` is set.

---

### Room Transition Flow

Triggered when player enters a `RoomExit` Area2D:

1. `RoomExit._on_body_entered()` fires — `_used` guard prevents double-trigger.
2. **Ability gate check**: if `required_ability` set and `has_ability()` false → return immediately.
3. `SceneManager.change_room(target_room, target_spawn)` called.
4. `SceneManager` checks `_is_transitioning` guard — returns if mid-transition.
5. Game kernel `change_room()`:
   a. Fade out (0.3s).
   b. Old room `queue_free()`.
   c. New room loaded and added to `RoomContainer`.
   d. Wait one physics frame (TileMapLayer collisions generate).
   e. Player repositioned to named spawn point. `velocity = Vector2.ZERO`.
   f. Fade in (0.3s).
6. New `Room._ready()` fires: sets respawn, calls `_on_enter()`, updates current zone.

Player physics frozen during load; re-enabled after spawn.

---

### Spawn Points

One required `PlayerSpawn` Marker2D per room — the default entry. Additional named spawn points correspond to specific directional entries.

**Naming convention**: spawn point name matches the `target_spawn` value in the `RoomExit` that leads here. Example: `room2` has spawn `"from_room1"`; the exit in `room1` targeting `room2` sets `target_spawn = "from_room1"`. Falls back to first child of `SpawnPoints` if name not found.

---

### Ability Gates

`RoomExit` gains one export:

```
@export var required_ability: String = ""  # "" = no gate
```

- `""` → always traversable.
- Ability set + `has_ability()` false → exit inert. Player collides with visual barrier. No transition.
- Ability later granted → gate opens live. No room reload needed — `has_ability()` queried on each `body_entered`.

Visual barrier: child `Node2D` named `GateLock` on the `RoomExit` node. Shown when locked, hidden when open. Art is room-specific, not system-driven.

---

### Checkpoint / Respawn

`GameManager.set_respawn(position, room_id, scene_path)` called in `Room._ready()` — **only if the active checkpoint is not in this room**:

```gdscript
# Room._ready() guard — prevents overwriting an active checkpoint on respawn
if GameManager.checkpoint_room != self.scene_file_path:
    GameManager.set_respawn(spawn_point.global_position, room_id, scene_file_path)
```

Without this guard, respawning into the checkpoint room would overwrite the checkpoint with the room entrance position — the checkpoint would become a one-shot benefit.

On `player_died`:
1. Health reset to max.
2. `SceneManager.change_room(respawn_scene, "PlayerSpawn")`.
3. Player returns to start of last room entered.

**No mid-room checkpoints at MVP.** Checkpoint/Respawn System extends this by calling `set_respawn()` explicitly from safe-room triggers.

**Dependency note:** This section depends on Checkpoint/Respawn System's `checkpoint_room` field on GameManager. See `checkpoint-respawn-system.md`.

---

### Room State Persistence

| State Type | Persisted | How |
|-----------|-----------|-----|
| Boss room cleared | Yes | `SaveManager` flag `"boss_cleared_{room_id}"` |
| Regular enemy defeated | No | Enemies respawn on room reload |
| Collectible picked up | Yes | `SaveManager` flag `"collected_{item_id}"` per item |
| Room visited | Yes | `SaveManager` flag `"visited_{room_id}"` on first entry |

Boss rooms check `"boss_cleared_{room_id}"` in `_on_enter()` — if true, boss and barrier not instantiated.

---

### Zone Entry Detection

In `Room._ready()` after `room_id` is set:

1. Look up `room_id` across all `ZoneResource` files to identify current zone.
2. If zone changed from `GameManager.current_zone`: emit `GameManager.zone_entered(zone)`.
3. If first visit (`"visited_{zone_id}"` flag absent): emit `GameManager.zone_first_visit(zone)`, set flag.
4. Start zone music if track differs from current.

---

### Interactions with Other Systems

| System | Direction | Exchange |
|--------|-----------|---------|
| Save/Load System | Bidirectional | Room state flags read/written; respawn scene/position saved |
| Camera System | Zone/Room → | Player `global_position` available after spawn reposition |
| Progression System | → Zone/Room | `has_ability()` queried live by gated `RoomExit` |
| Hazard System | Room owns | Hazard instances in `Hazards` node; respawn on room reload |
| Dialogue System | → Zone/Room | `zone_first_visit` signal triggers first-visit dialogue |
| Enemy AI System | Room owns | Enemy instances in `Enemies` node |
| Map System (VS) | Zone/Room → | `visited_{room_id}` flags drive map reveal |
| Checkpoint/Respawn System | Extends | Explicit `set_respawn()` calls from checkpoint triggers |

## Formulas

### Transition Timing

```
total_transition_time = fade_out + load_time + physics_frame + fade_in
                      = 0.3s + load_time + ~0.016s + 0.3s
                      ≈ 0.6s + load_time

Target: load_time < 0.5s per room at MVP scope
Acceptable total felt transition: ≤ 1.1s (0.6s fade masks load)
```

### Ability Gate Unlock Latency

```
-- Gate check on body_entered (physics frame event)
-- has_ability() is O(1) dictionary lookup
-- No polling — unlock felt instantly on next player contact with exit
```

### Room State Flag Naming

```
Boss cleared:       "boss_cleared_"  + room_id   → "boss_cleared_devium_arena"
Collectible picked: "collected_"     + item_id   → "collected_spell_ice_shard"
Room visited:       "visited_"       + room_id   → "visited_training_corridor_1"
Zone first visit:   "visited_"       + zone_id   → "visited_training_grounds"
```

### Zone Lookup Complexity

```
MVP scope: ~5 zones × ~6 rooms = 30 rooms
Zone lookup: O(zones × rooms_per_zone) = O(30) per room entry — negligible, no caching needed
```

### World Scale Reference

| Unit | Value | Notes |
|------|-------|-------|
| Player height | ~32 px | Reference for room proportions |
| Tile size | 16 × 16 px | TileMapLayer standard |
| Min room width | 320 px (20 tiles) | Minimum traversable space |
| Max room width | 640 px (40 tiles) | Current room_base target |
| Room height | 192–320 px (12–20 tiles) | Varies by room type |
| Jump clearance needed | 60 px min | Movement System peak height ≈ 58.7 px |
| Dash clearance needed | 40 px min | Movement System dash distance ≈ 39.6 px |

Level designers must validate room geometry against Movement System formulas.

## Edge Cases

**EC-01 — Player triggers two RoomExits simultaneously.**
`_used` flag on `RoomExit` prevents double-trigger from the same exit. `SceneManager._is_transitioning` prevents a second `change_room()` if two different exits fire in the same frame. First transition wins.

**EC-02 — Player dies during room transition.**
`player_died` fires while `SceneManager._is_transitioning` is true. Respawn `change_room()` returns immediately due to guard — death silently fails. **Resolution**: on `player_died`, force-clear `_is_transitioning` before issuing the respawn transition. Death always takes priority over an in-progress room load.

**EC-03 — Ability granted while player stands inside a locked exit.**
`body_entered` fires on entry only, not continuously. Standing in the exit when ability is granted does not open the gate. Player must step out and re-enter. Acceptable at MVP — ability unlocks happen during dialogue/cutscene, not while player is in an exit.

**EC-04 — Target spawn point name not found in destination room.**
Falls back to first child of `SpawnPoints`. If `SpawnPoints` is empty or missing, player position is unchanged — spawns at (0, 0). **Guard required**: `Room._ready()` must print an error if `SpawnPoints` has no children.

**EC-05 — Boss room entered after boss already defeated.**
`_on_enter()` checks `"boss_cleared_{room_id}"`. If true: boss not instantiated, barrier not spawned, room loads as empty arena. Normal room load flow — no special transition.

**EC-06 — room_id is empty string.**
`set_respawn()` stores empty `room_id`. Zone lookup fails. `SaveManager` flag keys collide. **Guard required**: `Room._ready()` must assert `room_id != ""` and print an error. Treat as a data authoring error.

**EC-07 — Two rooms share the same room_id.**
Save flags collide — one room's state silently overwrites the other. No runtime crash. **Enforced by convention**; `/consistency-check` validates uniqueness across all room scenes.

**EC-08 — SceneManager called before game kernel is in scene tree.**
`_get_game()` returns null. `change_room()` silently does nothing. Only occurs before `game.gd._ready()` — startup order prevents this during gameplay.

**EC-09 — room_id appears in multiple ZoneResources.**
Zone lookup returns first match — room has ambiguous zone identity. First match wins. `/consistency-check` must validate no room_id appears in more than one `ZoneResource`.

**EC-10 — Player killed by hazard in same frame as room transition.**
Both `player_died` and `body_entered` fire. EC-02 resolution applies: `player_died` force-clears `_is_transitioning`. Death wins — player respawns in current room. Room transition is discarded.

## Dependencies

### Systems this requires

| System | What Zone/Room needs |
|--------|---------------------|
| **Save/Load System** | `SaveManager.get_flag(key)`, `SaveManager.set_flag(key, value)` — room/zone visited, boss cleared, collectible picked flags |
| **Progression System** | `GameManager.has_ability(String)` — queried live by gated `RoomExit` |
| **Health System** | `GameManager.player_died` signal — triggers respawn transition |
| **GameManager autoload** | `set_respawn()`, `current_room`, `current_zone`; `zone_entered`, `zone_first_visit` signals |
| **SceneManager autoload** | `change_room(scene_path, spawn_point)` — transition guard and game kernel bridge |

### Systems that require this

| System | What it needs from Zone/Room |
|--------|------------------------------|
| **Camera System** | Player `global_position` in new room — available after spawn reposition |
| **Hazard System** | `Hazards` node in room scene — owns hazard instances |
| **Enemy AI System** | `Enemies` node in room scene — owns enemy instances |
| **Dialogue System** | `GameManager.zone_first_visit(zone)` signal — triggers first-visit dialogue |
| **Checkpoint/Respawn System** | `GameManager.set_respawn()` — checkpoints call this explicitly |
| **Material System** | `Collectibles` node in room scene — owns material instances |
| **Ability Gate System (VS)** | `RoomExit.required_ability` — gate logic built into this system |
| **Map System (VS)** | `"visited_{room_id}"` flags — drives map reveal |
| **Tutorial System (VS)** | `Triggers` node in room — tutorial triggers placed here |
| **Lore Fragment System (Alpha)** | `Collectibles` / `Triggers` node — lore items placed in rooms |

### Hard blockers (must exist before Zone/Room is testable)

- `SceneManager` autoload with `change_room()` implemented
- `GameManager` autoload with `set_respawn()`, `current_room`, `player_died`
- `SaveManager` autoload with `get_flag()`, `set_flag()`
- `room_base.tscn` with required child node structure
- At least two rooms connected by a `RoomExit` to test transition

## Tuning Knobs

### Transition Feel

| Knob | Current | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| Fade-out duration | 0.3 s | 0.1–0.6 | Exit snappiness. Below 0.1: jarring cut. Above 0.6: player notices wait. |
| Fade-in duration | 0.3 s | 0.1–0.6 | Entry feel. Faster fade-in (0.2s) than fade-out (0.3s) feels more energetic. |
| Fade color | Black | — | Black is standard. Zone-specific tint (e.g. deep red for boss transition) is a polish addition. |

### World Structure

| Knob | MVP Target | Range | Effect |
|------|-----------|-------|--------|
| Rooms per zone | ~6 | 3–10 | Zone density. Fewer: zones feel thin. More: harder to maintain consistent pacing and aesthetic. |
| Total zones at MVP | 1 | 1–2 | 1 zone validates the core hypothesis. Second zone validates zone transitions. |
| Room width | 320–640 px | 192–960 | Traversal time. At SPEED=90: 640 px room = ~7s to cross at full run. |
| Vertical room layers | 1–2 | 1–3 | Single-layer rooms are fastest to design and test; add layers for platforming variety. |

### Respawn

| Knob | Current | Notes |
|------|---------|-------|
| Respawn granularity | Per room entry | Player returns to room start on death. Checkpoint/Respawn System adds finer granularity post-MVP. |
| Respawn health | Full reset | `reset_health()` on respawn. No partial preservation at MVP. |

### Room Design Constraints (derived from Movement System — not tunable)

| Constraint | Value | Source |
|-----------|-------|--------|
| Min ceiling clearance for full jump | 60 px | Movement GDD: peak height ≈ 58.7 px |
| Min horizontal gap bridgeable by run+jump | 58 px | Movement GDD: horizontal range ≈ 58.5 px |
| Min horizontal gap bridgeable by dash | 40 px | Movement GDD: dash distance ≈ 39.6 px |
| Min platform width for comfortable landing | 32 px (2 tiles) | Player width + margin |

Level designers must build to these constraints. Rooms that violate them create movement feel regressions.

## Visual/Audio Requirements

### Transition Visual

Fade to black and back — `ColorRect` overlay with `modulate.a` tween. Covers full viewport; player and HUD fade with it.

**Zone-specific tint (polish):** Boss room transitions may fade to deep red or desaturated instead of black. Implemented in boss room `_on_enter()` override — not required at MVP.

### Ability Gate Visual

Locked exits must be visually distinct from open exits at a glance:

- **Locked**: visible barrier — stone wall, iron bars, energy field, or glyph seal. Art is zone-specific.
- **Open**: clear passage visible. No barrier object.
- No UI tooltip or text label at MVP — the visual barrier is the communication.
- Polish addition: gate-open animation on `GameManager.ability_unlocked` signal (glyph dissolves, bars retract).

### Zone Music

Each `ZoneResource` specifies a `music_track`. On zone entry:
- Same zone: music continues uninterrupted.
- New zone: current track fades out, new track fades in (crossfade 1.0–2.0s).
- Boss encounter: `boss_appeared` triggers boss music override (already implemented). Zone music resumes on `boss_defeated`.

### Room Transition Audio

No dedicated transition SFX at MVP — fade visual is sufficient. Polish addition: brief ambient swell timed to fade-out.

### Zone Ambient SFX

`ZoneResource.ambient_sfx` loops at reduced volume independently of music. Stops on boss encounter. Examples: stone corridor drip, wind through ruins, distant chanting.

### Spawn Point Markers

`Marker2D` nodes are editor gizmos only — not visible at runtime. No in-game visual needed.

## UI Requirements

### Zone Name Display

On first entry to a zone, display `ZoneResource.display_name` centered on screen — large text, fades in then out over ~3s, non-blocking. Signal: `GameManager.zone_first_visit(zone)`. HUD System renders it; Zone/Room System only emits. Suppressed on repeat visits via `"visited_{zone_id}"` flag.

### Transition Overlay

Fade `ColorRect` owned by game kernel scene (`game.tscn`), above the HUD in scene tree. Covers everything including HUD. HUD System does not manage it.

### Ability Gate Feedback

No HUD element at MVP. World-space barrier visual is sufficient. Polish addition: screen-edge pulse or controller rumble on repeated failed entry attempts.

### Map (Vertical Slice)

Map UI owned by Map System GDD (VS tier). Zone/Room System provides `"visited_{room_id}"` flags — Map System reads and renders. No map at MVP.

### Nothing else required

Zone/Room System does not drive health bars, mana bars, spell slots, or boss bars. Physics freeze during transition (game kernel) handles input suppression — no UI lock needed.

## Acceptance Criteria

**AC-01 — Room transition fires on exit contact.**
Walk player into a `RoomExit`. Screen fades to black, new room loads, player spawns at correct spawn point, screen fades in. Pass: complete transition without crash; player at correct position.

**AC-02 — Player spawns at named spawn point.**
`RoomExit` sets `target_spawn = "from_room1"`. Destination has `Marker2D` named `"from_room1"`. After transition, player position matches that marker. Pass: player at named spawn, not `PlayerSpawn`.

**AC-03 — Spawn fallback works.**
`target_spawn` set to a name that doesn't exist in destination. Player spawns at first child of `SpawnPoints`. Pass: no crash; player at fallback position.

**AC-04 — Double-trigger prevented.**
Two `RoomExit` Areas overlap. Player walks through both simultaneously. One transition fires. Pass: single room load only.

**AC-05 — Ability gate blocks without ability.**
`RoomExit.required_ability = "dash"`. `dash` not granted. Walk into exit. No transition. Player collides with visual barrier. Pass: gate inert, no room load.

**AC-06 — Ability gate opens after unlock.**
Same setup as AC-05. Grant `dash` via debug console. Walk into exit. Transition fires. Pass: traversable immediately after unlock, no room reload needed.

**AC-07 — Respawn set on room entry.**
Enter any room. Trigger player death. Player respawns at start of that room. Pass: respawn matches `PlayerSpawn` of last entered room.

**AC-08 — Boss room stays clear after defeat.**
Defeat boss. Exit room. Re-enter. Boss not present, barrier not present. Pass: `"boss_cleared_{room_id}"` persists; room loads empty.

**AC-09 — Zone first-visit signal fires once.**
Enter a zone for the first time — zone name display appears. Exit zone, re-enter. No second display. Pass: signal fires exactly once per zone per save file.

**AC-10 — Zone music changes on zone entry.**
Enter zone A — track A plays. Transition to zone B — track A fades, track B fades in. Pass: correct track per zone, no abrupt cut.

**AC-11 — Boss music overrides zone music.**
Enter boss room — boss music replaces zone music. Defeat boss — zone music resumes. Pass: override and restore both correct.

**AC-12 — Empty room_id logs error.**
Room scene with `room_id = ""` loads. Error appears in Godot output log. No crash. Pass: guard triggers, game continues.

**AC-13 — Player velocity zeroed after transition.**
Run at full speed into exit. After transition, player is stationary at spawn. Pass: no carry-through momentum.

**AC-14 — Physics frozen during load, restored after spawn.**
During transition fade/load, player does not fall under gravity. After spawn, player responds to input immediately. Pass: physics off during load, on after spawn.

**AC-15 — Death during transition respawns correctly.**
Trigger transition (fade begins). Before load completes, trigger `player_died`. Player respawns at last entered room. No stuck state. Pass: `_is_transitioning` force-cleared; death respawn completes cleanly.
