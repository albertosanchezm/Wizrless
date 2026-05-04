---
name: Wizrless Godot import pipeline findings
description: Technical issues discovered in existing asset imports that need corrective action
type: project
---

Reviewed `.import` files for `player_idle_run_attack.png`, `boss_devium.png`, `spike_ice.png` on 2026-04-17.

**Finding 1 — Missing Nearest filter (HIGH PRIORITY)**
The `texture_filter` parameter is absent from all inspected `.import` files. Godot applies the project-level default, which is bilinear unless explicitly overridden. If `rendering/textures/canvas_textures/default_texture_filter` is not set to `0` (Nearest) in `project.godot`, all pixel art is rendering with interpolation — causing blurring at scale. This must be verified and corrected before any visual review of sprites.

**Finding 2 — compress/mode correctly set**
All inspected files have `compress/mode=0` (lossless). This is correct for pixel art and must be maintained.

**Finding 3 — mipmaps correctly disabled**
`mipmaps/generate=false` is correct on all inspected files.

**Finding 4 — Misspelled folder name**
`assets/sprites/hazzards/` should be `assets/sprites/environment/hazards/`. Renaming requires scene reference updates — coordinate with technical artist.

**Finding 5 — Naming convention deviations**
Existing assets (`boss_devium.png`, `player_idle_run_attack.png`) predate the naming convention. These are migration candidates — do not block production on migration, but new assets must follow the convention.

**Why:** These findings were surfaced during Section 8 authoring. Correcting the filter issue has visible quality impact.

**How to apply:** When reviewing any sprite quality issue, check the Nearest filter setting first. When onboarding new assets, verify import file parameters against Section 8.1 of the art bible.
