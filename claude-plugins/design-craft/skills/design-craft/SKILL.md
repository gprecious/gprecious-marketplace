---
name: design-craft
description: Use when creating, revising, or critiquing frontend UI (web or mobile) where visual quality, product fit, design-system fidelity, or avoiding generic "AI-slop" output matters — e.g. "make this look good", "why does this look AI-generated", building a landing page / app screen / dashboard, or a design pass on existing UI. Turns vague design intent into a decision-first workflow: classify the surface, decide direction before code, escape default looks, build to measurable craft standards, and verify the rendered result. Portable across Claude Code and Codex.
---

# design-craft

Good design is **decisions, not vibes**. When an LLM writes UI without deciding typography, color, layout, surface type, motion, and copy for *this specific brief*, it falls back to the highest-frequency patterns in its training data — the look people call "AI slop." Slop is not ugliness; it's the **absence of decisions**.

This skill makes those decisions explicit and enforces them. It is the synthesis of Anthropic's `frontend-design` methodology, a surface-type router, a measurable craft standard, a named anti-slop banlist, and a rendered-output verification loop.

**Act as the design lead at a small studio** whose clients have already rejected templated work and are paying for a distinct, justified point of view — not a neutral UI generator.

## When to use

- Building any UI where it should look intentional: landing/marketing pages, app screens, dashboards, mobile UI.
- Someone says "make it look good / more polished / less generic / less AI-generated."
- A design pass / visual QA on existing UI.
- Reviewing whether a design reads as templated slop.

## When NOT to use

- Pure logic/backend/data work with no visual surface.
- The user gave an exact, locked visual spec or design system to implement verbatim — then **follow it exactly**; do not fight their chosen style. (Still apply the craft floor and verification.)

## Core principle: decide before you code

Do not open a `.css`/`.tsx` file until §0–§2 are done. Every color, type, spacing, motion, and copy choice in the build must trace back to a written decision. If you can't name why a choice is right for *this* brief, it's probably a default.

---

## The workflow — six gates

### Gate 0 — Classify the surface (router)

Before anything, classify the UI. Each type optimizes for different things; applying "marketing taste" to a dashboard produces slop, and vice-versa.

| Surface | Optimize for | Decide first |
|---|---|---|
| **marketing / brand / portfolio** | distinct impression, one memorable moment | visual thesis, hero medium, one CTA, proof |
| **functional app / product flow** | task clarity, calm density, reuse | user task, workspace object, navigation, existing components |
| **dashboard / analytics** | the decision the user must make | the decision, KPI grouping, comparison grain, filters |
| **mobile app** | thumb reach, platform conventions | platform (iOS/Android), nav model, first-run vs returning |
| **hybrid** | which sections are marketing vs product | section-by-section split |

If the surface is **not** marketing/brand/portfolio, **reduce visual novelty** and prioritize component reuse, information density, accessibility, and platform conventions over expressive direction. See `references/fundamentals.md` §"Surface playbook" for per-type good-defaults and anti-patterns.

### Gate 1 — Design-decision pass (no code yet)

Write a short brief. Ground it in the subject's real world (its materials, vocabulary, audience) — that's where non-generic choices come from.

```
SUBJECT: concrete product/place/person/topic (pin it if the brief doesn't)
AUDIENCE: who, and their emotional register
JOB: the single job of this screen
VISUAL THESIS: what the first viewport proves in one sentence
COMPONENT SOURCE: existing design system / library, or "new"
TOKENS:
  color:   4–6 named roles in OKLCH (perceptually uniform, smoother gradients), not raw hex
  type:    display / body / utility roles (2+ real typefaces, chosen not defaulted — never Inter/Geist by reflex)
  layout:  symmetric vs asymmetric (by product character) + one sentence / ASCII wireframe
  signature: the ONE element this screen is remembered by (if GPU/3D-driven → references/gpu-visuals.md)
ANTI-DEFAULTS: 3 specific clichés this brief must avoid
```

If a design system / component library already exists, **use its real components and tokens before inventing primitives**. Real system context is the strongest anti-slop lever.

### Gate 2 — Diverge → converge

For any surface where the visual direction is open (and always for a hero / ad / signature screen): **propose 3–5 genuinely different directions**, each with a one-line "default-escape point." Then pick **one**, state why it fits the audience and task, and reject the others with concrete reasons. Single-shot generation converges to the default; divergence-first escapes it.

If the brief already pins the direction, skip divergence and implement it faithfully.

### Gate 3 — Anti-default critique (before building)

Run the design plan against the named-cliché banlist. **Open `references/banlist.md`** and check every category (layout, cards/components, color/effects, type/copy, icons/media, motion). Revise anything that:

- could appear on any SaaS landing page,
- uses cards / gradients / badges / numbers / icons as decoration only,
- has a signature not drawn from the subject,
- has copy generic enough to belong to any product.

**The three AI default looks** — treat as blacklisted unless the brief explicitly asks or the subject truly grounds them:
1. warm cream (~`#F4F1EA`) + high-contrast serif + terracotta accent
2. near-black + one acid-green / vermilion accent
3. broadsheet: hairline rules, zero border-radius, dense newspaper columns

These are *defaults, not choices* — they show up regardless of subject. Don't spend a free axis on one. (Note: they now recur so often they are themselves slop.)

Reframe technique when stuck: turn a **component into a medium** and **remove the affordance** — e.g. "the ad is *not* a card; it's an editorial insert / a sponsor line," "onboarding is *not* a modal; it's a journey scene." Removing the default affordance forces a real solution.

### Gate 4 — Build

Implement only the chosen direction, deriving every value from the tokens.

