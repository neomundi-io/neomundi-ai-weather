# AI Weather Interpretation Matrix v0.1

**Status:** Experimental / pre-freeze
**Application:** NeoMundi AI Weather
**Matrix version:** 0.1
**Date:** 2026-08-19

## 1. Purpose

This document defines the executable interpretation logic used by AI Weather to derive a public weather state from a set of NeoMundi runtime measurement signals.

It operationalizes:

**AI Weather Interpretation Profile v0.1**

and is derived from:

**NeoMundi Metric Contract**
**Signal Interpretation and Consumption Rules v0.1**

This matrix defines **interpretation precedence**.

It does not redefine the semantics of the underlying measurement signals.

---

## 2. Core principle

AI Weather MUST evaluate multiple measurement dimensions before assigning a weather state.

The following rule is normative for this matrix:

> **No single favorable signal may override a materially degraded signal in another measured dimension.**

Therefore:

```text
high stability
+
material factual-risk signal
≠
CLEAR
```

Likewise:

```text
ALLOW
+
material degradation elsewhere
≠
CLEAR
```

The interpretation engine MUST evaluate adverse and insufficient-evidence conditions before evaluating CLEAR.

---

## 3. Weather states

The v0.1 matrix recognizes:

```text
CLEAR
WATCH
UNSETTLED
ALERT
INSUFFICIENT_DATA
```

`ALERT` is reserved and has no automatic production rule in v0.1.

---

## 4. Required interpretation order

The interpretation engine MUST evaluate conditions in the following order:

```text
1. INSUFFICIENT_DATA
2. UNSETTLED
3. WATCH
4. CLEAR
```

The first matching state wins.

`ALERT` is not automatically assigned in v0.1.

This precedence prevents a favorable stability signal from masking a degraded factual, coverage, or longitudinal signal.

---

# 5. Step 1 — INSUFFICIENT_DATA

AI Weather MUST return:

```text
INSUFFICIENT_DATA
```

when the available measurement evidence is not sufficient to legitimately derive a weather state.

Possible triggers include:

* required measurement signal unavailable;
* observation window incomplete;
* insufficient coverage;
* malformed measurement payload;
* incompatible measurement version;
* stale measurement;
* absence of a required system result;
* measurement status explicitly incomplete;
* coverage boundary not satisfied.

Conceptually:

```text
required evidence missing
=
INSUFFICIENT_DATA
```

Not:

```text
required evidence missing
=
CLEAR
```

### v0.1 implementation rule

Until quantitative minimum coverage requirements are formally versioned, the implementation MUST use only coverage requirements already explicitly defined by the active AI Weather measurement protocol.

The matrix MUST NOT invent a new universal numerical coverage threshold.

### Drivers

Possible machine-readable drivers:

```text
required_signal_missing
insufficient_coverage
measurement_incomplete
measurement_stale
measurement_malformed
measurement_version_incompatible
```

---

# 6. Step 2 — UNSETTLED

If measurement evidence is sufficient, AI Weather evaluates material degradation.

`UNSETTLED` represents a state where at least one materially adverse signal or an explicit adverse combination of signals is observed.

Possible qualifying patterns include:

### 6.1 Material factual-risk signal

```text
factual-risk signal materially elevated
=
UNSETTLED candidate
```

The exact numerical threshold MUST come from a versioned metric or application rule.

This matrix MUST NOT invent one.

---

### 6.2 FLAG activity combined with runtime degradation

Example:

```text
FLAG activity
+
DROP
=
UNSETTLED candidate
```

This combination represents concurrent runtime alert activity and degradation of the stability trajectory.

---

### 6.3 Strong multi-signal degradation

Example:

```text
runtime variation elevated
+
factual-risk signal elevated
+
longitudinal deterioration
=
UNSETTLED candidate
```

No single scalar average should neutralize this combination.

---

### 6.4 Deceptive stability

Example:

```text
runtime stability high
+
material factual-risk signal
=
deceptive stability
```

Possible weather state:

```text
UNSETTLED
```

