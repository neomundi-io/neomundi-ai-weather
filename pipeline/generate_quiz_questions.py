#!/usr/bin/env python3
"""
generate_quiz_questions.py — "Spot the Drift" candidate extractor
NeoMundi / AI Weather by ControlTowerAI

Finds same-question, different-answer pairs in the daily sentinel panel and
writes them out as candidate material for the quiz-full / quiz-daily widgets
(widgets/quiz/, quiz-engine.js — see Step 3).

DATA SOURCE NOTE (read before changing paths)
-----------------------------------------------------------------------------
The original spec for this script pointed at
aiweather-capsule/capsules/2026/*/*.json and data/history/*.json. Neither
contains what this script needs:

  - capsules/*.json are per-system AGGREGATES for the day (one score, one
    condition, one interoperability_contracts *list of file paths*) — they
    do not carry per-repetition response text.
  - The interoperability contracts those paths point to
    (aiweather-capsule/interoperability/<date>/<provider>-<request_id>.json)
    are the machine-readable ENF artifacts. They are DELIBERATELY stripped of
    raw content: "Provider/model identity is pseudonymized in this contract
    and cannot be reversed to the original value" (see any contract's
    observation.limitations). No llm_response field exists there.

The actual per-repetition text — and the full per-repetition signal set
(stability_score, coherence_score, factual_hallucination_score, decision,
g_final, delta_g, ...) — lives one stage upstream, in the runner output:

    AI_WEATHER_RUNNER/results/<YYYY-MM-DD>/<provider>_<model>_..._results.jsonl

This script reads THAT as its primary source. Capsules are still read, but
only for capsule_id (provenance/citation), and weather.json is read only for
public-identity resolution (see resolve_identities below). If capsules ever
gain per-repetition text, capsule_date/capsule_id here already line up and
the results.jsonl reads become redundant rather than wrong.

DAILY vs LONGITUDINAL
-----------------------------------------------------------------------------
Every capsule's interpretation_boundaries/rendering_metadata mark the
longitudinal probe as lab-only and "not_exposed" on the public wall
("longitudinal_probe": "Laboratory-only fixed stimulus; never influences
daily Weather or Judgment Demand"). This script honors that boundary: only
prompt_id values starting with "daily-" are eligible. longitudinal-* rows
are read (to correctly split groups) but never surfaced as quiz material.

WHAT COUNTS AS "DRIFT" HERE
-----------------------------------------------------------------------------
A pair only qualifies if NeoMundi's own measurement disagreed with itself
across repetitions of the identical prompt: either the decision differed
(ALLOW vs FLAG) or the stability_score spread crossed --stability-threshold.
Rows where the runner itself errored (decision == "ERROR", empty
llm_response) are dropped before any of this — that is a pipeline failure,
not an observed behavioral divergence, and must never be presented to a user
as "the AI changed its answer".
"""

import argparse
import json
import re
import statistics
from datetime import datetime, timezone
from pathlib import Path

DATE_DIR_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DAILY_PROMPT_PREFIX = "daily-"
LONGITUDINAL_PROMPT_PREFIX = "longitudinal-"

# jsonl "provider" values that differ from the public weather.json system id
# they should resolve to. The only known case: Meta/Llama is served via the
# Together.ai API, so the runner writes provider="together", but the public
# system id (and the id data/history + weather.json already use) is "meta".
PROVIDER_TO_SYSTEM_ID = {
    "together": "meta",
}

MIN_RESPONSE_CHARS = 40
DEFAULT_STABILITY_THRESHOLD = 0.15
DEFAULT_POOL_SIZE = 50

# A garbled/refusal-shaped non-answer tends to be a drastic length outlier
# versus its own group's other repetitions (empirically ~5x shorter in the
# one real case found in this pool: 145 chars vs a 2931-char median-sibling
# answer), whereas two genuinely different but complete answers to the same
# terse-answer prompt land much closer together (the closest real case in
# this pool sits at ~40% of its sibling, e.g. 728 vs 1794 chars). 0.2 sits
# with margin on both sides of that gap without needing per-prompt tuning.
MIN_LENGTH_RATIO = 0.2

SIGNAL_METRIC_FIELDS = [
    "stability_score",
    "coherence_score",
    "factual_hallucination_score",
    "semantic_instability_score",
    "semantic_risk",
    "g_final",
    "delta_g",
]


# ---------------------------------------------------------------------------
# I/O helpers (same tolerant loader as generate_capsule.py — PowerShell
# writes UTF-8 with BOM)
# ---------------------------------------------------------------------------

def load_json_file(path: Path):
    text = path.read_text(encoding="utf-8-sig")
    return json.loads(text)


