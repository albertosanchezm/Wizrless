# Art Bible: Wizrless

*Created: 2026-04-17*
*Status: Complete*
*> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED — Lean mode (2026-04-17)*

---

## Section 1: Visual Identity Statement

### The Visual Rule

> **The world is what was built to contain him. The spells are what he actually is.**

Every visual decision routes through this sentence. When an asset could go either more ornate or more decayed, lean decayed — the institution is losing. When a spell effect could be subtle or vivid, lean vivid — his power is the only thing in this world growing. When a new demonic element enters, it should not look sinister; it should look structurally *different* from everything the order built, like a different grammar leaking through.

*(Origin anchor: "The world is fading; the wizard is becoming.")*

---

### Supporting Visual Principles

#### Principle 1: Institutional Decay
*Anchored to: **Spell Alchemy***

The environment reads as a place of formal knowledge that has been slowly failing. Stone corridors carry the proportions of academic architecture — wide arched ceilings, deep-cut windows, carved stone borders — but surfaces are cracked, moss intrudes at grout lines, and once-precise stonework has partially collapsed. Color in the environment comes from oxidation and biological growth: verdigris on bronze fixtures, rust-orange seeping through grey stone, yellowing paper in rotting bookshelves. The institution is not dramatically ruined; it is quietly wrong, the way a building feels when the people maintaining it have been slowly replaced by fear.

**Design test:** When an environment prop could be intact or damaged, choose damaged unless the prop is being used as a puzzle or navigation element. Intact props signal agency; damaged props signal entropy. The player's agency (spells) is the only thing that should feel intact.

---

#### Principle 2: The Spell as Signal
*Anchored to: **Earned Truth***

Spells are the primary color event in any scene. The environment uses a desaturated palette — stone greys, ash whites, deep shadow browns, biological yellows — so that every active spell reads as an intrusion of pure chroma. Each spell element has a dedicated hue from a saturated, non-naturalistic range: fire is not orange-red but magenta-red; ice is not pale blue but electric cyan; shadow is not dark grey but deep violet with luminous edges. These are not colors the world produces. They are colors the wizard produces. The player's eye is trained over the first zone: if something is vivid, it is meaningful.

**Design test:** When an environmental detail (a torch, a stained-glass window, a ritual marking) could be rendered in a warm or saturated color, desaturate it until it reads as background unless it is directly story-flagged. A torch should be grey-amber, not orange. Spell fire should be the only magenta-red on screen.

---

#### Principle 3: The Second Grammar
*Anchored to: **Controlled Ascension***

As the wizard's demonic inheritance bleeds into his power, a second visual language enters the game — but it does not replace the first. The order built everything in curves, arcs, and organic stone forms: Gothic and Romanesque proportions, naturalistic wear patterns, soft edges in decay. The demonic visual language is geometric and angular: equilateral fractures, tessellating patterns, surfaces that look deliberately faceted rather than worn. Where the order's architecture curves, the demonic energy cuts. This second grammar appears first as a small highlight on a newly unlocked spell effect, then progressively in the wizard's own silhouette, ambient environmental cracks near him during high-power states, and eventually in final-form visual overlays. It must never read as "evil" — only as structurally alien to everything the order designed.

**Design test:** When designing a new demonic-tier visual element, ask: does it look like something the institution would build if corrupted, or does it look like something that came from outside the institution's entire visual vocabulary? It must be the second. If a demonic crack pattern in a wall could be mistaken for ordinary structural damage, add more geometric regularity until it reads as intentional, foreign grammar.

---

### Visual Opposition Summary

| Dimension | The World (Institution) | The Wizard (Becoming) |
|---|---|---|
| Palette | Desaturated: stone grey, ash white, rust, verdigris, biological yellow | Saturated non-naturalistic: magenta-red, electric cyan, deep violet, acid green |
| Form language | Arcs, curves, organic wear, Gothic proportions | Angular, geometric, tessellated, faceted — no organic wear |
| Texture quality | Cracked, mossy, oxidized, slow-rotting | Sharp-edged, luminous, structurally precise |
| Dominant mood | Something prestigious that is quietly losing | Something forbidden that is quietly winning |
| Changes over time | Increases in entropy and decay | Increases in saturation and geometric complexity |

---

## Section 2: Mood & Atmosphere

*This section defines the emotional target for each major game state. Every state must be visually distinguishable from every other. Overlap is a design failure — if two states could be photographed and mistaken for each other, one of them needs to be pushed further.*

*Design test for any new game state: if a player screenshots this moment without any UI, can they identify which state it is from the lighting and composition alone? If not, the state has not been pushed far enough.*

---

### 2.1 Exploration

**Primary mood target:** Suspended dread

The player is not afraid. They are aware. The corridors feel like they have been waiting for someone to come back and find what was left. Suspended dread is different from fear — it is the feeling of moving through a place that is still technically yours but that has turned against you so slowly you almost missed it.

**Lighting character:**
- Color temperature: Cold. Dominant light sources are grey-white ambient from high narrow windows, with secondary fill from pale verdigris-tinged reflections off oxidized bronze. No warm sources unless the player's spell is active.
- Contrast: Medium-low. Shadows are soft and pervasive rather than dramatic. There is no deep black, only many shades of dark grey. The world is not hiding things in shadow — it is simply dim everywhere, evenly, the way a building feels when the last people who cared about it have left.
- Light source type: Environmental ambience (diffused daylight, no direct source visible). Supplemented by faint bioluminescent growth (moss, fungi at grout lines) which reads as grey-green, never warm.

**Atmospheric descriptors:** Muffled, sedimentary, watchful, still, quietly wrong

**Energy level:** Contemplative

---

### 2.2 Combat — Rank-and-File Enemies

**Primary mood target:** Focused urgency

Not panic. Not fury. The sharp attention of someone doing something they are good at and discovering, in the doing, that they are better than they knew. Every combat encounter with a common enemy is a small experiment — does this combination work? What happens if I cast in this order? The emotional register is curious and alert, not threatened.

**Lighting character:**
- Color temperature: Shifts dynamically. The ambient cold remains (the world does not change because of the fight), but each active spell introduces a burst of saturated non-naturalistic chroma that dominates the local palette while it is active. The contrast between cold ambient and vivid spell light is the visual signature of combat.
- Contrast: High in the immediate area of spell effects. The spell becomes the key light, casting hard-edged colored shadows behind enemies and architecture. When no spell is active, contrast drops back to the exploration baseline instantly.
- Light source type: Player-generated. The wizard is the light source in combat. This should never be ambient or environmental.

**Atmospheric descriptors:** Reactive, chromatic, sharp-edged, kinetic, revelatory

**Energy level:** Measured-to-frenetic (scales with spell chain length — a single spell cast is measured; a three-step interaction resolving is frenetic)

---

### 2.3 Boss Encounter — Pre-Fight Dialogue

**Primary mood target:** Reluctant recognition

This is the most emotionally specific state in the game. The player knows what is about to happen. The character speaking knows what is about to happen. Neither of them wants to be here, for different reasons. The visual register must support the weight of that moment without tipping into melodrama. The feeling is the pause before the bell — not silence, but the air has changed, and everyone knows it.

**Lighting character:**
- Color temperature: Warmer than exploration, and deliberately so. The pre-fight space uses the faintest amber warmth — not a welcoming warmth, but the warmth of something that used to be a shared space. This is the only moment in the game where the environment is allowed a hint of warmth, and it makes the scene more painful, not more comfortable.
- Contrast: High but focused. A tight pool of light on the two figures. The rest of the room falls off into dark mid-tone. The player and the boss are isolated together in the frame.
- Light source type: A single practical source — a torch, a ritual brazier, a window with dying light behind it. The source is always visible and always feels like it has been there a long time.

**Atmospheric descriptors:** Intimate, weighted, amber-tinged, exposed, held-breath

**Energy level:** Held still

---

### 2.4 Boss Encounter — The Fight

**Primary mood target:** Controlled escalation

The grief of the dialogue is not erased — it is compressed and redirected. The fight begins from the emotional weight of what was just said and accelerates outward into kinetic intensity. The player and boss are both committed now. The visual register shifts from intimate to confrontational the moment the first attack is thrown.

