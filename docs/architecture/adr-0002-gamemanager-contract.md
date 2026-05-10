# ADR-0002: GameManager — Signal Hub and Player State Contract

## Status
Proposed

## Date
2026-05-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Scripting) |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff (cutoff ≈ 4.3) |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — signal declaration syntax and typed parameters unchanged since 4.3; confirmed by engine specialist |
| **Verification Required** | (1) Confirm `max` is not used as signal parameter name — use `maximum` instead (existing file already correct). (2) After migrating signal signatures, confirm all `_on_boss_appeared` and `_on_boss_defeated` handler signatures are updated. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture — GameManager must be registered per that ADR before this contract applies) |
| **Enables** | ADR-0007 (Damage API — defines take_damage() entry point formally), all boss/health/UI/audio ADRs |
| **Blocks** | Any story that connects to GameManager signals or reads GameManager state cannot be started until this ADR is Accepted |
| **Ordering Note** | The Devium boss migration (boss_appeared + boss_defeated signal parameter changes) must be completed before any boss-related stories can be written with stable TR references |

## Context

### Problem Statement

`GameManager` (`res://scripts/systems/game_manager.gd`) already exists as a working autoload. However, its current implementation has four critical mismatches with the GDD specifications:

1. `boss_appeared` uses a 2-parameter signature `(boss_name: String, max_health: int)` — GDD specifies 3 parameters with boss id for multi-boss tracking
2. `boss_defeated` emits no parameters — GDD specifies `(id: StringName)` for tracking which boss was defeated
3. `abilities` is a `Dictionary` with `String` keys — types should be `StringName` for performance on repeated lookups
4. Internal field names `respawn_scene`/`respawn_position` differ from GDD terminology `checkpoint_room`/`checkpoint_position`

Without this ADR, stories will be written against an unstable interface that will need to change, creating rework. This ADR locks the canonical contract and specifies the migration path for the four mismatches.

### Constraints

- `GameManager` already exists and is used by live Devium boss code — signal signature changes are breaking and require migrating all consumers
- Project is GDScript only; `StringName` and `String` are implicitly coercible, but typed callables will see a mismatch — all call sites must be updated
- The pattern "combined event hub + player state facade" is a known coupling trade-off acceptable for this scale. Acknowledged in Consequences.

### Requirements

- GameManager is the **single external entry point** for player health damage (all hazards, enemies, and traps call GameManager.take_damage())
- All cross-system boss lifecycle signals emitted from GameManager (not from the boss scene directly)
- All cross-system dialogue lifecycle signals emitted from GameManager
- Ability gating readable from any system via GameManager without querying the player scene
- Materials readable from any system via GameManager
- Upgrade tiers readable from any system via GameManager

## Decision

GameManager is the **combined event hub + player state facade** for Wizrless. It owns player-facing aggregate state and emits the cross-system lifecycle signals that multiple systems need to observe without coupling to the originating scene.

### State GameManager Owns

| Field | Type | Description | New/Existing |
|-------|------|-------------|--------------|
| `current_health` | `int` | Player current health | Existing |
| `max_health` | `int` | Player maximum health | Existing |
| `dialogue_active` | `bool` | True while a dialogue is running. Read-only for all non-GM systems. | Existing |
| `materials` | `Dictionary` | `{ StringName: int }` — per-element material counts (ember, frost, etc.) | **New** |
| `abilities_unlocked` | `Dictionary[StringName, bool]` | Ability gates — `{ &"dash": true, &"wall_jump": false, ... }`. Replaces old `abilities: Dictionary`. | Existing (renamed + retyped) |
| `upgrade_tiers` | `Dictionary[StringName, int]` | Per-spell upgrade level: `{ &"fireball": 2, &"ice_shard": 0, ... }` | **New** |
| `bosses_defeated` | `Array[StringName]` | IDs of defeated bosses. Persisted via SaveManager. | **New** |
| `checkpoint_room` | `String` | Scene path of the active checkpoint room. Replaces `respawn_scene`. | Existing (renamed) |
| `checkpoint_position` | `Vector2` | Player spawn position at active checkpoint. Replaces `respawn_position`. | Existing (renamed) |

### Signals GameManager Emits

```gdscript
# Boss lifecycle — emitted by BaseBoss subclass calling GameManager methods
signal boss_appeared(id: StringName, name: String, max_hp: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_defeated(id: StringName)

# Player lifecycle
signal player_died

# Dialogue lifecycle — forwarded from DialogueManager
signal dialogue_started
signal dialogue_ended
```

All signals use `StringName` for identifier parameters. `maximum` is used (not `max`) to avoid shadowing the GDScript built-in `max()` function.

### Methods GameManager Exposes