High stability MUST NOT force CLEAR in this case.

---

### 6.5 Material longitudinal deterioration

Where a versioned longitudinal rule exists:

```text
significant deterioration versus previous observation window
=
UNSETTLED candidate
```

The longitudinal rule MUST identify its reference window and measurement version.

---

### 6.6 Explicit severe conflict between measured dimensions

Example:

```text
stability signal favorable
+
factual signal materially unfavorable
```

The signals are not contradictory.

The interpretation reflects the unfavorable dimension.

---

### UNSETTLED drivers

Possible machine-readable drivers:

```text
factual_signal_material
flag_activity_material
delta_profile_drop
runtime_degradation_material
longitudinal_deterioration_material
multi_signal_degradation
deceptive_stability
signal_conflict_material
```

---

# 7. Step 3 — WATCH

If no UNSETTLED condition applies, AI Weather evaluates emerging or moderate tension.

`WATCH` represents a measurable deviation that deserves attention without meeting the criteria for material disturbance.

Possible patterns include:

### 7.1 Emerging factual-risk signal

```text
factual-risk signal above neutral
but below material degradation rule
=
WATCH candidate
```

---

### 7.2 Moderate runtime variation

```text
runtime variation elevated relative to applicable baseline
=
WATCH candidate
```

A versioned baseline or rule MUST exist before this becomes a numerical implementation condition.

---

### 7.3 Isolated FLAG activity

```text
limited FLAG activity
without material multi-signal degradation
=
WATCH candidate
```

A FLAG is an attention signal, not proof of failure.

---

### 7.4 Moderate signal conflict

Example:

```text
runtime stability favorable
+
secondary factual-risk signal non-neutral
=
WATCH candidate
```

---

### 7.5 Early longitudinal drift

```text
small but meaningful deterioration versus previous measurement window
=
WATCH candidate
```

This rule MUST be versioned before numerical enforcement.

---

### 7.6 Reduced but still valid measurement quality

If the active protocol explicitly permits interpretation under reduced coverage:

```text
coverage sufficient for interpretation
but below nominal coverage
=
WATCH candidate
```

This MUST NOT be used unless the applicable measurement protocol defines such a valid reduced-coverage state.

---

### WATCH drivers

Possible machine-readable drivers:

```text
factual_signal_elevated
runtime_variation_elevated
isolated_flag_activity
signal_conflict_moderate
longitudinal_drift
coverage_reduced_but_valid
```

---

# 8. Step 4 — CLEAR

`CLEAR` is assigned only after the interpretation engine has confirmed that none of the previous states apply.

Conceptually:

```text
measurement sufficient
+
no UNSETTLED rule matched
+
no WATCH rule matched
=
CLEAR
```

CLEAR therefore means:

> No material or emerging adverse weather signal was identified within the measured domain under the active interpretation profile.

It does not mean:

```text
true
safe
verified
approved
compliant
error-free
```

### CLEAR driver

Suggested machine-readable driver:

```text
no_adverse_signal_detected
```

---

# 9. ALERT — reserved in v0.1

`ALERT` is defined semantically but is not assigned automatically by this matrix.

AI Weather v0.1 MUST NOT implement:

```text
if metric > arbitrary_threshold:
    ALERT
```

A future ALERT rule MUST identify:

* interpretation profile version;
* measurement metric version;
* applicable model/task scope;
* signal combination;
* threshold or structural condition;
* severity semantics;
* empirical validation basis.

Until then:

```text
ALERT = reserved
```

---

# 10. No weighted-average fallback

The implementation MUST NOT use an opaque scalar fallback such as:

```text
weather_score =
    stability_weight
  + factuality_weight
  + coverage_weight
  + coherence_weight
```

unless such a transformation is separately validated and versioned.

Reason:

A weighted average could allow several favorable signals to conceal one materially degraded signal.

AI Weather v0.1 therefore uses:

```text
explicit precedence
+
explicit signal combinations
```

rather than:

```text
single blended score
```

---

# 11. Signal preservation

