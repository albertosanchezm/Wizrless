# Audio System

> **Status**: Complete
> **Author**: albertosanchezm + agents
> **Last Updated**: 2026-04-17
> **Implements Pillar**: Foundation — enables Spell Alchemy (interaction audio feedback), Earned Truth (boss music atmosphere)

## Overview

The Audio System is the bus architecture and playback infrastructure that all other game systems use to emit sound. It defines the project's audio routing graph (which bus categories exist), manages a pooled set of `AudioStreamPlayer` nodes for concurrent SFX playback, and exposes a simple playback interface so consuming systems never interact with Godot's `AudioServer` or `AudioStreamPlayer` nodes directly.

Four bus categories are defined: **Music** (zone ambient tracks, boss themes), **SFX** (spell casts, impacts, interactions, environmental), **UI** (menu navigation, HUD feedback), and **Voice** (reserved for future boss dialogue voiceover). Each category maps to a volume knob in the Settings System (PL1) and is independently mutable. The Master bus controls overall output volume.

All SFX playback goes through a pre-allocated pool of `AudioStreamPlayer` nodes (pool size: tuning knob). Consuming systems call a single playback method with an `AudioStream` resource; the Audio System resolves the correct pool slot. This prevents runtime allocation hitches during spell casts and combat impacts.

## Player Fantasy

The Audio System has no player fantasy of its own. It is the bus architecture, volume routing, and SFX pool that downstream systems draw upon — the player never touches it directly.

What this infrastructure enables is the fantasy. The Spell System and Audio Feedback System turn every cast into an experiment the ear can read: a cancel lands as a dull collapse, an amplification bites harder than either spell alone, a transformation arrives as a sound the player has never heard before — the first confirmation that something new exists. The Boss System uses the Voice and Music buses to stage the game's only warm moments: a held breath before the theme drops, a voice that knows the wizard's name.

The moment this makes possible: the first boss speaks. Ambience thins. A single line of dialogue on the Voice bus, clean, almost kind. Then the theme — low, patient, inevitable. The player understands, before the fight begins, that they were seen long before they arrived.

*Systems that deliver this fantasy:* Spell System (C3), Audio Feedback System (P3), Boss System (FT6), Dialogue System (FT7).

## Detailed Design

### Core Rules

**C1 — Bus Architecture**

Five buses are defined in Godot's AudioServer. The Audio System owns their creation, volume routing, and effect chain. No other system interacts with `AudioServer` directly.

| Bus | Parent | Default Volume | Effect Chain |
|-----|--------|----------------|--------------|
| Master | — | 1.0 (linear) | Limiter: ceiling −1 dBFS |
| Music | Master | 1.0 | — |
| SFX | Master | 1.0 | — |
| UI | Master | 1.0 | — |
| Voice | Master | 1.0 | — |

When Voice bus has an active stream (`notify_voice_start()` called): Music, SFX, and Ambience volumes are reduced by −6 dB (linear 0.5×) instantaneously. Restored instantaneously on `notify_voice_end()`. The duck applies only while `AudioStreamPlayer.playing == true` on the Voice bus — not on state entry alone.

### States and Transitions

**C2 — Music State Machine**

Nine music states. Only one state is active at a time. State changes are requested via `request_music_transition()`; the Audio System resolves priority conflicts.

| State | Priority | Loop |
|-------|----------|------|
| DEATH | 8 (highest) | No |
| VICTORY | 7 | No |
| BOSS_FIGHT | 6 | Yes |
| BOSS_PREFIGHT | 5 | No |
| COMBAT | 4 | Yes |
| CUTSCENE | 3 | No |
| EXPLORATION | 2 | Yes |
| MENU | 1 | Yes |
| SILENCE | 0 (lowest) | — |

**Priority rule**: A lower-priority request is ignored if a higher-priority state is active. DEATH and VICTORY always interrupt. SILENCE cannot be overridden by a request — it must be the explicit target.

**BOSS_PREFIGHT → BOSS_FIGHT transition (music-drives-transition model):**
1. Dialogue System triggers `request_music_transition(BOSS_PREFIGHT, stream, loop: false)`
2. BOSS_PREFIGHT track plays to completion
3. On natural end, Audio System emits `music_track_finished(BOSS_PREFIGHT)`
4. Boss System listens to this signal and begins the encounter (spawns boss, enables hitbox)
5. Audio System auto-transitions to BOSS_FIGHT on signal emission

This makes the music track the authoritative clock for the pre-fight window. Dialogue and pre-fight music must be co-authored to the same runtime window.

### Interactions with Other Systems

