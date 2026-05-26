# ADR-0005: Save/Load System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation (Persistence) |
| **Knowledge Risk** | MEDIUM — FileAccess API changed in Godot 4.4 (return types changed) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `design/gdd/save-load-system.md` |
| **Post-Cutoff APIs Used** | `FileAccess.file_exists(path)` — **Godot 4.4+ changed FileAccess return types**. Use `FileAccess.file_exists("user://path")` (static method) for existence checks — do NOT use `FileAccess.open()` null-check as the existence test, as return behavior changed. Verify in 4.6 docs. |
| **Verification Required** | (1) Confirm `FileAccess.file_exists()` is the correct static method name in Godot 4.6. (2) Confirm `FileAccess.rename()` exists as a static method for atomic rename in 4.6. (3) Confirm `JSON.stringify()` + `JSON.parse_string()` are the correct Godot 4.x JSON methods (not `JSON.print()` / `JSON.parse()`). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture — SaveManager is autoload #3) |
| **Enables** | ADR-0008 (Health System — registers "health" slice), ADR-0012 (Zone/Room System — registers "zones" slice), ADR-0016 (Checkpoint System — registers "checkpoints" slice), ADR-0019 (Boss System — registers "bosses" slice), ADR-0018 (Material System — registers "materials" slice) |
| **Blocks** | Any story implementing state persistence cannot start until this ADR is Accepted. Systems may not call FileAccess directly — they must register with SaveManager. |
| **Ordering Note** | SaveManager is autoload #3 — loads before all systems that call `register_save_provider()` in `_ready()`. This is the load-order guarantee. |

## Context

### Problem Statement

Persistent state is scattered: `GameManager.gd` directly writes data, there is no atomic write safety, and no system has a formal contract for what it persists or how it registers. The GDD specifies a provider-registration pattern but no ADR formalises the API, file format, or safety guarantees.

### Constraints

- One save slot — no profile system
- Settings System uses a separate file (`user://settings.json`) — NOT registered with SaveManager
- Godot 4.4+ changed FileAccess return types — must use static `FileAccess.file_exists()` for existence checks
- Atomic write required: interrupted writes must not corrupt the save

## Decision

