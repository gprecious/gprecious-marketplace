# CRO reference: landing, signup, paywall, forms

This reference bakes the CRO slice of
`docs/growth-marketer-research/conversion-and-positioning.md` for the `cro-audit` skill.
Preserve source IDs in audit recommendations so each claim remains traceable.

## Core audit frame

CRO improves conversion paths such as landing pages, signup flows, checkout, paywalls, and
forms through evidence, hypotheses, experiments, and business-relevant metrics.[S1][S2]
Audit friction as more than weak persuasion: look for cognitive load, unnecessary input,
message mismatch, slow or hard-to-use destinations, weak trust, and unclear next steps.[S1][S4][S9][S10]

Use this decision record for every recommendation:

```text
Problem -> Evidence -> Hypothesis -> Variant -> Primary metric -> Guardrail metric -> Decision rule
```

A/B winners require enough traffic and conversion evidence. For low-traffic pages, prefer
upper-funnel proxy metrics such as CTA click, form start, pricing visit, trial start, or
checkout step completion before claiming business lift.[S2][S3]

## Landing page checks

- Match ad/search intent, hero headline, proof, CTA, and form ask to the same promise.[S9][S10]
- Make the page useful, functional, and easy to navigate; destination usability is part of
  conversion quality, not just policy compliance.[S9]
- Compare performance against the same channel, intent, and segment baseline rather than
  treating industry median conversion rates as universal targets.[S10]
- If a search ad promises a narrow pain, avoid broad category copy. Put the ICP pain and
  outcome in the headline and CTA path.[S2][S9][S10]

## Signup and form checks

- Define the activation event: the first action where the user experiences product value.
  Ask only for information needed before that event; move the rest to progressive profiling.[S1][S2]
- Reduce visible and required fields. Remove low-value questions or mark them optional when
  the reason for asking is weak.[S4][S6]
- Labels, help text, and error messages should make the required input obvious and prevent
  avoidable validation failures.[S6]
- Checkout research reports that complexity and long forms drive abandonment, so treat every
  field as a cost that must earn its place.[S4]

## Paywall, pricing, and checkout checks

- Evaluate onboarding claim, paywall promise, trial length, plan count, annual/monthly
  anchoring, refund or guarantee language, and post-trial reminder as one funnel.[S8][S7]
- Do not assume a universal plan layout. Subscription benchmarks vary by category, traffic
  temperature, and purchase intent.[S8]
- Payment completion depends on payment method fit, security trust, error handling, guest
  checkout, and mobile friendliness as a combined experience.[S7]
- Trust proof should appear close to the decision point: customer proof, security cues,
  guarantee/refund details, or transparent trial terms.[S7][S8]

## Severity guide

- `high`: directly blocks or confuses the conversion decision, creates trust/payment risk, or
  asks for high effort before value is clear.
- `medium`: weakens the next step, adds avoidable cognitive load, or leaves an objection
  unanswered.
- `low`: local clarity or polish issue with limited funnel impact.

## Source links

- [S1] VWO, "Conversion Rate Optimization Process in 5 Easy Steps" — https://vwo.com/conversion-rate-optimization/cro-process-in-5-easy-steps/
- [S2] Optimizely, "A/B testing" — https://www.optimizely.com/optimization-glossary/ab-testing/
- [S3] Optimizely Support, "Statistical significance" — https://support.optimizely.com/hc/en-us/articles/4410284003341-Statistical-significance
- [S4] Baymard Institute, "Checkout Optimization: 5 Ways to Minimize Form Fields in Checkout" — https://baymard.com/blog/checkout-flow-average-form-fields
- [S5] Baymard Institute, "Checkout UX 2025: 10 Pitfalls and Best Practices" — https://baymard.com/blog/current-state-of-checkout-ux
- [S6] Baymard Institute, "Form Design: 6 Best Practices for Better E-Commerce UI" — https://baymard.com/learn/form-design
- [S7] Stripe, "Checkout flow design strategies that can help boost conversion and customer retention" — https://stripe.com/us/resources/more/checkout-flow-design-strategies-that-can-help-boost-conversion-and-customer-retention
- [S8] RevenueCat, "State of Subscription Apps 2026" — https://www.revenuecat.com/state-of-subscription-apps-2026-shopping/
- [S9] Google Ads Policy Help, "Destination experience" — https://support.google.com/adspolicy/answer/16427615
- [S10] Unbounce, "Conversion Benchmark Report" — https://unbounce.com/conversion-benchmark-report/
