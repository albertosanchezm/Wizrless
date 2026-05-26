# ADR-0001: Autoload Singleton Architecture

## Status
Accepted

## Date
2026-05-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Scripting) |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff (cutoff ≈ 4.3) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — Godot autoload system unchanged since 4.0; confirmed by engine specialist against 4.4–4.6 breaking-changes |
| **Verification Required** | (1) Confirm project.godot autoload section matches roster table below. (2) Confirm DialogueManager addon position after each plugin toggle. (3) Verify all 10 autoloads initialize without errors in empty scene before any game scene is loaded. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — this is the Foundation ADR |
| **Enables** | ADR-0002 (Signal Hub / GameManager Contract), ADR-0007 (Damage API & SpellInteractionEngine Contract), all system ADRs |
| **Blocks** | No implementation story may reference an autoload singleton by name until this ADR is Accepted and the load order is locked in project.godot |
| **Ordering Note** | All subsequent ADRs that reference GameManager, SaveManager, AudioSystem, SpellInteractionEngine, SpellSlotSystem, SpellVFXSpawner, AudioFeedbackSystem, or DialogueManager depend on this ADR for the canonical access pattern |

## Context

### Problem Statement

Wizrless has 10 cross-cutting systems that multiple game scenes and sub-systems need to access from any context. Four of these are already registered in project.godot (PhantomCameraManager, GameManager, SaveManager, SceneManager); six more are required by the GDDs (AudioSystem, SpellInteractionEngine, SpellSlotSystem, DialogueManager, AudioFeedbackSystem, SpellVFXSpawner). No formal decision exists on the complete roster, the required load order, or the canonical access pattern. Without this ADR:

- Stories implementing these systems specify access patterns inconsistently
- A load order violation in project.godot can corrupt initialization silently
- It is unclear which systems are autoloads vs. instanced per-scene

### Constraints

- Four autoloads already registered — this ADR formalizes and extends the existing state, it does not start fresh
- GDDs explicitly specify 5 of the 6 new systems as autoload singletons (TR-slot-001, TR-interaction-001, TR-vfx-001, TR-audiofb-001, TR-dialogue-001)
- PhantomCamera addon registers PhantomCameraManager as its own autoload and must remain at position 1
- Dialogue Manager v2 addon registers its autoload via `_enable_plugin()` — position is advisory, not guaranteed; must be verified after any plugin toggle
- Project is GDScript-only, solo developer — minimal boilerplate budget
- Provider registration pattern: systems call `SaveManager.register_save_provider()` during their own `_ready()` → SaveManager must load before all systems that register providers

### Requirements

- All cross-scene systems accessible from any GDScript without node path traversal per call
- Defined load order with documented dependency justification per position
- Clear rule for which systems are autoloads vs. instanced
- Zero per-frame overhead for access (direct global reference, no dictionary lookup)
- Load order safe for cross-autoload _ready() dependencies

## Decision

Use Godot's native **Autoload Singleton** system for the 10 cross-cutting systems. Access via the registered autoload name directly from any script. Godot synthesizes a global accessor for each autoload at parse time — `SpellInteractionEngine.process_hit(...)` resolves without any `get_node()` call.

### Autoload Roster

All entries must appear in `project.godot` `[autoload]` section in this exact order.

