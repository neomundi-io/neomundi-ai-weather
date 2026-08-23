#!/usr/bin/env python3
"""
verify_chain.py — Vérification d'intégrité de la hash-chain des capsules AI Weather.

Parcourt /capsules/ par ordre chronologique et vérifie :
  1. Que le content_hash stocké correspond bien au recalcul sur le contenu.
  2. Que le prev_hash de chaque capsule correspond au content_hash de la précédente
     (genesis pour la toute première, sequence_index attendu strictement croissant).

Sort un rapport clair et un code de sortie non-zéro si une rupture est détectée
(exploitable plus tard dans une alerte CI).

Usage:
    python verify_chain.py [--capsules-dir /path/to/capsules]
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path


def canonical_json_bytes(obj: dict) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def compute_content_hash(capsule: dict) -> str:
    capsule_copy = json.loads(json.dumps(capsule))
    capsule_copy["chain"].pop("content_hash", None)
    return hashlib.sha256(canonical_json_bytes(capsule_copy)).hexdigest()


def load_capsules(capsules_dir: Path):
    """Charge toutes les capsules, triées par date de fichier (YYYY/MM/DD.json)."""
    files = sorted(capsules_dir.glob("*/*/*.json"))
    capsules = []
    for f in files:
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            capsules.append((f, None, f"JSON invalide : {e}"))
            continue
        capsules.append((f, data, None))
    return capsules


def main():
    parser = argparse.ArgumentParser(description="Vérifie l'intégrité de la hash-chain des capsules.")
    parser.add_argument("--capsules-dir", type=str, default=None, help="Dossier /capsules/ (par défaut : ./capsules à côté du script).")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    capsules_dir = Path(args.capsules_dir).resolve() if args.capsules_dir else script_dir / "capsules"

    if not capsules_dir.exists():
        print(f"[ERREUR] Dossier introuvable : {capsules_dir}")
        sys.exit(2)

    capsules = load_capsules(capsules_dir)

    if not capsules:
        print(f"[INFO] Aucune capsule trouvée dans {capsules_dir}. Rien à vérifier.")
        sys.exit(0)

    print(f"Vérification de la chaîne — {len(capsules)} capsule(s) trouvée(s) dans {capsules_dir}\n")

    broken = False
    expected_prev_hash = "genesis"
    expected_sequence_index = 0

    for path, data, load_error in capsules:
        label = f"{path.relative_to(capsules_dir)}"

        if load_error:
            print(f"[RUPTURE] {label} — {load_error}")
            broken = True
            continue

        chain = data.get("chain", {})
        stored_hash = chain.get("content_hash")
        stored_prev = chain.get("prev_hash")
        stored_seq = chain.get("sequence_index")

        recomputed_hash = compute_content_hash(data)

        ok = True
        problems = []

        if recomputed_hash != stored_hash:
            ok = False
            problems.append(
                f"content_hash incohérent — attendu (recalculé) {recomputed_hash}, trouvé {stored_hash}"
            )

        if stored_prev != expected_prev_hash:
            ok = False
            problems.append(
                f"prev_hash incohérent — attendu {expected_prev_hash}, trouvé {stored_prev}"
            )

        if stored_seq != expected_sequence_index:
            ok = False
            problems.append(
                f"sequence_index incohérent — attendu {expected_sequence_index}, trouvé {stored_seq}"
            )

        if ok:
            print(f"[OK]      {label}  (seq={stored_seq}, content_hash={stored_hash[:12]}…)")
        else:
            broken = True
            print(f"[RUPTURE] {label}")
            for p in problems:
                print(f"          - {p}")

        # Pour la suite de la chaîne, on continue avec les valeurs *stockées*
        # (pas les valeurs recalculées) afin de localiser précisément où la
        # rupture a commencé, sans la faire se propager artificiellement.
        expected_prev_hash = stored_hash if stored_hash else recomputed_hash
        expected_sequence_index = (stored_seq if isinstance(stored_seq, int) else expected_sequence_index) + 1

    print()
    if broken:
        print("RÉSULTAT : chaîne ROMPUE — voir le(s) point(s) de rupture ci-dessus.")
        sys.exit(1)
    else:
        print("RÉSULTAT : chaîne valide de bout en bout.")
        sys.exit(0)


if __name__ == "__main__":
    main()