- **Spend boldness in one place.** The signature is the one memorable thing; keep everything around it quiet. Then remove one accessory (Chanel's rule) — cut decoration that doesn't clarify hierarchy, brand, or task.
- **Copy is design material, not decoration.** Name things by what the user controls, not how the system is built. Active voice; a control says what happens ("Save changes", not "Submit"); an action keeps its name through the whole flow (button "Publish" → toast "Published"). Treat empty/error states as direction, not mood.
- Meet the **measurable craft floor** — body ≥16px, text contrast ≥4.5:1, line length 45–75ch, 4/8 spacing scale, motion via transform/opacity only. Full numbers in `references/fundamentals.md`; keep it open while building.
- Watch CSS specificity: type-selectors (`.section`) vs element/utility selectors can cancel each other's padding/margin — a common generated-CSS bug.

### Gate 5 — Verify the rendered result

**Rendered output is the truth, not the source.** Before reporting done, **open `references/verification.md`** and run the browser gates: screenshot at desktop/tablet/mobile, then a screenshot-based self-critique (5-second test, hierarchy, type, color, spacing, motion, and a slop-tell scan). 

Blocking rule: if the critic finds **≥2 slop tells**, any accessibility hard-fail (contrast, focus, target size), mobile horizontal scroll, or missing empty/loading/error states → do a **targeted rework pass** (max 2) before finishing. If a fix needs a concept change, generate 3 revised concepts first.

Guard against **over-correction**: weird/maximalist/glassy/luxury-editorial escapes are *also* slop. Keep the brief's tone; take exactly one real risk.

---

## Measurable fundamentals (summary)

Keep `references/fundamentals.md` open during Gates 1 and 4. The non-negotiable numbers:

- **Type**: body ≥16px (dense UI ≥14px); line length 45–75ch (never >90ch, CJK ≤40em); body line-height 1.45–1.65; display vs body are different, justified faces; no global negative letter-spacing.
- **Color**: define in **OKLCH** (perceptually uniform); text contrast ≥4.5:1 (large ≥3:1; AAA target 7:1); UI borders/focus/icons ≥3:1; 60-30-10, one saturated accent reserved for action/status; dark mode is redesigned, not inverted; color is never the only carrier of state.
- **Spacing/layout**: 4/8 scale (0,2,4,8,12,16,24,32,48,64,96); intra-group spacing ≤ ½ inter-group; cards only for repeated entities / choices / modals / tool frames — never wrap a hero or a page section in a card; no horizontal scroll at 360px.
- **Hierarchy**: in 5 seconds a screenshot answers "what is it, for whom, what next?"; emphasis order = position/size > spacing > weight > color > motion; one job + one headline per section; controlled CTA count.
- **Motion**: transform/opacity only; durations micro 50–100 / short 150–250 / medium 250–400ms; different easing for enter/exit/move; `prefers-reduced-motion` removes non-essential motion; every motion explains hierarchy, state, causality, or story.

---

## Scaling up: one page → system → test

A single screen is Gates 1–5. Beyond that, three levels separate custom from templated:

- **Page** — the six gates above, for one surface.
- **System** — for multi-page work, keep a persistent **`design.md`** (the visual system: OKLCH palette, type roles, spacing/radius/motion tokens, anti-patterns) *separate from* project context (`CLAUDE.md` / `AGENTS.md`). Any agent should grasp the visual system from `design.md` alone. Put a line at its top telling agents to append newly-decided values, so it compounds each session. This is what stops page 2 (dashboard/auth) from drifting off the landing page's style.
- **Test** — turn `design.md`'s anti-patterns into programmatic checks and run them *before* building (see `references/verification.md` → Design TDD). Structured, machine-readable feedback beats "looks good."

---

## Using this skill in Claude Code vs Codex

The core workflow above is host-neutral markdown — it runs identically in both. Host specifics:

**Claude Code**
- Invoke with `/design-craft` or let it auto-trigger from the description.
- For visual verification (Gate 5), use claude-in-chrome / a dev server / Playwright screenshots when available.
- Large tables live in `references/*`; they load only when you open them (progressive disclosure).

**Codex**
- Codex may not auto-select this skill. When doing UI work, **read this SKILL.md first**, then inspect the project, then implement — or invoke via `/goal` pointing here. For durable per-repo defaults, mirror the craft floor into `AGENTS.md`.
- To make it discoverable, place a copy at `~/.agents/skills/design-craft/SKILL.md` or `.agents/skills/design-craft/SKILL.md`.
- Gate 5 verification: use whatever screenshot tool the session has (Playwright, a headless Chrome `--screenshot`, etc.).

**Guarded dependencies** — name and check before relying on any: browser available? dev server? Figma MCP? image generation? If a verification tool is unavailable, say "visual verification not performed" rather than assuming it passed.

## Reference files (open when the gate says so)

- `references/fundamentals.md` — typography/color/spacing/hierarchy/layout/motion as checkable rules + numbers, and the per-surface playbook. Open at Gate 1 and Gate 4.
- `references/banlist.md` — the extended AI-slop catalog (7 categories) + escape techniques + over-correction guard. Open at Gate 3.
- `references/verification.md` — browser render gates, the screenshot self-critique prompt, the quality-gate table, the rework loop, and **Design TDD** (anti-patterns→tests, Playwright/Vizzly, living external audit). Open at Gate 5.
- `references/gpu-visuals.md` — WebGL / shader / 3D (R3F + Next.js) as a deliberate **signature**: when to use, the 2–3 color restraint that makes 3D carry emotion, the Lenis+GSAP scroll-camera pattern, and non-negotiable perf / reduced-motion / SEO guardrails (+ "WebGL slop" guard). Open at Gate 1/4 when the signature is GPU-driven.
