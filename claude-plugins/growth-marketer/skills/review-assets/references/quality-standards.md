# quality-standards

`review-assets` uses these standards to decide whether generated marketing artifacts are ready to become a `draft-campaign` input. The goal is not prettier copy. The goal is a consistent, evidence-backed set of assets that a human can safely review before publishing.

## 1. Brand Voice Consistency

- Keep one recognizable voice across `service-profile.json`, `channel-scores.json`, `copy/*`, `playbook-*`, and `cro-audit-*`.
- Match the ICP's language. VOC quotes and ICP pain statements should shape headlines, objections, and CTA wording. Do not replace customer language with generic internal terms.
- Keep tone compatible with product category and channel. A B2B SaaS playbook can be direct and operational; a B2C app ad can be warmer and more benefit-led. The same promise should still be recognizable.
- Flag contradictions such as one artifact presenting the product as "AI automation" while another sells it as "manual expert service" unless the service profile explicitly supports both.

Source anchors: Qualtrics VOC and analytics guidance; HubSpot ICP guidance; April Dunford positioning components in `docs/growth-marketer-research/conversion-and-positioning.md` [S11], [S12], [S14], [S25], [S26].

## 2. Message Clarity and Positioning

- Every major asset should answer: who this is for, what problem it solves, why this option is different, and what the next action is.
- Use the service profile as the single source of truth for `icp`, `positioning.value_prop`, `positioning.category`, and `positioning.differentiators`.
- Prefer concrete value over broad claims. "Cuts weekly report assembly from 4 hours to 20 minutes" is valid only if evidence exists; otherwise write the mechanism without the unsupported number.
- Channel playbooks and copy should not drift from the selected channel's user intent. Search traffic can use direct problem/solution phrasing; cold social usually needs clearer context and faster relevance.

Source anchors: Value Proposition Canvas and April Dunford positioning guidance in `docs/growth-marketer-research/conversion-and-positioning.md` [S21], [S22], [S25], [S26]; copy formulas in `docs/growth-marketer-research/cognitive-techniques.md`.

## 3. Claim and Evidence Integrity

- Every factual claim, numeric claim, review quote, customer-count claim, benchmark, award, price anchor, ROI claim, or "best" claim needs a source in `service-profile.evidence[]`, `voc[]`, a reviewed upstream artifact, or a cited baked reference.
- Do not invent testimonials, customers, search volume, time savings, revenue lift, ratings, review counts, scarcity, waitlists, cohort capacity, or deadlines.
- Technique annotations from `generate-copy` are allowed as creative rationale, not as proof that a claim is true.
- When evidence is missing, list it as an evidence gap and recommend either removing the claim or collecting proof before publish.

Source anchors: FTC endorsement and fake review guidance in `docs/growth-marketer-research/cognitive-techniques.md`; evidence tracking contract in `docs/superpowers/specs/2026-05-25-growth-marketer-design.md` section 5.

## 4. Channel Fit

- Check that assets respect channel constraints and intent. ASO assets should foreground app-store search relevance and screenshots; Meta ads need fast visual hooks and proof; Google/Naver search should match explicit query intent; retargeting should acknowledge prior awareness.
- The channel recommendation in `channel-scores.json` and the chosen playbook/copy channel should agree or explain the exception.
- Targeting, KPI, budget, and creative guidance in `playbook-*` should reflect `channel_signals.product_type`, `market`, `price_model`, `target`, and `discovery_intent`.

Source anchors: channel-fit rubric in `analyze-service/references/channel-fit-rubric.md`; channel playbook references under `channel-playbook/references/channels/`.

## 5. CRO Readiness

- Landing, signup, checkout, pricing, and paywall recommendations should preserve message match from ad or search intent through headline, proof, CTA, and form ask.
- Flag unclear CTA hierarchy, unsupported proof blocks, high-friction form asks, hidden pricing risk, weak mobile CTA access, and paywall promises that are not supported by onboarding context.
- Recommendations should include an observable metric when possible: CTA click, form start, signup completion, trial start, checkout completion, activation, or paid conversion.

Source anchors: VWO, Optimizely, Baymard, Stripe, RevenueCat, Google destination experience, and Unbounce references in `docs/growth-marketer-research/conversion-and-positioning.md` [S1]-[S10].

## 6. Experiment Discipline

- Treat psychological techniques as hypotheses. Do not state or imply that a technique guarantees CTR or conversion lift.
- A review finding should prefer testable recommendations: what changes, why it should help, primary metric, guardrail metric, and the evidence or source behind the hypothesis.
- Avoid changing several causes at once when recommending A/B tests. Separate headline, offer, CTA, proof, and visual hierarchy changes when possible.

Source anchors: Optimizely A/B testing and sample size references; Kohavi controlled experiments survey in `docs/growth-marketer-research/cognitive-techniques.md`.

## 7. Dark-Pattern Avoidance

- Blocking issue: fake scarcity, fake countdowns, fake reviews, fake social proof, hidden fees, disguised commitment, unclear trial renewal, fear-based exaggeration beyond evidence, or pressure that obscures user choice.
- Scarcity, loss aversion, anchoring, authority, and social proof are only acceptable when the claim is true, sourced, and clear to the user.
- A failed dark-pattern check must produce `gate_status: "fail"` and a matching `blocking_findings[]` entry.

Source anchors: scarcity/FOMO, social proof, FTC endorsement guides, FTC fake review rule, and prospect theory cautions in `docs/growth-marketer-research/cognitive-techniques.md`.

## Severity Guide

- `blocking`: Must be fixed before `draft-campaign`; includes unsupported factual claims, fake proof/scarcity, legal/compliance risk, or contradiction that changes the offer.
- `high`: Likely to mislead users or materially weaken conversion; should be fixed before publish if possible.
- `medium`: Clear quality or consistency issue with a concrete fix.
- `low`: Polish or test idea that does not block publishing.

## Gate Rule

Set `gate_status` to `fail` when any finding has `severity: "blocking"` or when the artifact set is too incomplete to judge claim/evidence integrity. A failed gate must include `blocking_findings[]`. Set `gate_status` to `pass` only when no blocking findings remain and every reviewed artifact has a traceable path.