def load_jsonl_file(path: Path):
    rows = []
    with path.open(encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


# ---------------------------------------------------------------------------
# Public identity resolution — mirrors scripts/weather-data.js
# NMData.getPublicIdentity() field priority exactly, so a provider never
# shows a raw internal model string here that the live widgets wouldn't
# also show.
# ---------------------------------------------------------------------------

def resolve_identities(weather_json_path: Path):
    identities = {}
    if not weather_json_path.exists():
        return identities

    data = load_json_file(weather_json_path)
    for system in data.get("systems", []):
        if not isinstance(system, dict):
            continue
        system_id = system.get("id")
        if not system_id:
            continue

        provider = system.get("provider_display") or system.get("provider") or ""

        label = None
        if system.get("model_display"):
            label = system["model_display"]
        elif system.get("model_public") is not None:
            label = system["model_public"]
        elif system.get("public_label"):
            label = system["public_label"]
        elif system.get("model"):
            label = system["model"]

        identities[system_id] = {"provider": provider, "label": label}

    return identities


def resolve_system_id(provider_slug: str) -> str:
    return PROVIDER_TO_SYSTEM_ID.get(provider_slug, provider_slug)


# ---------------------------------------------------------------------------
# Capsule lookup — capsule_id only (see module docstring)
# ---------------------------------------------------------------------------

def load_capsule_id(capsules_dir: Path, date_str: str):
    year, month, day = date_str.split("-")
    capsule_path = capsules_dir / year / month / f"{day}.json"
    if not capsule_path.exists():
        return None
    try:
        capsule = load_json_file(capsule_path)
    except (json.JSONDecodeError, OSError):
        return None
    return capsule.get("capsule_id")


# ---------------------------------------------------------------------------
# Result folders
# ---------------------------------------------------------------------------

def find_result_dirs(results_root: Path):
    if not results_root.exists():
        return []
    dirs = [
        p for p in results_root.iterdir()
        if p.is_dir() and DATE_DIR_RE.match(p.name)
    ]
    return sorted(dirs, key=lambda p: p.name)


def load_date_rows(date_dir: Path):
    """All rows from every *_results.jsonl directly under date_dir, each
    tagged with a resolved system_id. Debug subfolders (debug_*) contain no
    *_results.jsonl themselves so the flat glob already skips them."""
    rows = []
    for jsonl_path in sorted(date_dir.glob("*_results.jsonl")):
        try:
            file_rows = load_jsonl_file(jsonl_path)
        except (json.JSONDecodeError, OSError):
            continue
        for row in file_rows:
            provider = row.get("provider") or ""
            row["_system_id"] = resolve_system_id(provider)
            rows.append(row)
    return rows


# ---------------------------------------------------------------------------
# Simple, dependency-free textual divergence
#
# Word-level Jaccard rather than character-level diff: LLM prose answering
# the same question but paraphrased throughout scores misleadingly low on
# character-sequence similarity even when the underlying claim is identical.
# Jaccard over the token set is a coarser but more legible proxy for "would
# a non-expert reader notice these say different things".
# ---------------------------------------------------------------------------

def word_set(text: str):
    return set(re.findall(r"[\w']+", (text or "").lower()))


def jaccard_similarity(text_a: str, text_b: str) -> float:
    set_a, set_b = word_set(text_a), word_set(text_b)
    if not set_a and not set_b:
        return 1.0
    if not set_a or not set_b:
        return 0.0
    return len(set_a & set_b) / len(set_a | set_b)


# ---------------------------------------------------------------------------
# Candidate extraction
# ---------------------------------------------------------------------------

def usable_rows(rows):
    """Drop pipeline failures — an ERROR decision or empty response is a
    runner/API failure, not an observed behavioral divergence."""
    out = []
    for row in rows:
        if row.get("decision") == "ERROR":
            continue
        text = (row.get("llm_response") or "").strip()
        if len(text) < MIN_RESPONSE_CHARS:
            continue
        if row.get("stability_score") is None:
            continue
        out.append(row)
    return out


def group_by_prompt(rows):
    groups = {}
    for row in rows:
        prompt_id = row.get("prompt_id") or ""
        if not prompt_id.startswith(DAILY_PROMPT_PREFIX):
            # Includes skipping longitudinal-* on purpose — lab-only probe,
            # never publicly exposed. See module docstring.
            continue
        key = (row["_system_id"], prompt_id)
        groups.setdefault(key, []).append(row)
    return groups


def filter_degenerate_rows(rows):
    """Drop responses that are a drastic length outlier against their own
    group's median. This targets garbled/refusal-shaped non-answers (an API
    hiccup that still returned SOME text, so usable_rows()'s MIN_RESPONSE_CHARS
    floor doesn't catch it) — not genuinely concise answers, which stay close
    to their group's median even when short. See MIN_LENGTH_RATIO above for
    the empirical basis of the threshold."""
    lengths = [len(r.get("llm_response") or "") for r in rows]
    if len(lengths) < 2:
        return rows

    median_length = statistics.median(lengths)
    if median_length <= 0:
        return rows

    return [
        r for r in rows
        if len(r.get("llm_response") or "") >= MIN_LENGTH_RATIO * median_length
    ]


def pick_extreme_pair(rows):
    """The two repetitions that bracket the observed stability_score range
    for this prompt: the most-stable-looking answer and the least. This is
    the pair most likely to make a concrete, explainable point ("here's a
    confident-looking answer to the same question, here's a flagged one")
    rather than two arbitrary repetitions."""
    ranked = sorted(rows, key=lambda r: r["stability_score"])
    return ranked[-1], ranked[0]  # (highest stability, lowest stability)


def build_delta_profile(response_a, response_b):
    delta = {}
    for field in SIGNAL_METRIC_FIELDS:
        value_a = response_a.get(field)
        value_b = response_b.get(field)
        if isinstance(value_a, (int, float)) and isinstance(value_b, (int, float)):
            delta[field] = round(value_b - value_a, 6)
        else:
            delta[field] = None
    return delta


def build_response_record(row):
    return {
        "request_id": row.get("request_id"),
        "repetition_index": row.get("repetition_index"),
        "api_timestamp": row.get("api_timestamp"),
        "decision": row.get("decision"),
        "text": (row.get("llm_response") or "").strip(),
        "stability_score": row.get("stability_score"),
        "coherence_score": row.get("coherence_score"),
        "factual_hallucination_score": row.get("factual_hallucination_score"),
        "semantic_instability_score": row.get("semantic_instability_score"),
        "g_final": row.get("g_final"),
        "delta_g": row.get("delta_g"),
    }


def build_candidates(date_str: str, rows, identities, capsule_id, stability_threshold):
    candidates = []
    usable = usable_rows(rows)

    for (system_id, prompt_id), group_rows in group_by_prompt(usable).items():
        group_rows = filter_degenerate_rows(group_rows)
        if len(group_rows) < 2:
            continue

        decisions = {r.get("decision") for r in group_rows}
        stability_scores = [r["stability_score"] for r in group_rows]
        stability_range = max(stability_scores) - min(stability_scores)
        decision_mismatch = len(decisions) > 1

        if not decision_mismatch and stability_range < stability_threshold:
            continue  # not a divergence, just normal run-to-run noise

        response_a, response_b = pick_extreme_pair(group_rows)
        text_similarity = jaccard_similarity(
            response_a.get("llm_response"), response_b.get("llm_response")
        )

        priority_score = (
            (2.0 if decision_mismatch else 0.0)
            + stability_range
            + (1.0 - text_similarity)
        )

        identity = identities.get(system_id, {"provider": system_id, "label": None})

        candidates.append({
            "capsule_date": date_str,
            "capsule_id": capsule_id,
            "prompt_id": prompt_id,
            "system_id": system_id,
            "identity": identity,
            "divergence_score": round(priority_score, 4),
            "signal": {
                "decision_mismatch": decision_mismatch,
                "decisions_observed": sorted(d for d in decisions if d),
                "stability_score_min": round(min(stability_scores), 6),
                "stability_score_max": round(max(stability_scores), 6),
                "stability_score_range": round(stability_range, 6),
                "text_similarity": round(text_similarity, 4),
                "delta_profile": build_delta_profile(response_a, response_b),
            },
            "responses": [
                build_response_record(response_a),
                build_response_record(response_b),
            ],
        })

    candidates.sort(key=lambda c: c["divergence_score"], reverse=True)
    return candidates


# ---------------------------------------------------------------------------
# Pool merge
# ---------------------------------------------------------------------------

def candidate_key(candidate):
    ids = tuple(sorted(r.get("request_id") for r in candidate["responses"]))
    return (candidate["capsule_date"], candidate["system_id"], candidate["prompt_id"], ids)

def merge_pool(existing_pool, new_candidates, pool_size):
    seen = set()
    merged = []

    for candidate in list(new_candidates) + list(existing_pool):
        key = candidate_key(candidate)
        if key in seen:
            continue
        seen.add(key)
        merged.append(candidate)

    merged.sort(key=lambda c: (c["capsule_date"], c["divergence_score"]), reverse=True)
    return merged[:pool_size]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description=(
            "Extract same-prompt / different-answer candidate pairs from the "
            "AI Weather runner output, for the 'Spot the Drift' quiz."
        )
    )
    parser.add_argument(
        "--date", type=str, default=None,
        help=(
            "Process only this date's results (YYYY-MM-DD) and merge into the "
            "existing pool. Default: backfill — scan every date folder found "
            "under --results-root and rebuild the pool from scratch."
        ),
    )
    parser.add_argument("--repo-root", type=str, default=None, help="Repo root. Default: parent of this script's directory.")
    parser.add_argument("--results-root", type=str, default=None, help="Default: <repo-root>/AI_WEATHER_RUNNER/results")
    parser.add_argument("--capsules-dir", type=str, default=None, help="Default: <repo-root>/aiweather-capsule/capsules")
    parser.add_argument("--weather-json", type=str, default=None, help="Default: <repo-root>/weather.json")
    parser.add_argument("--out-dir", type=str, default=None, help="Default: <repo-root>/quiz-data")
    parser.add_argument("--pool-size", type=int, default=DEFAULT_POOL_SIZE)
    parser.add_argument("--stability-threshold", type=float, default=DEFAULT_STABILITY_THRESHOLD)
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = Path(args.repo_root).resolve() if args.repo_root else script_dir.parent

    results_root = Path(args.results_root).resolve() if args.results_root else repo_root / "AI_WEATHER_RUNNER" / "results"
    capsules_dir = Path(args.capsules_dir).resolve() if args.capsules_dir else repo_root / "aiweather-capsule" / "capsules"
    weather_json_path = Path(args.weather_json).resolve() if args.weather_json else repo_root / "weather.json"
    out_dir = Path(args.out_dir).resolve() if args.out_dir else repo_root / "quiz-data"
    out_dir.mkdir(parents=True, exist_ok=True)

    identities = resolve_identities(weather_json_path)

    if args.date:
        date_dirs = [results_root / args.date]
        if not date_dirs[0].is_dir():
            raise FileNotFoundError(f"No results folder for {args.date}: {date_dirs[0]}")
    else:
        date_dirs = find_result_dirs(results_root)
        if not date_dirs:
            raise FileNotFoundError(f"No dated result folders found under {results_root}")

    all_new_candidates = []
    candidates_by_date = {}

    for date_dir in date_dirs:
        date_str = date_dir.name
        rows = load_date_rows(date_dir)
        capsule_id = load_capsule_id(capsules_dir, date_str)
        day_candidates = build_candidates(date_str, rows, identities, capsule_id, args.stability_threshold)
        candidates_by_date[date_str] = day_candidates
        all_new_candidates.extend(day_candidates)
        print(f"[OK] {date_str}: {len(rows)} rows scanned, {len(day_candidates)} divergence candidate(s)")

    pool_path = out_dir / "drift-pool.json"
    daily_path = out_dir / "daily-drift.json"

    if args.date and pool_path.exists():
        existing_pool = load_json_file(pool_path).get("pool", [])
    else:
        existing_pool = []

    pool = merge_pool(existing_pool, all_new_candidates, args.pool_size)

    pool_payload = {
        "schema_version": "quiz-drift-pool-0.1",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "pool_size": len(pool),
        "pool": pool,
    }
    pool_path.write_text(
        json.dumps(pool_payload, indent=2, ensure_ascii=False, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    print(f"[OK] Pool written: {pool_path} ({len(pool)} entries)")

    # "daily" = best candidate from the most recent date that has at least
    # one qualifying candidate, not necessarily the most recent date overall
    # (a fully-consistent day is possible and should not crash the widget).
    daily_entry = None
    for date_str in sorted(candidates_by_date.keys(), reverse=True):
        if candidates_by_date[date_str]:
            daily_entry = candidates_by_date[date_str][0]
            break

    if daily_entry is None and pool:
        daily_entry = pool[0]  # fallback: most recent pool entry overall

    if daily_entry is None:
        print("[WARN] No divergence candidate available for daily-drift.json — leaving previous file, if any, untouched.")
    else:
        daily_payload = {
            "schema_version": "quiz-daily-drift-0.1",
            "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
            "entry": daily_entry,
        }
        daily_path.write_text(
            json.dumps(daily_payload, indent=2, ensure_ascii=False, sort_keys=False) + "\n",
            encoding="utf-8",
        )
        print(f"[OK] Daily drift written: {daily_path}")
        print(f"     date       = {daily_entry['capsule_date']}")
        print(f"     system_id  = {daily_entry['system_id']}")
        print(f"     score      = {daily_entry['divergence_score']}")


if __name__ == "__main__":
    main()