**C3 — SFX Pool**

Sixteen `AudioStreamPlayer` nodes, pre-allocated on `_ready()`, permanently attached to the scene tree under AudioSystem. No runtime allocation during gameplay.

| Priority Tier | Value | Behaviour |
|---------------|-------|-----------|
| GUARANTEED | 3 | Never evicted; reserved for health-critical feedback (death, hit confirmation) |
| HIGH | 2 | Evicts NORMAL and LOW slots |
| NORMAL | 1 | Evicts LOW slots only |
| LOW | 0 | Evicted by any higher tier; dropped if pool is full |

Slot selection: find a free slot first. If none free, find the lowest-priority playing slot whose priority is strictly less than the incoming request. If a tie, evict the slot with the earliest play timestamp. If no evictable slot exists, the request is dropped and `play_sfx()` returns `false`.

Footstep deduplication: any SFX tagged as a footstep is rejected if the same stream played within the last 80 ms.

Two dedicated `AudioStreamPlayer` nodes outside the pool handle UI SFX (menu navigation, HUD feedback). UI players are never evicted by gameplay SFX.

**C4 — Public Interface**

`AudioSystem` is a singleton Autoload. All consuming systems use only these methods. No system calls `AudioServer` or touches `AudioStreamPlayer` nodes directly.

```gdscript
## Attempt to play an SFX from the pool. Returns false if dropped.
func play_sfx(stream: AudioStream,
              priority: SFXPriority = SFXPriority.NORMAL,
              pitch_scale: float = 1.0) -> bool

## Request a music state change. Ignored if current state has higher priority.
func request_music_transition(state: MusicState,
                               stream: AudioStream,
                               loop: bool) -> void

## Call when a Voice bus stream begins playing. Triggers −6 dB duck.
func notify_voice_start() -> void

## Call when Voice bus stream ends. Restores pre-duck volumes.
func notify_voice_end() -> void

## Set a bus volume. linear is 0.0–1.0 (not dB). Used by Settings System.
func set_bus_volume(bus_name: StringName, linear: float) -> void

## Read a bus volume (linear). Used by Settings System to persist/restore.
func get_bus_volume(bus_name: StringName) -> float

## Emitted when a non-looping track completes naturally.
signal music_track_finished(state: MusicState)
```

**C5 — Volume Persistence Contract**

On `_ready()`, AudioSystem initialises all buses to 1.0 linear. The Settings System is responsible for loading persisted volume values and calling `set_bus_volume()` per bus after save data is read. AudioSystem does not read save data directly — it only accepts and applies values the Settings System provides.

## Formulas

**F1 — Linear Volume to AudioServer dB Conversion**

Godot's `AudioServer.set_bus_volume_db()` takes decibels. The public interface accepts linear (0.0–1.0) for simplicity. The conversion:

```
db = 20 × log₁₀(linear)     when linear > 0.0
db = -80.0                   when linear = 0.0  (silence floor)
```

Variables:
- `linear` — input, range [0.0, 1.0]
- `db` — output, range [−80.0, 0.0] dBFS

In GDScript: `linear_to_db(linear)` (built-in). The −80 dB floor is enforced by clamping: `linear_to_db(max(linear, 0.0001))`.

---

**F2 — Voice Duck Attenuation**

When `notify_voice_start()` is called, affected buses are attenuated by −6 dB:

```
ducked_linear = pre_duck_linear × 0.5
```

Variables:
- `pre_duck_linear` — the bus's volume at the moment `notify_voice_start()` fires
- `ducked_linear` — applied volume during VO playback, range [0.0, 0.5]

The pre-duck value is stored per bus and restored exactly on `notify_voice_end()`. No interpolation — the cut is instantaneous because VO lines begin on a beat and the snap is preferable to a fade that starts before the voice.

## Edge Cases

**E1 — Priority conflict: simultaneous high-priority music requests**
Two systems request a music state change in the same frame. Rule: process requests in the order received this frame; the second request supersedes the first only if its priority is strictly higher. DEATH (8) always wins over BOSS_FIGHT (6). If same priority, first request wins.

**E2 — Pool exhausted with all GUARANTEED slots occupied**
Sixteen slots full, all GUARANTEED. A new GUARANTEED request arrives. Rule: GUARANTEED slots are never evicted — the new request is dropped and `play_sfx()` returns `false`. If this fires in production, the pool size tuning knob must be raised.

**E3 — Interrupted fade: scene transition during active music**
Scene unloads while a music track is playing. Rule: AudioSystem is an Autoload and persists across scene transitions. The active music state is preserved. The arriving scene must explicitly call `request_music_transition()` if it wants different music. No auto-stop on scene change.

