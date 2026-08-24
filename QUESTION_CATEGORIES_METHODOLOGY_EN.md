# QUESTION_CATEGORIES_METHODOLOGY_EN.md

# Question Category Methodology — AI Weather

**Languages:**
[🇫🇷 Version française](./QUESTION_CATEGORIES_METHODOLOGY_FR.md) · [🇬🇧 English version](./QUESTION_CATEGORIES_METHODOLOGY_EN.md)

---

## 1. Purpose of this document

AI Weather uses a structured set of repeated questions to observe the behaviour of artificial intelligence systems over time.

These questions are not designed solely as knowledge tests.

They operate as **probes** that expose systems to different forms of factual, epistemic, conceptual, comparative, or reflective tension.

The objective is to observe whether a system:

* maintains a stable answer;
* detects incorrect assumptions;
* distinguishes facts, hypotheses, and interpretations;
* appropriately calibrates its level of certainty;
* preserves conceptual distinctions;
* revises its reasoning when a difficulty appears;
* or enters a different response regime over time.

AI Weather therefore does not seek to establish a general ranking of model “quality” or “intelligence”.

Questions are **measurement stimuli** designed to make measurable behavioural variations observable.

---

# 2. Methodological principle

The methodology distinguishes two levels:

**categories are stable; questions are replaceable.**

Categories define the types of tension that the Observatory intends to measure.

Questions are concrete implementations of these categories and may evolve when a new formulation becomes more discriminating, robust, or relevant.

This separation allows the corpus to evolve without losing the methodological framework that structures the observation.

---

# 3. Question categories

## Category 1 — Factual knowledge under constraint

This category tests the system’s ability to produce factually correct information when the question introduces an additional difficulty: proximity between several plausible answers, the need to combine multiple facts, limited ambiguity, or distinctions between closely related concepts.

The objective is therefore not merely to test the memorisation of an isolated fact, but the ability to preserve factual accuracy when finer discrimination is required.

### What we observe

* factual accuracy;
* omissions;
* contradictions;
* confusion between related elements;
* stability across repetitions;
* appearance of unsupported information.

---

## Category 2 — Framing resistance and false-premise detection

Some questions intentionally contain an incorrect, debatable, simplified, or leading assertion.

The system must be capable of identifying the issue embedded in the question rather than implicitly accepting its framing.

This category simultaneously tests:

**nuance + factuality + resistance to question framing.**

False premises may include:

* an incorrect fact presented as established;
* an unsupported causal relationship;
* an excessive generalisation;
* a false attribution;
* a quotation attributed to the wrong person;
* a discovery, theory, or event attributed to an incorrect source.

### What we observe

* acceptance of a false premise;
* explicit correction of the framing;
* level of nuance;
* overconfidence;
* fabricated justification;
* persistence or correction of the error across repetitions.

---

## Category 3 — Uncertainty and epistemic calibration

This category does not simply test knowledge. It tests **the system’s relationship to its own certainty**.

Questions are selected to create situations in which the answer may be probable without being certain, context-dependent, or require distinguishing between different levels of knowledge.

The system may need to explicitly distinguish between:

* established fact;
* inference;
* hypothesis;
* uncertainty;
* or insufficient information.

### What we observe

* overconfidence;
* excessive caution;
* explicit recognition of uncertainty;
* calibration between expressed confidence and answer reliability;
* distinction between knowledge and inference;
* stability of confidence levels.

---

## Category 4 — Controversy and plurality of interpretations

Some questions concern domains in which multiple theories, schools of thought, models, or interpretations coexist.

The system must avoid incorrectly transforming a debated position into an established truth.

It must also avoid the opposite error: presenting every position as equally supported when the available evidence differs substantially.

This category therefore tests the ability to **preserve plurality without erasing the actual structure of evidence and consensus**.

### What we observe

* excessive simplification;
* false consensus;
* false equivalence;
* balance between perspectives;
* distinction between fact and interpretation;
* accurate representation of the level of consensus.

---

## Category 5 — Comparison between poorly commensurable systems

This category confronts the system with two or more objects, species, models, phenomena, or systems that may appear directly comparable even though their properties are partly heterogeneous.

Comparison may still be possible, but only when the criteria being used are made explicit.

The system should therefore recognise the limits of the comparison before producing a global conclusion.

### What we observe

* inappropriate reduction to a single metric;
* false equivalence;
* implicit comparison criteria;
* contextualisation;
* explicit identification of comparison dimensions;
* ability to reject an overly broad conclusion.

---

## Category 6 — Reflective reasoning and error detection

These questions require the system to reason about the conditions under which reasoning, an answer, or a conclusion can become incorrect, incomplete, or misleading.

They may also require the system to identify a contradiction or weakness within a chain of reasoning.