| # | Autoload Name | File | Role | Status |
|---|--------------|------|------|--------|
| 1 | `PhantomCameraManager` | `res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd` | Camera host bootstrap — addon requires first position | **Existing (addon)** |
| 2 | `GameManager` | `res://scripts/systems/game_manager.gd` | Player state, boss signals, dialogue flag, ability gates, upgrade tiers, material counts | **Existing** |
| 3 | `SaveManager` | `res://scripts/systems/save_manager.gd` | Provider registration, atomic JSON save/load, flag API | **Existing** |
| 4 | `SceneManager` | `res://scripts/systems/scene_manager.gd` | Scene transitions, room loading, fade management | **Existing** |
| 5 | `AudioSystem` | `res://scripts/systems/audio_system.gd` | 5-bus routing, 16-slot SFX pool, music state machine | **New** |
| 6 | `SpellInteractionEngine` | `res://scripts/systems/spell_interaction_engine.gd` | Status effects, interaction registry, process_hit(), status tick | **New** |
| 7 | `SpellSlotSystem` | `res://scripts/systems/spell_slot_system.gd` | Slot array, active index, slot unlock, loadout signals | **New** |
| 8 | `DialogueManager` | `res://addons/dialogue_manager/dialogue_manager.gd` | Dialogue Manager v2 addon runtime | **New (advisory position — see note)** |
| 9 | `AudioFeedbackSystem` | `res://scripts/systems/audio_feedback_system.gd` | Event→SFX routing table, subscribes to SpellInteractionEngine signals | **New** |
| 10 | `SpellVFXSpawner` | `res://scripts/systems/spell_vfx_spawner.gd` | Interaction VFX burst routing, subscribes to SpellInteractionEngine signals | **New** |

> **DialogueManager position note**: The Dialogue Manager v2 plugin writes its own entry to project.godot via `_enable_plugin()`. The position it occupies depends on when the plugin was enabled. After enabling or toggling the plugin, manually verify and correct its position in Project Settings → Autoload to match slot 8 above. Any re-enable of the plugin may append it to the end — always re-verify.

### Load Order Rationale

```
1. PhantomCameraManager  — Addon requirement: must be first. Camera host bootstraps
                           before any scene node resolves camera priorities.

2. GameManager           — Central coordinator. Loads before all systems that subscribe
                           to its signals or read its state during _ready().
                           Existing position — do not move.

3. SaveManager           — Loads before all systems that call register_save_provider()
                           in their _ready(). Existing position — do not move.

4. SceneManager          — Needs SaveManager ready to restore scene state on transitions.
                           Existing position — do not move.

5. AudioSystem           — No cross-autoload dependencies. Must precede
                           AudioFeedbackSystem which routes events through it.

6. SpellInteractionEngine— Loads after GameManager so SIE._ready() can subscribe to
                           GameManager signals if needed. Loads before SpellSlotSystem
                           and the Presentation tier that subscribes to its signals.

7. SpellSlotSystem       — Needs GameManager (milestone state) + SaveManager (provider
                           registration) both ready. Needs SIE loaded for signal contracts.

8. DialogueManager       — Addon. Advisory position. Loads after GameManager (dialogue_active
                           flag lives on GameManager). Verify after each plugin toggle.

9. AudioFeedbackSystem   — Needs AudioSystem (play_sfx) + SpellInteractionEngine signals
                           connectable during _ready().

10. SpellVFXSpawner      — Needs SpellInteractionEngine signals connectable during _ready().
```

### Non-Autoload Systems (Instanced, Not Global)

These systems live inside scene trees and are NOT autoloads:

| System | Location | Reason |
|--------|----------|--------|
| Player health state | Player scene (CharacterBody2D) | Per-entity; only player scene reads/writes it |
| Enemy AI states | Enemy scenes (LimboHSM nodes) | Per-entity; no cross-scene access needed |
| BaseEnemy / boss subclasses | Room scenes | Instanced per room, destroyed on room change |
| Camera nodes | Room scenes | PhantomCamera2D nodes inside room scenes |
| HUD | Game scene (CanvasLayer) | Single instance; subscribes to signals via autoloads |
| Boss Dialogue UI | Game scene (instanced per boss) | Instanced per encounter |

### Access Pattern

