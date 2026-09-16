"""
Tests for the additive V2 extension of generate_capsule.py (Bloc Jeudi,
AI_WEATHER_V2_LAUNCH_PLAN_2026-09-21.md section 4-5).

Offline tests only: no real capsule under aiweather-capsule/capsules/ is ever read,
written, or overwritten. All fixture writes happen in temporary directories, per the
project's existing test convention (see test_capsule_index.py).
"""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import generate_capsule as subject

REPO_ROOT = Path(__file__).resolve().parents[2]


def minimal_legacy_raw(condition="clear"):
    """A minimal but schema-valid data/history/*.json-shaped legacy source (today's
    real production shape - no methodology_version, no repetition_count)."""
    system = {
        "id": "openai",
        "model": "gpt-4o-2024-11-20",
        "model_display": "ChatGPT",
        "model_public": None,
        "public_label": "SYSTEM-01",
        "condition": condition,
        "judgment_demand": {"level": "J1"},
        "score": 100,
        "observations": 30,
        "expected_observations": 30,
        "fully_scored": 30,
        "coverage": 1.0,
        "coverage_status": "nominal",
        "total_coverage": 1.0,
        "metrics": {"normal": 1, "variation": 0, "factual_alert": 0, "incomplete": 0},
        "interpretation": {"condition": condition},
        "last_observed_at": "2026-09-16T06:00:00Z",
        "detail": {"previous_condition": "clear", "weather_authority": True, "longitudinal_influences_weather": False},
        "daily": {"role": "daily", "condition": condition, "score": 100, "coverage": 1.0},
        "longitudinal": {"role": "longitudinal", "condition": None, "score": 0, "coverage": 1.0},
    }
    return {
        "protocol": {"daily_weather_authority": True, "longitudinal_weather_authority": False},
        "interpretation_contract": {"profile_version": "0.2"},
        "global_condition": condition,
        "global_judgment_demand": {"level": "J1"},
        "global_score": 100,
        "panel_summary": {"systems_expected": 1},
        "probe_contract": {"daily": {}, "longitudinal": {}},
        "systems": [system],
    }


def v2_raw_from_legacy(legacy):
    """The same fixture, additionally declaring a complete V2 methodology - the shape
    data/history/*.json would carry AFTER the longitudinal engine is wired in (not done
    in this block, per the launch plan)."""
    raw = copy.deepcopy(legacy)
    raw["methodology_version"] = {"id": "AI_WEATHER_METHOD_V2_0"}
    raw["baseline_config_version"] = "v2.0-launch"
    raw["repetition_count"] = 7
    raw["systems"][0]["longitudinal"] = {
        "role": "longitudinal",
        "condition": None,
        "score": 71,
        "coverage": 1.0,
        "repetition_count": 7,
        "current_longitudinal_state": {"state": "attention_renforcee", "deviation_index": -1.96, "as_of": "2026-09-16"},
        "deviation_index": -1.96,
        "baseline": {"median": 71, "mad": 0, "mad_floor": 7.14, "mad_floor_applied": True, "effective_mad": 7.14},
        "uncertainty": {"estimator": "wilson_90pct_descriptive_only", "low": 28.95, "mid": 55.15, "high": 81.36},
        "coverage_detail": {"value": 1.0, "status": "nominal"},
        "detected_events": [{"type": "persistent_deviation", "date": "2026-09-14"}],
        "system_identity": {"model_declared": "sonar-reasoning-pro", "identity_status": "declared"},
        "evidence_integrity": {"chain": {"sequence_index": 26}},
    }
    return raw