**E4 — notify_voice_end() called without a preceding notify_voice_start()**
Caller error. Rule: AudioSystem tracks duck state with a counter. If `notify_voice_end()` is called when counter is already zero, it is a no-op. No crash, no volume change.

**E5 — notify_voice_start() called twice before notify_voice_end()**
Two overlapping VO lines. Rule: duck state uses a reference counter. `notify_voice_start()` increments; `notify_voice_end()` decrements. Duck is lifted only when counter reaches zero. Pre-duck volumes are captured on the first `notify_voice_start()` only.

**E6 — Volume persistence corruption: save data contains out-of-range value**
Settings System calls `set_bus_volume()` with a value outside [0.0, 1.0]. Rule: AudioSystem clamps the input: `linear = clamp(linear, 0.0, 1.0)`. No error raised — the clamped value is applied silently.

**E7 — music_track_finished fires for a looping track**
Looping tracks never emit `music_track_finished` — the signal fires only when a non-looping stream reaches its natural end. If a looping track is stopped externally via `request_music_transition()`, no signal is emitted. Boss System must not rely on this signal for looping BOSS_FIGHT tracks.

**E8 — Game loaded mid-boss-fight (continue from save)**
Player saves inside a boss arena. On load, Dialogue System is not active, so BOSS_PREFIGHT never plays. Boss System must detect this condition and call `request_music_transition(BOSS_FIGHT, ...)` directly. This is a Boss System responsibility — AudioSystem has no concept of "resume from save."

**E9 — Footstep deduplication window during lag spike**
A frame takes longer than 80 ms. Rule: timestamps are measured in real time (`Time.get_ticks_msec()`), not in frames. A lag spike does not cause the dedup window to fire early or double-fire.

## Dependencies

**Upstream (systems AudioSystem depends on):**

| System | What AudioSystem needs from it |
|--------|-------------------------------|
| Settings System (PL1) | Calls `set_bus_volume()` per bus after loading persisted values. AudioSystem initialises to 1.0 defaults on `_ready()` and waits. |

AudioSystem is Foundation-layer — it has no other boot-time dependencies.

**Downstream (systems that depend on AudioSystem):**

| System | How it uses AudioSystem |
|--------|------------------------|
| Spell System (C3) | `play_sfx()` for cast, impact, and cancellation sounds |
| Health System (C2) | `play_sfx(GUARANTEED)` for hit confirmation and death |
| Boss System (FT6) | `request_music_transition()` for BOSS_PREFIGHT and BOSS_FIGHT; listens to `music_track_finished` to time encounter start |
| Dialogue System (FT7) | `notify_voice_start()` / `notify_voice_end()` to bracket VO; triggers BOSS_PREFIGHT via `request_music_transition()` |
| Audio Feedback System (P3) | Wraps `play_sfx()` with game-context logic (pitch variation, SFX selection by state); AudioSystem is stateless about game context |
| HUD System (P1) | `play_sfx()` via UI players for menu navigation and HUD feedback |
| Settings System (PL1) | `get_bus_volume()` to read current values before persisting; `set_bus_volume()` to restore on load |

**Interface contract:** All downstream systems treat AudioSystem as an opaque service. They provide a stream and a request — they never inspect pool state, bus internals, or music state directly.

## Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `sfx_pool_size` | 16 | 8–32 | Maximum concurrent gameplay SFX. Raise if E2 edge case fires in production. |
| `voice_duck_db` | −6 dB (0.5×) | −3 dB to −12 dB | How much music/SFX drops under VO. Shallower = more musical bleed; deeper = cleaner voice. |
| `footstep_dedup_ms` | 80 ms | 40–150 ms | Minimum gap between repeated footstep sounds. Lower = faster cadence; higher = more dedup protection. |
| `master_limiter_ceiling_dbfs` | −1.0 dBFS | −0.5 to −3.0 | Peak ceiling on master output. Lower = more headroom, quieter max volume. |
| `bus_default_volume` | 1.0 (linear) | 0.0–1.0 | Initial volume for each bus before Settings System applies user preferences. Change only during audio mix tuning. |

All knobs are constants in `AudioSystem.gd`. They are not exposed to the Settings System — Settings System controls per-bus volume only, not these structural parameters.

## Acceptance Criteria

**AC-AUD-001 — Bus architecture initialises correctly**
On game launch, Godot's AudioServer contains exactly 5 buses (Master, Music, SFX, UI, Voice) with default volumes of 1.0 linear each. No other buses exist.