**Lighting character:**
- Color temperature: Cold returns. The warmth of the pre-fight dies when the fight begins — a deliberate, readable shift. The boss's own visual signature (each boss should have a distinct spell-light color) becomes the dominant chroma event, competing with the player's spell palette for visual ownership of the frame.
- Contrast: The highest in the game. Deep environmental shadows, multiple competing saturated light sources (player spells vs. boss's own effects), hard edges throughout. The architecture barely reads — only the two combatants and their light matter.
- Light source type: Competing player- and boss-generated light. The background is sacrificed to the fight.

**Atmospheric descriptors:** Contested, saturated, percussive, gravity-weighted, relentless

**Energy level:** Frenetic with structured pauses (boss phase transitions are visual resets that briefly drop the energy before escalating again)

---

### 2.5 Victory — Boss Defeated

**Primary mood target:** Hollow gravity

This is not triumph. The wizard has killed someone who knew him. Hollow gravity: the effort is over, the room is quiet, something has been taken from the world.

**Lighting character:**
- Color temperature: Shifts to the coldest in the game. Post-fight, all spell light dies. The boss's light goes out first, then the player's. What remains is cooler and dimmer than even the exploration baseline.
- Contrast: Low. The drama is over. The light is flat and grey, almost colourless. There is no composition pull — the player is standing in a space that no longer has a focal point.
- Light source type: Return to ambient environmental only.

**Atmospheric descriptors:** Drained, colourless, cavernous, quiet, irrevocable

**Energy level:** Still

---

### 2.6 Discovery — Lore Reveal

**Primary mood target:** Vertiginous clarity

The moment of understanding. The player receives a truth they have been approaching for the entire zone. Vertiginous clarity is the feeling of a piece falling into place that recontextualizes everything before it — not comforting, not frightening, but lucid in a way that is its own kind of disorienting.

**Lighting character:**
- Color temperature: Neutral with a very faint violet undertone. Not warm, not cold — the visual equivalent of a cleared register. The violet is a trace of the wizard's demonic grammar beginning to intrude on his perception.
- Contrast: Medium with a strong single directional fill. The lore object or revelation source is lit from one angle, creating deliberate readable shadows.
- Light source type: Object-proximate. The light comes from or through the source of the revelation.

**Atmospheric descriptors:** Crystalline, directional, violet-edged, suspended, lucid

**Energy level:** Contemplative-to-still

---

### 2.7 Menu — Title Screen

**Primary mood target:** Ominous invitation

The promise before the experience. Must establish the tonal register of the entire game in a single held image: something prestigious that is failing, something forbidden that is growing.

**Lighting character:**
- Color temperature: Deep cold with a single saturated intrusion. The dominant ambient is near-black with a slight blue-black cast. Against this, one element carries vivid saturated colour: a spell effect, a fragment of demonic geometry, a single lit window in the far distance.
- Contrast: Extreme. Near-black background, isolated vivid foreground element. Silhouette carries the composition.
- Light source type: The single vivid element is self-illuminating. Everything else is in ambient cold.

**Atmospheric descriptors:** Monumental, silent, cold, fractured, charged

**Energy level:** Inert with a single point of tension

---

### 2.8 Death — Defeat

**Primary mood target:** Clinical interruption

Death is educational, not punishment. The visual register must support this: defeat should feel like a hard stop, not a catastrophe.

**Lighting character:**
- Color temperature: Desaturated to near-monochrome. All saturated spell chroma abruptly absent.
- Contrast: Flat. No dramatic lighting, no focal point. The environment without the wizard's light looks exactly like its base state.
- Light source type: Ambient environmental only. The spell light is gone because the wizard is gone.

**Atmospheric descriptors:** Flat, grey, evacuated, matter-of-fact, momentary

**Energy level:** Abrupt stop — the state transition out of death should be fast enough that it reads as a reset, not a mourning beat.

---

### State Differentiation Matrix

| State | Dominant Temp | Spell Chroma | Contrast | Energy | Distinguishing Feature |
|---|---|---|---|---|---|
| Exploration | Cold, grey-white | No | Low-medium | Contemplative | Uniform dim ambience, no focal point |
| Combat | Cold + vivid spell burst | Yes (player) | High (local) | Measured→frenetic | Player is the light source |
| Boss Pre-Fight | Faint amber warmth | No | High, focused | Held still | Only moment of warmth in the game |
| Boss Fight | Cold + competing chroma | Yes (player + boss) | Maximum | Frenetic | Two competing saturated palettes |
| Victory | Coldest, draining | No (extinguished) | Flat-low | Still | Visible removal of chroma |
| Lore Reveal | Neutral, violet trace | Trace only | Medium, directional | Contemplative-still | Directional fill from source object |
| Title Screen | Near-black cold | One element | Extreme | Inert | Single saturated intrusion on silhouette |
| Death | Grey-blue monochrome | No (absent) | Flat | Abrupt stop | Complete evacuation of spell chroma |

---

## Section 3: Shape Language

*Shape is the fastest language in visual design. Before color registers, before detail resolves, before the player reads a label — shape communicates. This section defines the shape vocabulary for every major visual system in Wizrless. All shape decisions answer to the visual rule: the world is what was built to contain him; the spells are what he actually is.*

---

### 3.1 Character Silhouette Philosophy

**Core principle: Every archetype is readable at 32×32 pixels.**

A 2D metroidvania requires silhouette clarity as a functional constraint, not just an aesthetic one. In fast combat, the player reads the screen in compressed time. Every character design is considered first as a solid black shape against a white field. If the archetype is not identifiable at thumbnail size, the design has not started yet.

**The player wizard — triangular instability**
*Anchored to: Controlled Ascension*

The wizard's base silhouette is built on a top-heavy triangle: wide, voluminous robes at the shoulders narrowing toward the feet, with a pointed hood creating a vertical apex. The triangle points upward — potential, something wanting to become more. Early game, the triangle is clean and soft-edged. As demonic power grows, the triangle fractures: angular protrusions enter the silhouette edge, the cloak hem begins to cut in irregular geometric notches, and by late game the outer silhouette carries the faceted, tessellating quality of the demonic grammar.

*Visual rule anchor:* The soft triangle is what the order made him. The fractured triangle is what he actually is.

**Order soldiers — rectangular authority**
*Anchored to: Earned Truth*

Rank-and-file enemies read as solid rectangles: broad shoulders, symmetrical armor, perpendicular stance. The rectangle communicates institutional rigidity — shapes decided by a uniform, not by the person. Soldiers must never have a more visually interesting silhouette than the wizard. Their shape is the containment the visual rule names.

**Bosses — silhouette as biography**
*Anchored to: Earned Truth*

Each boss's silhouette breaks from the soldier archetype — they are people, not instruments. Bosses are allowed asymmetry: a cape draped off-center, a weapon held with personal style rather than drill training. The asymmetry is emotional information: these characters have made choices. Their unique silhouette is withheld until the pre-fight reveal — the visual shift from soldier-rectangle to individual is story delivery.

**NPCs — soft interruptions**
Rounded, smaller, lower-silhouette forms. Never compete with the wizard in vertical scale. The design rule: an NPC silhouette reads as a question mark — slightly hunched, slightly incomplete. This keeps the wizard as the dominant vertical presence in any shared scene.

---

### 3.2 Environment Geometry

**Two vocabularies, spatially segregated — until they are not.**

**The institution: curves, arcs, and organic decay**

The order's architecture speaks entirely in curves: pointed Gothic arches, Romanesque barrel vaults, colonnade proportions favoring the circle and ellipse. Even rigid elements (walls, floors) soften with carved stone borders, worn grout lines, and organic intrusion. Moss follows the grout grid, not a geometric pattern. Cracks propagate along stress lines, not straight paths.

*Design rule:* Every environmental object in an institution zone must have at least one curved edge. No prop is purely rectilinear. Even a bookshelf's corners have worn chamfers.

*Visual rule anchor:* Curves are the shape of containment. The order built everything in arcs because arcs lead back to themselves.

**Corrupted and demonic zones: geometric regularity, angular intrusion**

As the story progresses into deeper zones, the environment's shape vocabulary fractures — but not into ordinary structural damage. Demonic grammar enters via geometric regularity: cracks that run in straight lines at 30- or 60-degree angles, wall surfaces that appear faceted rather than worn, patterns that repeat with tessellating precision. Where the institution curves, the demonic energy cuts.

*Design rules for demonic environment geometry:*
- Angles must be chosen from a limited set: 30, 45, 60, or 90 degrees only. No organic diagonals.
- Repeated shapes must demonstrate clear tessellation — the pattern continues beyond the visible damage area.
- Faceted surfaces must feel intentional, as though the surface was redesigned, not broken.

*Progression:* Zone 1 — demonic geometry only in spell effects. Zones 2–3 — small intrusions near high-power-use areas. Final zones — the two vocabularies co-dominant, one imposed on the other.

---

### 3.3 UI Shape Grammar

**The HUD speaks the demonic grammar, not the institution's.**

The UI uses the geometric, angular, faceted language of the wizard's demonic nature — not the Gothic curves of the world. Narratively: the UI is the wizard's interface with his own power. Functionally: angular UI elements maintain visual separation from the organic world behind them.

**Spell slot indicators**
Angular, faceted geometric forms — not circles or pill shapes. Each slot is a consistent polygon. Empty slot: desaturated accent tone, geometry visible but unfilled. Filled slot: the spell's assigned hue saturating the form from center outward. Locked (not yet unlocked): the geometric form is absent, not a placeholder — the space is empty.

**Health display**
A segmented angular bar — trapezoidal segments, slightly irregular, reading as assembled fragments. Full health: all segments filled with the wizard's core accent. Low health: vivid remaining segments against angular gaps. No rounded bars, circular pools, or organic fills — these belong to the institution's vocabulary.

**Ability icons**
Geometric container (hexagonal or faceted polygon frame). Icon interior uses no more than 3 geometric primitives. Shape communicates element through abstract geometry, not pictographic representation: fire = upward acute triangles; ice = regular angular lattice; shadow = radiating obtuse angles from a central void.

*Pillar anchor: Spell Alchemy.* The icon's geometric abstraction reinforces that spells are understood through structural logic, not surface appearance. Learning the icon is learning something real about the spell.

**Menus and overlay UI**
All chrome uses angular, chamfered frames — no rounded corners. Menu backgrounds are semi-transparent dark fills with a low-opacity (10–15%) demonic grammar tile pattern. Section headers within angular bracket shapes, not Gothic frames. The entire menu system reads as a second-language document overlaid on the institution's world.

---

### 3.4 Hero Shapes vs. Supporting Shapes

**Compositional rules for player prominence**

The wizard is the vertical apex in every scene. No mid-ground element is taller or more vertically complex. Background elements that exceed the wizard's height use atmospheric perspective (slightly desaturated, slightly lighter value) to recede.

**Shape complexity gradient:** The player character is the most visually complex form on the mid-ground layer. Soldiers are simpler rectangles. Props and platforms simpler still. The eye is drawn to complexity; that complexity belongs to the wizard.

**Design rule:** Only the player, his spells, and his UI use the demonic shape vocabulary in normal gameplay. Any enemy or environment element using faceted, angular forms is immediately legible as narratively significant — a story beat, a boss with demonic corruption, a zone under the wizard's influence.

**Focal point hierarchy in composed frames**

| Priority | Element | Shape characteristic |
|---|---|---|
| 1 | Player wizard | Most complex silhouette, angular demonic grammar, vertical apex |
| 2 | Active spell effects | Geometric, angular, high-saturation forms in motion |
| 3 | Boss / significant enemies | Unique asymmetric silhouette, mid complexity |
| 4 | Interactive objects / gates | Slightly more regular than background, subtle angular accent |
| 5 | Environmental midground | Curved institutional vocabulary, medium detail |
| 6 | Environmental background | Curved institutional vocabulary, reduced detail, atmospheric |

---

### Shape Consistency Tests

Apply to every new asset before approval:

1. **Silhouette test:** Render as solid black at 32×32. Is the archetype identifiable? If not, the design is unresolved.
2. **Grammar test:** Does this asset use curves (institution) or angles (demonic)? Is that the correct grammar? Mismatches require a specific story/design justification.
3. **Hierarchy test:** Place the asset in a test scene with the wizard. Does the wizard remain the most complex mid-ground silhouette? If the asset competes, simplify it.
4. **UI separation test:** Place the UI over a representative environment screenshot. Do UI shapes read as a distinct layer? If UI edges dissolve into environmental curves, angular contrast is insufficient.
5. **Progression legibility test:** Compare the wizard's Zone 1 silhouette to Zone 4. Is the demonic grammar clearly more present late-game? The progression must be visible without annotation.

---

## Section 4: Color System

*This section is the authoritative source for all color decisions in Wizrless. Every artist, VFX designer, and UI implementer must route color choices through this document. When a color decision is not explicitly covered here, escalate rather than assuming.*

---

### 4.1 Primary World Palette

Built from the chemistry of a failing institution: oxidation, biological growth, and stone that has not been cleaned in decades. Every color has a material origin — invented, decorative colors do not belong here.

**Rule:** No world color may exceed saturation 25 (HSL, 0–100) except where flagged as a story-significant marker.

| Name | HSL | Material Origin | Role | Emotional Signal |
|---|---|---|---|---|
| **Ashwork** | H:220 S:6 L:72 | Limestone dust, aged plaster | Primary surface fill for all stone — the base state of the world | Institutional fading. Still a building; just accumulating neglect. |
| **Vault Shadow** | H:215 S:12 L:22 | Deep corridor shadow, bricked-over windows | Shadow fill, depth planes, architectural recesses | Deliberate darkness — the institution sealing itself off. |
| **Seam Rust** | H:18 S:38 L:42 | Iron oxide from corroded brackets, hinges | Accent on structural metal; stress fractures; floor staining | Warmth from damage, not life. Slow, mechanical dying. |
| **Verdigris** | H:168 S:28 L:38 | Copper oxidation on bronze fixtures, railings | Accent on formal architectural features | Prestige in decay. The institution's tarnished credential. |
| **Canker Yellow** | H:52 S:30 L:55 | Mold, aged paper, dying moss, biological leaching | Organic growth at stone edges, paper/textile props | Something living where it should not. A slow timer of neglect. |
| **Bone Mortar** | H:38 S:14 L:62 | Old mortar and grout | Grout lines, carved detail fills, secondary stone surfaces | Specificity of age. Makes architecture feel handbuilt and old. |
| **Dead Bronze** | H:30 S:20 L:30 | Oxidized bronze mid-tone | Dark metal fixtures, door mechanisms | Functional the way a person looks healthy in dim light. |

**Palette constraints:**
- Seam Rust is the only hue with saturation above 30 — use sparingly as accent, never as background fill.
- Canker Yellow and Verdigris never appear adjacent on a single asset — they occupy different surface types (biological vs. metalwork).
- Vault Shadow is the darkest world value. True black is reserved for the demonic grammar.

---

### 4.2 Spell Palette

Spells are the only chromatic events in Wizrless. Spell colors must be colors the world does not produce. Any hue plausibly resulting from oxidation, decay, or biological growth is disqualified.

**Architecture:** Six elemental families, each owning a 30–40 degree hue range. Adjacent families separated by at least 40 degrees. Active spell effects: Saturation 75–100, Luminosity 55–75. These are identification colors — precision and distinctiveness override aesthetics.

**Non-naturalistic mandate:** Fire is NOT orange-red (torches and rust already own that). Ice is NOT pale blue (reads as environmental cold). No spell family may use yellow-green, yellow-orange, or brown (owned by world decay palette).

---

**Family 1: Fire — Magenta Crimson** | H:340 S:95 L:60
Rationale: Red-orange is naturalistic fire. Magenta-red is not produced by any combustion process — it leverages the "red = heat" visual shorthand while violating it to signal forbidden power. Trails toward white at peak intensity, never toward orange.

**Family 2: Ice — Electric Cyan** | H:192 S:100 L:62
Rationale: Pale blue reads as environmental cold. Electric cyan at S:100 L:62 is categorically brighter and more saturated than any environmental cold tone — the contrast does the work. Crystallizes to white facets at edges, never to grey-blue.

**Family 3: Shadow — Deep Violet** | H:275 S:88 L:42
Rationale: Shadow canonically reads as dark grey or black. Using deep violet breaks the naturalistic association, signals that this darkness is summoned and shaped. Adjacent to the demonic grammar's color — reinforcing that shadow magic is the element closest to the wizard's heritage. Void-field with luminous violet perimeter.

**Family 4: Lightning — Acid Yellow** | H:65 S:100 L:58
Rationale: Natural yellow (H:45–55) is owned by Canker Yellow at low saturation. Acid yellow (H:65, S:100) is categorically synthetic — the sulfur-yellow of plasma discharge. Pulses between acid yellow and near-white at high frequency.

**Family 5: Conjuration — Amber Gold** | H:44 S:90 L:50
Rationale: Deep amber-gold carries the visual weight of arcane formality without belonging to any naturalistic process. NOTE: At S:90 L:50, this is categorically distinct from the Boss Pre-Fight ambient (H:38 S:20 L:45). Hard geometric edges; slow, persistent hold — conjuration constructs persist, they do not flash.

**Family 6: Dissolution — Acid Green** | H:145 S:96 L:50
Rationale: Mid-green at maximum saturation reads as synthetic corrosion, not biology. 47 degrees from Ice (H:192) — mitigated by animation (ice: static crystal hold; dissolution: inward-advancing edge consume).

---

**Hue Separation Check**

| Pair | Distance | Risk | Mitigation |
|---|---|---|---|
| Lightning (H:65) / Conjuration (H:44) | 21° | **Flag** | Lightning pulses rapidly; Conjuration holds still in geometry. Sound must differ categorically — hard requirement to audio. |
| Ice (H:192) / Acid Green (H:145) | 47° | Monitor | Ice L:62 vs. Acid Green L:50. Shape: crystalline vs. edge-consuming. |
| All other pairs | 47°+ | Safe | — |

---

### 4.3 The Demonic Grammar Color Identity

**Fracture White** — H:55 S:15 L:88

A bleached sulfurous off-white with cold-side temperature bias. Not pure white (divine). Not warm white (candlelight). Not any spell hue at high luminosity (S:15 is near-achromatic). The only element in the game that is simultaneously very bright and very desaturated — a visual category that belongs to no existing system.

**Why it reads as alien without reading as evil:** Visual culture assigns evil to deep blacks, blood-reds, and sickly greens. Fracture White has none of these qualities. It reads as categorically *other* — from a different structural register entirely.

**Application rules:**
- Appears ONLY on demonic geometry elements: cracked surfaces with demonic pattern, geometric overlays on the wizard at high-power states, inner edge-lines of tessellating demonic patterns.
- Must always appear in hard geometric shapes — triangular facets, straight line segments, equilateral angles. Never as a soft glow, gradient, or organic form.
- Secondary use as outline/edge color on demonic geometry at small scale.
- At the Title Screen, may serve as the "single saturated intrusion" anchor.

**Progression metric:** Fracture White coverage on the wizard's silhouette and environmental cracking increases measurably as demonic power grows. This is the only purely visual metric of the Controlled Ascension pillar — visible in a screenshot without any UI.

---

### 4.4 Semantic Color Vocabulary

**The cardinal rule:** Colors earn their meaning through the world palette system, not through conventional UI color language. Every semantic assignment has a material rationale.

| Color | Semantic Role | Justification |
|---|---|---|
| Magenta-Crimson | Active fire element; heat interactions | Learnable from first fire spell. Most visually aggressive spell color. |
| Electric Cyan | Active ice element; slowing/freezing | Highest environmental contrast — reliable for puzzle interactions. |
| Deep Violet | Active shadow element; demonic adjacency; narrative weight | Violet proximity to Fracture White primes lore reveal states. |
| Acid Yellow | Active lightning; chain effects | Fast, unstable. Cultural shorthand for electrical discharge elevated to max saturation. |
| Amber Gold | Active conjuration; arcane formality | Permanence, weight. Slow visual register vs. lightning's adjacent hue. |
| Acid Green | Active dissolution; transformation of matter | Synthetic corrosion read. Advancing from edges = consumption. |
| Seam Rust | Structural failure; environmental hazard marker | Rust = iron failing. Environmental rust = something here about to stop working. |
| Verdigris | Former formality; credential markers; aged prestige | Concentration indicates original institutional hierarchy. |
| Canker Yellow | Biological encroachment; time passage; lore objects | More presence = further from maintained core. Tints aged paper and lore items. |
| Fracture White | Demonic grammar; structural alienness; wizard's true nature | No material origin in the institution's world — that absence IS its meaning. |
| Ashwork | Background; default state; institutional normalcy | Not a semantic color — the baseline. Eye seeks departure from it; the departure is the signal. |

**What colors do NOT mean in this world:**
- Gold does not mean "reward/collectible" — it means arcane materialization
- Red does not mean "danger alarm" — magenta-red means fire only, Seam Rust means material failure
- Green does not mean "health/safe" — Acid Green means dissolution, Canker Yellow means biological growth
- Blue does not mean "magic generally" — Electric Cyan means ice/cold element specifically

---

### 4.5 Per-Zone Color Temperature Rules

The world palette is fixed. Zones differentiate through dominant color ratios and ambient temperature offsets — not new colors. A player must identify their zone from a screenshot without UI.

| Zone | Name | Dominant Colors | Suppressed | Ambient Temp | ID Signal |
|---|---|---|---|---|---|
| 1 | The Outer Cloister | Ashwork (85%), Bone Mortar, trace Seam Rust | Verdigris minimal, Canker Yellow trace | Neutral-cold, grey-white | Cleanest stone. Baseline. |
| 2 | The Archive Undercroft | Vault Shadow (expands), Canker Yellow, Bone Mortar | Ashwork recedes, Seam Rust low | Cool with yellow-green bioluminescent cast | Canker Yellow at book-height — only zone with warm-decay tone at mid-level |
| 3 | The Ceremonial Halls | Verdigris (highest concentration), Ashwork, Dead Bronze | Canker Yellow suppressed, shadows organized | Coolest zone, long grey light shafts | Verdigris everywhere — greenish metallic note to all formal features |
| 4 | The Containment Vaults | Vault Shadow (deepest), Seam Rust (pushed to S:38 max), Dead Bronze | Bone Mortar minimal | Cold, red-shifted from Seam Rust | Rust as dominant tone, not accent. Iron and grating geometry. Lowest luminosity. |
| 5 | The Demonic Threshold | Ashwork base, Vault Shadow, Fracture White in environmental cracks | Verdigris and Canker Yellow both minimal | Neutral, persistent violet trace | Fracture White in cracks. Geometric damage patterns. Categorically different from previous zones. |
| 6 | The Ascendant Chamber | Fracture White (structural), Vault Shadow, Ashwork as trace substrate | All warm tones near-zero | Violet ambient tint from environment (not spell light) | Inverse of Zone 1 — Fracture White as primary, Ashwork as trace. |

---

### 4.6 UI Palette

**UI neutrals (derived from world palette, elevated for legibility):**

| UI Role | Color | Notes |
|---|---|---|
| Panel background | H:215 S:10 L:18 | Vault Shadow, slightly darker and blued |
| Panel border | H:38 S:20 L:45 | Bone Mortar toward Dead Bronze — the "age" of the UI |
| Text primary | H:220 S:5 L:80 | Ashwork, elevated luminosity |
| Text secondary | H:38 S:15 L:55 | Bone Mortar — subordinate, warm-neutral |
| Text disabled | H:215 S:8 L:35 | Vault Shadow mid-lightness |

**UI utility colors (UI layer only — must never bleed into gameplay visuals):**

| Function | Color | Notes |
|---|---|---|
| Health critical (<25%) | H:0 S:80 L:45 | True red — 20° from fire's magenta-red. Must also pulse + audio cue. |
| Ability ready | H:220 S:4 L:92 | Near-white cold — unobtrusive when simply available |
| Locked / unavailable | H:225 S:15 L:30 | Vault Shadow territory — absence of signal |
| Active selection / focus | Fracture White pulse H:55 S:15 L:88 | Demonic grammar for selection affordance — what the wizard focuses on, the geometry acknowledges |
| New / undiscovered | H:192 S:60 L:38 | Ice hue at dramatically reduced saturation — dark teal, not vivid cyan |
| Spell slot fill | Spell family hue at S:40 L:35 | Muted family tint — player learns hue identity in HUD before seeing it at full VFX saturation |

**Typography constraint:** No UI text color may share a hue range with an active spell family at saturation above 40.

---

### 4.7 Colorblind Safety

**Mitigation principle:** No spell may be identified by color alone. Every spell family must satisfy all three identification channels: color + shape + sound.

**Highest risk pair — Fire (H:340) / Shadow (H:275) under protanopia:** Both shift toward dark blue-purple. Mitigation: Fire radiates outward (burst geometry, white trail). Shadow holds inward (void field, luminous perimeter). Categorically different audio. Never cast simultaneously without positional separation.

**Multisensory identification matrix:**

| Family | Color | Shape | Sound |
|---|---|---|---|
| Fire | Magenta-crimson, white trail | Outward radial, explosive | High-frequency crackling, ascending pitch |
| Ice | Electric cyan, white facets | Crystalline hold, inward angles | Mid-frequency chime, sharp onset, slow decay |
| Shadow | Deep violet, luminous perimeter | Void inward, edge-glow, formless center | Low resonant drone, subharmonic |
| Lightning | Acid yellow pulse, white flicker | Branching linear, rapid animation | Rapid percussive discharge, staccato |
| Conjuration | Amber gold, hard edges | Held geometric, slow materialization | Low resonant chord, sustained |
| Dissolution | Acid green, advancing | Inward-consuming from perimeter | Mid hiss, continuous |

---

## Section 5: Character Design Direction

*All decisions route through the visual rule: "The world is what was built to contain him. The spells are what he actually is."*

---

### 5.1 The Player Character — Visual Archetype and Growth Arc

#### The Baseline: A Novice Who Does Not Know His Own Nature

The wizard at game-start is a contradiction made visible: someone trained by an institution whose visual language does not fit him. His robes are institutional — long, formal, ash-grey, soft-edged and floor-length. The silhouette honors the top-heavy triangle but in its cleanest form: the order's proportions. He wears them correctly. He looks like someone who belongs here. This is the lie the game opens on.

**Material detail — early game:**
- Fabric: Heavy, matte cloth. Absorbs light the way stone does — institutional grey, not personal expression. Deliberate cloth fold direction: trained, the drape of years in the same garment.
- Trim: Minimal formal piping at collar and cuffs in slightly cooler grey. The order's rank mark. No personal ornamentation.
- Hood: Up in idle and exploration. Down position reserved for specific story beats — hood coming down = exposure, being seen.
- Belt: Plain wrapped cord. Functional, not decorative.
- Footwear: Hidden by robes at Stage 1. He is not yet rooted to the world he stands in.

**Face direction at 2D sprite scale:**
Expression through hood position, head angle, and body posture — not rendered detail. Head slightly down, chin tucked: wariness, containment. Head forward, chin level: attention. Face turned from camera: concealment. Two pixels for eyes under the hood are presence, not expression.

---

#### Five Legible Growth Stages

**Design rule: nothing added by growth is ever removed. The wizard's silhouette is a record.**

| Stage | Trigger | Visual Change | What It Signals |
|---|---|---|---|
| 1 — Baseline | Game start | Clean robes, intact, hood up, no demonic geometry | The institution's product, wearing its costume |
| 2 — First Fracture | First boss defeated | One small angular notch at robe hem. Fracture White trace on one sleeve hem. | Something has started that cannot be undone |
| 3 — Emergence | Second spell slot / second boss | Multiple angular hem cuts; geometric fracture on one shoulder seam; hood apex develops an angular split. | The institutional form is losing the argument |
| 4 — Assertion | Third boss / major demonic power | Robe fabric at edges carries tessellating Fracture White pattern. Angular cuts multiply. Collar trim replaced by geometric fracture. | The second grammar now dominant at his boundaries |
| 5 — Claimed | Post-penultimate boss / Zone 5–6 | Fully faceted outer silhouette. Fracture White structural on chest and shoulders. Fractured geometric hood apex. **Feet visible** — robe hem has receded. | He is rooted now. He is what he is. |

**The footwear revelation closes the loop with the opening.** He was not rooted to this world at game start. At Stage 5, he is rooted to himself.

Clothing always reflects the institution's starting grammar, progressively overwritten. The robes do not disappear — they fracture. The order's visual language is not erased; it is inhabited and changed from the inside.

*Pillar anchor: Controlled Ascension.*

---

### 5.2 Visual Distinction Rules per Character Type

**Legibility test:** Archetype identifiable within 500ms at game camera distance, reading only silhouette and color band.

---

**Order Soldiers — rectangular authority**
Shape: Solid rectangle, bilateral symmetry. Shoulder width equals or exceeds hip width. Vertical axis rigid. Shorter than wizard at apex.
Color: World palette only (Ashwork, Vault Shadow, Dead Bronze, trace Seam Rust at joints). No spell-palette color under any circumstances.
Hierarchy: More Verdigris on armor = higher rank. Shape stays rectangular — rank earns decoration, not asymmetry.
Test: Silhouette reads as standing rectangle with visored head and weapon at rest. Any confusion with NPC or boss = borrow complexity that belongs to another archetype.

**Bosses — silhouette as biography**
Shape: Asymmetric individuals. Each breaks bilateral symmetry in a character-driven way. No two bosses share an asymmetry pattern.
Color: World palette base + one story-designated accent (not a spell palette color — a patina of their personal history). In death, this accent is the last color to leave the screen.
Reveal: Boss silhouette deliberately withheld until pre-fight moment. Visual shift from soldier-rectangle to individual-silhouette is a story beat.
Test: Every boss distinguishable from every other at 32×32 as a solid shape.

**NPCs — soft interruptions**
Shape: Rounded, smaller, hunched — a compressed question mark. Never claiming the wizard's vertical apex.
Color: World palette, biased Canker Yellow and Bone Mortar. No Fracture White, no spell palette.
Test: Not confusable with a patrolling soldier. Roundness and compression do that work.

**Hostile Creatures**
Shape: Organic irregularity + one geometric intrusion (angular bone formation, crystalline eye, tessellating hide marking). Intrusion becomes more pronounced in Zones 5–6.
Color: World palette with biological yellows dominant; Fracture White trace on the demonic intrusion element only.
Test: Reads organic and mobile at 32×32. Geometric intrusion visible as "something different," not the first thing read.

---

### 5.3 Expression and Pose Philosophy

**Governing principle: suppressed expressiveness.** Characters do not perform emotions — they contain them, and the containment is the performance. Emotion leaks through what the body does when it forgets to perform composure. Spell-casting moments are the only time bodies are allowed to be fully committed.

*Pillar anchor: Earned Truth.*

**Wizard posture states:**

*Idle — Novice (Stages 1–2):* Weight centered, feet hidden, arms close, head slightly down. Slow breathing cycle (4–5 frames). The posture of someone waiting for permission to move.

*Idle — Claimed (Stages 4–5):* Weight forward on visible feet. Wider stance. Arms with more space — more claim over the air around him. Head level. The posture of someone who no longer needs to minimize his presence.

*The Stage 3 transition is a visible landmark:* Posture shifts when robe hem cuts first appear. Same upgrade, two simultaneous changes.

*Movement — Exploration:* Deliberate and robed. Upper body and head carry movement. Stages 1–2: slight forward head lean. Stages 4–5: neutral head, lean gone. He is no longer leading with uncertainty.

*Combat Ready (between casts):* Wider stance, lower center of gravity. Casting hand at chest height, fingers separated — available, not reaching. At Stages 4–5, Fracture White visible at fingertips.

*Casting:* **The most committed animation in the game.** Full arm extension, body weight committed, hood shifts. In all other states, the wizard holds something back. The cast releases it. This is what he is.

*Direction rule:* The cast must be the most kinetically extreme pose in the entire animation set. Every other state should feel like held-back cast energy.

*Death:* Not dramatic. He folds the way a body folds when suddenly uninhabited. No reach, no outstretched arm. Wrong posture before he reaches the ground — the posture of absence.

**Soldier posture:** Drill posture at all times. Patrol = mechanical, rehearsed. Death = heavy inward collapse. No flourish — load-bearing walls giving way.

**Boss posture:** Most expressive of any character in pre-fight dialogue. Allowed to show what they hold back. Asymmetric weight, a grip on the opposite forearm, looking at the wizard and then away. In combat: personal — their attack patterns reflect who they are.

---

### 5.4 Level of Detail Philosophy

**Camera distance contract:** All design investment must produce visual return at the game's camera distance. Detail visible only in the asset editor is detail never in the game.

**Base resolution: 48×48 pixels per character tile unit.** *(Verify against existing Godot sprites.)*

Every design pass begins with the silhouette at game resolution before moving to detail.

**Invest heavily in:**
- Silhouette edges — complexity pays off most per pixel at camera distance
- Key pose frames — 2–3 keyframes that define an action, transitional frames leaner
- Color-change events — precise color boundaries over smooth gradients
- Distinction markers — the one element that makes a character archetype-legible

**Economize on:**
- Interior texture fills — 2–3 value steps maximum at camera distance
- Secondary accessories — detail invisible at game scale goes to promo art only
- Face and hand detail — head angle and 2px eye highlight over rendered features
- Transitional frames — 8–12 frames for a walk cycle; more is diminishing return

**Spell VFX: inverted LOD.** Spell effects are the primary color events — highest frame budget in the project. Invest in the apex frame and decay pattern first, not the onset. A spell that holds its apex for 4 frames at full saturation reads as powerful.

*Visual rule anchor: Spells are what he actually is. They receive the most visual effort in the game.*

---

### Character Design Consistency Tests

1. **Archetype silhouette test:** Solid black at 48×48. Archetype identifiable? If not, unresolved.
2. **Growth stage test:** Stage 1 vs. Stage 5 side by side. A new observer should read them as visually different characters. If not, Stage 5 is insufficiently pushed.
3. **Color quarantine test:** No world-palette color above S:25 on any character (except Seam Rust accent). No spell-palette hue on non-wizard, non-spell elements.
4. **Camera distance test:** Final asset evaluated at game camera scale. Detail not readable at scale is removed or flagged as promo art only.
5. **Posture read test:** Exploration-idle, combat-idle, and cast/attack pose. Emotional difference between states readable without audio or UI.

---

## Section 6: Environment Design Language

*The world communicates the institution's failure not through dramatic ruin but through the slow, material evidence of a place that has been wrong for a long time. All environment decisions answer to: "The world is what was built to contain him."*

---

### 6.1 Architectural Style and World History

**The Order's Architecture: Authority as Argument**

The institution built to persuade, not to please. High ceilings — ceremonially high, not functionally. Pointed Gothic arches running taller than their span requires. Romanesque columns: thick, load-bearing, serious. Doorways wider than one person needs. Every space sized for authority: what happens here matters more than what you feel about it.

*Pillar anchor: Earned Truth.* The architecture must earn the institution's credibility before the player can feel the betrayal. The building must first look legitimate.

**The Decay as Evidence — Quiet Wrongness, Not Dramatic Ruin**

Each sign of quiet wrongness is individually deniable, collectively damning:
- Stone in good structural condition, not cleaned in decades. Grime accumulates evenly — no maintenance evidence.
- Formal carved borders where specific imagery has been professionally removed (not smashed — smoothed over with mortar). The ceremony kept, the participants unnamed.
- Bookshelves organized by rigorous system, partially emptied, remaining volumes rearranged to appear full.
- Door hardware in Dead Bronze, functional — but some doors have inside-bar locks added. The institution locked people out of certain rooms. Or in.
- Sconce patterns: maintained and unmaintained alternating. Where people still go, and where they stopped, told by candlestubs.

**Zone Architecture Personalities**

| Zone | Character | What It Communicates Before Lore |
|---|---|---|
| Outer Cloister | Open colonnades, intact arches, wide corridors for visibility | This is where new members are assessed. The institution watches here. |
| Archive Undercroft | Dense, low-ceiling maze. Shelving cuts sightlines. Bioluminescence only light. | Knowledge stored but not freely shared. The layout is for insiders. |
| Ceremonial Halls | Largest vertical spaces, polished floors, architectural detail concentrated. Deliberate emptiness — sized for an absent audience. | Ritual happened here regularly. Its absence is the story. |
| Containment Vaults | Thick walls, iron-barred windows, lower ceiling, industrial locks. Containment formulae in carvings. Sounds behave differently — walls too heavy. | Built to hold something that needed more than stone. |
| Demonic Threshold | Institution architecture intact but invaded. Geometric cracks at 30/45/60-degree angles through Gothic arches. Two grammars in same space. | The thing contained did not leave through the doors. |
| Ascendant Chamber | Fracture White structurally dominant. Institution curves only visible as substrate. | The containment failed — or was never meant to hold. |

---

### 6.2 Texture Philosophy

**Technique: Pixel art at 320×180 (scaled up). Tiles: 16×16 standard, 32×32 feature tiles.**

This resolution forces material communication through texture *pattern* rather than texture *density*. Every pixel in a tile does legible work. Material identity (stone vs. metal vs. organic) communicates through structural tile logic, not photographic accuracy.

**Material Signal System** *(consistent across all zones — corruption does not change material identity, only its state)*

| Material | Pixel Pattern | Color Anchor | Distinguishing Detail |
|---|---|---|---|
| Stone (cut ashlar) | Horizontal coursing, offset joints, 45° chamfer at corners | Ashwork primary, Bone Mortar at joints | Joints slightly lighter; shadow at lower joint edge |
| Stone (rough) | Irregular face, no coursing, rounded edge silhouettes, 1–2px dark pits | Ashwork primary, Vault Shadow in pits | No straight lines in surface grain |
| Metal (bronze) | Tight crosshatch worked surface; 1–2px specular dot on facing surface | Dead Bronze primary, Seam Rust at age-lines | Rust bleeds from edges, never center-surface |
| Metal (iron/bars) | Vertical/horizontal linear grain only. Specular stripe not dot. | Near-black base, Seam Rust at corrosion | Reads dark — functional, not meant to be seen |
| Wood | Parallel grain with slight natural curve. Occasional knot (oval, grain deflects around). | Bone Mortar dominant, Vault Shadow in grain depth | Grain lines never perfectly parallel — 1–2px drift per 16px run |
| Organic growth | Irregular blob clusters, never grid. Feathered 1px dither into surface. Lighter center, darker perimeter. | Canker Yellow, grey-green secondary | Follows grout lines and moisture paths |
| Fabric/textile | Diagonal weave intact; degraded: diagonal interrupted by vertical tears, dithered fraying | Bone Mortar base; Seam Rust or Vault Shadow at soiling | Intact = diagonal order; damaged = pattern breaks |
| Paper/parchment | Very slight base lightness variation simulating age. Text as abstract dark marks. | Canker Yellow dominant | Edge darkening; irregular water-stain blooms |

**The Degradation Spectrum**

Zone 1 (maintained): Full tile detail. Joints clear. Metal specs bright. Organic growth 2–4px at grout lines only.
Zones 2–3 (progressive neglect): Growth expands 4–8px, bridges stone faces. Crack tile variants introduced. Metal specs dimmed 15%.
Zone 4 (functional decay): Organic growth 20–30% of stone faces. Crack variants dominant. Rust-variant metal. Settled/tilted floor variants.
Zones 5–6 (demonic intrusion): Institution textures remain but fractured by demonic geometry tiles at straight-line angles (30/45/60°) with Fracture White edge-lines. Organic growth ceases — nothing biological grows where demonic grammar has taken hold.

**Design rule:** Organic growth (Canker Yellow) and demonic geometry (Fracture White) must never dominate the same surface simultaneously. They are mutually exclusive. The demonic does not corrupt — it replaces.

---

### 6.3 Prop Density Rules

**Core principle: density communicates institutional function, not aesthetic preference.**

| Zone | Density | Rule |
|---|---|---|
| Outer Cloister | Sparse | Supervision requires sightlines. Props are architectural, not accumulated. |
| Archive Undercroft | Dense | Functional space overwhelmed by its contents. Navigation lanes still visible, narrowing. |
| Ceremonial Halls | Open with focal density | Props at architectural features only. Emptiness in the processional center is the statement. |
| Containment Vaults | Functional density | Operational props: locks, grating, containment apparatus. Industrial, not decorative. |
| Demonic Threshold | Collapsed density | Institutional props knocked or fractured. Demonic intrusions replace cleared areas. |
| Ascendant Chamber | Near-zero | Institution gone. Isolated institutional remnants function as archaeological evidence. |

**Claustrophobia:** Earned when prop density and architecture constrain movement AND vertical sightlines simultaneously. Use only where the space's history justifies it (archives, preparation rooms, intensive-use spaces).

**Exposure:** Structural — no mid-ground element breaks the sightline to the far wall. Communicates the player's smallness against the institution. In Zone 6, the same exposure inverts: the space is vast but so is the wizard.

**Design rule:** Abrupt transitions between claustrophobia and exposure within a single room read as error. Use a transition beat (doorway, ceiling shift, platform gap).

---

### 6.4 Environmental Storytelling Guidelines

*Anchored to: Earned Truth.* No single element tells a complete story. Each contributes one fact to a picture assembled over time.

**Eight Storytelling Categories**

**1 — Interrupted Action:** A scene frozen mid-process. Specificity required — not a generic mess, but evidence of the exact action that was happening.
*Example:* Open journal with increasingly erratic last entry, quill dropped mid-stroke, page torn away diagonally. A restraint cuff hanging from the table edge on its chain. The reader was not left alone.

**2 — Selective Erasure:** Deliberate removal vs. decay. Removal leaves clean edges and empty mounting points. Decay follows environmental logic.
*Example:* Formal carved frieze depicting robed figures in procession. Every face professionally removed — smoothed with mortar, not smashed. Robes and hands in perfect detail. The ceremony kept; the participants unnamed.

**3 — Occupation Without Ownership:** Temporary habitation in space not designed for it. Props of improvised occupation must contrast with the space's built purpose.
*Example:* Behind a column in the Outer Cloister: a folded bedroll of institutional fabric, a candle stub, a child's illustration on the back of an official document. Someone lived here. Small. Young. The player was small and young in this institution once.

**4 — Asymmetric Maintenance:** Maintained things reveal ongoing priorities. Abandoned things reveal what was deprioritized. Readable within a single room.
*Example:* Containment vault door locks recently oiled — clean metal, visible tool scrape marks. Cell interiors (visible through grate): years-old mold, heavily encrusted. The order still locks the doors. Whether anyone is inside is deliberate ambiguity.

**5 — Material Out of Place:** Wrong material for its location = arrived from elsewhere or placed with intent. The mismatch must be legible from the world palette.
*Example:* In the Archive Undercroft (Zone 2 materials), a single sealed Dead Bronze case (Zone 3 material) on a lower shelf. Long enough here to accumulate archival dust. Formal lock plate — not the industrial iron of the Vaults. Something important hidden outside its proper zone.

**6 — Scale Testimony:** Scale of apparatus communicates scale of commitment or fear.
*Example:* Binding apparatus in one vault chamber: anchor chains the diameter of the wizard's torso, central mounting at ceiling height, floor worn in a circular pattern suggesting rotation. Bindings empty but intact and taut. Whatever was here left through the chains, not by breaking them.

**7 — Duplication as Obsession:** Same text, symbol, or object appearing 3+ times in a small space communicates institutional fixation or fear of forgetting.
*Example:* Same containment formula inscribed at least fourteen times on one cell wall — in different media (charcoal, scratched stone, something darker), different heights, at least two handwriting styles. One set careful and institutional. One set irregular, pressured, from multiple positions. Keeper and kept, both writing it.

**8 — Architectural Honesty:** When a building's structure reveals what its ornament denies, the gap is the story.
*Example:* The Ceremonial Hall's formal processional floor has a drain. Placed centrally, beneath the ritual focus. Stained. The architecture is telling the truth that the ceremony's aesthetic hides.

---

### 6.5 Metroidvania-Specific Environment Rules

*Anchored to: Controlled Ascension.* Gates exist so their opening means something. Every visual system below reinforces that access was earned.

---

**6.5.1 Locked Paths (Ability-Gated) — Three Gate Classes**

All three introduced and unreachable in Zone 1. Player learns to read classes before Zone 2.

**Class A — Physical Architecture Block:** Doorway filled with smooth-faced filler stone — no joint pattern, slightly lighter Ashwork tone than surroundings, Seam Rust staining at base (iron rebar inside). Reads as "added later." Signal: structural incompatibility.

**Class B — Demonic Geometry Seal:** Fracture White tessellating facets overlaid across the opening, extending 2–3px into the wall on both sides. Gate communicates: "this requires the demonic grammar." As the wizard's Fracture White grows, the gate becomes visually complementary — the same grammar. Signal: resonance.

**Class C — Institutional Lock:** Formal door (Dead Bronze hardware, carved frame) with an iron bar sealed from the *inside*, visible through the hinge gap. Communicates: "something on the other side sealed this." Opens via story beat, not ability unlock. Signal: something inside chose to lock it.

---

**6.5.2 Previously Visited Rooms**

**Spell residue:** Very faint environmental tint (5% desaturated overlay) of dominant spell family hue on nearest stone surface. Subliminal on first pass, consciously readable on return. "This is where I fought."

**Crack displacement:** Micro-cracks slightly more regular than natural structural fractures form around the wizard's presence. Not demonic geometry — one step toward it. Combat rooms and lore rooms accumulate more than traversal rooms.

**Environmental disturbance:** Lightweight props (scroll cases, candle stubs, papers) displaced by the player's traversal remain displaced on return. The environment remembers.

*Rule:* No single signal strong enough to read as new story information. Together they communicate "I have been here."

---

**6.5.3 Hidden Paths**

All three techniques introduced in Zone 1. A player who discovers the technique there carries it forward.

**False Wall:** Correct stone texture but subtle coursing irregularity — joints 2px closer spacing, or mortar line slightly thicker than established grid. Not dramatic. Rewards attention.

**Bioluminescent Seam (Zone 2+):** Canker Yellow growth following routes ordinary fungi would not — toward blank wall sections, implying a moisture source behind them. First instance in Zone 2 co-occurs with a nearby false wall to teach the signal.

**Demonic Geometry Resonance (Zones 4–6):** Fracture White edge-light at 10–15% opacity bleeding through a wall surface from behind. As the wizard's demonic power grows, the resonance becomes slightly more visible — his grammar makes the hidden grammar readable. Both mechanical and narrative.

*Rule:* Hidden paths never require an ability to discover, only to enter. Discovery is observational and available from Zone 1.

---

**6.5.4 Environmental Hazards**

Readable as "this hurts" before the player touches them. First encounter with each class in a safe-observation context. Hazards are visually present, not hidden.

**Four signal layers — all hazards must satisfy all four:**

*Layer 1 — Color:* Every hazard carries Seam Rust at the contact point. The color of things failing. Zone 5–6 exception: demonic hazards use Fracture White as primary signal, not Seam Rust. The transition from rust-hazards to fracture-hazards announces that the nature of the threat has changed.

*Layer 2 — Motion:* Hazards animate on visible, non-synchronized cycles. Player can always observe at least one complete cycle before committing to movement. Pre-collapse platforms show 1px vibration before falling.

*Layer 3 — Environmental context:* Hazards leave evidence. Spike floors have scratch marks beside them. Acid drips have eroded stone beneath. Collapsing platforms carry crack variants and asymmetric sag.

*Layer 4 — Zone integration:* Zone 1: minimal, tutorial-paced. Zones 2–3: procedural (gravity/age). Zone 4: most dense and designed — the vaults were built with hazard systems as containment. Zone 5–6: demonic hazards (Fracture White edges, cutting geometry).

**Non-negotiable rules:**
- No hazard surface may use Ashwork as primary color. Ashwork is background — hazards must read against it.
- No hazard may be in shadow deep enough to conceal its Seam Rust signal. Motion layer required if lighting suppresses color.
- Hazards have layout priority over storytelling props when both share a room.

---

### Section 6 Design Tests

1. **Material test:** Every significant surface material identifiable from a static screenshot? If ambiguous, add one additional pixel pattern signal.
2. **Gate legibility test:** New player categorizes gate as Class A, B, or C within 3 seconds? If not, gate visual is insufficiently differentiated.
3. **Hazard read test:** Cover the motion layer in a static frame. Is the hazard still identifiable from color and context alone?
4. **Zone identity test:** Any room screenshot identifiable to its zone within 5 seconds using art bible knowledge?
5. **Storytelling clarity test:** Every story prop assigned to a named category. No prop budget for decoration.
6. **Visited-room read test:** Pre-visit and post-visit screenshots side by side. Difference visible and readable as "visited," not "story changed" or "level error."
7. **Hidden path reward test:** Every hidden path discovered in internal testing. Too-hidden = fix signal. Under-rewarded = fix reward.

---

## Section 7: UI/HUD Visual Direction

### Philosophy

Screen-space HUD using the **demonic grammar** as its visual system. The UI is not a neutral overlay — it reads as the wizard's emerging self-knowledge. The hexagonal Fracture White language that bleeds into the environment late-game is the same language the HUD speaks from the start. The player is not reading a designer's UI; they are reading the part of themselves the order cannot see.

No diegetic framing (no notebook, no runic circles the wizard "draws"). Screen-space — clear and responsive. The demonic grammar provides narrative grounding without sacrificing readability.

---

### Screen Layout

```
[Spell Slots: bottom-left]          [Health bar: bottom-right]
[Slot 1][Slot 2][Slot 3][Slot 4][Slot 5]        [||||||||||||]
```

**Spell slots** appear at the bottom-left, reading left-to-right as they unlock (Slot 1 at launch, Slot 5 never appears until earned). Slots do not animate in from offscreen — a new slot materializes at its final position in 2 frames (frame 1: empty frame appears, frame 2: element fills). There is no fanfare. The new power appears and is immediately usable.

**Health bar** reads left-to-right (conventional direction — drains from right toward left). This prioritizes zero-friction legibility for all players over metaphorical direction. The bar uses a segmented fill (no smooth gradient) to indicate discrete damage thresholds.

---

### Spell Slot Visual Spec

Each spell slot is a **hexagonal Fracture White frame** on a transparent background.

| State | Frame opacity | Fill opacity | Animation |
|-------|--------------|--------------|-----------|
| Empty | 20% | — | Static |
| Filled | 60% | Spell element color at 80% | Static |
| Active / focused | 60% | Spell element color at 80% | 0.8Hz pulse, scale 100%→106%→100%, continuous |
| On cast | 60% | Flash to 100% fill for 1 frame, return | 1-frame flash, no easing |

The 3:1 opacity ratio (60% filled vs. 20% empty) provides legibility at 16×16 without breaking the demonic grammar's muted character.

Slot size: **16×16 pixels** at 320×180 internal resolution. Each icon is a maximum of **3 geometric primitives**, no gradients, no outlines below 2px. The element color fills the interior; the Fracture White hexagonal frame is the constant.

---

### Health Bar Spec

- Position: bottom-right, horizontally aligned with spell slots
- Fill direction: left-to-right drain (right side depletes first)
- Width: 48px at 320×180. Height: 6px
- Color: **Fracture White** at 70% opacity (not a spell color — health is institutional)
- Segmented: one segment per 10% of max health (10 segments total)
- Critical threshold (≤20%): Segments at and below threshold switch to **Seam Rust** (H:18 S:38 L:42). Shape/opacity backup ensures colorblind legibility — the rust segments also pulse at 0.5Hz

---

### Typography

**Typeface direction**: Angular humanist sans-serif — flat-cut terminals, no rounded ends, no traditional serifs. The cut geometry echoes the demonic grammar without being ornamental.

| Use | Size | Weight |
|-----|------|--------|
| HUD stat readouts | 5px cap-height minimum (320×180) | Regular |
| Menu labels | 7px cap-height | Regular |
| Dialogue body | 8px cap-height | Regular |
| Boss name on encounter | 10px cap-height | Bold/Heavy |

**Dialogue legibility rule**: Dialogue text blocks use the angular face at 8px cap-height with 140% line-height. If a candidate typeface fails legibility at this size with the Vault Shadow background, it is disqualified regardless of aesthetic fit. The angular character must survive legibility testing — it is not a compromise.

---

### Iconography

- **Size**: 16×16 per spell icon
- **Structure**: 3 geometric primitives maximum — no gradients, no detail below 2px
- **Frame**: Hexagonal Fracture White frame (same for all spell types; element color differentiates content)
- **Style**: Abstract geometric — icons read as symbols, not illustrations. A fire icon is not a flame; it is a triangle-and-arc that means fire within the game's visual vocabulary. Players learn the vocabulary; the icons do not explain themselves.

---

### Animation Standards

"Suppressed expressiveness" — the UI should not compete with spells for visual energy. All HUD animation is short, geometric, and un-telegraphed.

| Element | Animation | Duration |
|---------|-----------|----------|
| Menu open/close | Clip-reveal (hard cut edge, no easing) | 80ms |
| Slot unlock | Frame appears (1 frame), fill appears (1 frame) | 2 frames |
| Cast | Fill flashes 100% → returns to 60% | 1 frame |
| Health drain | Segments deplete at 6px/frame | Variable |
| Slot pulse (active) | Scale 100%→106%→100% | 0.8Hz continuous |

---

### Accessibility Standards

**Reduced Flashing toggle** (required at ship): A single accessibility setting that flattens all strobing spell VFX. When enabled:
- All spell flash rates capped at ≤3Hz
- Lightning VFX switches from strobe arc to sustained glow
- Slot cast flash removed (holds at 100% for 100ms instead)

This toggle applies globally to all spell VFX, present and future. It must be accessible from the main menu and from the pause menu — not buried. Default: off.

**Colorblind safety**: Critical health state (Seam Rust at ≤20%) uses both color change AND opacity pulse. Fire spell icon shape must be visually distinct from Shadow at 16×16 (protanopia risk noted in Section 4). Add a shape backup (Fire: triangle-dominant; Shadow: arc-dominant) if playtesting surfaces confusion.

---

### Consistency Tests

1. **Hierarchy test**: Spell VFX is the most visually prominent element in any frame. HUD is second. Environment is last.
2. **Mute test**: Screenshot with all spell VFX removed. HUD must still be readable in Vault Shadow environment.
3. **Focus legibility test**: Active slot pulse visible against late-game demonic grammar background (Zone 5 screenshot).
4. **Critical health read test**: At ≤20% health, the state must be readable in under 1 second by a first-time player.
5. **Reduced flashing verification**: All VFX with toggle enabled pass Harding photosensitivity standard (≤3Hz, ≥0.1s inter-flash interval).

---

## Section 8: Asset Standards

### Renderer Constraints (Hard Limits)

These are engine-level ceilings enforced by the GL Compatibility renderer. All asset decisions must respect them.

| Constraint | Value | Notes |
|-----------|-------|-------|
| Renderer | GL Compatibility | Set in project.godot — do not change |
| Internal viewport | 640×360 | 2x integer scale to 1280×720 window |
| Max texture size | 2048×2048 | Per atlas — GL Compatibility ceiling |
| Draw call budget | 500 @ 60fps | Cross-scene limit including UI and VFX |
| Max simultaneous Light2D | 2 | Hard limit — do not exceed |
| ShaderMaterial instances | 1 per element family | All Fire VFX share one instance; all Ice share one; etc. |

---

### File Formats

| Asset type | Format | Notes |
|-----------|--------|-------|
| Sprites, tiles, UI | PNG | No JPG — compression artifacts at pixel art scale are unacceptable |
| Sprite atlases | PNG | Pack per category (see below) |
| Audio | OGG | Compressed; WAV for SFX source files only |
| Fonts | TTF / OTF | One file per weight |
| Shaders | .gdshader | One file per visual effect family |

---

### Import Settings (All Sprites)

These settings are already correct in the project and must not be changed:

```
compress/mode = 0          # Lossless (RGBA8)
mipmaps/generate = false   # Off — nearest-neighbor pixel art
texture_filter = 0         # Nearest neighbor
```

---

### Naming Convention

Format: `[type]_[subject]_[variant]_[state].[ext]`

| Segment | Values |
|---------|--------|
| type | `bg` (background), `char` (character), `env` (environment prop), `ui` (UI element), `vfx` (visual effect), `tile` (tileset) |
| subject | Snake_case subject name (e.g., `wizard`, `vault_corridor`, `spell_slot`) |
| variant | Numeric index or named variant (e.g., `stage2`, `01`, `alt`) |
| state | Animation state or frame descriptor (e.g., `idle`, `cast`, `hit`, `frame_00`) |

Examples:
- `char_wizard_stage1_idle.png`
- `bg_vault_corridor_01.png`
- `ui_spell_slot_empty.png`
- `vfx_fire_burst_frame_00.png`

---

### Sprite Atlas Organization

One atlas per logical group. Do not mix categories across atlases.

| Atlas | Contents | Max size |
|-------|----------|---------|
| `atlas_char_wizard.png` | All 5 wizard growth stage animations | 2048×512 |
| `atlas_char_enemies_[zone].png` | All enemy sprites per zone | 2048×1024 |
| `atlas_tile_[zone].png` | Zone tileset (standard + feature tiles) | 2048×2048 |
| `atlas_ui_hud.png` | Spell slots, health bar, icons, frame elements | 512×512 |
| `atlas_vfx_[element].png` | Per-element spell VFX frames | 1024×1024 |

---

### Tile Standards

| Tile type | Size | Used for |
|-----------|------|---------|
| Standard tile | 16×16 px | Floor, wall, ceiling, ground |
| Feature tile | 32×32 px | Doors, pillars, notable props |
| Character unit | 48×48 px | Player and enemy sprite bounds |

Characters occupy a 48×48 bounding box at game resolution. Actual pixel art within that box may use less — empty space is intentional for hit-feel spacing and shadow room.

---

### Animation Standards

| Asset class | FPS | Notes |
|-------------|-----|-------|
| Environment / background | 12 fps | Ambient loops, decay particles |
| Character movement | 12 fps | Walk, idle, platforming |
| Combat / spell VFX | 24 fps | Cast, impact, interaction effects |
| UI elements | As specified in Section 7 | Clip-reveal 80ms, slot pulse 0.8Hz |

---

### Wizard Growth Stage Resources

The wizard's costume evolves through 5 stages (institutional clean → fully faceted demonic). Implementation: 5 swappable SpriteFrames resources on a single AnimatedSprite2D node. Swap the resource at story milestones — do not create a new AnimatedSprite2D per stage.

| Stage | Costume description | Unlock condition |
|-------|--------------------|-----------------| 
| Stage 1 | Institutional robes, clean | Start |
| Stage 2 | Robes worn, geometry beginning at edges | After Zone 1 boss |
| Stage 3 | Robes partially replaced by faceted demonic geometry | After Zone 2 boss |
| Stage 4 | Geometry dominant, robes as remnants | After Zone 3 boss |
| Stage 5 | Fully faceted, feet visible, Fracture White geometry complete | Final arc |

---

### Performance Budget per Asset Class

| Asset class | Draw call budget | Notes |
|-------------|-----------------|-------|
| Environment / background | 200 | Tilemap batching reduces this significantly |
| Characters + enemies | 100 | All on CanvasItem default |
| Spell VFX | 100 | Shared ShaderMaterial mandatory |
| UI / HUD | 50 | |
| Light2D + shadows | 50 | Max 2 Light2D active simultaneously |
| **Total** | **500** | Hard ceiling |

---

### Consistency Tests

1. **Import settings test**: All PNG imports in repo use compress/mode=0, no mipmaps, nearest filter. Automated check on CI or pre-commit.
2. **Atlas size test**: No atlas exceeds 2048×2048.
3. **Draw call test**: Scene with maximum expected enemy count + all active spell VFX stays under 500 draw calls at 60fps.
4. **ShaderMaterial test**: No two VFX nodes of the same element use separate ShaderMaterial instances.
5. **Naming compliance test**: All assets in `assets/sprites/` follow the `[type]_[subject]_[variant]_[state]` convention.

---

## Section 9: Reference Direction

*These references are production guides, not mood boards. Each names one specific technique to extract and one specific element to leave behind. No two references point in the same direction.*

---

### Hollow Knight (2017, Team Cherry)

**What to draw from**: The principle of reading environmental state from a single dominant hue ratio per zone — not from new colors, but from shifting how much of each existing palette color occupies the frame. The Forgotten Crossroads and the City of Tears use the same grey-and-blue vocabulary; the ratio of dark mid-tone to ambient light is what makes each zone feel categorically different. Apply directly to Wizrless zone differentiation: Zones 1–6 shift *proportions* of the established world palette, never introduce new world colors.

**What to avoid**: Total environmental abstraction — Hollow Knight's props and architecture read as impressionistic. Wizrless requires material specificity (cut ashlar vs. rough stone vs. oxidized bronze) because the environmental storytelling system depends on the player reading *what a surface is made of* and *why it is failing*. Where Hollow Knight lets stone be atmospheric, Wizrless makes stone be evidence.

**Connects to**: Institutional Decay, Per-Zone Color Temperature Rules

---

### Disco Elysium (2019, ZA/UM)

**What to draw from**: The visual treatment of institutional prestige in terminal decline — specifically, rendering a grand architectural space at full formal detail while letting the occupants and props reveal the institution has been wrong for decades. Architecture must first earn credibility (correct proportions, formal carved borders, deliberate scale) before the evidence of wrongness is introduced. The building makes the betrayal possible.

**What to avoid**: The warm-palette nostalgia tint — its decay reads as melancholy, even romantic. Wizrless must avoid warmth as atmosphere. Warmth appears exactly once (boss pre-fight) and must not bleed into environmental backgrounds. The institution is not sad about what it is. It is still operating.

**Connects to**: Institutional Decay, Boss Pre-Fight mood target, Zone Architecture Personalities

---

### Neon Genesis Evangelion — TV Series (1995–96, Gainax)

**What to draw from**: The compositional rule of placing geometric, alien visual forms against recognizable institutional architecture to signal that two incompatible grammars are co-present in the same physical space. NERV HQ's angular corridors exist alongside the biomechanical Evas — the gap in visual grammar between environment and entity is precisely the feeling of wrongness without villainy. Demonic geometry tiles entering Gothic arches in Zones 4–6 should produce the same read: not evil intruding on good, but a different structural logic imposing itself on the existing one.

**What to avoid**: The color language of activation sequences and final episodes — high-saturation warm golds, deep reds, apocalyptic visual signaling. The demonic grammar looks *different*, not *dangerous*. Fracture White is a cold, near-achromatic off-white — keep it categorically separated from any warm "ascension" visual tradition.

**Connects to**: The Second Grammar, Demonic zone geometry, Fracture White color identity

---

### Return of the Obra Dinn (2018, 3909 LLC)

**What to draw from**: The discipline of communicating material information — wood, rope, metal, fabric — through pure structural pixel patterns with no color saturation. Material identity reads from *pattern and edge behavior*, not from color or shading gradient. Apply as a stress test for the material signal system: every tile material (cut ashlar, rough stone, Dead Bronze, organic growth) must be distinguishable purely from its pixel pattern structure — the world palette color fills it, but the pattern is the material.

**What to avoid**: The 1-bit palette and dithering technique itself — Wizrless uses full 8-bit color and depends on the world palette for zone differentiation and hazard signaling. The principle to borrow is the underlying discipline (patterns carry material identity), not the aesthetic constraint. Adopting the high-contrast graphic look would destroy the low-saturation subtlety that makes spells read as color events.

**Connects to**: Institutional Decay, Material Signal System, Spell as Signal

---

### Mark Rothko — Seagram Murals (1958–59)

**What to draw from**: Rothko designed these murals specifically to make diners feel uncomfortable — dark, claustrophobic fields in which the space feels wrong to occupy. The Seagram Murals use deep maroon and near-black fields with barely-visible internal rectangular structure (his "windows and doors") to make you feel observed from inside the canvas. Extract this for Exploration mood: deep Vault Shadow backgrounds in corridor spaces should carry 2–4% internal value variation — not visible as detail, felt as the room having a back wall that is paying attention.

**What to avoid**: Rothko's organic, soft-edged field boundaries. Every color boundary in Wizrless is a material or architectural edge — hard, legible, earned by pixel pattern meeting pixel pattern. Borrow the emotional intent of near-uniform dark fields, not the soft wash technique.

**Connects to**: Exploration mood target, Vault Shadow application, Institutional Decay
