# Review Log: Camera System

---

## Review — 2026-04-23 — Verdict: MAJOR REVISION NEEDED → REVISED IN SESSION

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, gameplay-programmer, creative-director
Blocking items: 13 | Recommended: 16
Prior verdict resolved: No — first review

Summary: The review identified two pillar violations (look-ahead contradicting the "hunted man" Player Fantasy; boss frame delegation undermining "you cannot look away"), one design gap (Spell Alchemy had no camera moment), one unresolved dependency contract (Dialogue signal routing deferred), and multiple technical bugs (EC-06 phantom knobs, F-2 division-by-zero guards, AC-03/AC-15 untestable, EC-12/T-11 missing ACs). The creative director confirmed both pillar violations as BLOCKING. All 13 blockers were resolved in the same session through design decisions by the author and technical corrections applied directly to the GDD.

### Blockers Resolved in This Session

| Blocker | Resolution |
|---|---|
| Look-ahead contradicts "hunted man" fantasy | Look-ahead removed from all modes. CR-EX-4 now documents the design rationale explicitly. |
| Boss may leave frame | CR-BR-4 now specifies a boss movement constraint formula (max displacement ≤ arena_half_width − 32 px). CR-BR-2 updated to include boss framing as a dual contract. |
| Spell Alchemy has no camera moment | `heavy_impact_resolved` signal contract defined in Dependencies. `shake_on_impact` flag documented. |
| Dialogue signal routing deferred | Resolved: Narrative System activates phanCam_dialogue. Dependency table updated. OQ-03 closed. |
| EC-06 phantom br_deadzone knobs | EC-05 (renumbered) now correctly references CR-BR-3/CR-BR-4 framing constraints. No phantom knobs. |
| F-2 division-by-zero guards | Explicit branch guards added: `if t_g > 0` and `if t_d > 0` protect all divisions. Phase rules documented. |
| F-2/F-3 numbering with F-1 removed | F-1 (Look-ahead state machine) removed. Old F-2→F-1, old F-3→F-2. All cross-references updated. |
| AC-03 subjective (no perceptible jump) | Rewritten: max 8 px per-frame delta during interrupt blend window. |
| AC-15 human perception study | Rewritten: oscillation frequency from zero-crossings, 18–22/s for Damage Shake, 8–12/s for Impact Shake. |
| EC-12 crash path missing AC | AC-19 added: scene reload during hold timer, assert no freed-object errors. |
| T-11 player death missing AC | AC-20 added: assert pcam state reset on scene reload. |
| EC-12 node ownership unspecified | EC-10 (renumbered) now specifies CameraController node owns the hold sequence. |
| emitter.stop() API uncited | Note added in F-1 stacking pseudocode: verify method signature against PhantomCamera addon source. |
