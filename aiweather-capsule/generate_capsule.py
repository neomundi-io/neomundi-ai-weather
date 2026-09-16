#!/usr/bin/env python3
"""
generate_capsule.py — AI Weather Capsule Engine (RECONSTRUCTED v0.2)
NeoMundi / AI Weather by ControlTowerAI

This file is a reconstruction, not a recovered original. The original v0.2
generator (used to produce capsules/2026/08/21.json and 22.json) was lost
and not found in any of the repository's .zip backups. This version was
derived by reverse-engineering the exact schema of those two real capsules,
field by field against their source data/history/*.json files, then
validated on 2026-08-23 with an isolated dry-run: same top-level keyset,
same coverage/observations sub-schema, real (non-placeholder)
interpretation_boundaries/rendering_metadata/signature, and a clean
verify_chain.py pass across a copy of the real 17/21/22 chain plus the
dry-run capsule.
"""

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_VERSION = "0.2"
SCHEMA_VERSION_V2 = "2.0"
SOURCE_FORMAT = "ai_weather_history_v0.2"

INTERPRETATION_BOUNDARIES = {
    "daily_probe": "Weather-authoritative daily stimulus; drives interpretation and Judgment Demand upstream",
    "execution": "consumer responsibility",
    "interpretation": "AI Weather Interpretation Profile",
    "judgment_demand": "AI Weather Judgment Demand Profile",
    "longitudinal_probe": "Laboratory-only fixed stimulus; never influences daily Weather or Judgment Demand",
    "measurement": "NeoMundi measurement signals",
    "principle": "Measurement != Interpretation != Judgment Demand != Action",
}

RENDERING_METADATA = {
    "daily_question_visibility": "public",
    "longitudinal_question_visibility": "not_exposed",
    "longitudinal_visibility": "lab_only",
    "wall_source": "daily_probe_only",
}

SIGNATURE = "reserved_for_future_version"


# ---------------------------------------------------------------------------
# Canonical JSON / hash (identical contract to verify_chain.py)
# ---------------------------------------------------------------------------

def canonical_json_bytes(obj: dict) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def compute_content_hash(capsule: dict) -> str:
    capsule_copy = json.loads(json.dumps(capsule, ensure_ascii=False))
    capsule_copy.setdefault("chain", {}).pop("content_hash", None)
    return hashlib.sha256(canonical_json_bytes(capsule_copy)).hexdigest()


# ---------------------------------------------------------------------------
# Robust JSON loader (PowerShell writes UTF-8 with BOM)
# ---------------------------------------------------------------------------

def load_json_file(path: Path) -> dict:
    text = path.read_text(encoding="utf-8-sig")
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError(f"Root JSON value must be an object: {path}")
    return data


# ---------------------------------------------------------------------------
# Existing capsules
# ---------------------------------------------------------------------------

def find_all_capsules(capsules_dir: Path):
    files = sorted(capsules_dir.glob("*/*/*.json"))
    parsed = []
    for path in files:
        try:
            data = load_json_file(path)
            chain = data.get("chain", {})
            parsed.append((data.get("date", ""), chain.get("sequence_index", -1), path, data))
        except (json.JSONDecodeError, OSError, ValueError):
            continue
    parsed.sort(key=lambda item: (item[0], item[1]))
    return parsed


def find_previous_capsule(capsules_dir: Path):
    capsules = find_all_capsules(capsules_dir)
    if not capsules:
        return None
    return capsules[-1][3]


# ---------------------------------------------------------------------------
# V2 detection and additive projection (Bloc Jeudi, AI_WEATHER_V2_LAUNCH_PLAN_2026-09-21.md
# section 4). A source is treated as V2 only if it EXPLICITLY declares a complete V2
# methodology (methodology_version.id + repetition_count at top level). Today's real
# data/history/*.json files declare neither - they are legacy sources and produce byte-
# identical capsules to before this change. The longitudinal engine is NOT wired into
# data/history/*.json today (explicitly out of scope for this block) - so this code path
# is only exercised by test fixtures until that wiring happens, deliberately.
# ---------------------------------------------------------------------------

