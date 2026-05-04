# Spell VFX System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-04
> **Implements Pillar**: Spell Alchemy (visual legibility of interactions), Earned Truth (spell identity)

## Overview

The Spell VFX System defines the visual identity of every spell and interaction in the game. It owns four categories of visual output:

1. **Projectile visuals** — the in-flight appearance of each spell (sprite, trail particles, light)
2. **Impact VFX** — the hit/expire effect when a projectile contacts an enemy or surface
3. **Interaction VFX** — the effect fired by the Spell Interaction Engine when a combo triggers (Steam Burst, Cryoblast, Extinguish, Amplify, Inferno)
4. **Status effect visuals** — persistent visual indicators on enemies for FROZEN, BURNING, MARKED, SLOWED, STUNNED

The system does not own audio — that is the Audio Feedback System. It does not own damage numbers — those belong to Enemy Base System. It does not own the mana bar or cooldown overlay — those are HUD.

**Architecture:** Most VFX are self-contained inside their respective projectile scenes or enemy nodes. The Spell VFX System's primary structural contribution is the `SpellVFXSpawner` autoload, which listens to `SpellInteractionEngine.interaction_triggered` and spawns the correct interaction VFX scene at the correct world position. Projectile VFX require no central coordinator — each scene handles its own birth, life, and death visuals.

**Visual law:** Any two spells must be distinguishable at a glance. Color alone cannot be the only differentiator — shape and motion must carry the distinction for colorblind players. This is a hard constraint, not a guideline.

## Player Fantasy

Spells are the only color in the world.

Everything else in Wizrless is stone, shadow, and ice. The wizard moves through spaces built to suppress. When he raises his hand and Fireball leaves it — orange and alive against the dark — that is the first moment of color the player has seen in that room. It earns attention. It should feel earned.

Each spell has a visual personality the player should be able to name before they know its name. Fireball feels eager — it moves fast, it trails heat, it wants to hit something. Ice Shard feels precise — crystalline, cold, minimal. Shadow Tendril feels wrong in a way that is hard to articulate until it curves. These are not purely aesthetic choices. They communicate danger, range, and timing. A player watching Cryoblast for the first time should stop moving for a half-second. Not because a prompt told them something happened. Because something obviously, spectacularly happened, and they did it.

Status effects on enemies are quieter — information, not spectacle. The ice crystal overlay on a frozen enemy and the MARKED sigil need to be readable at combat distance without dominating the character art.

## Detailed Design

_TBD_

## Formulas

_TBD_

## Edge Cases

_TBD_

## Dependencies

_TBD_

## Tuning Knobs

_TBD_

## Acceptance Criteria

_TBD_
