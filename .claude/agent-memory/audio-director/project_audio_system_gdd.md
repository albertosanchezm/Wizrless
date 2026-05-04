---
name: Audio System GDD — Section C design decisions
description: All key decisions made for Section C (Detailed Design) of design/gdd/audio-system.md — bus arch, music states, SFX pool, public interface, volume contract
type: project
---

Section C was fully designed in conversation on 2026-04-17. Not yet written to the file.

**Why:** User requested concrete spec output (not philosophy) as a precursor to writing the GDD section.

**How to apply:** When user asks to write Section C to the file, use the spec in the conversation as the source of truth. Do not redesign — write it.

## Key decisions

### Bus architecture
5 buses: Master (limiter), Music, SFX, UI, Voice.
- Music bus ducks -6 dB when Voice is active (instantaneous, not faded).
- UI bus exempt from all ducking.
- SFX bus: no effects, no tail.
- All buses declared in Project Settings before any scene loads.

### Music states (8)
SILENT, MENU, EXPLORATION, COMBAT, BOSS_PREFIGHT, BOSS_FIGHT, VICTORY, DEATH, CUTSCENE.
- Exploration→Combat: hard cut.
- Combat→Exploration: 2-second linear crossfade.
- Any→Boss Pre-Fight: hard stop, 0.5s silence, then one-shot intro.
- Pre-Fight→Boss Fight: frame-accurate, no gap — this transition IS the staging.
- Any→Victory/Death: hard cut.
- MVP: discrete tracks only (no stems). Interface designed for stems later without signature change.

### SFX pool
16 slots total. Pre-instantiated at _ready(), never created at runtime.
- 4 GUARANTEED: spell cast/impact.
- 2 GUARANTEED: player damage.
- 8 best-effort: footsteps, env, projectile travel.
- (2 UI players are separate AudioStreamPlayers on UI bus, not in the SFX pool.)
- Preemption: oldest LOW first, then oldest NORMAL. GUARANTEED/HIGH never preempted.
- Play stamp (monotonic int) tracks "oldest".
- Footstep dedup: 80 ms minimum gap enforced by pool.

### Public interface (AudioSystem autoload)
- play_sfx(stream, priority, pitch_scale)
- request_music_transition(state, stream, loop)
- notify_voice_start() / notify_voice_end()
- set_bus_volume(bus_name, linear) / get_bus_volume(bus_name)
- Signal: music_track_finished(state) — emitted when non-looping track ends naturally.

### Volume contract
AudioSystem owns buses and dB conversion. Settings System owns save file and sliders.
Settings System calls set_bus_volume() on startup after loading save. AudioSystem applies defaults (1.0 linear) until Settings System calls in.
Autoload order: AudioSystem before SettingsSystem.
