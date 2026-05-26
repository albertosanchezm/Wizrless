# ADR-0012: Zone/Room System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (World Structure) |
| **Knowledge Risk** | MEDIUM — TileMapLayer is a Godot 4.4+ API change (was TileMap in 4.3) |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `design/gdd/zone-room-system.md` |
| **Post-Cutoff APIs Used** | `TileMapLayer` (Godot 4.4+) — **breaking change from `TileMap`**. Use `TileMapLayer` not `TileMap` for room terrain. Verify `TileMapLayer` API in 4.6 engine reference. |
| **Verification Required** | (1) Confirm `TileMapLayer` is the correct class name in Godot 4.6 (not `TileMap`). (2) Confirm `get_tree().change_scene_to_packed()` vs `SceneManager` custom implementation — project uses SceneManager autoload. (3) Confirm `Node.scene_file_path` property exists and returns the scene's `.tscn` path in 4.6. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (SceneManager autoload #4), ADR-0002 (GameManager — `player_died`, `set_respawn()`, `current_zone`), ADR-0005 (SaveManager — room state flags), ADR-0006 (Camera — limit_target push on room entry) |
| **Enables** | ADR-0015 (Hazard System — `Hazards` node in room), ADR-0019 (Boss System — boss arena room), ADR-0016 (Checkpoint System — `set_respawn()` calls), ADR-0017 (Dialogue System — `zone_first_visit` signal) |
| **Blocks** | No level design work may start until room base scene and transition flow are Accepted |

## Context

Room structure and transition flow are implemented but undocumented. `TileMapLayer` vs `TileMap` API change in Godot 4.4 is a critical breaking change. This ADR formalises the contract before more rooms are authored.

## Decision

### Room Base Structure

Every room is a scene extending `room_base.tscn` (`class_name Room extends Node2D`):

```
Room (Node2D)
  @export var room_id: String = ""        # REQUIRED; unique across all rooms; guard: assert room_id != ""
  Terrain         (TileMapLayer)          # NOT TileMap — Godot 4.4+ breaking change
  SpawnPoints     (Node2D)
    PlayerSpawn   (Marker2D)              # REQUIRED default spawn
    [named...]    (Marker2D)              # directional entries; name matches target_spawn
  Exits           (Node2D)
    [RoomExit...]  (Area2D)               # one per connection
  Enemies         (Node2D)               # optional
  Hazards         (Node2D)               # optional
  Collectibles    (Node2D)               # optional
  Triggers        (Node2D)               # optional
```

`room_id` must be unique across all rooms. Validated by `/consistency-check`. Guard in `_ready()`:
```gdscript
assert(room_id != "", "Room %s has empty room_id" % name)
```

### Zone Resource

```gdscript
class_name ZoneResource
extends Resource

@export var zone_id:              StringName
@export var display_name:         String
@export var music_track:          AudioStream
@export var ambient_sfx:          AudioStream
@export var rooms:                Array[String]  # room_ids in this zone
@export var first_visit_dialogue: String = ""
```

Zone lookup: Room._ready() searches all loaded ZoneResources for room_id. O(zones × rooms/zone) = O(30) at MVP — no caching needed.

### RoomExit (Ability Gate)

```gdscript
class_name RoomExit
extends Area2D

@export var target_room:    String  # scene path: "res://scenes/rooms/room2.tscn"
@export var target_spawn:   String = "PlayerSpawn"  # Marker2D name in destination
@export var required_ability: String = ""  # "" = no gate; "dash" = requires dash ability

var _used: bool = false             # prevents double-trigger

func _on_body_entered(body: Node2D) -> void:
    if _used: return
    if not body.is_in_group(&"player"): return
    if required_ability != "" and not GameManager.has_ability(required_ability): return
    _used = true
    SceneManager.change_room(target_room, target_spawn)
```

Gate opens live: `has_ability()` queried on each `body_entered`. No room reload needed when ability is granted.

### Room Transition Flow

```
1. Player enters RoomExit Area2D
2. _used guard + player group check + ability gate check
3. SceneManager.change_room(target_room, target_spawn):
   a. _is_transitioning guard (prevents double-transition)
   b. Fade out (0.3s)
   c. Current room queue_free()
   d. New room instantiated and added to RoomContainer
   e. Wait one physics frame (TileMapLayer collisions generate)
   f. Player repositioned to spawn; velocity = Vector2.ZERO
   g. Fade in (0.3s)
4. New Room._ready() fires:
   a. assert room_id != ""
   b. Set camera limit_target on pcam nodes
   c. Update GameManager.current_room
   d. Zone detection + zone_entered signal
   e. Respawn guard: set GameManager respawn if checkpoint_room != scene_file_path
   f. Boss room: check boss_cleared flag; skip boss + barrier if true
   g. Call _on_enter() virtual method
```

Player physics frozen during load (velocity zeroed at spawn). Re-enabled after spawn.

### Respawn Guard

```gdscript
# In Room._ready()
if GameManager.checkpoint_room != self.scene_file_path:
    GameManager.set_respawn(
        $SpawnPoints/PlayerSpawn.global_position,
        room_id,
        scene_file_path
    )
```

Without this guard, re-entering a room that contains a checkpoint would overwrite the checkpoint position.

### Room State Flags (SaveManager)