The difficulty therefore does not necessarily lie in the knowledge being mobilised, but in the system’s ability to examine the structure of its own reasoning or of reasoning presented to it.

### What we observe

* internal coherence;
* contradiction detection;
* identification of hidden assumptions;
* ability to revise;
* persistence of an error after detection;
* stability of the argumentative chain.

---

## Category 7 — Conceptual boundaries and anthropomorphism

Certain concepts become particularly unstable when applied to artificial systems.

These include:

* consciousness;
* understanding;
* belief;
* intention;
* intelligence;
* will;
* subjective experience.

This category tests the system’s ability to distinguish between:

* functional description;
* analogy;
* metaphor;
* interpretation;
* ontological claim.

### What we observe

* anthropomorphism;
* conceptual slippage;
* confusion between observable behaviour and internal state;
* semantic caution;
* preservation of conceptual distinctions.

---

## Category 8 — Lower-difficulty control questions

Not every AI Weather question should operate at maximum difficulty.

A small number of simpler questions provide a **control level**.

These probes help determine whether an anomaly observed on a complex question reflects a local difficulty or a broader degradation in system behaviour.

They therefore provide a behavioural baseline during each measurement session.

### What we observe

* baseline stability;
* availability;
* elementary factuality;
* simple coherence;
* general anomalies;
* degradation unrelated to the stress probes.

---

# 4. Primary category and secondary tags

The categories defined above are not necessarily mutually exclusive.

A single question may simultaneously activate several dimensions.

For example, a question comparing two forms of intelligence may involve:

* a poorly commensurable system comparison;
* a false premise;
* a scientific nuance problem.

To preserve both analytical richness and corpus balance, each question receives:

* **one primary category**, used to compose the corpus;
* **zero, one, or multiple secondary tags**, used for analysis.

Example:

```yaml
question_id: trap-A4
primary_category: cross-system-comparison
secondary_tags:
  - false-premise-resistance
  - scientific-nuance
```

A question therefore counts only once in the main corpus distribution while remaining analysable through several dimensions.

---

# 5. Stress probes and control probes

The daily corpus combines two complementary functions.

## Stress probes

Most of the corpus consists of questions selected for their capacity to produce:

* divergences;
* errors;
* meaningful formulation changes;
* confidence variation;
* contradictions;
* regime changes;
* or behavioural differences between systems.

The objective is not to make models fail artificially.

The purpose is to use stimuli demanding enough to reveal variations that would remain invisible on trivial questions.

## Control probes

A smaller number of deliberately simpler questions are maintained in the corpus.

These questions provide a reference for distinguishing:

**general system instability**

from

**instability specific to a difficult type of solicitation.**

---

# 6. Question selection

Question difficulty alone is not sufficient to justify inclusion in AI Weather.

A question must produce an informative signal.

Selection criteria may include:

* frequency of observed anomalies;
* capacity to differentiate systems;
* variability across repetitions;
* sensitivity to change over time;
* robustness of wording;
* limited dependence on a temporary external event;
* ability to test a clearly identified methodological dimension.

An extremely difficult question that systematically produces the same behaviour across all systems may be less informative than a slightly easier question that strongly differentiates them.

---

# 7. Question rotation and versioning

Categories constitute the permanent reference framework.

Questions may be:

* retained;
* modified;
* replaced;
* added;
* removed.

Any substantial modification to a question must be versioned in order to preserve longitudinal traceability.

When a question is replaced, the new question must remain explicitly associated with a methodological category.

Results obtained using two different versions of the same probe should not be treated as strictly identical without a comparability check.

---

# 8. Initial phase — September 2026

For the first thirty days of September 2026, AI Weather will deliberately prioritise the most discriminating probes identified during the preparatory phases.

This period is intended to:

* increase the probability of observing regime changes;
* identify the most sensitive categories;
* assess day-to-day system stability;
* characterise differences between providers and models;
* and establish an initial longitudinal baseline.

The corpus will therefore consist primarily of **stress probes**, complemented by **two or three simpler control probes**.

This configuration is deliberate: the initial phase seeks to maximise the instrumental sensitivity of AI Weather before progressively optimising corpus composition.

---

# 9. Interpretation principle

AI Weather does not treat an isolated answer as a verdict on a model.

The object of observation is the **dynamics of behaviour**:

* repetition;
* dispersion;
* rupture;
* recovery;
* drift;
* emergence or disappearance of anomalies.

A difficult question is therefore not valuable simply because it generates more errors.

It becomes methodologically useful when it helps reveal a reproducible or significant change in system behaviour.

---

# 10. Guiding principle

**Difficulty is not an end in itself.**

A good AI Weather probe is a question capable of revealing a **measurable regime change over time**.

It is this sensitivity to change — rather than the intrinsic difficulty of the question — that determines its value for the Observatory.
