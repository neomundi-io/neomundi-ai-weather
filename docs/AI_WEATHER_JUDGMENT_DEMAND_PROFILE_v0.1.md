# AI Weather Judgment Demand Profile v0.1

**Status:** Experimental / pre-freeze
**Application:** NeoMundi AI Weather
**Profile version:** 0.1
**Date:** 2026-08-19

## 1. Purpose

This document defines the **Judgment Demand Level** used by AI Weather.

The purpose of the Judgment Demand Level is not to judge the model.

It is to indicate:

> **the degree of judgment, attention, review, or supervision that the observed situation appears to require.**

AI Weather therefore separates:

```text
Observed state
↓
Weather interpretation
↓
Judgment demand
```

The intended public meaning is:

> **Here is the observed state, and here is how much judgment this situation demands.**

---

## 2. Fundamental boundary

The Judgment Demand Level is an interpretation aid.

It is not:

* a model quality score;
* a provider ranking;
* a truth score;
* a safety certification;
* a compliance decision;
* an execution order;
* a universal governance verdict.

It MUST NOT be interpreted as authority over the consuming system or user.

NeoMundi measures.

AI Weather interprets.

The user, organization, or consuming system retains responsibility for judgment and action.

---

## 3. Why the letter J

The Judgment Demand Level uses the prefix:

```text
J
```

for:

```text
Judgment
```

This avoids confusion with NeoMundi measurement signals such as:

```text
G
g_score
stability_score
```

The semantic layers therefore remain distinct:

```text
G / stability / factuality / variation
=
measurement dimensions

CLEAR / WATCH / UNSETTLED / ALERT
=
AI Weather interpretation state

J1 / J2 / J3 / J4
=
Judgment Demand Level
```

---

# 4. Judgment Demand Levels

AI Weather v0.1 defines four Judgment Demand Levels:

```text
J1
J2
J3
J4
```

with:

```text
J1 — Standard judgment
J2 — Increased attention
J3 — Reinforced review / judgment
J4 — Explicit oversight required
```

French rendering:

```text
J1 — Jugement standard
J2 — Attention renforcée
J3 — Revue / discernement renforcé
J4 — Supervision explicite requise
```

---

# 5. J1 — Standard judgment

## Meaning

`J1` represents a situation where the current AI Weather interpretation does not identify an adverse signal requiring increased attention.

Typical mapping:

```text
CLEAR
→
J1
```

Public meaning:

> The observed state does not currently indicate a need for heightened judgment beyond the normal level appropriate to the task.

J1 MUST NOT mean:

```text
no judgment required
automatic trust
factually correct
safe
verified
approved
```

Even under J1, the user remains responsible for applying judgment appropriate to the task and context.

---

# 6. J2 — Increased attention

## Meaning

`J2` represents a situation where the observed signals justify increased attention.

Typical mapping:

```text
WATCH
→
J2
```

Possible causes include:

* emerging factual-risk signal;
* isolated FLAG activity;
* reduced but still interpretable coverage;
* moderate runtime variation;
* early longitudinal drift;
* moderate disagreement between measurement dimensions.

Public meaning:

> The observed state contains a signal that deserves additional attention before relying on the output without further examination.

J2 does not mean the model is wrong.

It means that **more judgment is appropriate than under a routine state**.

---

# 7. J3 — Reinforced review / judgment

## Meaning

`J3` represents a situation where the observed signal configuration justifies reinforced review or independent judgment.

Typical mapping:

```text
UNSETTLED
→
J3
```

Possible causes include:

* material factual-risk activity;
* material runtime degradation;
* significant multi-signal deterioration;
* deceptive stability;
* substantial conflict between favorable stability and unfavorable factual signals;
* significant longitudinal deterioration.

Public meaning:

> The observed state should not be consumed routinely without additional review, verification, or independent judgment.

J3 does not prescribe the exact action.

Depending on context, the consuming system may choose:

```text
verify
review
compare
regenerate
reroute
ask for additional evidence
escalate
```

The action remains a consumer responsibility.

---

# 8. J4 — Explicit oversight required

## Meaning

`J4` represents the highest Judgment Demand Level defined in v0.1.

Typical mapping:

```text
ALERT
→
J4
```

Public meaning:

> The observed situation requires explicit oversight before the result should influence a consequential decision or workflow.

J4 MAY correspond in future profiles to situations such as:

* severe multi-signal degradation;
* explicitly versioned high-severity factual-risk conditions;
* severe runtime deterioration;
* critical measurement conflict;
* high-consequence operational contexts combined with adverse signals.

However, AI Weather v0.1 does not yet define an automatic production rule for ALERT.

Therefore J4 remains semantically defined but conservatively assigned.

---

# 9. INSUFFICIENT_DATA is outside the J scale

`INSUFFICIENT_DATA` MUST NOT automatically map to:

```text
J1
```

or any reassuring state.

It represents a different situation:

```text
we do not have enough measurement evidence
```

rather than:

```text
the situation was measured and appears routine
```

Recommended rendering:

```text
Judgment Demand Level: NOT DETERMINED
Reason: insufficient measurement evidence
```