`SaveManager` (autoload #3 per ADR-0001) is the single system that writes to `user://wizrless_save.json`. All other systems register their slice via `register_save_provider()`. No system writes to disk except `SaveManager` and `SettingsSystem`.

### Public API

```gdscript
## Register a system's save/load participation.
## key: unique slice name in the JSON document.
## save_fn: called with no args; must return Dictionary.
## load_fn: called with the system's Dictionary slice on load.
func register_save_provider(key: String, save_fn: Callable, load_fn: Callable) -> void

## Called on boot. Emits save_loaded or no_save_found.
func check_and_load() -> void

## Start a new playthrough. Emits confirm_overwrite if file exists.
func new_game() -> void

## Trigger a save. Called by Checkpoint, Boss, and Zone systems.
func save_game() -> void

## Returns true if a save file exists and is not corrupt.
func has_save() -> bool

# Signals
signal save_loaded
signal no_save_found
signal confirm_overwrite          # UI must handle; calls new_game() only on confirm
signal save_error(message: String)
```

### Save Document Structure

```json
{
  "meta": {
    "save_version": 1,
    "timestamp_unix": 0,
    "playtime_seconds": 0,
    "game_version": "0.1.0"
  },
  "health":      { ... },
  "spells":      { ... },
  "zones":       { ... },
  "checkpoints": { ... },
  "materials":   { ... },
  "spell_upgrades": { ... },
  "bosses":      { ... },
  "lore":        { ... }
}
```

`meta` slice owned by SaveManager. All other slices owned by the registered system. SaveManager does not inspect or validate system slice content.

### Registered Providers

| System | JSON Key | What It Persists |
|--------|----------|-----------------|
| Health System | `"health"` | current_health, max_health |
| Spell System | `"spells"` | owned spells, slot count, equipped loadout |
| Zone/Room System | `"zones"` | visited rooms, cleared enemies, opened doors |
| Checkpoint System | `"checkpoints"` | last activated checkpoint ID |
| Material System | `"materials"` | material type → quantity map |
| Spell Upgrade System | `"spell_upgrades"` | per-spell upgrade levels |
| Boss System | `"bosses"` | defeated boss IDs (permanent) |
| Lore Fragment System | `"lore"` | discovered fragment IDs |

### Save Trigger Callers

| System | When It Calls save_game() |
|--------|--------------------------|
| Checkpoint System | Immediately on player checkpoint activation |
| Boss System | After defeat animation completes |
| Zone/Room System | When new zone is fully loaded |

No other system may call `save_game()` directly.

### Atomic Write Procedure

```gdscript
func save_game() -> void:
    if _state == State.SAVING:
        _pending_save = true
        return
    _state = State.SAVING
    var doc := _collect_all_slices()   # calls each registered save_fn()
    var json := JSON.stringify(doc)
    var tmp := "user://wizrless_save.tmp"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        _state = State.IDLE
        save_error.emit("disk_full")
        return
    f.store_string(json)
    f.close()
    # Atomic rename: tmp → save file
    var err := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(tmp),
        ProjectSettings.globalize_path("user://wizrless_save.json")
    )
    if err != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
        save_error.emit("rename_failed")
    _state = State.IDLE
    if _pending_save:
        _pending_save = false
        save_game()
```

On failed write: `.tmp` deleted. Previous save intact. `save_error` emitted.

### State Machine

```
NO_FILE ──new_game()──→ IDLE ──save_game()──→ SAVING ──write ok──→ IDLE
                          ↑                      │ write fail ─────→ IDLE (save_error emitted)
                          └──────────────────────┘ (pending queue)
IDLE ──check_and_load()──→ LOADING ──read ok──→ IDLE (save_loaded)
                                     └─parse fail→ IDLE → NO_FILE (save_error + corrupt backup)
```

### Error Handling

| Error | Action |
|-------|--------|
| JSON parse fail | Rename to `.corrupt.json`, transition to NO_FILE, emit save_error |
| `save_version` too new | Treat as NO_FILE, preserve file, emit save_error("version_too_new") |
| Missing system slice on load | Call load_fn({}) — system initialises to defaults |
| load_fn throws | Log key + error, continue with other systems, emit save_error |
| Disk full | Delete .tmp, preserve old save, emit save_error("disk_full") |

### Playtime Formula

```
playtime_on_save = playtime_stored + floor((Time.get_ticks_msec() - session_start_ticks) / 1000)
```

Not paused during pause menu. Display: `HH:MM` where `hours = p / 3600`, `minutes = (p % 3600) / 60`.

## Alternatives Considered

### Alternative A: Direct FileAccess Per System

Each system writes its own file (health.json, zones.json, etc.).

- **Pros**: Systems are fully independent; no registration needed.
- **Cons**: No atomic write across systems; player save is split across files; no single save-game trigger; file count grows with each system.
- **Rejected**: AC-SAV-011 explicitly requires zero FileAccess calls outside SaveManager.

### Alternative B: Godot ConfigFile Instead of JSON

Use Godot's built-in `ConfigFile` (INI-like format) instead of JSON.

- **Pros**: Built-in Godot API; typed sections.
- **Cons**: Not human-readable; no standard migration path; GDD specifies JSON.
- **Rejected**: GDD specifies JSON. Steam Cloud Saves (OQ-SAV-002) work cleanly with JSON.

## Consequences

### Positive
- Single write path — atomic write protects all system state at once
- Registration pattern — SaveManager stays decoupled from system internals
- Missing slice handled gracefully — forward-compatibility without migration for additive changes
- Corrupt file preserved — player can potentially recover `.corrupt.json` manually

### Negative
- All systems must register before `check_and_load()` is called — boot sequence ordering is critical
- Save queue holds only 1 pending save — a rapid sequence of 3 triggers drops the 3rd
- No multiple save slots — not a constraint today but can't be retrofitted without breaking the JSON structure

### Risks

- **FileAccess API drift**: Godot 4.4+ changed FileAccess. Verification Required items above must be confirmed before implementation. If `FileAccess.file_exists()` signature changed again in 4.6, adapt accordingly.
- **Boot ordering**: If a system registers after `check_and_load()` fires, its `load_fn` is never called for the current session. Mitigation: `check_and_load()` deferred to end of `_ready()` chain via `call_deferred()` — all Autoloads complete `_ready()` before deferred calls fire.
- **New Game data race**: `new_game()` during active save queues the delete, but the old save is intact until the queue processes. Mitigation: documented in state machine above.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-save-001 | save-load-system.md | Automatic save triggers (checkpoint, boss defeat, zone transition) | Save Trigger Callers table |
| TR-save-002 | save-load-system.md | Atomic write with .tmp → rename | Atomic Write Procedure section |
| TR-save-003 | save-load-system.md | `register_save_provider()` pattern | Public API section (also in ADR-0001) |
| TR-save-004 | save-load-system.md | Corrupt save handling — rename to .corrupt.json | Error Handling table |
| TR-save-005 | save-load-system.md | Missing slice → load_fn({}) | Error Handling table |
| TR-save-006 | save-load-system.md | One save slot; Settings System excluded | Decision intro + Registered Providers table |

## Performance Implications

- **I/O**: JSON write is synchronous — blocks for the write duration. For small saves (<16 KB), < 5 ms. At MVP save complexity, negligible.
- **CPU**: JSON.stringify() on the full document — O(N) with N = total persisted fields. Negligible at MVP scale.
- **Memory**: Full save document held in memory during write. At MVP: < 10 KB. Negligible.

## Validation Criteria

- AC-SAV-001: `has_save()` true after `new_game()`, file contains valid JSON with `meta`
- AC-SAV-002: register/save/load round-trip preserves data exactly
- AC-SAV-003: atomic write simulation — old save intact on failed write
- AC-SAV-004: corrupt JSON → `save_error` + `.corrupt.json` created + `has_save()` false
- AC-SAV-005: missing slice → `load_fn({})` called, no crash
- AC-SAV-006: 3 rapid save_game() calls → exactly 2 write operations
- AC-SAV-011: zero `FileAccess` calls outside `save_system.gd` and `settings_system.gd`

## Related Decisions

- ADR-0001: Autoload Singleton Architecture — SaveManager is autoload #3
- ADR-0008: Health System — registers "health" slice
- ADR-0012: Zone/Room System — registers "zones" slice
- ADR-0016: Checkpoint System — registers "checkpoints" slice
- ADR-0019: Boss System — registers "bosses" slice
- `design/gdd/save-load-system.md` — full GDD, all TR-save-* requirements
