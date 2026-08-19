# AI Weather Interpretation Profile v0.1

**Status:** Experimental / pre-freeze
**Application:** NeoMundi AI Weather
**Profile version:** 0.1
**Date:** 2026-08-19

## 1. Purpose

This document defines how **AI Weather** consumes NeoMundi runtime measurement signals in order to derive a public weather condition for an observed AI model.

It is an **application-specific interpretation profile**.

It does not redefine the underlying NeoMundi measurement semantics.

AI Weather therefore follows the architecture:

```text
NeoMundi measurement
        ↓
runtime signals
        ↓
AI Weather Interpretation Profile
        ↓
weather condition
        ↓
public rendering
```

The public weather condition is an interpretation of multiple measured signals.

It is **not itself a NeoMundi measurement primitive**.

---

## 2. Source contract

This profile is derived from:

**NeoMundi Metric Contract**
and specifically from:

**Signal Interpretation and Consumption Rules**

Source repository:

```text
neomundi-io/neomundi-metric-contract
```

Source rules:

```text
signal_interpretation_and_consumption_rules.en.md
```

At the time of this profile:

```text
source_contract_status = experimental / pre-freeze
source_rules_status    = work in progress / standardization
```

AI Weather MUST therefore identify the interpretation profile version used to produce every published weather condition.

Future changes to the NeoMundi Metric Contract MUST NOT silently alter the interpretation of previously published AI Weather observations.

---

## 3. Fundamental boundary

AI Weather preserves the NeoMundi separation:

```text
Measurement ≠ Interpretation ≠ Policy ≠ Execution
```

NeoMundi measures.

AI Weather interprets a defined set of measurement signals for the limited purpose of producing a weather condition.

The weather condition MUST NOT be interpreted as:

* proof that a model is correct;
* proof that a model is incorrect;
* a universal safety rating;
* a compliance certification;
* a provider ranking;
* an authorization or prohibition to use a model;
* a general judgment about model quality.

The weather condition describes an **observed runtime state under the applicable AI Weather measurement protocol**.

---

## 4. Multi-signal principle

AI Weather MUST derive its weather condition from a **combination of signals**.

No individual signal may independently represent the complete weather state.

In particular:

```text
high stability ≠ factual correctness
```

and:

```text
stable ≠ clear weather automatically
```

and:

```text
ALLOW ≠ verified truth
```

and:

```text
FLAG ≠ proven error
```

A model may therefore exhibit high runtime stability while simultaneously exhibiting elevated factual-risk signals.

Such a state MUST NOT automatically be rendered as CLEAR solely because the stability signal is high.

---

## 5. Interpretation dimensions

AI Weather v0.1 may consume the following dimensions when available.

### 5.1 Runtime stability

Possible source signals include:

```text
G
g_score
stability_score
regime
```

These signals characterize runtime stability.

They MUST NOT be treated as factual-accuracy scores.

---

### 5.2 Runtime variation and trajectory

Possible source signals include:

```text
delta_g
delta_series
delta_variation
delta_profile
```

These signals describe change in runtime stability and the shape of the observed trajectory.

Examples may include:

```text
FLAT
DROP
V_SHAPE
```

A trajectory signal describes runtime behavior.

It does not independently establish factual correctness.

---

### 5.3 Runtime classification

Possible states include:

```text
ALLOW
FLAG
```

`FLAG` indicates that the applicable NeoMundi measurement configuration identified a generation deserving attention.

`ALLOW` means that no such runtime alert was produced under the applicable configuration.

Neither state independently establishes truth or safety.

---

### 5.4 Factual-risk signal

Where available, AI Weather may consume:

```text
hallucination_score
factual_alert
```

These signals represent a dimension distinct from runtime stability.

A model may therefore exhibit:

```text
high stability
+
elevated factual-risk signal
```

without contradiction.

AI Weather MUST preserve this distinction.

---

### 5.5 Semantic coherence

Where available, AI Weather may consume:

```text
coherence_score
```

Semantic coherence is a distinct signal dimension.

High coherence MUST NOT be silently interpreted as factual correctness.

---

### 5.6 Measurement coverage

AI Weather MUST distinguish between:

```text
measured and neutral
```

and:

```text
not measured / insufficiently measured
```