def source_declares_v2_methodology(raw: dict) -> bool:
    methodology = raw.get("methodology_version")
    return (
        isinstance(methodology, dict)
        and bool(methodology.get("id"))
        and raw.get("repetition_count") is not None
    )


def build_longitudinal_reference(longitudinal_block, weather_authority_value):
    """
    Additive V2 projection of the longitudinal probe's measurement, sibling to the
    legacy `longitudinal` key (never replaces it). Returns None - so the caller omits
    the key entirely rather than emit a block full of nulls - unless the source's
    `longitudinal` block already carries V2 fields (i.e. current_longitudinal_state).
    """
    if not isinstance(longitudinal_block, dict):
        return None
    if "current_longitudinal_state" not in longitudinal_block:
        return None

    return {
        "weather_authority": weather_authority_value,
        "repetition_count": longitudinal_block.get("repetition_count"),
        "current_longitudinal_state": longitudinal_block.get("current_longitudinal_state"),
        "score": longitudinal_block.get("score"),
        "deviation_index": longitudinal_block.get("deviation_index"),
        "baseline": longitudinal_block.get("baseline"),
        "uncertainty": longitudinal_block.get("uncertainty"),
        "coverage": longitudinal_block.get("coverage"),
        "detected_events": longitudinal_block.get("detected_events", []),
        "system_identity": longitudinal_block.get("system_identity"),
        "evidence_integrity": longitudinal_block.get("evidence_integrity"),
    }


def build_daily_challenge(daily_block):
    """
    Additive, explicitly non-authoritative mirror of the existing `daily` block,
    renamed for editorial clarity ("Today's Challenge"). Structurally a sibling key,
    never nested inside longitudinal_reference and never read by
    build_longitudinal_reference - the daily challenge can never determine the
    longitudinal state (AI_WEATHER_V2_LAUNCH_PLAN_2026-09-21.md section 2, principle).
    """
    if not isinstance(daily_block, dict):
        return None
    projected = dict(daily_block)
    projected["weather_authority"] = False
    return projected


# ---------------------------------------------------------------------------
# Per-system public projection (daily / longitudinal preserved, plumbing dropped)
# ---------------------------------------------------------------------------

def project_probe(role_block, weather_authority_value, rename_prompt_id_to=None):
    if not isinstance(role_block, dict):
        return role_block

    projected = dict(role_block)
    projected.pop("prompt_ids_observed", None)

    if rename_prompt_id_to and "prompt_id" in projected:
        projected[rename_prompt_id_to] = projected.pop("prompt_id")

    projected["weather_authority"] = weather_authority_value

    return projected


