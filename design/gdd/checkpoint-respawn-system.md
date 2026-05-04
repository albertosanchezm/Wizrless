# Checkpoint / Respawn System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-03
> **Implements Pillar**: Controlled Ascension (progression safety)

## Overview

The Checkpoint/Respawn System defines where the player returns to after death and how that position is established. It has two halves: **checkpoints** (placed objects the player activates to anchor their respawn position) and **respawn** (the death → reload → reposition sequence that gets the player back into the game).

At MVP, every room has at least one default respawn position — the `PlayerSpawn` marker at the room entrance. Explicit checkpoint objects can be placed mid-room or mid-zone to give the player a closer anchor. Activating a checkpoint saves the game immediately. On death, the player reloads to the last activated checkpoint's position; if no checkpoint was activated, they reload to the room entrance.

The core infrastructure already exists: `GameManager.set_respawn()`, `GameManager.respawn_position`, `DeathState` loading the respawn scene and repositioning the player. This GDD specifies the missing layer — the Checkpoint scene, its activation logic, and the rules that govern which position DeathState uses when multiple anchors are possible.

No death penalty. Wizrless is not a roguelite. Dying costs time, not materials or progression. The player respawns at full health at the last anchor point.

## Player Fantasy

The checkpoint is not a reward — it is a promise.

When the wizard touches the checkpoint, the game says: *you will start here, not back at the door, if something goes wrong*. The player decides when to push forward and when to play it safe, and the checkpoint is the instrument of that decision. A well-placed checkpoint in a dangerous room gives the player permission to experiment. Without it, they would play conservatively and miss what the room was designed to teach them.

Respawn should feel like a reset, not a punishment. Fade to black, a breath, back in the room. The game does not lecture. It just lets the player try again.

## Detailed Design

### System Components

| Component | Type | Status |
|-----------|------|--------|
| `GameManager.set_respawn()` | Method | Implemented |
| `GameManager.respawn_position` | Property | Implemented |
| `GameManager.respawn_scene` | Property | Implemented |
| `GameManager.reset_health()` | Method | Implemented |
| `DeathState` — full death/reload sequence | LimboState | Implemented |
| Room entry auto-respawn (PlayerSpawn) | Room._ready() | Implemented |
| `Checkpoint` scene (Area2D) | Scene + Script | **Not implemented** |
| `GameManager.checkpoint_id` | Property | **Not implemented** |
| `GameManager.checkpoint_room` | Property | **Not implemented** |
| Save-on-activate trigger | - | **Not implemented** |

---

### Checkpoint Object

```
Checkpoint (Area2D)
├─ Sprite2D               -- two-frame animation: "inactive" / "active"
├─ CollisionShape2D       -- CircleShape2D, radius 24 px
└─ ActivationParticles    -- CPUParticles2D, plays on first activation (optional)
```

**Script:** `scripts/world/checkpoint.gd`

```gdscript
@export var checkpoint_id: String = ""   # unique per room, e.g. "room3_mid"

var _activated: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    _update_visual()

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group(&"player"): return
    if _activated: return
    _activate()

func _activate() -> void:
    _activated = true
    _update_visual()
    GameManager.set_checkpoint(checkpoint_id, global_position, owner.scene_file_path)
    GameManager.save_game()
    # play SFX via AudioManager (checkpoint_save bus)

func _update_visual() -> void:
    # swap to "active" frame or enable active sprite variant
```

**collision_layer = 0** (not on any layer — passive sensor)
**collision_mask = 2** (detects player only)

---

### GameManager Extensions Required

Three new properties, one new method:

```gdscript
# --- New checkpoint state ---
var checkpoint_id:    String  = ""         # empty = no checkpoint active
var checkpoint_room:  String  = ""         # scene path of room with active checkpoint

# --- New method ---
func set_checkpoint(id: String, pos: Vector2, room_scene: String) -> void:
    checkpoint_id   = id
    checkpoint_room = room_scene
    set_respawn(pos, room_scene.get_basename(), room_scene)

# --- New method ---
func save_game() -> void:
    # Write checkpoint_id, checkpoint_room, respawn_position to SaveManager
    # SaveManager serializes to disk immediately
    pass  # implementation owned by Save/Load System
```

`checkpoint_id = ""` is the "no checkpoint" sentinel. Room entry never sets `checkpoint_id` — that sentinel means "use room entry spawn."

---

### Respawn Priority

When DeathState triggers respawn, position resolution uses this priority order:

