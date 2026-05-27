# Offer, Positioning, And Lifecycle Email Frameworks

This reference bakes only the copy-generation slices from `docs/growth-marketer-research/conversion-and-positioning.md`: VOC/ICP, lifecycle email, offer, positioning, value proposition, and hook model. CRO audit material is intentionally excluded.

## VOC And ICP Inputs

Use `service-profile.json` as the source of truth. Translate internal product language into customer language from:
- `icp.segment`
- `icp.pains`
- `icp.goals`
- `voc[].quote`
- `positioning.value_prop`
- `positioning.category`
- `positioning.differentiators`
- `evidence[]`

VOC fields worth preserving when available: source, segment, stage, verbatim, pain, trigger, desired outcome, objection, current alternative, and proof needed. ICP should be narrow enough to affect channel, targeting, offer, proof, and CTA.

Sources:
- Qualtrics Voice of Customer: https://www.qualtrics.com/customer-experience/voice-of-customer/
- Qualtrics VOC analytics: https://www.qualtrics.com/articles/customer-experience/voice-of-customer-analytics/
- HubSpot ICP template: https://www.hubspot.com/make-my-persona/ideal-customer-profile-template
- Harvard Business School JTBD: https://www.hbs.edu/faculty/Pages/item.aspx?num=51553
- Wynter message testing: https://wynter.com/products/message-testing

## Offer And Positioning

Positioning should answer: when the customer compares this service against real alternatives, where is the value most obvious?

Use these fields in generated copy:
- competitive alternative
- differentiated capability
- value created by the capability
- strongest target segment
- market category
- current trigger or pain
- proof needed

Offer levers:
- dream outcome
- proof / perceived likelihood
- time-to-value
- effort / switching cost
- risk reversal
- bonus stack
- price anchor

Do not invent proof, guarantees, bonuses, or discounts. If a lever is not supported by `service-profile.json`, mark it as a recommendation or omit it from final copy.

Sources:
- Strategyzer Value Proposition Canvas: https://www.strategyzer.com/library/the-value-proposition-canvas
- Strategyzer value proposition: https://www.strategyzer.com/value-proposition
- April Dunford positioning intro: https://www.aprildunford.com/post/an-introduction-to-positioning
- April Dunford positioning exercise: https://www.aprildunford.com/post/a-product-positioning-exercise
- Acquisition.com offers page: https://www.acquisition.com/offers-oo

## Hook Model For Copy

Use the hook model mainly for onboarding and retention copy:
- trigger: external cue such as email or push
- action: low-friction next behavior
- variable reward: useful insight, benchmark, saved time, completed task, or progress signal
- investment: saved template, uploaded data, invited teammate, completed profile, or created content

Copy should not overpromise habit formation. Use the model to choose the next CTA, not to manipulate users.

Source:
- Nir and Far Hooked workbook: https://www.nirandfar.com/download/hooked-workbook.pdf

## Lifecycle Email Sequence

Lifecycle email works by stage and behavior signal, not by sending the same newsletter to every user. For onboarding, prefer:
- T+0 welcome and purpose confirmation
- activation blocker help
- first success prompt
- proof or reassurance
- next habit or team expansion

Rules:
- one product action per email
- suppress or branch after activation
- use downstream metrics such as activation, click, reply, repeat purchase, trial-to-paid, churn prevention
- keep consent, authentication, and unsubscribe expectations visible for promotional sends
- optimize subject and content through tests without treating open rate as the final metric

Sources:
- Customer.io lifecycle campaigns: https://customer.io/learn/lifecycle-marketing/essential-lifecycle-marketing-campaigns
- Braze lifecycle marketing: https://www.braze.com/resources/articles/growth-marketers-and-lifecycle-marketing
- Klaviyo winback flow: https://help.klaviyo.com/hc/en-us/articles/115002775192
- Google sender guidelines FAQ: https://support.google.com/a/answer/14229414
- Mailchimp open and click rates: https://mailchimp.com/help/about-open-and-click-rates/

## Output Implications

Generated copy should include:
- audience and service-profile source path
- selected asset type and channel
- variants A/B or sequence branches
- annotation per variant with technique ID and source ref
- why the technique fits this ICP and channel
- measurement hypothesis, primary metric, and guardrail metric
- explicit note when a tempting claim cannot be used because evidence is missing
