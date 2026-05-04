---
name: Collaboration Feedback — GDD Authoring Style
description: User provides locked decisions up front and expects the agent to execute on them precisely, not re-litigate them
type: feedback
---

User provides locked design decisions up front when asking for GDD section authoring. The agent should treat these as immutable constraints and build the full spec without re-asking about them.

**Why:** Reduces back-and-forth on decisions already made. The user is the creative director; the agent is the expert executor on spec authoring when decisions are locked.

**How to apply:** When a user message says "already locked" or provides a bulleted list of decisions, do not present alternative options for those items. Proceed directly to authoring the spec with those decisions baked in. Ask only about genuine ambiguities that cannot be resolved from the provided information.