Missing or incomplete measurement MUST NOT silently become:

```text
0
ALLOW
STABLE
CLEAR
safe
verified
```

Coverage therefore participates directly in the interpretability of the resulting weather state.

---

### 5.7 Temporal and longitudinal signals

Where available, AI Weather may additionally consume longitudinal signals such as:

```text
previous_condition
delta_day_1
delta_day_7
regime change
condition change
```

These signals provide context about changes over time.

Longitudinal interpretation MUST remain distinguishable from the measurement of the current observation window.

---

## 6. Weather states

AI Weather v0.1 defines the following public interpretation states:

```text
CLEAR
WATCH
UNSETTLED
ALERT
INSUFFICIENT_DATA
```

These states are interpretation labels.

They are not NeoMundi primitive measurement states.

---

## 7. CLEAR

### Meaning

`CLEAR` represents a measurement window in which the available multi-signal evidence does not currently indicate a material degradation according to the AI Weather interpretation profile.

Conceptually:

```text
sufficient measurement coverage
+
runtime stability compatible with baseline
+
no significant runtime degradation signal
+
no material factual-risk signal
+
no significant conflicting signal
=
CLEAR
```

### Important limitation

`CLEAR` MUST NOT mean:

```text
factually correct
safe
approved
verified
compliant
risk-free
```

CLEAR is therefore equivalent to:

> No significant adverse weather signal was identified within the measured domain under the current interpretation profile.

---

## 8. WATCH

### Meaning

`WATCH` represents an observed state where at least one signal warrants attention, but the available evidence does not support classification as a stronger weather disturbance.

Possible drivers may include:

* moderate runtime variation;
* emerging longitudinal drift;
* increased factual-risk signal;
* disagreement between runtime signals;
* reduced but still usable measurement coverage;
* deterioration relative to the previous observation window;
* isolated FLAG activity;
* other profile-defined early-warning conditions.

Conceptually:

```text
mostly stable environment
+
meaningful secondary signal
=
WATCH
```

A WATCH condition is intended to expose **emerging tension**, not to declare failure.

---

## 9. UNSETTLED

### Meaning

`UNSETTLED` represents a measurement window containing a material degradation signal or a combination of adverse signals.

Possible drivers may include:

* significant factual-risk activity;
* material FLAG activity;
* sustained or substantial runtime variation;
* DROP-type runtime degradation;
* meaningful longitudinal deterioration;
* multiple simultaneously degraded dimensions;
* strong conflict between stability and factual-risk signals.

A particularly important example is:

```text
high runtime stability
+
elevated factual-risk signal
=
possible deceptive stability
```

Such a state MUST NOT remain CLEAR solely because the model is stable.

Depending on the applicable thresholds and profile version, it may produce WATCH or UNSETTLED.

---

## 10. ALERT

### Meaning

`ALERT` is reserved for conditions that meet a future explicitly versioned high-severity interpretation rule.

AI Weather v0.1 MUST NOT infer an ALERT state from arbitrary or undocumented numerical thresholds.

An ALERT rule MUST identify at minimum:

```text
interpretation_profile_version
signal or signal combination
threshold or condition
measurement scope
model/task context where relevant
semantics of the alert
```

Until such rules are empirically validated and versioned, ALERT SHOULD remain conservatively used or unused.

---

## 11. INSUFFICIENT_DATA

### Meaning

`INSUFFICIENT_DATA` represents a measurement window where the available evidence is insufficient to produce a legitimate weather interpretation.

Possible causes include:

* missing required measurement signals;
* insufficient observation coverage;
* incomplete measurement window;
* malformed source payload;
* unavailable system result;
* stale evidence;
* incompatible measurement version.

Conceptually:

```text
insufficient evidence
≠
CLEAR
```

AI Weather MUST therefore prefer:

```text
INSUFFICIENT_DATA
```

over silently assigning a reassuring weather condition.

---

## 12. No single-signal weather rule

AI Weather MUST NOT use rules equivalent to:

```text
if stability_score is high:
    CLEAR
```

or:

```text
if G is high:
    CLEAR
```

or:

```text
if decision == ALLOW:
    CLEAR
```

or:

```text
if factual_alert == 0:
    CLEAR
```

