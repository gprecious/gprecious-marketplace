# Design fundamentals — agent-checkable rules

Open during Gate 1 (deciding tokens) and Gate 4 (building). Every rule is a checkable standard with numbers, not a vibe. Sources at the bottom.

## Typography

| Item | Rule |
|---|---|
| Body size | Web body ≥ **16px**. Dense admin/tables never below **14px**. Secondary text down to 13px only if contrast ≥ 4.5:1. |
| Line length | Long body **45–75ch** target, never above **90ch**. CJK long body ≤ **~40em**. |
| Line-height | body **1.45–1.65**, UI labels 1.2–1.35, display 0.95–1.15. Long body ≥ **1.5**. |
| Type scale | product UI `12/14/16/20/24/32`; marketing `14/16/20/28/40/56/72`; mobile ≤ 4 sizes. Ratio: compact 1.125, general 1.2, expressive 1.25–1.333. |
| Display vs body | Display = personality (used with restraint), body = legibility. Never two faces of the same personality. If display is decorative, body is neutral. |
| Weight | ≤ 3 steps in one area (`400/500/700`). No body weight 300. All-caps labels 11–12px with letter-spacing 0.04–0.08em. |
| Tracking | Headings only when the face runs wide: −0.005 to −0.015em. **No global −0.02em.** Body tracking = 0. |
| Fail if | one system-ui/Inter stack carries the whole identity; every heading 700/800; body ≤14px; long paragraphs with no max-width; everything center-aligned. |

## Color

| Item | Rule |
|---|---|
| Contrast | body/text ≥ **4.5:1**; large text ≥ 3:1; AAA-target screens body ≥ 7:1; borders/focus/icons/inputs ≥ **3:1**. |
| Palette size | surfaces 2–4, text 2–3, primary 1, secondary 0–1, semantic 4. Outside marketing, **one** saturated hue leads. |
| 60-30-10 | 60% neutral/surface, 30% secondary, 10% accent. Accent only on CTA / active / current / critical. |
| Harmony | calm/product: analogous or mono + accent. marketing: complementary only on the CTA. dashboard: semantic colors must not clash with data meaning. |
| Color space | Define colors in **OKLCH** (perceptually-uniform Lightness·Chroma·Hue), not raw hex/HSL: even brightness across hues, predictable contrast, and smoother gradients (hex gradients often band). Ship as CSS vars. |
| Dark mode | Redesign, don't invert. Dark surface ~`#0b0d10` with 2–3 elevation steps; lower accent saturation vs light; avoid pure-white body text. |
| State color | success/warning/danger/info never by color alone — pair icon/text/label. |
| Fail if | purple→blue gradient as default hero/CTA; gray text on colored bg; every CTA a gradient; semantic colors used as brand decoration. |

## Spacing & rhythm

| Item | Rule |
|---|---|
| Scale | `0/2/4/8/12/16/24/32/48/64/96`. Product UI 4/8-based; marketing 8/16/24-based. |
| Grouping (proximity) | intra-group spacing ≤ **½** inter-group. e.g. label→input 4–8, field→field 16, section→section 32–64. |
| Optical vs metric | correct icon/text baselines and card centers by eye; 1–2px optical correction is allowed over pure math. |
| Rhythm | if all same-level sections share identical height/spacing → cookie-cutter. At least one section's rhythm should follow its content density. |
| Fail if | every card `p-6 gap-4`; every section `py-24`; identical padding on nested cards; layout shift on hover/focus. |

## Hierarchy & scannability

| Item | Rule |
|---|---|
| 5-second test | From a screenshot alone, within 5s answer **what / for whom / what next**. If not → hierarchy FAIL. |
| Emphasis order | 1 position/size, 2 spacing, 3 weight, 4 color, 5 motion. Never build hierarchy from color + shadow only. |
| Scan path | marketing: brand/product signal → value → CTA → proof. app: title/status → primary action → current object → secondary nav. dashboard: decision KPI → driver → drilldown. |
| One job per section | one headline, one supporting line, 0–1 primary action per section. No repeated mood statements. |
| Fail if | everything same weight inside cards; 3+ equal CTAs; headline strong but no brand/product signal; copy could shrink 30% and read clearer. |

## Layout

| Item | Rule |
|---|---|
| Grid | desktop marketing: 12-col or asymmetric editorial. app/dashboard: nav / workspace / inspector regions first. mobile: single column + near-thumb primary action. |
| Symmetry | Choose deliberately: **symmetric** (even grid, balanced → professional, formal) vs **asymmetric** (negative space, room to experiment → artistic, "lets the design breathe"). Pick by product character; don't default to centered symmetry. |
| Whitespace | structure, not decoration. Edge padding: mobile 16–20, tablet 24–32, desktop 40–80. Long body max-width ~65ch. |
| Alignment | same functional group shares an x-axis; ≤ 2 floating alignments; numbers/money right-aligned / tabular-nums. |
| Cards | only for repeated items, selectable entities, or modal/tool frames. **Never** wrap a hero, a whole section, or a plain text block in a card. |
| Responsive | no horizontal scroll at 360px (except deliberate 2D regions: data table / canvas / map). |
| Fail if | app UI is only stacked cards; marketing first viewport split like a dashboard; mobile is a shrunk desktop stack. |

