# AI-slop banlist + escape techniques

Open at Gate 3 (anti-default critique). These are the highest-frequency clichés LLMs emit when a design decision is missing. **A single item is not a crime — the crime is the cluster and the lack of a reason.** Flag anything below; if you keep it, write down why it's the right choice for *this* brief.

## A. Layout / composition
- Cookie-cutter rhythm: hero → 3 features → testimonials → pricing → CTA.
- First viewport auto-converging to: centered hero text + gradient blob + right-side device mockup.
- Bento grid used as "a nice box collection" with no information structure.
- Every section same height, same padding, same center alignment.
- App/dashboard built as a stacked-card mosaic only.
- A card inside the marketing hero, making the first viewport a dashboard instead of a poster.
- Top-right "More / Learn more / View all ›" idiom everywhere.
- Reflexive single **centered hero CTA** (one centered call-to-action as the default hero) — center only when the composition earns it.

## B. Cards / components
- `rounded-xl + border + shadow-sm + p-6` cards everywhere ("cardocalypse").
- Nested cards, card-in-card, a surface inside a card inside a surface.
- **Left colored border/stripe on a card** (the classic native-ad tell).
- Media-object template: thumbnail + title + 1-line desc + rounded CTA.
- icon-in-colored-circle + title + 2-line text, repeated ×3.
- Pill badge: `AD / NEW / PRO / BETA / Sponsored` uppercase + letter-spacing.
- A huge Lucide icon larger than the content it labels.
- Modal abuse: complex settings that deserve their own page crammed into a modal.

## C. Color / effects
- Purple/violet/indigo→blue gradient as the default accent.
- Gradient text + gradient CTA + gradient orb all at once.
- Glassmorphism, neon/cyan-on-dark, glow, blurred blobs used to feel "cool".
- Gray text on colored background; absolute black/white pairing failing contrast.
- Semantic colors used as decoration rather than meaning.
- One-hue palette: everything slate/blue/purple.
- "Dark luxury" clone: near-black + acid-green/vermilion + huge serif applied to every brief.

## D. Typography / copy
- **Inter / Geist** (or a single system-ui stack) as the entire identity — the reflexive agent defaults. Name them as banned in the prompt so the model looks elsewhere.
- Display and body sharing the same `600/700/800` weight ramp.
- Global `letter-spacing: -0.02em`.
- Marketing filler: "Unlock the power of…", "All-in-one solution", "Built for X", "Designed for Y".
- Placeholder copy left in: "Short description goes here", "Brand Name".
- Redundant UX writing: label + sublabel + helper + hint all saying the same thing.
- A tiny uppercase monospace eyebrow on every section.
- Cream background + oversized editorial serif as a reflexive default ("neo-slop").

## E. Icons / images / media
- Stroke-2 round-cap line-icon set (especially **Lucide**) sprinkled as decoration.
- Emoji bullets / rocket / sparkle standing in for hierarchy.
- Stock-photo-vibe hero, blurry people photos, generic 3D shapes.
- Abstract mockup where the real product/venue/object should be shown.
- Imagery unrelated to the section's meaning (cyan lasers, abstract waves).

## F. Motion
- Fade-in-up on scroll for every element.
- Blanket `.2s ease` transition.
- Pulse/breathe glow, bouncing buttons, elastic icons.
- ScrollTrigger used decoratively when there's no scroll-driven story.
- Hover scale/shadow causing layout jitter.

## G. Verification-avoidance (process slop)
- Calling it "polished" without a screenshot.
- Checking desktop only, skipping mobile/tablet.
- Skipping long-label / empty / error / loading / focus states.
- Not measuring contrast / focus / touch targets.
- No `prefers-reduced-motion`.

---

## Why slop happens

Underspecified prompts make the model fall back to high-frequency training patterns (OpenAI's own framing; design writers call it the "statistical default"). It's not "the model can't design" — it's "with no decision, it fills in the average." Every gate in this skill exists to replace an average with a decision.

## Escape techniques (in order of leverage)

1. **Named banlist** — "no purple gradient / no 3-card row / no side stripe" beats "make it pretty."
2. **Surface classifier** — decide marketing vs app vs dashboard vs mobile first (Gate 0).
3. **Component → medium reframing** — the ad is *not a card*, it's an editorial insert; onboarding is *not a modal*, it's a journey scene. **Remove the default affordance** to force a real solution.
4. **Diverge first** — 3–5 distinct directions with explicit default-escape points, then pick one.
5. **Critic gate** — screenshot-based; ≥2 tells → rework (see `verification.md`).
6. **Scoring weight** — if you rank designs, give anti-slop real weight so a "clean but generic" entry can't win on tidiness alone.

## Counter-examples & the over-correction guard

- purple, Inter, cards, gradients are **not** crimes alone — the cluster and the absence of reason are.
- "No border-radius at all" is wrong; the rule is **no single large radius applied to everything**. A radius *scale* that carries structure is fine.
- "Inter is banned" is wrong; the rule is **no default stack as the whole identity**. If the design system is Inter, keep it but still decide display/body/label roles.
- Semantic red/yellow/green is fine as *meaning*; it's slop only as decoration or when color is the sole signal.

**Over-correction is also slop.** A banlist alone can push a model into weird brutalism, maximalist chaos, or luxury-editorial cosplay. Always pair it with "keep the brief's tone" and "**take exactly one real risk**." And no amount of banlist replaces real project facts — a design system, real content, real assets, and the actual user task are what keep output from re-converging.

---

## Sources
Impeccable slop catalog · 925 Studios "AI Slop Fonts and Gradients" · Paul Bakaus "AI slop design tells" · OpenAI "Designing delightful frontends" · NN/g "Why vague prompts fail" · community practitioner threads. Full URLs in the research report accompanying this skill.