```gdscript
# CORRECT — direct global accessor (Godot synthesizes this at parse time)
SpellInteractionEngine.process_hit(self, damage, element)
SaveManager.register_save_provider("health", _save, _load)
AudioSystem.play_sfx(sfx, AudioSystem.Priority.NORMAL, 1.0)
GameManager.take_damage(amount)

# FORBIDDEN — path resolution per call (redundant + brittle to renames)
get_node("/root/SpellInteractionEngine").process_hit(...)

# FORBIDDEN — caching autoload via @onready get_node (redundant; global accessor exists)
@onready var _sie := get_node("/root/SpellInteractionEngine")
```

The global accessor is not just idiomatic — it is the Godot 4 intended usage. Autoloads are accessible as top-level global identifiers without any node path lookup. Caching via get_node is not incorrect but bypasses type safety and is unnecessary.

### Architecture Diagram

```
project.godot [autoload] section (load order = top to bottom)
──────────────────────────────────────────────────────────────
[1]  PhantomCameraManager   (addon — must be first)
[2]  GameManager            (central coordinator — existing)
[3]  SaveManager            (persistence foundation — existing)
[4]  SceneManager           (scene transitions — existing)
[5]  AudioSystem            (SFX pool + music state)
[6]  SpellInteractionEngine (status effects + interactions)
[7]  SpellSlotSystem        (equipped spell slots)
[8]  DialogueManager        (addon — advisory position)
[9]  AudioFeedbackSystem    (event→SFX routing)
[10] SpellVFXSpawner        (interaction VFX routing)
──────────────────────────────────────────────────────────────

Runtime scene tree (autoloads not shown — they live at /root/)
├── RoomContainer           (current room scene)
│   ├── Player (CharacterBody2D — owns health state, movement, spell casting)
│   ├── Enemies (instanced per room, removed on room change)
│   └── Hazards
├── HUD (CanvasLayer — subscribes to GameManager + SpellSlotSystem signals)
└── [Boss Dialogue UI — instanced per boss encounter]
```

### Key Interfaces

These interfaces are defined by this ADR. All other ADRs must use them.

```gdscript
# ── SaveManager ──────────────────────────────────────────────────────────────
SaveManager.register_save_provider(key: String, save_fn: Callable, load_fn: Callable) -> void
SaveManager.save_game() -> void
SaveManager.load_game() -> void
SaveManager.get_flag(key: String) -> Variant
SaveManager.set_flag(key: String, value: Variant) -> void

# ── AudioSystem ───────────────────────────────────────────────────────────────
AudioSystem.play_sfx(stream: AudioStream, priority: AudioSystem.Priority, pitch_scale: float) -> void
AudioSystem.notify_voice_start() -> void
AudioSystem.notify_voice_end() -> void
# AudioSystem.Priority enum: GUARANTEED > HIGH > NORMAL > LOW

# ── SpellInteractionEngine ────────────────────────────────────────────────────
SpellInteractionEngine.process_hit(enemy: BaseEnemy, base_damage: int, element: StringName) -> int
signal SpellInteractionEngine.interaction_triggered(enemy: BaseEnemy, interaction_name: StringName, final_damage: int)
signal SpellInteractionEngine.status_applied(enemy: BaseEnemy, status: StringName, duration: float)
signal SpellInteractionEngine.status_expired(enemy: BaseEnemy, status: StringName)

# ── GameManager ───────────────────────────────────────────────────────────────
GameManager.take_damage(amount: int) -> void
GameManager.has_ability(ability_id: StringName) -> bool
GameManager.get_upgrade_tier(spell_id: StringName) -> int
GameManager.set_checkpoint(room: String, position: Vector2) -> void
GameManager.dialogue_active: bool        # read-only by non-GameManager systems
GameManager.materials: Dictionary        # read-only by non-GameManager systems
signal GameManager.boss_appeared(id: StringName, name: String, max_hp: int)
signal GameManager.boss_health_changed(current: int, maximum: int)
signal GameManager.boss_defeated(id: StringName)
signal GameManager.player_died
signal GameManager.dialogue_started
signal GameManager.dialogue_ended

# ── SpellSlotSystem ───────────────────────────────────────────────────────────
SpellSlotSystem.slots: Array[SpellResource]   # read-only by non-SlotSystem systems
SpellSlotSystem.active_index: int
signal SpellSlotSystem.active_spell_changed(spell: SpellResource)
signal SpellSlotSystem.slot_unlocked(new_count: int)
signal SpellSlotSystem.loadout_changed

# ── DialogueManager (addon) ───────────────────────────────────────────────────
# Interface defined by Dialogue Manager v2 — see addon docs.
# Entry points used by this project (TR-dialogue-002):
DialogueManager.show_dialogue_balloon(resource: DialogueResource, title: String) -> void
DialogueManager.show_dialogue_balloon_scene(scene: PackedScene, resource: DialogueResource, title: String) -> void
signal DialogueManager.dialogue_started(resource: DialogueResource)
signal DialogueManager.dialogue_ended(resource: DialogueResource)
```

