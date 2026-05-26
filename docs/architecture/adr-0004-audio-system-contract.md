# ADR-0004: Audio System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation (Audio) |
| **Knowledge Risk** | MEDIUM — `AudioServer` and `AudioStreamPlayer` API stable; Godot 4.4+ changed some bus return types |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `design/gdd/audio-system.md` |
| **Post-Cutoff APIs Used** | `linear_to_db()` — built-in, unchanged. `AudioServer.set_bus_volume_db()` / `get_bus_volume_db()` — confirmed unchanged in 4.4–4.6. `AudioStreamPlayer.finished` signal — unchanged. |
| **Verification Required** | (1) Confirm `AudioServer.bus_count` can be read and matches project AudioBus Layout. (2) Confirm `AudioStreamPlayer.playing` property is readable without null-check in 4.6. (3) Confirm `Time.get_ticks_msec()` returns `int` in GDScript 4 — footstep dedup math uses int subtraction. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture — AudioSystem is autoload #5) |
| **Enables** | ADR-0022 (Audio Feedback System — wraps play_sfx()), ADR-0017 (Dialogue System — notify_voice_start/end), ADR-0019 (Boss System — music transitions), ADR-0008 (Health System — GUARANTEED SFX for death/hit) |
| **Blocks** | No story emitting sound effects or requesting music transitions may start until this ADR is Accepted |
| **Ordering Note** | AudioSystem (#5) must load before AudioFeedbackSystem (#9). Settings System must call set_bus_volume() after load — not during _ready(). |

## Context

### Problem Statement

Audio infrastructure is unarchitected: no bus layout is defined in `project.godot`, no SFX pool exists, and consuming systems call `AudioStreamPlayer` directly or create them at runtime. This causes audio allocation hitches during combat and makes bus volume control impossible. The GDD defines a complete audio architecture but no ADR locks it.

### Constraints

- AudioSystem is an autoload that survives scene transitions — music state persists across rooms
- `AudioStreamPlayer` nodes must be pre-allocated (no runtime allocation during gameplay)
- Voice duck must be instantaneous (no fade) because VO lines begin on a beat
- Settings System owns volume UI but AudioSystem owns the bus — they communicate via set/get_bus_volume()

## Decision

`AudioSystem` (autoload #5 per ADR-0001) owns all audio infrastructure: bus routing, SFX pool, music state machine, and voice ducking. No other system touches `AudioServer` or `AudioStreamPlayer` directly.

### Bus Architecture

Five buses in Godot AudioServer (defined in project AudioBus Layout `.tres`, not in code):

| Bus | Parent | Default Volume | Effect Chain |
|-----|--------|----------------|--------------|
| Master | — | 1.0 (linear) | Limiter: ceiling −1 dBFS |
| Music | Master | 1.0 | — |
| SFX | Master | 1.0 | — |
| UI | Master | 1.0 | — |
| Voice | Master | 1.0 | — |

AudioSystem initializes to 1.0 on `_ready()`. Settings System applies user preferences via `set_bus_volume()` after save load.

### Voice Ducking

When `notify_voice_start()` called: Music and SFX buses reduced to `pre_duck × 0.5` instantaneously. Reference-counted — `notify_voice_end()` decrements; duck lifts when counter reaches zero. Pre-duck values captured on first `notify_voice_start()` only.

### Music State Machine

Nine states, one active at a time. Higher priority state ignores lower-priority requests.

| State | Priority | Loop |
|-------|----------|------|
| DEATH | 8 | No |
| VICTORY | 7 | No |
| BOSS_FIGHT | 6 | Yes |
| BOSS_PREFIGHT | 5 | No |
| COMBAT | 4 | Yes |
| CUTSCENE | 3 | No |
| EXPLORATION | 2 | Yes |
| MENU | 1 | Yes |
| SILENCE | 0 | — |

BOSS_PREFIGHT → BOSS_FIGHT transition is **music-driven**: BOSS_PREFIGHT plays to completion → `music_track_finished(BOSS_PREFIGHT)` emits → Boss System starts the encounter → AudioSystem auto-transitions to BOSS_FIGHT. The music track is the authoritative clock for the pre-fight window.

### SFX Pool

```gdscript
enum SFXPriority { LOW = 0, NORMAL = 1, HIGH = 2, GUARANTEED = 3 }

# 16 AudioStreamPlayer children (gameplay SFX)
# 2 AudioStreamPlayer children (UI SFX — never evicted by gameplay requests)
# All pre-allocated in _ready(), never created at runtime
```

Slot selection:
1. Find a free slot → play
2. No free slot → find lowest-priority playing slot with priority < incoming
3. Tie on priority → evict earliest play timestamp
4. No evictable slot → drop request, return `false`

GUARANTEED slots never evicted. If all 16 slots are GUARANTEED and a 17th GUARANTEED arrives: dropped, return `false`.

Footstep deduplication: SFX tagged as footstep rejected if same stream played within last 80 ms (wall clock, not frames).

### Public API

```gdscript
# Play SFX from pool. Returns false if dropped.
func play_sfx(stream: AudioStream, priority: SFXPriority = SFXPriority.NORMAL, pitch_scale: float = 1.0) -> bool

# Request music state change. Ignored if current state has higher priority.
func request_music_transition(state: MusicState, stream: AudioStream, loop: bool) -> void

# Call when Voice bus begins playing. Triggers -6 dB duck.
func notify_voice_start() -> void

# Call when Voice bus stream ends. Decrements duck reference counter.
func notify_voice_end() -> void

# Set bus volume (linear 0.0–1.0). Called by Settings System. Clamped.
func set_bus_volume(bus_name: StringName, linear: float) -> void

# Read bus volume (linear). Called by Settings System before save.
func get_bus_volume(bus_name: StringName) -> float

# Emitted when a non-looping track completes naturally.
signal music_track_finished(state: MusicState)
```

### Volume Conversion

```gdscript
# Internal use only — converts public linear API to AudioServer dB
func _linear_to_bus_db(linear: float) -> float:
    return linear_to_db(max(linear, 0.0001))  # -80 dB floor
```

### Architecture Diagram

```
Settings System → set_bus_volume("Music", 0.8) → AudioServer.set_bus_volume_db(...)

Dialogue System  ─┐
Boss System        ├─ request_music_transition(state, stream, loop)
Zone System      ─┘     └─ MusicStateMachine: priority check → play/ignore

Spell System     ─┐
Health System    ─┤
AudioFeedback    ─┼─ play_sfx(stream, priority, pitch) → SFXPool → AudioStreamPlayer
HUD System       ─┤
Boss System      ─┘

Dialogue System → notify_voice_start() / notify_voice_end()
                    └─ VoiceDuckController: reference counter → Music/SFX bus duck

AudioStreamPlayer.finished → music_track_finished(BOSS_PREFIGHT) → Boss System
```

## Alternatives Considered

### Alternative A: Node-Based AudioSystem Inside Scene Tree

AudioSystem as a regular scene node, instanced into each room scene.

- **Pros**: Easier to inspect in scene debugger.
- **Cons**: Destroyed on scene change — music stops between rooms. Boss music cannot transition to exploration music across a scene load. SFX pool recreated per scene.
- **Rejected**: Music persistence across scene transitions is a hard requirement.

### Alternative B: Ambience as Sixth Bus

Add Ambience bus for zone-specific ambient audio.

- **Deferred**: Zone/Room GDD does not specify ambient audio for MVP. Add if Zone System requires it. OQ-AUD-002 tracks this. Adding a bus requires updating project AudioBus Layout `.tres` and this ADR.

## Consequences

### Positive
- Zero runtime AudioStreamPlayer allocation during gameplay — no hitch
- Single entry point (`play_sfx`) — bus routing, priority, and pool management invisible to callers
- Music-driven boss transition removes frame-timing fragility from the encounter start
- Voice duck reference counter handles nested VO without corruption

### Negative
- AudioSystem is now a dep for every system that emits sound — changes to bus layout require this ADR update
- BOSS_PREFIGHT track length must match dialogue window — co-authorship constraint between audio and narrative (OQ-AUD-004)
- 16 GUARANTEED slots hard-blocked if ever fully occupied (pool exhaustion)

### Risks

- **Bus layout desync**: Bus names in AudioBus Layout `.tres` must match the StringName literals used in `set_bus_volume()` calls. If a bus is renamed in the editor, AudioSystem silently does nothing. Mitigation: AudioSystem._ready() asserts all 5 bus names exist at launch.
- **Footstep dedup false positive during lag spike**: A frame > 80 ms could block a legitimate footstep. Mitigated by using wall clock (`Time.get_ticks_msec()`), not frame count.
- **BOSS_PREFIGHT never completes**: If the audio file is missing or corrupt, `music_track_finished` never fires → boss encounter never starts. Mitigation: Boss System sets a fallback timer (3× expected track duration) that force-starts the encounter if the signal hasn't fired.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-audio-001 | audio-system.md | Five audio buses with independent volume control | Bus Architecture section |
| TR-audio-002 | audio-system.md | 16-slot SFX pool | SFX Pool section |
| TR-audio-003 | audio-system.md | Priority-based eviction | SFX Pool slot selection algorithm |
| TR-audio-004 | audio-system.md | Music state machine with 9 states | Music State Machine section |
| TR-audio-005 | audio-system.md | BOSS_PREFIGHT→BOSS_FIGHT music-driven transition | Music State Machine transition description |
| TR-audio-006 | audio-system.md | Voice duck −6 dB, reference counted | Voice Ducking section |
| TR-audio-007 | audio-system.md | `play_sfx()` is the single SFX entry point | Public API section (also in ADR-0001) |

## Performance Implications

- **CPU (per SFX call)**: Linear scan of 16 slots = O(16). Constant time. < 0.01 ms.
- **CPU (per frame)**: Zero — pool slots checked only on `play_sfx()` calls, not per frame.
- **Memory**: 18 AudioStreamPlayer nodes (16 gameplay + 2 UI) × ~8 KB each ≈ 144 KB. Negligible.
- **Load time**: All 18 nodes created in `_ready()` before any scene loads.

## Validation Criteria

- AC-AUD-001: 5 buses at launch, all at 1.0 linear default
- AC-AUD-002: 16 + 2 AudioStreamPlayer children, none created post-ready
- AC-AUD-003: GUARANTEED-full pool drops NORMAL request (returns false)
- AC-AUD-004: HIGH evicts LOW slot
- AC-AUD-005: BOSS_FIGHT rejects EXPLORATION transition
- AC-AUD-006: DEATH interrupts BOSS_FIGHT within one frame
- AC-AUD-007: music_track_finished fires for non-looping track, not for looping
- AC-AUD-009: Voice duck applies only while AudioStreamPlayer.playing == true
- AC-AUD-010: Reference counter — duck lifts only on second notify_voice_end()
- AC-AUD-015: Zero AudioServer / AudioStreamPlayer references outside audio_system.gd

## Related Decisions

- ADR-0001: Autoload Singleton Architecture — AudioSystem is autoload #5
- ADR-0022: Audio Feedback System — subscribes to SIE signals, wraps play_sfx()
- ADR-0017: Dialogue System — notify_voice_start/end, BOSS_PREFIGHT transition
- ADR-0019: Boss System — music_track_finished → encounter start
- `design/gdd/audio-system.md` — full GDD, all TR-audio-* requirements
