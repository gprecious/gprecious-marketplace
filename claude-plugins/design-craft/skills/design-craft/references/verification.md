# Verification — rendered output is the truth

Open at Gate 5. **Evaluate the rendered screenshots, not the source code.** "Looks polished" without a screenshot is process slop. Use whatever renderer the session has (claude-in-chrome, a dev server + Playwright, or headless Chrome `--screenshot`); if none is available, say so explicitly — do not assume a pass.

## Browser render gate

```
Screenshot the running UI at:
- Desktop  1440×900
- Tablet   768×1024
- Mobile   390×844 and 360×740

Then verify:
- No horizontal scroll:  documentElement.scrollWidth <= innerWidth + 1
- Visible focus: tab through primary controls, capture a focus screenshot (ring ≥3:1)
- Text overflow: no element with scrollWidth > clientWidth unless allowlisted
- Touch targets: interactive ≥ 44×44 CSS px, or a documented exception
- Contrast: text ≥4.5:1, UI/focus indicators ≥3:1
- Reduced motion: emulate prefers-reduced-motion; non-essential motion is gone
- States: empty / loading / error / success exist for every async or data-driven region
```

Headless Chrome one-liner (no MCP needed):
```
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --window-size=1440,900 --virtual-time-budget=5000 \
  --screenshot=out.png "file://ABSOLUTE/PATH/or/http://localhost:PORT"
```
For file:// pages that iframe sibling files, Chrome loads them under default flags (verified). Over a dev server, no restriction.

## Screenshot self-critique prompt

Run this against the screenshots (ideally as a separate reviewer turn/agent):

```
You are the design critic. Read the desktop/tablet/mobile screenshots, NOT the source.
Score each axis 0–10 with one concrete reason:
1. First 5 seconds — can a new user name product, audience, and next action?
2. Hierarchy — what is first / second / third? Is that correct?
3. Typography — line length, type roles, weight discipline, body readability.
4. Color — contrast, accent discipline, semantic clarity, dark-mode handling.
5. Spacing — grouping, rhythm, alignment, mobile density.
6. Layout — grid, responsive behavior, do cards earn their existence?
7. Motion — meaningful, performant, reduced-motion safe.
8. Anti-slop — list every tell from banlist.md by name.

Return FAIL if: anti-slop finds ≥2 tells, OR any accessibility axis <8,
OR mobile horizontal scroll, OR missing empty/loading/error states.
On FAIL, give targeted fixes. If a fix needs a concept change, propose 3 revised
concepts before editing. Over-correction (weird/maximal/glassy) is also a FAIL.
```

## Quality-gate table

| Gate | PASS | FAIL |
|---|---|---|
| Responsive | no h-scroll from 360px, primary action reachable, text readable | desktop stack shrunk, clipped text, hidden CTA |
| Focus | all interactive reachable, focus ring 3:1, logical order | invisible focus, keyboard trap, hover-only affordance |
| Text overflow | long label/name/price never clips or overlaps | overlap, or ellipsis with no title |
| States | loading/empty/error/success/partial specified | happy path only |
| Accessibility | AA contrast, 44px targets where applicable, visible labels | placeholder-only labels, low contrast, tiny targets |
| Slop | 0–1 minor tell, with a stated reason | ≥2 tells or a default cluster |
| Motion | transform/opacity, reduced-motion handled | layout animation, pulse/glow, no reduced-motion |

## Rework loop (max 2 passes)

```
Pass 1 — hard failures only: overflow, contrast, focus, slop tells, missing states.
Pass 2 — polish hierarchy/rhythm/type only if the score is still <8.
After each pass: re-screenshot the same viewports; compare before/after.
Stop if the score regresses or a fix introduces unrelated changes.

Final report must include:
- viewports/screenshots checked
- failures found
- fixes made
- checks skipped, with the reason
```

## Sources
Playwright (visual comparisons, accessibility testing) · WCAG 2.2 target-size 2.5.5 · web.dev prefers-reduced-motion · self-critique / iterative-refinement research (Self-Refine, Reflexion). Full URLs in the accompanying research report.