## Alternatives Considered

### Alternative A: Service Locator
- **Description**: One `Services` autoload. All systems call `Services.get("SpellInteractionEngine")` to retrieve a typed reference.
- **Pros**: More testable — mock services injectable in tests. Explicit dependency declaration.
- **Cons**: Dictionary lookup per call. String-keyed access loses type safety. Significant boilerplate for solo dev with no existing test infrastructure.
- **Rejection Reason**: GDDs already specify direct autoload access. No test infrastructure exists to benefit from mockability. Adds complexity without payoff at this stage.

### Alternative B: Dependency Injection
- **Description**: No autoloads. Dependencies passed through scene hierarchy at construction time.
- **Pros**: Fully testable. No global state. Clean boundaries.
- **Cons**: Massive plumbing for 10 systems × many consumers. Godot's scene system makes deep injection awkward. GDDs specify autoloads explicitly.
- **Rejection Reason**: Incompatible with GDD specifications. High overhead for a solo developer. Premature optimization at this stage.

## Consequences

### Positive
- Zero friction — GDDs already specify this pattern for 5 of the 10 systems
- Godot-idiomatic — the intended Godot 4 usage, no boilerplate
- Direct access — no per-call overhead; global accessors are compile-time resolved
- Defined order — load order bugs detectable by comparing project.godot against this ADR
- Four existing autoloads formalized without disruption

### Negative
- Autoloads are harder to unit test in isolation (GUT requires workarounds for autoloads)
- Global state — systems must be disciplined about what they expose as mutable
- Adding a new autoload requires updating this ADR and project.godot

### Risks

- **Load order violation**: If an autoload's _ready() references another autoload that has not loaded yet, silent null access or crash at launch. **Mitigation**: document dependency justification per position in this ADR; verify project.godot order matches the table above after any change.

- **DialogueManager position drift**: Re-enabling the Dialogue Manager plugin appends its entry to the end of [autoload], breaking the documented order. **Mitigation**: add a project setup checklist step to re-verify and reorder DialogueManager after any plugin toggle.

- **Hidden coupling**: Systems may accumulate calls to autoloads they should not touch, creating invisible dependencies. **Mitigation**: each subsequent ADR's "ADR Dependencies" section must explicitly list which autoloads it uses; this creates a static record of autoload usage across the architecture.