```
1. Active checkpoint in current room
   → spawn at GameManager.respawn_position (checkpoint position)
   → no scene change needed

2. Active checkpoint in a different room
   → SceneManager.change_room(GameManager.checkpoint_room)
   → game.gd repositions player to GameManager.respawn_position
     (NOT named spawn — must use stored Vector2)

3. No active checkpoint
   → SceneManager.change_room(GameManager.respawn_scene)
   → game.gd repositions player to room's PlayerSpawn marker
```

This requires one change to `game.gd`'s room transition: after loading the room, if `GameManager.checkpoint_id != ""`, position player at `GameManager.respawn_position` (Vector2) instead of the named spawn point.

---

### Room Entry vs Checkpoint Conflict

`Room._ready()` currently calls `GameManager.set_respawn()` on every room load. This must NOT overwrite an active checkpoint in the same room.

**Rule**: `Room._ready()` calls `set_respawn()` only when:
```
GameManager.checkpoint_room != self.scene_file_path
```

If the player re-enters a room where they already activated a checkpoint, the checkpoint position is preserved. The room entry anchor only matters for rooms the player hasn't checkpointed.

---

### Multiple Checkpoints Per Room

Last activated wins. No "active checkpoint" list — one active checkpoint globally at any time.

Player activates checkpoint A → `checkpoint_id = "room3_a"`. Player then activates checkpoint B in the same room → `checkpoint_id = "room3_b"`. If they die, they respawn at B. A is now inert.

Visual state: each Checkpoint script tracks `_activated` independently per instance. Checkpoint A stays visually "active" even after B supersedes it — there is no visual "deactivation." Players see their trail of activated anchors. Only the last one matters for respawn.

---

### Death and Respawn Sequence

Full sequence from HP → 0 to player control restored:

```
1. GameManager.take_damage() → HP reaches 0
2. GameManager.player_died signal emitted
3. Player script → dispatch &"die" to HSM
4. DeathState._enter():
   a. velocity = Vector2.ZERO
   b. physics disabled
   c. death animation plays (~0.85–1.0 s)
   d. GameManager.player_died emitted again (existing — harmless redundancy)

5. DeathState._on_death_finished() (after animation):
   a. Resolve respawn target per priority rules above
   b. If same room: player.global_position = GameManager.respawn_position
   c. If different room: SceneManager.change_room(target_scene)
      → fade out (0.3 s) → load room → position player → fade in (0.3 s)

6. GameManager.reset_health() → current_health = max_health

7. HSM dispatch &"land" → player enters Idle state

8. Iframes active for 1.0 s (existing player invulnerability window)
```

Total time from death to player control: ~2.3 s (same room) / ~2.9 s (room change, includes transitions).

---

### Save on Activation

Checkpoint activation triggers an immediate save. This is the ONLY game event that writes to disk at MVP (manual save is not exposed to the player).

What gets written:
```
checkpoint_id:        "room3_mid"
checkpoint_room:      "res://scenes/world/rooms/room3.tscn"
respawn_position:     Vector2(240, 180)
abilities_unlocked:   [...] 
current_health:       85     # player's HP at time of activation
```

On load (continue game): restore all above into GameManager before room load. Player enters the checkpoint room at checkpoint position with saved HP.

---

### Checkpoint Placement Rules (Level Design Contract)

- Every room must have exactly one `PlayerSpawn` Marker2D in its `SpawnPoints` node (already enforced by room base).
- Mid-room checkpoints are optional. Placed under the room's root or a `Checkpoints` node.
- `checkpoint_id` must be unique globally (naming convention: `{room_id}_{descriptor}`, e.g. `"room3_before_boss"`).
- No checkpoint within 64 px of a KillZone edge (respawn safety margin).
- No checkpoint inside a DamageZone.
- Boss rooms: checkpoint placed BEFORE the boss barrier, never inside the arena.

---

### Collision Architecture

```
collision_layer = 0    (passive — not on any layer)
collision_mask  = 2    (detects player on layer 2)
```

Checkpoint does not register on any layer — other objects cannot collide with it. It only listens for the player entering its radius.

## Formulas

### Total Respawn Time (Same Room)

```
T_respawn = T_death_anim + T_fade_out + T_fade_in
          = 1.0 + 0.0 + 0.0   (same room: no fades needed)
          = 1.0 s

Minimum: 0.85 s (Devium boss death uses 0.85 s wait)
Standard: 1.0 s (player death state wait)
```

### Total Respawn Time (Different Room)

