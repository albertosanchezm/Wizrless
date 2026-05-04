---
name: Wizrless art bible authoring state
description: Current art bible section completion status and key design decisions locked in
type: project
---

Art bible at `design/art/art-bible.md` is in active authoring. As of 2026-04-17:

- Section 1 (Visual Identity Statement): COMPLETE
- Section 2 (Mood & Atmosphere): COMPLETE
- Section 3 (Shape Language): COMPLETE
- Section 4 (Color System): COMPLETE
- Section 5 (Character Design Direction): COMPLETE
- Section 6 (Environment Design Language): COMPLETE
- Section 7 (UI/HUD Visual Direction): PENDING
- Section 8 (Asset Standards): DRAFTED (returned as inline text, not yet written to file — confirm with user before writing)
- Section 9 (Reference Direction): PENDING

**Why:** Solo indie project, art bible is the primary visual source of truth before any full asset production begins.

**How to apply:** When resuming art bible work, check which sections are still marked pending and pick up from Section 7 or 9. Section 8 draft exists in session history — ask user if they want to write it to the file.

Key locked decisions:
- Base render resolution: 320×180, scaled up by Godot viewport
- Character tile sizes: 16×16 standard, 32×32 feature, 48×48 player wizard canvas
- Pixel art tool: Aseprite (source files to src/art/, exports to assets/sprites/)
- 6 spell families with distinct non-naturalistic hues (see Section 4)
- Fracture White (H:55 S:15 L:88) is the demonic grammar color — never used decoratively
- World palette: max saturation 25 (HSL); Seam Rust only exception at S:38
- 500 draw call budget at 60fps