- **Autoload naming collision**: A future autoload may shadow or conflict with an existing Godot global name. **Mitigation**: all project autoloads use PascalCase names that do not conflict with Godot built-ins (confirmed for current roster).

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-slot-001 | spell-slot-system.md | SpellSlotSystem is an autoload singleton | Registered as autoload #7 with canonical file path |
| TR-interaction-001 | spell-interaction-engine.md | SpellInteractionEngine is an autoload singleton | Registered as autoload #6 with canonical file path |
| TR-interaction-012 | spell-interaction-engine.md | SpellInteractionEngine must load before scenes that call take_damage() in _ready() | All autoloads load before any scene — confirmed by Godot's initialization model. Load order table places SIE at #6 after GameManager so SIE._ready() can safely subscribe to GameManager signals. |
| TR-vfx-001 | spell-vfx-system.md | SpellVFXSpawner is an autoload singleton | Registered as autoload #10 |
| TR-audiofb-001 | audio-feedback-system.md | AudioFeedbackSystem autoload routes events to AudioSystem | Registered as autoload #9, after AudioSystem (#5) |
| TR-dialogue-001 | dialogue-system.md | Dialogue Manager v2 addon as dialogue runtime | Registered as autoload #8 (advisory position) |
| TR-audio-007 | audio-system.md | play_sfx() is the single SFX entry point | AudioSystem.play_sfx() defined as the canonical interface |
| TR-save-003 | save-load-system.md | register_save_provider() pattern | SaveManager.register_save_provider() defined as key interface |
| TR-hazard-002 | hazard-system.md | All hazard damage routes through GameManager.take_damage() | GameManager.take_damage() defined as key interface |
| TR-dialogue-004 | dialogue-system.md | GameManager.dialogue_active flag suppresses gameplay input | GameManager.dialogue_active: bool defined as readable field |
| TR-movement-004 | movement-system.md | Ability gating via GameManager.has_ability(ability_id) | GameManager.has_ability() defined as key interface |
| TR-upgrade-003 | spell-upgrade-system.md | Projectile reads tier via GameManager.get_upgrade_tier(spell_id) | GameManager.get_upgrade_tier() defined as key interface |

## Performance Implications

- **CPU**: Autoload _ready() runs once at startup — negligible total (< 1 ms)
- **Memory**: 10 GDScript singleton instances — negligible (< 1 MB estimated)
- **Load Time**: All 10 autoloads initialize before any game scene loads — adds to initial load time only, not per-scene load time
- **Frame**: Zero per-frame overhead for access — global accessor is compile-time resolved, no dictionary lookup, no path traversal

## Migration Plan

Four autoloads already exist in project.godot. Migration steps for the six new autoloads:

1. Create stub scripts for the six new autoloads at the paths in the roster table
2. Register each in project.godot [autoload] section in the specified order
3. Verify with empty scene that all 10 load without console errors
4. Enable Dialogue Manager v2 plugin if not already enabled; re-verify and correct its position to slot 8
5. As each system GDD is implemented, flesh out its autoload stub with the full implementation

## Validation Criteria

- All 10 autoloads listed in project.godot [autoload] section in the order specified
- Empty scene loads with zero console errors from any autoload
- `SpellInteractionEngine.process_hit()` callable from a dummy enemy script (no get_node required)
- `SaveManager.register_save_provider()` callable from a non-autoload scene script
- `GameManager.take_damage()` callable from a hazard Area2D script
- `AudioSystem.play_sfx()` callable from AudioFeedbackSystem
- `DialogueManager` position in project.godot matches slot 8 (verify after plugin enable/disable)
- No autoload _ready() produces null reference errors (indicates load order violation)

## Related Decisions

- ADR-0002: Signal Hub / GameManager Contract — depends on this ADR; defines GameManager's full signal surface
- ADR-0007: Damage API & SpellInteractionEngine Contract — depends on this ADR; defines SpellInteractionEngine's full API
- `design/gdd/spell-slot-system.md` — TR-slot-001
- `design/gdd/spell-interaction-engine.md` — TR-interaction-001, TR-interaction-012
- `design/gdd/audio-system.md` — TR-audio-007
- `design/gdd/save-load-system.md` — TR-save-003
- `design/gdd/audio-feedback-system.md` — TR-audiofb-001
- `design/gdd/spell-vfx-system.md` — TR-vfx-001
- `design/gdd/dialogue-system.md` — TR-dialogue-001, TR-dialogue-004
- `design/gdd/hazard-system.md` — TR-hazard-002
- `design/gdd/movement-system.md` — TR-movement-004
- `design/gdd/spell-upgrade-system.md` — TR-upgrade-003