```
T_respawn = T_death_anim + T_fade_out + T_room_load + T_fade_in
          = 1.0 + 0.3 + ~0.2 + 0.3
          ≈ 1.8 s (room load time varies by scene complexity)
```

### Invincibility Frames on Respawn

```
iframes_duration = 1.0 s   (existing player default)

Purpose: prevents immediate re-death on respawn into hazard proximity.
Hazards that activate during iframes window: no damage applied.
(Owned by Health System — Checkpoint System only ensures iframes are triggered.)
```

### Checkpoint Activation Radius

```
CollisionShape2D: CircleShape2D, radius = 24 px

Activation occurs when player character's CollisionShape2D (layer 2)
overlaps the checkpoint's CircleShape2D.
Player center must be within 24 + player_half_width ≈ 24 + 8 = 32 px of checkpoint center.
```

### Variable Definitions

| Variable | Default | Description |
|----------|---------|-------------|
| `checkpoint_id` | `""` | Empty = no checkpoint; non-empty = checkpoint active |
| `checkpoint_room` | `""` | Scene path of room containing active checkpoint |
| `respawn_position` | PlayerSpawn pos | Vector2 spawn position (set by checkpoint or room entry) |
| `T_death_anim` | 1.0 s | Delay in DeathState before respawn triggers |
| `T_fade` | 0.3 s | Per-direction room transition fade |
| `iframes_duration` | 1.0 s | Post-respawn invincibility window |
| `activation_radius` | 24 px | Checkpoint trigger circle radius |

## Edge Cases

**EC-01 — Player activates checkpoint mid-combat.**
Checkpoint has no combat awareness. Activation fires on `body_entered` regardless of enemies present. Correct: checkpoints are not combat-gated at MVP. Boss rooms are an exception — no checkpoint inside the boss arena (design rule, not code guard).

**EC-02 — Player dies before game is first saved.**
No checkpoint active → `checkpoint_id = ""`. DeathState uses `respawn_scene` from Room._ready() (room entry). Player respawns at room entrance. No data loss — no checkpoint data to lose.

**EC-03 — Save file corrupted or missing on load.**
Save/Load System GDD handles corruption fallback. Checkpoint System receives whatever GameManager is initialized with. If `checkpoint_id = ""` after load: room entry spawn used. No crash.

**EC-04 — Player activates checkpoint, loads save on different session.**
SaveManager restores `checkpoint_id`, `checkpoint_room`, `respawn_position`. Room loads. If checkpoint room differs from spawn room: SceneManager loads checkpoint room. Player positioned at saved `respawn_position`. Full cross-session restore.

**EC-05 — Checkpoint placed in boss room.**
Design rule violation (see placement rules). No code guard. If placed inside boss arena: player respawns mid-fight after boss combat barrier re-closes. **Document as forbidden placement** — no runtime mitigation at MVP.

**EC-06 — Player re-enters room where checkpoint was activated.**
`Room._ready()` checks `GameManager.checkpoint_room != self.scene_file_path`. If match: `set_respawn()` is NOT called. Checkpoint position preserved. Player spawn during room entry comes from `GameManager.respawn_position` (the checkpoint). Verified by: enter room, activate checkpoint, exit room, re-enter — respawn position unchanged.

**EC-07 — Two players approach same checkpoint simultaneously.**
Single-player game. Not applicable.

**EC-08 — Checkpoint activated while player is airborne (jumping).**
`body_entered` fires on Area2D overlap, not ground contact. Player activates checkpoint mid-jump. Checkpoint position is on the ground (Marker2D is at floor level). Respawn position may be slightly above the collision shape. Guard: set `respawn_position` to `checkpoint.global_position + Vector2(0, 0)` — checkpoint is authored at floor level by level designer. Not a code guard — placement convention.

**EC-09 — GameManager save_game() called but SaveManager not yet implemented.**
`save_game()` is a stub at MVP (per survey). Checkpoint activates, updates GameManager state, calls `save_game()` — stub returns immediately. State is in-memory only. Not persisted to disk. Cross-session restore fails silently. **Known gap — SaveManager implementation unblocks this.**