The interpretation engine MUST preserve the semantic dimension of each signal.

Conceptually:

```text
stability
factuality
coherence
trajectory
coverage
longitudinal change
```

remain distinct.

The resulting weather condition is a derived interpretation state.

It MUST NOT replace the original measurement values.

---

# 12. Driver transparency

Every weather state SHOULD include machine-readable interpretation drivers.

Example:

```json
{
  "condition": "WATCH",
  "drivers": [
    "factual_signal_elevated"
  ]
}
```

Example:

```json
{
  "condition": "UNSETTLED",
  "drivers": [
    "deceptive_stability",
    "factual_signal_material"
  ]
}
```

Example:

```json
{
  "condition": "INSUFFICIENT_DATA",
  "drivers": [
    "insufficient_coverage"
  ]
}
```

This permits wall, capsule, newsletter, widgets, and public releases to explain the weather condition without reverse-engineering the decision logic.

---

# 13. Interpretation trace

The generated interpretation SHOULD expose:

```text
profile
profile_version
condition
drivers
evaluated_at
```

Conceptual payload:

```json
{
  "profile": "AI_WEATHER_INTERPRETATION",
  "profile_version": "0.1",
  "condition": "WATCH",
  "drivers": [
    "factual_signal_elevated"
  ],
  "evaluated_at": "..."
}
```

Where useful, the implementation MAY additionally expose:

```text
rules_matched
rules_evaluated
```

provided this does not create unnecessary implementation complexity.

---

# 14. Current data compatibility

The current AI Weather aggregated daily output already exposes dimensions including:

```text
condition
score
observations
fully_scored
coverage
metrics.normal
metrics.variation
metrics.factual_alert
metrics.incomplete
previous_condition
regime_distribution
```

The v0.1 interpretation engine MAY consume these currently available aggregated dimensions.

However:

`score` MUST NOT independently define the weather condition.

In particular:

```text
score = 100
```

does not automatically imply:

```text
CLEAR
```

if another measured dimension indicates degradation.

---

# 15. Transitional implementation rule

The current AI Weather implementation predates this multi-signal interpretation matrix.

During migration:

1. existing measurement output MUST remain unchanged where possible;
2. a new interpretation function SHOULD consume the existing measurement output;
3. the function SHOULD derive the new weather condition;
4. the interpretation profile version and drivers SHOULD be added to the daily aggregate;
5. the capsule SHOULD record the resulting interpretation;
6. rendering layers SHOULD consume the interpreted condition.

The measurement layer itself SHOULD NOT be modified merely to accommodate display colors.

---

# 16. Model-level interpretation

Each observed model SHOULD receive its own interpretation state.

Conceptually:

```text
MODEL A
measurement signals
↓
interpretation
↓
CLEAR

MODEL B
measurement signals
↓
interpretation
↓
WATCH

MODEL C
measurement signals
↓
interpretation
↓
UNSETTLED
```

The public panel therefore reflects measured differences among models rather than assigning one universal state to the entire provider ecosystem.

---

# 17. Panel-level interpretation

A global panel condition MAY also be derived.

However, it MUST NOT be computed as a simple arithmetic average of model states.

Until a panel-level aggregation policy is explicitly versioned, the global condition SHOULD remain conservative and transparent.

Possible future strategies include:

```text
worst material state present
distribution-based interpretation
coverage-weighted panel state
state-count thresholds
```

None of these is normative in v0.1.

The existing global condition MAY remain transitional until a dedicated panel-level rule is frozen.

---

# 18. Color mapping

Public colors are rendering metadata.

Recommended conceptual mapping:

```text
CLEAR             → green
WATCH             → yellow
UNSETTLED         → orange
ALERT             → red
INSUFFICIENT_DATA → neutral / grey
```

The color itself MUST NOT become the canonical semantic state.

Canonical:

```text
condition = "WATCH"
```

Rendering:

```text
yellow
```

This allows interfaces to change visual design without changing historical interpretation semantics.

---

# 19. Rule identifiers