## Motion

| Item | Rule |
|---|---|
| Property | animate `transform` / `opacity` by default. `top/left/width/height/margin/filter` only with a reason (they trigger layout/paint every frame → jank). |
| Duration | micro 50–100ms, short 150–250ms, medium 250–400ms, narrative 400–700ms. No blanket `.2s ease`. |
| Easing | enter ease-out, exit ease-in, move ease-in-out/spring. bounce/elastic only for genuinely playful products. |
| Reduced motion | `@media (prefers-reduced-motion: reduce)` removes parallax, scroll reveal, looping glow; keep only state-clarifying opacity/instant transitions. |
| Purpose | motion must explain hierarchy, state, causality, or story. If it can't, delete it. |
| Fail if | fade-in-up on everything; pulse/breathe glow; bouncing CTA; layout-property animation; no reduced-motion. |

---

## Surface playbook (per Gate 0 type)

| Surface | Decide first | Good defaults | Anti-patterns |
|---|---|---|---|
| **Marketing / landing** | brand/product first signal, visual thesis, hero medium, one CTA, proof type | first viewport as one composition; real product/place/object visual; one memorable risk | generic SaaS hero, purple gradient, 3-card features, hero-in-a-card, vague copy |
| **Functional app** | user task, workspace object, navigation, primary action, existing components | calm hierarchy, dense but readable, design-system tokens, all interactive states | marketing hero inside the app, decorative cards, ornamental icons, hidden focus |
| **Dashboard** | the decision, KPI grouping, comparison grain, filters/drilldown | decision-first IA, fewer charts grouped better, tabular nums, disciplined semantic color | stat-card mosaic, chart decoration, missing empty/loading/error states, dark cloud clone |
| **Mobile** | platform, thumb zone, nav model, first-run/returning states | bottom primary actions, 44px targets, ≤4 type sizes, 8pt rhythm | desktop shrink, hover-only affordance, top-only CTA, tiny tap targets |
| **Hybrid** | which sections are marketing vs product evidence | marketing hero + real app screenshot as proof; app sections keep product density | marketing cards pretending to be app UI; app dashboard used as decoration |

---

## Copy-paste fundamentals checklist

```
Surface
- [ ] Classified: marketing | functional app | dashboard | mobile | hybrid
- [ ] One-sentence visual thesis exists
- [ ] One primary user task / conversion action named

Typography
- [ ] Body ≥16px (dense UI ≥14px); long line length 45–75ch (<90)
- [ ] Body line-height 1.45–1.65
- [ ] Display/body roles different and justified
- [ ] No default-stack-as-identity unless inherited from a design system
- [ ] No global negative tracking; body tracking 0

Color
- [ ] Body contrast ≥4.5:1; large ≥3:1; UI/focus ≥3:1
- [ ] Palette has roles (surface/text/primary/semantic), not random hex
- [ ] Accent ≤10% of area, reserved for action/status
- [ ] Dark mode redesigned, not inverted; color not the only state carrier

Spacing & layout
- [ ] 4/8 spacing scale; intra-group ≤ ½ inter-group
- [ ] Grid/regions named before components placed
- [ ] Cards only for repeated entities / choices / modals / tool frames
- [ ] No horizontal scroll at 360px (except deliberate 2D regions)
- [ ] Long labels/names/prices/localized strings don't overlap

Hierarchy & scan
- [ ] 5s: screenshot answers what / for whom / what next
- [ ] Explicit primary/secondary/tertiary order
- [ ] One job + one headline per section; CTA count controlled
- [ ] Copy can't be cut 30% without losing meaning

Motion
- [ ] transform/opacity by default; duration tokens; enter/exit/move easing differ
- [ ] prefers-reduced-motion handled; every motion has a purpose
```

---

## Sources

WCAG 2.1/2.2 (contrast 1.4.3, non-text 1.4.11, reflow 1.4.10, visual presentation 1.4.8, target size 2.5.5) · USWDS typography · Baymard line-length · Butterick Practical Typography · NN/g (typeface pairing, color 60-30-10, F-pattern, visual-design testing) · Material 3 (type scale, spacing, color, motion easing/duration) · web.dev (high-performance CSS animations, prefers-reduced-motion) · Gestalt principles.