**AC-AUD-002 — SFX pool pre-allocated**
On scene load, AudioSystem contains exactly 16 `AudioStreamPlayer` children plus 2 dedicated UI players. No `AudioStreamPlayer` nodes are created after `_ready()` completes.

**AC-AUD-003 — play_sfx returns false when pool exhausted and no evictable slot exists**
Fill all 16 pool slots with GUARANTEED-priority SFX. Call `play_sfx()` with NORMAL priority. Return value must be `false`. No crash. Pool state unchanged.

**AC-AUD-004 — Priority eviction: HIGH evicts LOW**
Fill pool with 16 LOW-priority SFX. Call `play_sfx()` with HIGH priority. Return value must be `true`. One LOW slot is evicted. Sixteen slots remain occupied.

**AC-AUD-005 — Music state machine respects priority**
While BOSS_FIGHT (priority 6) is active, call `request_music_transition(EXPLORATION, stream, true)`. Exploration must not play. BOSS_FIGHT continues uninterrupted.

**AC-AUD-006 — DEATH interrupts BOSS_FIGHT**
While BOSS_FIGHT is active, call `request_music_transition(DEATH, stream, false)`. DEATH track must begin within one frame. BOSS_FIGHT stops.

**AC-AUD-007 — music_track_finished emitted on non-looping track end**
Play a non-looping stream in BOSS_PREFIGHT state. When the stream ends naturally, `music_track_finished(BOSS_PREFIGHT)` must be emitted. No signal emitted for a looping track stopped externally.

**AC-AUD-008 — Boss pre-fight transition is music-driven**
Connect a listener to `music_track_finished`. Play a 2-second non-looping BOSS_PREFIGHT track. Listener fires at ≤2.1 seconds. Boss encounter does not begin before the signal fires.

**AC-AUD-009 — Voice duck applies only while playing**
Call `notify_voice_start()` before Voice bus `AudioStreamPlayer` is playing. Music bus volume must remain at pre-duck level. Start playing on Voice bus. Music bus must drop to 0.5× within one frame.

**AC-AUD-010 — Voice duck reference counter**
Call `notify_voice_start()` twice. Call `notify_voice_end()` once. Music bus must remain ducked. Call `notify_voice_end()` again. Music bus must restore to pre-duck volume.

**AC-AUD-011 — Volume clamp on out-of-range input**
Call `set_bus_volume("Music", 1.5)`. Music bus volume must be set to 1.0. No error raised.

**AC-AUD-012 — Footstep deduplication**
Call `play_sfx(footstep_stream)` twice within 80 ms. Second call must return `false`. Call again after 80 ms has elapsed. Third call must return `true`.

**AC-AUD-013 — Scene persistence**
Load Scene A, request EXPLORATION music. Transition to Scene B without calling `request_music_transition()`. EXPLORATION music must still be playing in Scene B.

**AC-AUD-014 — Settings System volume round-trip**
Call `set_bus_volume("SFX", 0.6)`. Call `get_bus_volume("SFX")`. Return value must be 0.6 ± 0.001.

**AC-AUD-015 — No direct AudioServer calls outside AudioSystem**
Grep the codebase for `AudioServer.` and `AudioStreamPlayer` references outside `audio_system.gd`. Result must be zero matches.

## Open Questions

**OQ-AUD-001 — ADR for AudioSystem Autoload vs. SceneTree node**
AudioSystem is designed as a singleton Autoload. This decision should be recorded in an ADR before implementation. The alternative (a SceneTree node that consuming scenes must reference) was rejected on the grounds that audio must survive scene transitions — an ADR formalises this choice.

**OQ-AUD-002 — Ambience bus**
The current design has four active buses (Music, SFX, UI, Voice). Zone-specific ambient audio (wind, water, dungeon hum) would benefit from a fifth Ambience bus so it can be separately ducked and volume-controlled. Deferring to Save/Load and Zone/Room system designs to determine if ambient audio is in scope for MVP.

**OQ-AUD-003 — Existing asset naming migration**
`assets/audio/music/devium_combat.mp3` does not follow the naming convention (`mus_boss_devium_combat_loop.ogg`). Migration is a sound designer task and not a design-phase blocker, but should be tracked before audio implementation begins.

**OQ-AUD-004 — Boss Pre-Fight music authoring window**
The music-drives-transition model requires the BOSS_PREFIGHT track length to match the pre-fight dialogue window. The dialogue length for Devium is not yet authored. Both must be co-designed when the Dialogue System and Boss System GDDs are written — flag this as a cross-system dependency at that point.