Executable rules SHOULD receive stable identifiers.

Suggested v0.1 identifiers:

```text
AWI-001  insufficient required evidence
AWI-010  material factual-risk signal
AWI-011  FLAG + DROP
AWI-012  material multi-signal degradation
AWI-013  deceptive stability
AWI-014  material longitudinal deterioration

AWI-020  elevated factual-risk signal
AWI-021  moderate runtime variation
AWI-022  isolated FLAG activity
AWI-023  moderate signal conflict
AWI-024  longitudinal drift
AWI-025  reduced but valid coverage

AWI-030  no adverse signal detected
```

Future revisions MAY add or retire rules.

Rule semantics MUST NOT silently change under the same identifier.

---

# 20. Precedence table

| Priority | Rule family                                  | Result              |
| -------- | -------------------------------------------- | ------------------- |
| 1        | Missing / invalid / insufficient measurement | `INSUFFICIENT_DATA` |
| 2        | Material adverse signal or combination       | `UNSETTLED`         |
| 3        | Emerging / moderate adverse signal           | `WATCH`             |
| 4        | No adverse rule matched                      | `CLEAR`             |
| Reserved | Future explicit high-severity rule           | `ALERT`             |

The highest-priority matching interpretation wins.

---

# 21. Example — stable but elevated factual signal

Input:

```text
runtime stability = high
variation         = low
coverage          = sufficient
factual signal    = elevated
```

Interpretation:

```text
WATCH
```

Possible driver:

```text
factual_signal_elevated
```

The model MUST NOT remain CLEAR solely because its runtime behavior is stable.

---

# 22. Example — deceptive stability

Input:

```text
runtime stability = high
coverage          = sufficient
factual signal    = materially elevated
```

Interpretation:

```text
UNSETTLED
```

Drivers:

```text
deceptive_stability
factual_signal_material
```

---

# 23. Example — fully stable measured state

Input:

```text
coverage              = sufficient
runtime variation     = neutral
factual-risk signal   = neutral
FLAG activity         = absent
longitudinal drift    = not materially observed
```

Interpretation:

```text
CLEAR
```

Driver:

```text
no_adverse_signal_detected
```

---

# 24. Example — incomplete measurement

Input:

```text
required measurement coverage = insufficient
```

Interpretation:

```text
INSUFFICIENT_DATA
```

Driver:

```text
insufficient_coverage
```

No other favorable signal may override this state.

---

# 25. Versioning rule

Any material change to:

* state semantics;
* precedence;
* rule identifiers;
* signal combinations;
* quantitative thresholds;
* coverage requirements;
* longitudinal logic;

requires a new interpretation matrix version.

Example:

```text
AI_WEATHER_INTERPRETATION_MATRIX_v0.2
```

Historical capsules MUST retain the matrix/profile version used at generation time.

---

# 26. Current v0.1 freeze

### Frozen

* multi-signal interpretation;
* adverse-first precedence;
* `INSUFFICIENT_DATA → UNSETTLED → WATCH → CLEAR`;
* no single-signal CLEAR rule;
* no weighted-average fallback;
* deceptive stability handling;
* explicit interpretation drivers;
* model-level interpretation;
* separation between semantic condition and UI color;
* ALERT reserved;
* versioned rule identifiers.

### Not frozen

* numerical factual-risk thresholds;
* numerical variation thresholds;
* longitudinal drift thresholds;
* universal minimum coverage threshold;
* model-specific calibration;
* task-specific calibration;
* global panel aggregation policy;
* automatic ALERT rule.

These require empirical calibration and explicit versioning.

---

## 27. Canonical v0.1 rule

> **AI Weather evaluates evidence insufficiency first, material degradation second, emerging tension third, and assigns CLEAR only when no adverse rule applies.**

This rule ensures that:

```text
stability cannot hide factual degradation
```

and:

```text
missing evidence cannot become reassuring evidence
```

---

**NeoMundi AI Weather**
**Interpretation Matrix v0.1**
Measurement preserved. Interpretation explicit. Rendering downstream.