```gdscript
# Player damage — all external damage sources call this; GameManager applies directly
# to current_health and emits player_died if health reaches 0.
# (Future: may delegate to a HealthSystem node if the health system is extracted.
#  Health System ADR will define whether delegation is introduced.)
func take_damage(amount: int) -> void

# Ability gate — called by MovementSystem before allowing Dash, wall-jump, etc.
func has_ability(ability_id: StringName) -> bool

# Ability unlock — called by progression milestones and boss defeat handlers
func unlock_ability(ability_id: StringName) -> void

# Upgrade query — called by projectile scenes in _ready() to scale stats
func get_upgrade_tier(spell_id: StringName) -> int

# Upgrade write — called by UpgradeShrine interaction
func set_upgrade_tier(spell_id: StringName, tier: int) -> void

# Checkpoint — called by Checkpoint Area2D on activation
func set_checkpoint(room: String, position: Vector2) -> void

# Boss lifecycle — called by BaseBoss subclasses to emit signals
func emit_boss_appeared(id: StringName, name: String, max_hp: int) -> void
func emit_boss_health_changed(current: int, maximum: int) -> void
func emit_boss_defeated(id: StringName) -> void
```

### Architecture Diagram

```
Systems that write TO GameManager state:
  Hazards     → GameManager.take_damage()
  Enemies     → GameManager.take_damage()
  Boss scenes → GameManager.emit_boss_appeared/defeated()
  Checkpoints → GameManager.set_checkpoint()
  Materials   → (future MaterialSystem writes GameManager.materials)
  Milestones  → GameManager.unlock_ability()

Systems that read FROM GameManager:
  MovementSystem    → has_ability()
  SpellUpgrades     → get_upgrade_tier()
  HUD               → subscribes to boss_appeared/defeated + player_died
  AudioFeedback     → subscribes to player_died
  HealthSystem GDD  → subscribes to... (see HealthSystem ADR — TBD)
  SpellVFX          → (no direct GameManager reads)
  CheckpointRespawn → reads checkpoint_room + checkpoint_position on player_died
  DialogueSystem    → reads + sets dialogue_active; emits dialogue_started/ended
```

### Interaction with Other Autoloads

GameManager does NOT directly call SpellInteractionEngine, AudioSystem, SpellSlotSystem, or SpellVFXSpawner. These systems subscribe to GameManager signals or are called from game scenes directly. Cross-cutting concerns go through signals, not direct inter-autoload calls from GameManager.

Exception: DialogueManager signals are forwarded — GameManager subscribes to DialogueManager.dialogue_started/dialogue_ended and re-emits them as its own signals, while also setting `dialogue_active`.

## Alternatives Considered

### Alternative A: Thin Event Bus (signals only)
- **Description**: GameManager emits signals only; all state lives in dedicated autoloads (MaterialSystem, AbilitySystem, etc.)
- **Pros**: Better separation of concerns; each system is independently testable
- **Cons**: Requires more autoloads (currently 4 new would be needed); more boilerplate; GDDs all reference GameManager state directly
- **Rejection Reason**: GDDs explicitly reference `GameManager.materials`, `GameManager.has_ability()` etc. Adopting this pattern requires revising the entire GDD suite. Premature for this stage.

### Alternative B: Split SignalBus + PlayerState
- **Description**: Two autoloads — `SignalBus` for events, `PlayerState` for mutable data
- **Pros**: Clean separation; SignalBus is trivially testable
- **Cons**: Two more autoloads; the existing GameManager already combines both; requires migration of all current consumers
- **Rejection Reason**: Existing code already combines both. Splitting now is pure rework with no immediate gameplay benefit.

## Consequences

### Positive
- Complete, stable contract for GameManager — stories can safely reference it
- Mismatched signal signatures resolved before more boss code is written
- `StringName` types for identifiers — efficient repeated lookups at runtime
- Migration path documented — Devium and any other consumers know exactly what to update

### Negative
- Signal parameter changes are breaking — all existing `_on_boss_appeared` and `_on_boss_defeated` handlers must be updated before this ADR moves to Accepted
- Combined hub+facade creates a single point of coupling: any system subscribing to boss events transitively depends on player health state fields on the same node. Accepted trade-off at this scale.

### Risks

- **Consumer migration missed**: If any handler is missed during the boss_appeared/boss_defeated parameter migration, it will produce a runtime connection error at boss encounter. **Mitigation**: the Migration Plan below lists all known consumer sites; grep `boss_appeared` and `boss_defeated` across codebase before marking Accepted.
- **abilities Dictionary collision**: Current `abilities: Dictionary` uses String keys. After renaming to `abilities_unlocked: Dictionary[StringName, bool]`, any load of old save data will fail to find keys (StringName vs String coercion inconsistency in persisted JSON). **Mitigation**: SaveManager migration must be tested against existing save files before deploying this change.

## Migration Plan

These changes must be made to `res://scripts/systems/game_manager.gd` before this ADR moves from `Proposed` to `Accepted`:

### 1. boss_appeared — add id parameter

```gdscript
# BEFORE:
signal boss_appeared(boss_name: String, max_health: int)

# AFTER:
signal boss_appeared(id: StringName, name: String, max_hp: int)
```

Update all consumers: grep `_on_boss_appeared`, `boss_appeared.connect`, `boss_appeared.emit`.