def build_public_model_record(system: dict, protocol: dict) -> dict:
    """
    Public, model-centric projection of one measured system.

    Internal provider plumbing (id, provider, provider_slug, provider_display,
    detail.source_file, detail.unknown_probe_rows) is deliberately excluded.
    Upstream interpretation and Judgment Demand are preserved, never recomputed.
    """

    detail = system.get("detail")
    if not isinstance(detail, dict):
        detail = {}

    protocol = protocol if isinstance(protocol, dict) else {}

    daily = project_probe(
        system.get("daily"),
        protocol.get("daily_weather_authority"),
    )

    longitudinal = project_probe(
        system.get("longitudinal"),
        protocol.get("longitudinal_weather_authority"),
        rename_prompt_id_to="probe_id",
    )

    record = {
        "model": system.get("model"),
        "model_display": system.get("model_display"),
        "model_public": system.get("model_public"),
        "public_label": system.get("public_label"),

        "condition": system.get("condition"),
        "judgment_demand": system.get("judgment_demand"),
        "score": system.get("score"),

        "observations": system.get("observations"),
        "expected_observations": system.get("expected_observations"),
        "fully_scored": system.get("fully_scored"),
        "coverage": system.get("coverage"),
        "coverage_status": system.get("coverage_status"),
        "total_coverage": system.get("total_coverage"),

        "metrics": system.get("metrics"),
        "interpretation": system.get("interpretation"),
        "last_observed_at": system.get("last_observed_at"),

        "previous_condition": detail.get("previous_condition"),
        "weather_authority": detail.get("weather_authority"),
        "longitudinal_influences_weather": detail.get("longitudinal_influences_weather"),

        # --- legacy keys, unchanged, kept for backward compatibility ---
        "daily": daily,
        "longitudinal": longitudinal,
    }

    # --- V2 additive projection: present only if the source's longitudinal block
    # already carries V2 fields (see build_longitudinal_reference) - absent entirely
    # for every capsule generated from today's real data/history/*.json files.
    longitudinal_reference = build_longitudinal_reference(
        system.get("longitudinal"),
        protocol.get("longitudinal_weather_authority"),
    )
    if longitudinal_reference is not None:
        record["longitudinal_reference"] = longitudinal_reference
        daily_challenge = build_daily_challenge(system.get("daily"))
        if daily_challenge is not None:
            record["daily_challenge"] = daily_challenge

    return record


# ---------------------------------------------------------------------------
# Panel-level coverage (passthrough of panel_summary + system-derived counts)
# ---------------------------------------------------------------------------

def compute_coverage(panel_summary: dict, systems: list) -> dict:
    if not isinstance(panel_summary, dict):
        panel_summary = {}

    systems_observed = 0
    systems_daily_fully_covered = 0
    systems_longitudinal_fully_covered = 0
    systems_fully_covered = 0

    for system in systems:
        if not isinstance(system, dict):
            continue

        top_coverage = system.get("coverage")
        total_coverage = system.get("total_coverage")
        daily_coverage = (system.get("daily") or {}).get("coverage")
        longitudinal_coverage = (system.get("longitudinal") or {}).get("coverage")

        try:
            if top_coverage is not None and float(top_coverage) > 0:
                systems_observed += 1
        except (TypeError, ValueError):
            pass

        try:
            if daily_coverage is not None and float(daily_coverage) >= 1:
                systems_daily_fully_covered += 1
        except (TypeError, ValueError):
            pass

        try:
            if longitudinal_coverage is not None and float(longitudinal_coverage) >= 1:
                systems_longitudinal_fully_covered += 1
        except (TypeError, ValueError):
            pass

        try:
            if total_coverage is not None and float(total_coverage) >= 1:
                systems_fully_covered += 1
        except (TypeError, ValueError):
            pass

    return {
        "daily_fully_scored": panel_summary.get("daily_fully_scored"),
        "daily_observations_expected": panel_summary.get("daily_observations_expected"),
        "daily_panel_coverage": panel_summary.get("daily_panel_coverage"),
        "last_measurement_at": panel_summary.get("last_measurement_at"),
        "longitudinal_fully_scored": panel_summary.get("longitudinal_fully_scored"),
        "longitudinal_observations_expected": panel_summary.get("longitudinal_observations_expected"),
        "longitudinal_panel_coverage": panel_summary.get("longitudinal_panel_coverage"),
        "panel_coverage": panel_summary.get("panel_coverage"),
        "systems_daily_fully_covered": systems_daily_fully_covered,
        "systems_expected": panel_summary.get("systems_expected"),
        "systems_fully_covered": systems_fully_covered,
        "systems_insufficient_data": panel_summary.get("systems_insufficient_data"),
        "systems_longitudinal_fully_covered": systems_longitudinal_fully_covered,
        "systems_observed": systems_observed,
        "total_expected_observations": panel_summary.get("total_expected_observations"),
        "total_observations": panel_summary.get("total_observations"),
    }


# ---------------------------------------------------------------------------
# AI Weather history normalization
# ---------------------------------------------------------------------------

