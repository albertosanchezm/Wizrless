---
name: Codebase audio migration debt
description: Specific locations in the existing codebase that must be changed when AudioSystem autoload is implemented — do not forget these when the implementation task starts
type: project
---

Identified on 2026-04-17 by reading the live codebase.

**Why:** These are pre-AudioSystem workarounds. If not migrated, the Music bus volume knob, ducking, and pool will not work correctly.

**How to apply:** When drafting the AudioSystem implementation story or ADR, flag these as required migration tasks — they are not optional cleanup.

## Locations

1. `scripts/systems/game_manager.gd` line 34 — `var _music_player: AudioStreamPlayer`
   Delete. Music player moves to AudioSystem autoload.

2. `scripts/systems/game_manager.gd` lines 81–97 — `play_boss_music()` and `stop_boss_music()` and `_on_boss_appeared()`
   Delete all three. Boss System will call `AudioSystem.request_music_transition()` instead.
   GameManager signals (boss_appeared, boss_defeated) are kept — they become the trigger for Boss System to call AudioSystem.

3. `scripts/systems/game_manager.gd` line 41 — `_music_player.bus = &"Master"`
   This routes music to Master, bypassing the Music bus entirely. Music volume knob and ducking are broken until this is fixed.

4. `scripts/player/player.gd` lines 36–38 — `$StepSFX`, `$DamageSFX`, `$JumpSFX` AudioStreamPlayer nodes
   Remove from player scene. Replace with `AudioSystem.play_sfx()` calls from the relevant player states (run_state for steps, damage handled via GameManager.player_took_damage signal, jump_state for jumps).