```
Boss cleared:       "boss_cleared_" + room_id   → bool
Collectible picked: "collected_"    + item_id   → bool
Room visited:       "visited_"      + room_id   → bool
Zone first visit:   "visited_"      + zone_id   → bool
```

Flags read via `SaveManager.get_flag(key)` and written via `SaveManager.set_flag(key, value)`.

### Zone Detection and Signals

```gdscript
# GameManager signals added for zone system:
signal zone_entered(zone: ZoneResource)
signal zone_first_visit(zone: ZoneResource)
```

Room._ready() emits `zone_entered` on zone change and `zone_first_visit` on first visit (flag check + set).

### Death During Transition (EC-02)

On `GameManager.player_died`:
1. Force-clear `SceneManager._is_transitioning = false`
2. Issue respawn `change_room()` — death always takes priority

### Camera Integration

After spawn point repositioning, Zone/Room System assigns `limit_target` to pcam nodes:
```gdscript
phanCam_exploration.limit_target = phanCam_exploration.get_path_to($Terrain)
phanCam_combat.limit_target = phanCam_combat.get_path_to($Terrain)
```
Must happen before player can move (within `_on_enter()`).

### World Scale Reference

| Constraint | Value | Source |
|-----------|-------|--------|
| Min ceiling clearance | 60 px | Movement System peak height ≈ 58.7 px |
| Min horizontal gap (jump) | 58 px | Movement System range ≈ 58.5 px |
| Min horizontal gap (dash) | 40 px | Movement System dash distance ≈ 39.6 px |
| Tile size | 16 × 16 px | TileMapLayer standard |
| Target room width | 320–640 px | Zone/Room GDD |

### Architecture Diagram

```
Room scene tree (instance in RoomContainer):
  Room (Node2D, room_id exported)
  ├── Terrain (TileMapLayer)   ← NOT TileMap (4.4+ breaking change)
  ├── SpawnPoints / PlayerSpawn (Marker2D)
  ├── Exits / RoomExit (Area2D) → SceneManager.change_room()
  ├── Enemies / Hazards / Collectibles / Triggers
  └── _on_enter() virtual

SceneManager (autoload #4):
  ├── change_room(scene_path, spawn_name)
  ├── _is_transitioning guard
  └── Fade overlay (ColorRect in game.tscn, above HUD)

GameManager:
  ├── player_died signal → force-clear _is_transitioning → respawn
  ├── set_respawn(position, room_id, scene_path)
  ├── current_room, current_zone (read by systems)
  └── zone_entered, zone_first_visit signals → Dialogue System
```

## Alternatives Considered

### Alternative: Godot Built-in Scene Changer (change_scene_to_packed)

Use Godot's native `get_tree().change_scene_to_packed()` instead of a custom SceneManager.

- **Pros**: No custom code; Godot handles deallocation.
- **Cons**: No fade control; player node would be destroyed and re-created on each transition (save/load state); no transition guard; no `_is_transitioning` coordination with death.
- **Rejected**: Player persists outside the room scene. Custom SceneManager provides the fade and guard needed.

## Consequences

### Positive
- `TileMapLayer` usage documented — prevents accidental use of deprecated `TileMap`
- Respawn guard prevents checkpoint overwrite on room re-entry
- Death-during-transition EC-02 explicitly handled
- Room state flags use consistent naming convention

### Negative
- Zone lookup is O(30) per room entry — tiny at MVP but grows with world size
- `room_id` uniqueness enforced only by convention + `/consistency-check` — runtime errors if duplicated

### Risks

- **TileMapLayer API divergence**: If Godot 4.6 changed any TileMapLayer property names, room terrain access in code breaks. Mitigation: Verification Required item #1; check engine reference before authoring any code that reads TileMapLayer.
- **SceneManager._is_transitioning race**: If two systems force-clear the flag simultaneously, a double transition fires. Mitigation: only `player_died` handler is allowed to force-clear; no other system touches this flag.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-zone-001 | zone-room-system.md | Room extends Node2D; room_id exported and unique | Room Base Structure section |
| TR-zone-002 | zone-room-system.md | TileMapLayer (not TileMap) for terrain | Verification Required + room structure |
| TR-zone-003 | zone-room-system.md | RoomExit Area2D with ability gate and _used guard | RoomExit section |
| TR-zone-004 | zone-room-system.md | Room transition flow with physics-frame wait | Room Transition Flow section |
| TR-zone-005 | zone-room-system.md | Respawn guard prevents checkpoint overwrite | Respawn Guard section |
| TR-zone-006 | zone-room-system.md | Room state flags naming convention | Room State Flags section |
| TR-zone-007 | zone-room-system.md | Zone detection + zone_entered + zone_first_visit signals | Zone Detection section |
| TR-zone-008 | zone-room-system.md | Death-during-transition: force-clear _is_transitioning | Death During Transition section |
| TR-zone-009 | zone-room-system.md | Camera limit_target pushed before player moves | Camera Integration section |

## Related Decisions

- ADR-0001: SceneManager is autoload #4
- ADR-0005: SaveManager — room state flags via get_flag/set_flag
- ADR-0006: Camera System — limit_target NodePath pushed per room
- ADR-0016: Checkpoint System — explicit set_respawn() calls
- `design/gdd/zone-room-system.md` — full GDD