def normalize_ai_weather_history(raw: dict) -> dict:
    panel_summary = raw.get("panel_summary", {})
    systems = raw.get("systems", [])
    protocol = raw.get("protocol", {})

    if not isinstance(panel_summary, dict):
        raise ValueError("'panel_summary' must be a JSON object.")
    if not isinstance(systems, list):
        raise ValueError("'systems' must be a JSON array.")

    observations = [
        build_public_model_record(system, protocol)
        for system in systems
        if isinstance(system, dict)
    ]

    result = {
        "source_format": SOURCE_FORMAT,
        "protocol": raw.get("protocol"),
        "interpretation_contract": raw.get("interpretation_contract"),
        "global_condition": raw.get("global_condition"),
        "global_judgment_demand": raw.get("global_judgment_demand"),
        "legacy_global_score": raw.get("global_score"),
        "panel_summary": panel_summary,
        "probe_contract": raw.get("probe_contract"),
        "coverage": compute_coverage(panel_summary, systems),
        "observations": observations,
    }

    # --- V2 additive root fields: present only if the source explicitly declares a
    # complete V2 methodology (see source_declares_v2_methodology). Absent for every
    # real data/history/*.json file today - the longitudinal engine is not wired into
    # that source yet (AI_WEATHER_V2_LAUNCH_PLAN_2026-09-21.md section 4/10).
    if source_declares_v2_methodology(raw):
        result["methodology_version"] = raw.get("methodology_version")
        result["baseline_config_version"] = raw.get("baseline_config_version")
        result["repetition_count"] = raw.get("repetition_count")

    return result


def normalize_input(raw: dict) -> dict:
    if "systems" in raw and "panel_summary" in raw:
        return normalize_ai_weather_history(raw)
    raise ValueError(
        "Input does not look like a data/history/YYYY-MM-DD.json file "
        "('systems' and 'panel_summary' top-level keys required). "
        "This reconstructed v0.2 generator has no generic/example fallback."
    )


# ---------------------------------------------------------------------------
# Capsule construction
# ---------------------------------------------------------------------------

def build_capsule(raw: dict, date_str: str, prev_capsule) -> dict:
    normalized = normalize_input(raw)

    if prev_capsule is None:
        prev_hash = "genesis"
        sequence_index = 0
    else:
        previous_chain = prev_capsule.get("chain", {})
        prev_hash = previous_chain.get("content_hash")
        if not prev_hash:
            raise ValueError("Previous capsule does not contain chain.content_hash.")
        previous_sequence = previous_chain.get("sequence_index")
        if not isinstance(previous_sequence, int):
            raise ValueError("Previous capsule contains invalid sequence_index.")
        sequence_index = previous_sequence + 1

    capsule_id = f"neomundi-aiweather-{date_str}"
    issued_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    is_v2 = "methodology_version" in normalized

    capsule = {
        "schema_version": SCHEMA_VERSION_V2 if is_v2 else SCHEMA_VERSION,
        "capsule_id": capsule_id,
        "date": date_str,
        "issued_at": issued_at,
        "chain": {
            "prev_hash": prev_hash,
            "sequence_index": sequence_index,
        },
        "source_format": normalized["source_format"],
        "protocol": normalized["protocol"],
        "interpretation_contract": normalized["interpretation_contract"],
        "global_condition": normalized["global_condition"],
        "global_judgment_demand": normalized["global_judgment_demand"],
        "legacy_global_score": normalized["legacy_global_score"],
        "panel_summary": normalized["panel_summary"],
        "probe_contract": normalized["probe_contract"],
        "coverage": normalized["coverage"],
        "observations": normalized["observations"],
        "interpretation_boundaries": INTERPRETATION_BOUNDARIES,
        "rendering_metadata": RENDERING_METADATA,
        "signature": SIGNATURE,
    }

    if is_v2:
        capsule["methodology_version"] = normalized["methodology_version"]
        capsule["baseline_config_version"] = normalized["baseline_config_version"]
        capsule["repetition_count"] = normalized["repetition_count"]

    capsule["chain"]["content_hash"] = compute_content_hash(capsule)
    return capsule


