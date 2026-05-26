# ADR-0016: Checkpoint / Respawn System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Feature (Progression Safety) |
| **Knowledge Risk** | LOW — Area2D, CircleShape2D, and node APIs unchanged |
| **References Consulted** | `design/gdd/checkpoint-respawn-system.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (GameManager — `set_respawn()`, `player_died`, `respawn_position`), ADR-0005 (SaveManager — `save_game()`), ADR-0012 (Zone/Room — `Room._ready()` respawn guard), ADR-0009 (Movement — DeathState executes respawn) |
| **Enables** | No downstream ADR; this is a leaf in the dependency graph |
| **Blocks** | No save-on-activate or death→respawn story may start until this ADR is Accepted |

## Context

`GameManager.set_respawn()` and `DeathState` already exist. The missing layer is the `Checkpoint` scene, its activation contract, and the exact rule governing when `Room._ready()` may and may not call `set_respawn()`. Without this contract, multiple implementations would conflict.

## Decision

### Checkpoint Scene

```
Checkpoint (Area2D)
├─ Sprite2D               -- two-frame atlas: "inactive" / "active"
├─ CollisionShape2D       -- CircleShape2D, radius 24 px
└─ ActivationParticles    -- CPUParticles2D, plays on first activation
```

```gdscript
# scripts/world/checkpoint.gd
@export var checkpoint_id: String = ""   # unique: "{room_id}_{descriptor}"

var _activated: bool = false

collision_layer = 0    # passive sensor — no layer
collision_mask  = 2    # detects player only

func _ready() -> void:
    assert(checkpoint_id != "", "Checkpoint in %s has empty checkpoint_id" % owner.name)
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group(&"player"): return
    if _activated: return
    _activate()

func _activate() -> void:
    _activated = true
    _update_visual()
    GameManager.set_checkpoint(checkpoint_id, global_position, owner.scene_file_path)
    SaveManager.save_game()    # immediate save on activation

func _update_visual() -> void:
    $Sprite2D.frame = 1   # "active" frame
    $ActivationParticles.emitting = true
```

### GameManager Extensions

```gdscript
# Three new properties added to GameManager:
var checkpoint_id:   String = ""   # "" = no checkpoint active
var checkpoint_room: String = ""   # scene path of room with active checkpoint

# New method:
func set_checkpoint(id: String, pos: Vector2, room_scene: String) -> void:
    checkpoint_id   = id
    checkpoint_room = room_scene
    set_respawn(pos, room_scene.get_basename(), room_scene)
```

`checkpoint_id = ""` is the "no checkpoint" sentinel. Room entry never sets `checkpoint_id` — only `Checkpoint._activate()` does.

### Respawn Guard in Room._ready()

Per ADR-0012, `Room._ready()` calls `set_respawn()` only when:

```gdscript
if GameManager.checkpoint_room != self.scene_file_path:
    GameManager.set_respawn(
        $SpawnPoints/PlayerSpawn.global_position,
        room_id,
        scene_file_path
    )
```

If the player re-enters a room where they activated a checkpoint, this guard preserves the checkpoint position. Combined with the `checkpoint_id != ""` sentinel, DeathState knows to use the stored Vector2 instead of a named spawn.

### Respawn Priority Order

```
1. checkpoint_room == current room:
   → player.global_position = GameManager.respawn_position
   → no scene change
   → 1-frame repositioning

2. checkpoint_room != current room (different room):
   → SceneManager.change_room(GameManager.checkpoint_room)
   → after load: position player at GameManager.respawn_position (Vector2, not named spawn)

3. checkpoint_id == "" (no checkpoint):
   → SceneManager.change_room(GameManager.respawn_scene)
   → after load: position player at named PlayerSpawn Marker2D
```

DeathState resolves this priority after death animation completes (~1.0s).

### Post-Respawn Iframes

After player is repositioned:
```gdscript
GameManager.iframe_timer = GameManager.IFRAME_DURATION  # 0.8s (Health System constant)
```

Prevents immediate re-damage from hazards near respawn point.

### Save Schema (under "checkpoints" key)

```json
{
  "checkpoints": {
    "checkpoint_id":    "room3_mid",
    "checkpoint_room":  "res://scenes/world/rooms/room3.tscn",
    "respawn_position": { "x": 240.0, "y": 180.0 }
  }
}
```

### Checkpoint Placement Rules

- Every room has exactly one `PlayerSpawn` Marker2D (enforced by room base scene).
- `checkpoint_id` must be globally unique: `{room_id}_{descriptor}` convention.
- No checkpoint within 64 px of any KillZone edge.
- No checkpoint inside any DamageZone.
- Boss rooms: checkpoint placed BEFORE the boss barrier only. Never inside the arena.

### Architecture Diagram

```
Player touches Checkpoint Area2D
  → _activate()
    → GameManager.set_checkpoint(id, pos, room_path)
    → SaveManager.save_game() [immediate disk write]

player_died signal
  → DeathState._enter()
    → death animation (~1.0s)
    → resolve respawn priority
    → if same room: global_position = respawn_position
    → if different room: SceneManager.change_room(checkpoint_room)
    → GameManager.respawn() [restores health, sets iframes]
```

## Consequences

### Positive
- Respawn guard prevents checkpoint overwrite on room re-entry (TR-checkpoint-004)
- Immediate save on activation ensures checkpoint persists across crashes
- Sentinel `checkpoint_id = ""` cleanly represents "no checkpoint" without nullable types

### Negative
- `SaveManager.save_game()` called on every checkpoint activation — small I/O spike on activation. Acceptable at MVP; mitigation: async write (future optimization).
- Boss room checkpoint placement is a design convention, not a runtime guard — relies on level designer compliance.

### Risks

- **Respawn position saved but scene changes**: If room scene is renamed or moved after a save, `checkpoint_room` path becomes invalid. SceneManager must handle missing scene path gracefully — fall back to `respawn_scene` (room entry).
- **Checkpoint in scene tree after room unload**: `Checkpoint` is a child of the room — it is freed with the room. State is preserved in `GameManager.checkpoint_id/room` (in-memory) and in save file. No dangling references.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-checkpoint-001 | checkpoint-respawn-system.md | Checkpoint Area2D with one-shot _activated flag | Checkpoint Scene section |
| TR-checkpoint-002 | checkpoint-respawn-system.md | On activation: GameManager.set_checkpoint(room, position) → save_game() | `_activate()` method |
| TR-checkpoint-003 | checkpoint-respawn-system.md | Respawn priority: active checkpoint same room > other room > room entrance | Respawn Priority Order section |
| TR-checkpoint-004 | checkpoint-respawn-system.md | Room._ready() must NOT call set_respawn() if checkpoint_room == self.scene_file_path | Respawn Guard section |

## Related Decisions

- ADR-0002: GameManager — owns `respawn_position`, `player_died` signal
- ADR-0005: SaveManager — `save_game()` called on activation
- ADR-0009: Movement System — DeathState is the respawn executor
- ADR-0012: Zone/Room System — `Room._ready()` respawn guard (TR-zone-007)
- `design/gdd/checkpoint-respawn-system.md` — full GDD