**EC-10 — Debug HP floor prevents death.**
`take_damage()` clamps to min 1 HP. Player cannot die. Respawn system untestable with floor active. Must disable debug floor to test full respawn sequence. See GameManager:take_damage() note.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Health System** | Receives from | `GameManager.player_died` signal triggers DeathState which owns respawn execution |
| **Zone/Room System** | Owns placement | Checkpoints live in room's scene tree; room entry calls `set_respawn()` for default anchor |
| **Save/Load System** | Sends to | `GameManager.save_game()` → SaveManager writes checkpoint state to disk. Save/Load System must expose a `save_game()` method. |
| **Hazard System** | Constraint | Checkpoint placement must not overlap DamageZones or KillZones (EC-08, design rule) |
| **Player** | DeathState executes | `DeathState._on_death_finished()` is the respawn executor — changes room or repositions player |
| **SceneManager** | Called by | DeathState calls `SceneManager.change_room()` for cross-room respawn |

**Reverse dependencies:**
- Save/Load System must call `GameManager.save_game()` on checkpoint activation — this GDD defines the trigger.
- HUD System may subscribe to a `checkpoint_activated` signal for UI feedback (activation flash/icon).

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `T_death_anim` | 1.0 s | 0.5–2.0 s | Below 0.5: death feels instant — no weight. Above 2.0: frustrating wait. 1.0 s is the emotional beat. |
| `T_fade` | 0.3 s | 0.15–0.6 s | Room transition speed. Below 0.15: jarring cut. Above 0.6: sluggish. |
| `iframes_duration` | 1.0 s | 0.5–2.0 s | Post-respawn invulnerability. Below 0.5: can die immediately on bad respawn. Above 2.0: exploitable in boss fights. |
| `activation_radius` | 24 px | 16–48 px | Checkpoint trigger area. Below 16: player must stand exactly on it. Above 48: triggers from too far away (feels wrong). |
| Save HP on activate | current HP | full HP option | Currently saves HP at moment of activation. Alternative: always save max HP. Design choice: current HP rewards checkpointing mid-fight. |

## Acceptance Criteria

**AC-01 — Checkpoint activates on player contact.**
Player walks into checkpoint Area2D (radius 24 px). Checkpoint visual switches to active state. SFX plays. `GameManager.checkpoint_id` set to the checkpoint's `checkpoint_id`. Verified by: walk into checkpoint, check GameManager state in debugger.

**AC-02 — Checkpoint activates only once per instance.**
Player re-enters checkpoint area after activation — no double activation, no SFX replay, no second save call. Verified by: enter checkpoint twice, confirm `_activate()` called once.

**AC-03 — Same-room respawn at checkpoint position.**
Player activates checkpoint, then dies. Player respawns at checkpoint's `global_position`, not at `PlayerSpawn`. Health restored to max. Verified by: activate checkpoint at room midpoint, trigger death (disable HP floor), confirm respawn position.

**AC-04 — Cross-room respawn at checkpoint position.**
Player activates checkpoint in room A, transitions to room B, dies in room B. Player loads back into room A at checkpoint position (not room A's entrance). Verified by: checkpoint room A, travel to room B, die, confirm room A loads at checkpoint coords.

**AC-05 — Room entry does not overwrite active checkpoint.**
Player activates checkpoint in room A (position X). Player exits and re-enters room A. `GameManager.respawn_position` still equals checkpoint position X (not PlayerSpawn position). Verified by: check GameManager.respawn_position before and after re-entry.

**AC-06 — No checkpoint: respawn at room entrance.**
No checkpoint ever activated. Player dies. Respawns at room's PlayerSpawn marker. `GameManager.checkpoint_id` remains `""`. Verified by: fresh game state, trigger death, confirm PlayerSpawn respawn.

**AC-07 — Last activated checkpoint wins (multi-checkpoint room).**
Room has checkpoint A and checkpoint B. Player activates A then B. Player dies → respawns at B's position. Player dies again → still B. Verified by: two checkpoints in test room, activate in order, die twice.

**AC-08 — Save triggered on activation.**
When `save_game()` is implemented: checkpoint activation writes `checkpoint_id`, `checkpoint_room`, `respawn_position`, and HP to disk. Verified by: activate checkpoint, close game, reopen, confirm "continue" resumes at checkpoint room. *(Blocked until SaveManager implements save_game().)*

**AC-09 — Full respawn iframes.**
Player respawns adjacent to an active hazard. Hazard does not damage player during 1.0 s iframe window. After 1.0 s, hazard deals damage normally. Verified by: respawn next to active GroundSpike, confirm no damage for 1 s.

**AC-10 — Checkpoint outside boss arena.**
No checkpoint scene exists inside any boss room's combat barrier boundary. Verified by: inspect all boss room scenes for Checkpoint nodes inside the barrier zone. (Design-time check, not runtime.)