# ---------------------------------------------------------------------------
# Write capsule
# ---------------------------------------------------------------------------

def write_capsule(capsule: dict, capsules_dir: Path) -> Path:
    date_str = capsule["date"]
    year, month, day = date_str.split("-")
    out_dir = capsules_dir / year / month
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{day}.json"

    if out_path.exists():
        raise FileExistsError(
            f"A capsule already exists for {date_str}: {out_path}\n"
            "Immutability rule: existing capsules are never overwritten automatically."
        )

    payload = json.dumps(capsule, indent=2, sort_keys=True, ensure_ascii=False)
    out_path.write_text(payload + "\n", encoding="utf-8")
    return out_path


def update_latest_pointer(capsules_dir: Path, capsule_path: Path) -> Path:
    latest_path = capsules_dir.parent / "latest.json"
    relative_path = capsule_path.relative_to(capsules_dir.parent)
    normalized_path = "/" + str(relative_path).replace("\\", "/")
    latest_path.write_text(
        json.dumps({"latest": normalized_path}, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return latest_path


def validate_date(date_str: str) -> str:
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as exc:
        raise ValueError(f"Invalid date: {date_str}. Expected YYYY-MM-DD.") from exc
    return date_str


def validate_ai_weather_source(raw: dict) -> None:
    if not ("systems" in raw and "panel_summary" in raw):
        return

    required_top_level = [
        "protocol",
        "global_condition",
        "interpretation_contract",
        "global_judgment_demand",
        "probe_contract",
    ]
    missing = [key for key in required_top_level if key not in raw]
    if missing:
        raise ValueError(
            "AI Weather history source is missing required interpreted fields: "
            f"{', '.join(missing)}"
        )

    for index, system in enumerate(raw.get("systems", [])):
        if not isinstance(system, dict):
            raise ValueError(f"systems[{index}] must be an object.")
        for field in ("condition", "interpretation", "judgment_demand"):
            if field not in system:
                raise ValueError(
                    f"systems[{index}] is missing '{field}'. "
                    "Run the current multi-signal aggregator before generating the capsule."
                )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate an immutable AI Weather capsule and append it to the SHA-256 hash-chain."
    )
    parser.add_argument("--input", type=str, required=True, help="Path to data/history/YYYY-MM-DD.json")
    parser.add_argument("--date", type=str, default=None, help="Capsule date YYYY-MM-DD. Default: current UTC date.")
    parser.add_argument("--capsules-dir", type=str, default=None, help="Capsule directory. Default: ./capsules next to this script.")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    capsules_dir = Path(args.capsules_dir).resolve() if args.capsules_dir else script_dir / "capsules"
    capsules_dir.mkdir(parents=True, exist_ok=True)

    input_path = Path(args.input).resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    raw = load_json_file(input_path)
    validate_ai_weather_source(raw)
    print(f"[OK] Source loaded: {input_path}")

    date_str = validate_date(args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d"))

    prev_capsule = find_previous_capsule(capsules_dir)
    capsule = build_capsule(raw=raw, date_str=date_str, prev_capsule=prev_capsule)
    out_path = write_capsule(capsule=capsule, capsules_dir=capsules_dir)
    latest_path = update_latest_pointer(capsules_dir=capsules_dir, capsule_path=out_path)

    print()
    print(f"[OK] Capsule generated: {out_path}")
    print(f"     sequence_index       = {capsule['chain']['sequence_index']}")
    print(f"     prev_hash            = {capsule['chain']['prev_hash']}")
    print(f"     content_hash         = {capsule['chain']['content_hash']}")
    print(f"     source_format        = {capsule['source_format']}")
    print(f"     systems              = {len(capsule['observations'])}")
    print(f"     global_condition     = {capsule['global_condition']}")
    print(f"[OK] latest.json updated: {latest_path}")


if __name__ == "__main__":
    main()