### 2. boss_defeated — add id parameter

```gdscript
# BEFORE:
signal boss_defeated()

# AFTER:
signal boss_defeated(id: StringName)
```

Update all consumers including `stop_boss_music` callable — change to accept one arg.

### 3. abilities → abilities_unlocked (Dictionary[StringName, bool])

```gdscript
# BEFORE:
var abilities: Dictionary = { "dash": false, "wall_jump": false, ... }

# AFTER:
var abilities_unlocked: Dictionary[StringName, bool] = {
    &"dash": false, &"wall_jump": false, ...
}
```

Update `has_ability()` and `unlock_ability()` signatures to `StringName`. Update all call sites.

### 4. Rename respawn fields to checkpoint fields

```gdscript
# BEFORE:
var respawn_scene: String
var respawn_position: Vector2

# AFTER:
var checkpoint_room: String
var checkpoint_position: Vector2
```

Update all references: `set_respawn_point()` becomes `set_checkpoint()` (may already match).

### 5. Add new fields

Add net-new fields with zero-value defaults:
```gdscript
var materials: Dictionary[StringName, int] = {}
var upgrade_tiers: Dictionary[StringName, int] = {}
var bosses_defeated: Array[StringName] = []
```

### 6. Save/Load provider registration

GameManager must register a SaveManager provider in _ready() for its state fields:
```gdscript
func _ready() -> void:
    SaveManager.register_save_provider("game_manager", _save, _load)
```

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-boss-008 | boss-system.md | Signals: boss_appeared(id, name, max_hp), boss_health_changed(current, max), boss_defeated(id) | All three signals defined with correct typed signatures |
| TR-hazard-002 | hazard-system.md | All hazard damage routes through GameManager.take_damage() | take_damage(amount: int) defined as the canonical player damage entry point |
| TR-material-002 | material-system.md | GameManager.materials: Dictionary stores per-type counts | materials: Dictionary[StringName, int] defined |
| TR-movement-004 | movement-system.md | Ability gating via GameManager.has_ability(ability_id) | has_ability(ability_id: StringName) -> bool defined |
| TR-upgrade-003 | spell-upgrade-system.md | Projectile reads tier via GameManager.get_upgrade_tier(spell_id) | get_upgrade_tier(spell_id: StringName) -> int defined |
| TR-checkpoint-002 | checkpoint-respawn-system.md | On activation: GameManager.set_checkpoint(room, position) | set_checkpoint(room: String, position: Vector2) defined |
| TR-dialogue-004 | dialogue-system.md | GameManager.dialogue_active flag suppresses gameplay input and grants invulnerability | dialogue_active: bool defined as GM-owned state |
| TR-dialogue-005 | dialogue-system.md | Signals: dialogue_started, dialogue_ended (forwarded from DialogueManager) | Both signals defined; GM forwards from DialogueManager |
| TR-health-004 | health-system.md | Signals: health_changed(current, max), player_damaged(amount), player_died | player_died signal defined; health_changed and player_damaged reserved for Health System ADR |
| TR-boss-009 | boss-system.md | Boss defeat triggers immediate save_game() | emit_boss_defeated() will call SaveManager.save_game() before emitting |

## Performance Implications

- **CPU**: Signal emissions are Godot-native and negligible; Dictionary lookups with StringName keys are O(1)
- **Memory**: New Dictionary fields (materials, upgrade_tiers) grow with game content — bounded by number of spell elements × spell types (< 100 keys total)
- **Frame**: No per-frame GameManager calls; all access is event-driven or one-shot

## Validation Criteria

- `boss_appeared` emits with 3 typed parameters; Devium boss connects correctly
- `boss_defeated` emits with id param; `stop_boss_music` callback updated to accept id
- `has_ability(&"dash")` returns correct value without runtime type error
- `GameManager.materials[&"ember"]` accessible from MaterialDrop scene without error
- `get_upgrade_tier(&"fireball")` returns 0 before any upgrade applied
- `set_checkpoint(scene_path, position)` stores correctly and returns same values on `player_died`
- `dialogue_active` is true while Dialogue Manager balloon is visible, false after

## Related Decisions

- ADR-0001: Autoload Singleton Architecture — defines that GameManager is autoload #2
- ADR-0007: Damage API & SpellInteractionEngine Contract — depends on take_damage() interface from this ADR
- `design/gdd/boss-system.md` — TR-boss-008, TR-boss-009
- `design/gdd/hazard-system.md` — TR-hazard-002
- `design/gdd/material-system.md` — TR-material-002
- `design/gdd/movement-system.md` — TR-movement-004
- `design/gdd/spell-upgrade-system.md` — TR-upgrade-003
- `design/gdd/checkpoint-respawn-system.md` — TR-checkpoint-002
- `design/gdd/dialogue-system.md` — TR-dialogue-004, TR-dialogue-005
- `design/gdd/health-system.md` — TR-health-004 (partial — full health signal surface in Health System ADR)