The weather state MUST result from the profile-defined combination of the required measurement dimensions.

---

## 13. Conflict handling

Conflicting measurement signals are expected.

Example:

```text
runtime stability = high
decision          = ALLOW
factual signal    = elevated
```

This MUST NOT automatically be treated as an internal inconsistency.

It may represent:

```text
stable generation
+
factual weakness
```

AI Weather MUST preserve the semantic dimensions of these signals and apply explicit precedence or interpretation rules.

No conflict resolution rule may be reverse-engineered from incidental correlations in one experimental dataset.

---

## 14. Interpretation drivers

Each generated weather condition SHOULD expose the signals that materially contributed to the interpretation.

Example:

```json
{
  "condition": "WATCH",
  "drivers": [
    "factual_signal_elevated",
    "runtime_stability_high"
  ]
}
```

Another example:

```json
{
  "condition": "UNSETTLED",
  "drivers": [
    "flag_rate_elevated",
    "delta_profile_drop",
    "longitudinal_deterioration"
  ]
}
```

Drivers improve transparency without collapsing the underlying measurements into a single opaque score.

---

## 15. No universal scalar weather score

AI Weather v0.1 does not define a universal scalar equation such as:

```text
WeatherScore = aG + bF + cC + dCoverage
```

unless such a transformation is separately validated, documented, versioned, and justified.

A weighted average may hide a strongly degraded signal behind several favorable signals.

AI Weather therefore prefers an explicit **multi-signal interpretation matrix** over an opaque scalar aggregation.

---

## 16. Threshold policy

AI Weather MUST NOT infer official thresholds from exploratory NeoMundi studies.

Any numerical threshold used to derive a weather condition MUST be explicitly documented within the interpretation profile or a versioned dependency.

Where relevant, a threshold SHOULD identify:

```text
metric_version
normalizer_version
model scope
task scope
protocol version
threshold value
threshold semantics
```

Thresholds MAY initially remain experimental.

They MUST NOT be represented as universal NeoMundi thresholds unless formally promoted into the corresponding NeoMundi contract.

---

## 17. Coverage boundary

AI Weather conclusions apply only to the measured domain.

Principle:

> Absence of evidence is only meaningful over the measured domain.

Therefore:

```text
no factual alert observed
```

is meaningful only if the factual signal was actually measured with sufficient coverage.

Similarly:

```text
no runtime degradation observed
```

is meaningful only over the applicable observation window.

AI Weather MUST preserve the distinction between:

```text
MEASURED + NO_SIGNAL
```

and:

```text
NOT_MEASURED / INSUFFICIENT_COVERAGE
```

---

## 18. Temporal boundary

Every AI Weather condition is bound to a specific observation window.

A weather state from a previous day MUST NOT automatically describe the current runtime state.

Where previous conditions are carried forward for interface continuity, the resulting output MUST retain sufficient metadata to distinguish:

```text
new measurement
```

from:

```text
carried-forward previous state
```

A carried-forward state MUST NOT silently appear as a newly measured state.

---

## 19. Model-centric public representation

AI Weather public releases are model-centric.

The public capsule MAY expose:

```text
model
model_display
public_label
condition
score
observations
fully_scored
coverage
metrics
regime_distribution
previous_condition
last_observed_at
prompt_set
```

Provider-oriented internal plumbing SHOULD NOT be necessary for public interpretation.

Fields such as:

```text
provider_slug
source_file
internal runner identifier
local path
secret configuration
```

SHOULD remain outside the public capsule unless a future provenance requirement explicitly justifies their publication.

---

## 20. Capsule integration

A daily AI Weather capsule SHOULD preserve both:

1. the underlying measurement outputs;
2. the interpretation profile used to derive the weather state.

Conceptual structure:

```json
{
  "measurement": {
    "...": "observed signals"
  },
  "interpretation": {
    "profile": "AI_WEATHER_INTERPRETATION",
    "profile_version": "0.1",
    "condition": "WATCH",
    "drivers": [
      "factual_signal_elevated"
    ]
  }
}
```

The interpretation object MUST NOT replace the underlying measurements.

---

## 21. Required version references

Each public capsule SHOULD identify sufficient information to reproduce its interpretation.

At minimum:

```text
capsule_schema_version
measurement_contract_version
interpretation_profile_version
measurement_protocol_version
```

Where applicable:

```text
metric_version
normalizer_version
```

Changes to interpretation logic require a new profile version.

Historical capsules MUST NOT be silently recomputed under a new interpretation profile.

---

## 22. Public rendering boundary

The capsule is the canonical machine-readable daily object.

Other products MAY derive from it:

```text
AI Weather Wall
newsletter
X / Twitter publication
LinkedIn publication
widgets
daily summaries
partner integrations
historical datasets
longitudinal analysis
```

These renderings MAY simplify or summarize the capsule.

They MUST NOT silently modify its underlying measurements.

---

## 23. Example interpretation cases

### Case A — Stable and no adverse complementary signal

```text
runtime stability      = high
runtime variation      = low
factual-risk signal    = low
coverage               = sufficient
longitudinal change    = limited
```

Possible interpretation:

```text
CLEAR
```

---

### Case B — Stable but factual-risk signal emerging

```text
runtime stability      = high
factual-risk signal    = elevated
coverage               = sufficient
```

Possible interpretation:

```text
WATCH
```

or:

```text
UNSETTLED
```

depending on the versioned factual-risk rule.

It MUST NOT automatically remain CLEAR.

---

### Case C — Stable but materially factually degraded

```text
runtime stability      = high
factual-risk signal    = materially elevated
```

Interpretation concept:

```text
deceptive stability
```

Possible weather state:

```text
UNSETTLED
```

---

### Case D — Runtime degradation

```text
delta_profile = DROP
FLAG activity = elevated
```

Possible weather state:

```text
UNSETTLED
```

subject to the applicable versioned interpretation rule.

---

### Case E — Missing measurement

```text
required measurement unavailable
```

Weather state:

```text
INSUFFICIENT_DATA
```

Not:

```text
CLEAR
```

---

## 24. Implementation principle

The weather interpretation SHOULD be computed before capsule publication.

Recommended runtime path:

```text
AI Weather runners
        ↓
raw observations
        ↓
NeoMundi scoring / measurement
        ↓
daily aggregation
        ↓
AI Weather Interpretation Profile v0.1
        ↓
daily weather condition
        ↓
capsule generation
        ↓
hash-chain
        ↓
public release
```

The capsule generator SHOULD record the already-derived interpretation.

It SHOULD NOT independently invent or duplicate interpretation rules.

---

## 25. Experimental status

AI Weather Interpretation Profile v0.1 is experimental.

Its purpose is to provide:

* an explicit interpretation boundary;
* reproducible public weather states;
* traceability between measurement and rendering;
* a practical implementation surface for ongoing NeoMundi standardization;
* empirical feedback for future revisions of the NeoMundi Metric Contract.

The profile MAY evolve as additional runtime evidence is collected.

Any material interpretation change MUST produce a new profile version.

---

## 26. Canonical principle

AI Weather follows this rule:

```text
Measure multiple dimensions.
Preserve their meaning.
Interpret them explicitly.
Publish the interpretation with provenance.
Never let one favorable signal hide another degraded signal.
```

Or more compactly:

> **The weather condition is derived from a set of observed signals, never from a single metric.**

---

## 27. Current v0.1 freeze boundary

This v0.1 document freezes the **interpretation architecture**, not yet all numerical thresholds.

Frozen in v0.1:

* multi-signal interpretation;
* separation between measurement and weather condition;
* distinction between stability and factuality;
* explicit treatment of signal conflicts;
* coverage boundary;
* temporal boundary;
* `CLEAR`;
* `WATCH`;
* `UNSETTLED`;
* `ALERT`;
* `INSUFFICIENT_DATA`;
* interpretation drivers;
* versioned interpretation profile;
* prohibition on single-signal weather classification.

Not yet frozen:

* official numerical boundaries between CLEAR / WATCH / UNSETTLED;
* model-specific thresholds;
* task-specific thresholds;
* ALERT severity threshold;
* longitudinal drift thresholds;
* any universal scalar weather score.

These elements require empirical validation and explicit versioning before becoming normative within AI Weather.

---

**NeoMundi AI Weather**
Runtime measurement → multi-signal interpretation → public weather state