class GenerateCapsuleV2Tests(unittest.TestCase):

    def test_legacy_source_is_byte_for_byte_unaffected(self):
        raw = minimal_legacy_raw()
        capsule = subject.build_capsule(raw, "2026-09-16", prev_capsule=None)

        self.assertEqual(capsule["schema_version"], "0.2", "Source legacy -> schema_version reste 0.2")
        self.assertNotIn("methodology_version", capsule, "Aucun champ V2 racine sur une source legacy")
        self.assertNotIn("baseline_config_version", capsule)
        self.assertNotIn("repetition_count", capsule)

        record = capsule["observations"][0]
        self.assertNotIn("longitudinal_reference", record, "Aucun bloc V2 par systeme sur une source legacy")
        self.assertNotIn("daily_challenge", record)
        self.assertIn("daily", record, "Les cles legacy restent presentes")
        self.assertIn("longitudinal", record)
        self.assertEqual(record["condition"], "clear", "Comportement legacy inchange")

    def test_v2_source_produces_additive_v2_fields_without_removing_legacy_ones(self):
        raw = v2_raw_from_legacy(minimal_legacy_raw())
        capsule = subject.build_capsule(raw, "2026-09-16", prev_capsule=None)

        self.assertEqual(capsule["schema_version"], "2.0", "Source V2 complete -> schema_version passe a 2.0")
        self.assertEqual(capsule["methodology_version"], {"id": "AI_WEATHER_METHOD_V2_0"})
        self.assertEqual(capsule["baseline_config_version"], "v2.0-launch")
        self.assertEqual(capsule["repetition_count"], 7)

        record = capsule["observations"][0]
        self.assertIn("longitudinal_reference", record)
        self.assertIn("daily_challenge", record)
        # Legacy keys must still be present, untouched, alongside the new ones.
        self.assertIn("daily", record)
        self.assertIn("longitudinal", record)
        self.assertEqual(record["longitudinal"]["score"], 71, "La cle legacy 'longitudinal' n'est pas modifiee")

        lr = record["longitudinal_reference"]
        self.assertEqual(lr["current_longitudinal_state"]["state"], "attention_renforcee")
        self.assertEqual(lr["baseline"]["mad_floor_applied"], True)
        self.assertEqual(lr["uncertainty"]["estimator"], "wilson_90pct_descriptive_only")
        self.assertFalse(lr["weather_authority"], "Coherent avec le protocole legacy encore fourni dans ce fixture (longitudinal_weather_authority=False)")

    def test_daily_challenge_never_appears_inside_longitudinal_reference(self):
        """Structural non-regression: Today's Challenge can never determine the
        longitudinal state - verified as a JSON-structure fact, not just a convention."""
        raw = v2_raw_from_legacy(minimal_legacy_raw())
        capsule = subject.build_capsule(raw, "2026-09-16", prev_capsule=None)
        record = capsule["observations"][0]

        lr_serialized = json.dumps(record["longitudinal_reference"])
        self.assertNotIn("SYSTEM-01", lr_serialized)  # sanity: distinct object, not a shared reference
        self.assertNotIn("daily_challenge", record["longitudinal_reference"])
        self.assertNotIn("longitudinal_reference", record["daily_challenge"])

    def test_daily_challenge_is_explicitly_non_authoritative(self):
        raw = v2_raw_from_legacy(minimal_legacy_raw())
        capsule = subject.build_capsule(raw, "2026-09-16", prev_capsule=None)
        record = capsule["observations"][0]
        self.assertFalse(record["daily_challenge"]["weather_authority"], "daily_challenge est structurellement non-autoritatif")

    def test_hash_chain_still_computable_for_both_legacy_and_v2(self):
        legacy_capsule = subject.build_capsule(minimal_legacy_raw(), "2026-09-16", prev_capsule=None)
        self.assertEqual(legacy_capsule["chain"]["prev_hash"], "genesis")
        self.assertEqual(legacy_capsule["chain"]["sequence_index"], 0)
        self.assertTrue(legacy_capsule["chain"]["content_hash"])

        v2_capsule = subject.build_capsule(v2_raw_from_legacy(minimal_legacy_raw()), "2026-09-17", prev_capsule=legacy_capsule)
        self.assertEqual(v2_capsule["chain"]["prev_hash"], legacy_capsule["chain"]["content_hash"])
        self.assertEqual(v2_capsule["chain"]["sequence_index"], 1)
        # Re-verify independently, exactly as verify_chain.py would.
        recomputed = subject.compute_content_hash(v2_capsule)
        self.assertEqual(recomputed, v2_capsule["chain"]["content_hash"])

    def test_real_production_file_regression(self):
        """Regenerate a capsule from a REAL, PAST, FROZEN data/history/*.json (read-only)
        and its REAL previous capsule (read-only), in memory only - nothing is written
        back. Every field must match the real stored capsule except issued_at and the
        two hash-dependent fields (which legitimately change with wall-clock time).

        Pinned to 2026-09-15 (prev: 2026-09-14), NOT to "today's" file.

        History: this test originally targeted 2026-09-16 - the date that was "today"
        when it was written. That date stopped being a safe fixture the moment the
        actual V2 launch (2026-09-16, see AI_WEATHER_V2_LAUNCH_REPORT_2026-09-21.md)
        deliberately enriched data/history/2026-09-16.json with V2 fields while leaving
        the capsule already published that morning at schema_version 0.2 (immutability
        rule, capsule V2 starts at the next generation - see
        AI_WEATHER_V2_POST_LAUNCH_CLEANUP.md). Regenerating from the now-enriched source
        no longer matches that already-published legacy capsule - not a regression in
        generate_capsule.py (proven correct by every other test in this suite and by two
        real V2 capsule generations this week), just a fixture that pointed at a file the
        daily pipeline was always going to mutate. A past, already-published day is
        immutable by the project's own rule (aiweather-capsule/capsules/ are never
        rewritten) and therefore safe to pin permanently - any past day works; 09-15 was
        already the adjacent real fixture used elsewhere in this suite."""
        history_path = REPO_ROOT / "data" / "history" / "2026-09-15.json"
        real_capsule_path = REPO_ROOT / "aiweather-capsule" / "capsules" / "2026" / "09" / "15.json"
        prev_real_capsule_path = REPO_ROOT / "aiweather-capsule" / "capsules" / "2026" / "09" / "14.json"
        if not (history_path.exists() and real_capsule_path.exists() and prev_real_capsule_path.exists()):
            self.skipTest("Real repository fixtures not found in this environment.")

        raw = subject.load_json_file(history_path)
        prev_capsule = subject.load_json_file(prev_real_capsule_path)
        real_capsule = subject.load_json_file(real_capsule_path)

        regenerated = subject.build_capsule(raw, "2026-09-15", prev_capsule=prev_capsule)

        ignore_keys = {"issued_at"}
        for key in real_capsule:
            if key in ignore_keys:
                continue
            if key == "chain":
                self.assertEqual(regenerated["chain"]["prev_hash"], real_capsule["chain"]["prev_hash"])
                self.assertEqual(regenerated["chain"]["sequence_index"], real_capsule["chain"]["sequence_index"])
                continue
            self.assertEqual(
                regenerated.get(key), real_capsule.get(key),
                f"Regression sur une source legacy reelle : le champ '{key}' a change apres la modification V2",
            )
        self.assertNotIn("methodology_version", regenerated, "2026-09-15 est un jour passe, immuable, et reste une source legacy pour toujours")


    def test_real_shadow_v2_pipeline_produces_a_real_v2_capsule(self):
        """Bloc Jeudi-bis: consume the REAL shadow output produced by
        longitudinal_v2_bridge.ps1 (AI_WEATHER_RUNNER/tests/test_longitudinal_v2_bridge.ps1
        must have been run first) and build a real V2 capsule from it. Written to a
        temporary directory only - never to aiweather-capsule/capsules/."""
        shadow_path = REPO_ROOT / "data" / "shadow" / "v2" / "2026-09-16.json"
        if not shadow_path.exists():
            self.skipTest("Run AI_WEATHER_RUNNER/tests/test_longitudinal_v2_bridge.ps1 first to produce the real shadow fixture.")

        raw = subject.load_json_file(shadow_path)
        self.assertTrue(subject.source_declares_v2_methodology(raw), "Le fichier shadow reel declare bien une methodologie V2 complete")

        capsule = subject.build_capsule(raw, "2026-09-16", prev_capsule=None)

        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp) / "capsules"
            written_path = subject.write_capsule(capsule, out_dir)
            self.assertTrue(written_path.exists())
            reloaded = json.loads(written_path.read_text(encoding="utf-8"))

        self.assertEqual(reloaded["schema_version"], "2.0")
        self.assertEqual(reloaded["methodology_version"]["id"], "AI_WEATHER_METHOD_V2_0")
        self.assertEqual(reloaded["baseline_config_version"], "v2.0-launch")
        self.assertEqual(reloaded["repetition_count"], 7)

        mistral = next(o for o in reloaded["observations"] if o.get("model") == "mistral-medium-3-5")
        self.assertIn("longitudinal_reference", mistral)
        self.assertIn("daily_challenge", mistral)
        lr = mistral["longitudinal_reference"]
        for key in ("current_longitudinal_state", "uncertainty", "detected_events", "system_identity", "coverage", "baseline"):
            self.assertIn(key, lr, f"'{key}' manquant dans longitudinal_reference (Mistral)")
        self.assertEqual(lr["current_longitudinal_state"]["state"], "attention_accrue")
        self.assertFalse(mistral["daily_challenge"]["weather_authority"])

        # Chain still verifiable independently, exactly as verify_chain.py would do.
        recomputed_hash = subject.compute_content_hash(reloaded)
        self.assertEqual(recomputed_hash, reloaded["chain"]["content_hash"])


if __name__ == "__main__":
    unittest.main()