or machine-readable:

```json
{
  "level": null,
  "status": "not_determined",
  "reason": "insufficient_data"
}
```

This preserves the distinction between:

```text
measurement indicates low judgment demand
```

and:

```text
judgment demand cannot legitimately be determined
```

---

# 10. v0.1 mapping

The v0.1 mapping is intentionally simple and transparent:

| AI Weather condition | Judgment Demand Level | Meaning                        |
| -------------------- | --------------------: | ------------------------------ |
| `CLEAR`              |                  `J1` | Standard judgment              |
| `WATCH`              |                  `J2` | Increased attention            |
| `UNSETTLED`          |                  `J3` | Reinforced review / judgment   |
| `ALERT`              |                  `J4` | Explicit oversight required    |
| `INSUFFICIENT_DATA`  |                  none | Judgment demand not determined |

This mapping is versioned.

It MUST NOT silently change under profile version 0.1.

---

# 11. No independent J-score in v0.1

AI Weather v0.1 MUST NOT calculate Judgment Demand from an independent weighted score.

For example, it MUST NOT introduce:

```text
JudgmentScore =
a × stability
+
b × factuality
+
c × coverage
```

without separate validation and versioning.

Instead:

```text
measurement
↓
AI Weather interpretation
↓
Judgment Demand mapping
```

This prevents AI Weather from creating two competing interpretation engines.

---

# 12. Relationship with the Weather condition

The Weather condition describes:

> **What does the observed state look like?**

The Judgment Demand Level describes:

> **How much judgment does that observed state appear to require?**

Example:

```text
Weather:
WATCH

Judgment Demand:
J2 — Increased attention
```

Another example:

```text
Weather:
UNSETTLED

Judgment Demand:
J3 — Reinforced review / judgment
```

The two fields SHOULD remain distinct in machine-readable outputs.

---

# 13. Machine-readable representation

Recommended structure:

```json
{
  "condition": "watch",
  "judgment_demand": {
    "profile": "AI_WEATHER_JUDGMENT_DEMAND",
    "profile_version": "0.1",
    "level": "J2",
    "label": "increased_attention",
    "meaning": "Increased attention"
  }
}
```

French rendering MAY display:

```text
J2 — Attention renforcée
```

while preserving the canonical machine-readable label:

```text
increased_attention
```

---

# 14. Recommended canonical labels

```text
J1
standard_judgment

J2
increased_attention

J3
reinforced_review

J4
explicit_oversight_required
```

For insufficient data:

```text
level = null
status = not_determined
reason = insufficient_data
```

---

# 15. Interpretation transparency

The Judgment Demand object SHOULD preserve the Weather condition from which it was derived.

Example:

```json
{
  "condition": "watch",
  "drivers": [
    "factual_signal_elevated"
  ],
  "judgment_demand": {
    "level": "J2",
    "label": "increased_attention",
    "derived_from_condition": "watch"
  }
}
```

This makes the logic transparent:

```text
factual signal elevated
↓
WATCH
↓
J2
```

rather than presenting J2 as an unexplained score.

---

# 16. Public communication principle

AI Weather SHOULD avoid language such as:

```text
this model is orange
this model is dangerous
this model is unreliable
```

when the underlying evidence only supports an observed state within a measurement window.

Preferred framing:

```text
The current observation window is WATCH.
Judgment Demand: J2 — Increased attention.
```

or:

> **The observed signal configuration currently calls for increased attention.**

This moves the public interpretation away from categorical judgment about a model and toward **responsible consumption of evidence**.

---

# 17. Responsibility principle

The Judgment Demand Level is deliberately designed to reinforce responsibility.

AI Weather does not remove judgment from the user.

It makes the need for judgment more visible.

Canonical principle:

> **AI Weather does not tell you what to think. It helps you see how much judgment the observed situation demands.**

This principle SHOULD guide wall, newsletter, widget, and educational rendering.

---

# 18. Educational function

Judgment Demand is also an educational layer.

Its purpose includes teaching users that:

* a stable output may still require factual scrutiny;
* a coherent output may still be wrong;
* incomplete evidence should not produce confidence;
* conflicting signals require interpretation;
* model outputs should be consumed according to context;
* responsibility does not disappear because an AI appears stable.

AI Weather therefore aims to strengthen judgment rather than replace it.

---

# 19. Context boundary

The Judgment Demand Level in AI Weather v0.1 is derived from the AI Weather observation protocol.

It does not yet account for the consequence level of the user's actual task.

For example:

```text
WATCH
→
J2
```

within AI Weather v0.1 regardless of whether the downstream task is:

```text
creative brainstorming
medical advice
financial advice
legal analysis
industrial control
```

A future context-specific consumer policy MAY legitimately increase the required level of oversight.

Example:

```text
AI Weather = WATCH
base Judgment Demand = J2

+
high-consequence medical context
=
consumer policy may require stronger review
```

Such context-specific escalation belongs to the consuming policy layer.

It MUST NOT be silently embedded in the measurement itself.

---

# 20. No automatic action

J1–J4 are not action commands.

They MUST NOT be confused with:

```text
CONTINUE
VERIFY
STOP
REGENERATE
REROUTE
ABSTAIN
HUMAN_REVIEW
```

Those are possible consumer actions.

The correct architecture remains:

```text
NeoMundi measurement
↓
AI Weather condition
↓
Judgment Demand Level
↓
consumer judgment / policy
↓
action
```

---

# 21. Capsule integration

The daily capsule SHOULD record the Judgment Demand object already produced by the interpretation layer.

Conceptual structure:

```json
{
  "model": "example-model",
  "condition": "watch",
  "interpretation": {
    "profile": "AI_WEATHER_INTERPRETATION",
    "profile_version": "0.1",
    "drivers": [
      "factual_signal_elevated"
    ]
  },
  "judgment_demand": {
    "profile": "AI_WEATHER_JUDGMENT_DEMAND",
    "profile_version": "0.1",
    "level": "J2",
    "label": "increased_attention",
    "derived_from_condition": "watch"
  }
}
```

The capsule generator SHOULD record this result.

It SHOULD NOT independently recompute Judgment Demand.

---

# 22. Rendering examples

## CLEAR

```text
CLEAR
J1 — Standard judgment
```

Public explanation:

> No adverse signal currently calls for heightened attention within the measured window.

---

## WATCH

```text
WATCH
J2 — Increased attention
```

Public explanation:

> One or more observed signals call for increased attention.

---

## UNSETTLED

```text
UNSETTLED
J3 — Reinforced review / judgment
```

Public explanation:

> The observed signal configuration warrants additional verification or independent review.

---

## ALERT

```text
ALERT
J4 — Explicit oversight required
```

Public explanation:

> Explicit oversight is required before the result influences a consequential workflow.

---

## INSUFFICIENT_DATA

```text
INSUFFICIENT DATA
Judgment Demand: not determined
```

Public explanation:

> Available measurement evidence is insufficient to assign a legitimate Judgment Demand Level.

---

# 23. Wall presentation

A model card MAY present:

```text
MODEL NAME

WATCH
J2

Increased attention

Driver:
Factual signal elevated
```

The interface SHOULD make the interpretation understandable without requiring users to understand all underlying NeoMundi metrics.

Detailed measurement data MAY remain accessible through expansion, tooltip, capsule, or technical view.

---

# 24. Newsletter presentation

A daily newsletter MAY derive language such as:

```text
4 models entered J2 today.
Primary drivers: factual alerts and reduced coverage.
No J3 condition was observed.
```

This framing emphasizes the demand for attention rather than ranking providers.

---

# 25. Longitudinal use

Judgment Demand Levels MAY be analyzed over time.

Examples:

```text
J1 → J1 → J2 → J2 → J3
```

or:

```text
J2 → J1
```

This MAY support longitudinal questions such as:

* how often does a model require increased attention?
* how persistent are J2 or J3 periods?
* which signal families most frequently drive increased Judgment Demand?
* how quickly does a model return to J1 after a disturbance?

Historical analysis MUST retain the interpretation profile version.

---

# 26. No ranking by default

Judgment Demand MUST NOT automatically become a provider leaderboard.

For example:

```text
Model A had 12 J2 days
Model B had 3 J2 days
```

does not by itself establish that Model A is universally worse.

Different models, versions, availability patterns, task scopes, and measurement conditions may differ.

Any comparison MUST retain appropriate methodological context.

---

# 27. Versioning

Any material change to:

* J-level semantics;
* condition-to-J mapping;
* public labels;
* insufficient-data handling;
* context escalation rules;
* interpretation relationship;

requires a new profile version.

Example:

```text
AI_WEATHER_JUDGMENT_DEMAND_PROFILE_v0.2
```

Historical capsules MUST retain the profile version active at generation time.

---

# 28. v0.1 freeze boundary

## Frozen

```text
CLEAR → J1
WATCH → J2
UNSETTLED → J3
ALERT → J4
INSUFFICIENT_DATA → no J level
```

Frozen meanings:

```text
J1 — Standard judgment
J2 — Increased attention
J3 — Reinforced review / judgment
J4 — Explicit oversight required
```

Also frozen:

* Judgment Demand is distinct from measurement;
* Judgment Demand is distinct from execution policy;
* J-levels are not model quality scores;
* insufficient evidence cannot produce J1;
* J-levels are model-window interpretations;
* J-levels reinforce user responsibility;
* context-specific escalation remains downstream.

## Not frozen

* context-sensitive escalation;
* task-specific J-level mappings;
* high-consequence domain policy;
* independent Judgment Demand scoring;
* automatic J4 thresholds;
* organization-specific actions for each J-level.

These belong to future profiles or consumer policies.

---

# 29. Canonical statement

> **Here is the observed state, and here is how much judgment this situation demands.**

French:

> **Voici l'état observé, et voici combien de jugement cette situation demande.**

---

# 30. Canonical responsibility statement

> **AI Weather does not replace judgment. It makes the need for judgment visible.**

---

**NeoMundi AI Weather**
**Judgment Demand Profile v0.1**
Observe the state. Make judgment demand visible. Keep responsibility with the consumer.
