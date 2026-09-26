"""Derive reader-facing Stage 7A.7 tables from already verified raw CSV.

No thresholds or candidate decisions are changed. Run only after
stage7a7_independent_audit.py has passed for all formal conditions.
"""

from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path

from stage7a7_independent_audit import CONDITIONS, bit, read_csv, recompute


def save(path: Path, rows: list[dict[str, object]]) -> None:
    assert rows, path
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def condition_overview(formal: Path) -> list[dict[str, object]]:
    out = []
    for condition in CONDITIONS:
        rows = read_csv(formal / condition / "samples.csv")
        for (split, scheme, flow), values in sorted(recompute(rows, False).items()):
            out.append(
                {
                    "condition": condition,
                    "split": split,
                    "scheme": scheme,
                    "flow": flow,
                    "n": values["n"],
                    "correct_unique_k": values["correct_unique_k"],
                    "correct_unique_low": values["correct_unique_low"],
                    "correct_unique_high": values["correct_unique_high"],
                    "false_unique_k": values["false_unique_k"],
                    "false_unique_low": values["false_unique_low"],
                    "false_unique_high": values["false_unique_high"],
                    "rejected_k": values["rejected_k"],
                    "ambiguous_k": values["ambiguous_k"],
                    "low_confidence_k": values["low_confidence_k"],
                    "generated_by_edit_k": values["generated_by_edit_k"],
                    "added_by_completion_k": values["added_by_completion_k"],
                    "active_k": values["active_k"],
                    "truth_in_set_k": values["truth_in_set_k"],
                    "mean_set_size": values["mean_set_size"],
                    "mean_scored_candidates": values["mean_scored_candidates"],
                    "mean_optimizer_evaluations": values["mean_optimizer_evaluations"],
                    "mean_wall_clock_s": values["mean_wall_clock_s"],
                }
            )
    return out


def budget_attribution(formal: Path) -> list[dict[str, object]]:
    samples = read_csv(formal / "nominal" / "samples.csv")
    groups: dict[tuple[str, str, str], list[dict[str, str]]] = defaultdict(list)
    for row in samples:
        if row["scheme"] == "H50_Zin50" and row["flow"] in ("C5", "C12", "C37"):
            groups[row["split"], row["scenario"], row["flow"]].append(row)
    output = []
    for (split, scenario, flow), rows in sorted(groups.items()):
        n = len(rows)
        output.append(
            {
                "split": split,
                "scenario": scenario,
                "flow": flow,
                "n": n,
                "truth_in_pool_k": sum(bit(r["truth_in_search_pool"]) for r in rows),
                "edit_generated_k": sum(bit(r["generated_by_edit"]) for r in rows),
                "completion_added_k": sum(bit(r["added_by_completion"]) for r in rows),
                "in_pool_not_seen_k": sum(
                    bit(r["truth_in_search_pool"]) and not bit(r["active"])
                    for r in rows
                ),
                "active_not_in_set_k": sum(
                    bit(r["active"]) and not bit(r["truth_in_set"])
                    for r in rows
                ),
                "in_set_truncation_low_k": sum(
                    bit(r["truth_in_set"]) and r["reason"] == "search_budget_truncated"
                    for r in rows
                ),
                "in_set_margin_low_k": sum(
                    bit(r["truth_in_set"]) and r["reason"] == "insufficient_unique_margin"
                    for r in rows
                ),
                "in_set_multiple_k": sum(
                    bit(r["truth_in_set"]) and r["state"] == "MULTIPLE_AMBIGUOUS"
                    for r in rows
                ),
                "fit_gate_rejected_k": sum(r["reason"] == "fit_quality_gate" for r in rows),
                "correct_unique_k": sum(bit(r["correct_unique"]) for r in rows),
                "false_unique_k": sum(bit(r["false_unique"]) for r in rows),
                "mean_active_candidates": sum(int(r["candidate_count"]) for r in rows) / n,
                "mean_optimizer_evaluations": (
                    sum(int(r["optimizer_evaluations"]) for r in rows) / n
                ),
                "mean_wall_clock_s": sum(float(r["wall_clock_s"]) for r in rows) / n,
            }
        )
    return output


def view_competition(formal: Path) -> list[dict[str, object]]:
    rows = read_csv(formal / "nominal" / "samples.csv")
    selected: dict[str, dict[str, dict[str, str]]] = defaultdict(dict)
    for row in rows:
        if row["flow"] == "C37":
            selected[row["sample_id"]][row["scheme"]] = row
    output = []
    for sample_id, views in sorted(selected.items()):
        assert set(views) == {"H50", "Zin50", "H50_Zin50"}, sample_id
        first = views["H50"]
        r: dict[str, object] = {
            "sample_id": sample_id,
            "split": first["split"],
            "scenario": first["scenario"],
            "truth_id": first["truth_id"],
            "parameter_seed": first["parameter_seed"],
            "noise_seed": first["noise_seed"],
        }
        for name, prefix in (("H50", "h"), ("Zin50", "zin"), ("H50_Zin50", "joint")):
            x = views[name]
            for key in (
                "best_candidate", "closest_competitor", "truth_rank",
                "truth_distance", "competitor_distance", "margin", "state",
                "reason", "candidate_set", "set_size", "fit_statistic",
                "fit_threshold", "correct_unique", "false_unique",
            ):
                r[f"{prefix}_{key}"] = x[key]
        output.append(r)
    return output


def condition_transitions(formal: Path) -> list[dict[str, object]]:
    original = {
        r["sample_id"]: r
        for r in read_csv(formal / "nominal" / "samples.csv")
        if r["scheme"] == "H50_Zin50" and r["flow"] == "C37"
    }
    output = []
    for condition in CONDITIONS[1:]:
        paired = {
            r["sample_id"]: r
            for r in read_csv(formal / condition / "samples.csv")
            if r["scheme"] == "H50_Zin50" and r["flow"] == "C37"
        }
        assert original.keys() == paired.keys(), condition
        for sample_id in sorted(original):
            a, b = original[sample_id], paired[sample_id]
            output.append(
                {
                    "condition": condition,
                    "sample_id": sample_id,
                    "split": a["split"],
                    "scenario": a["scenario"],
                    "same_true_parameters": int(
                        a["true_main_scale"] == b["true_main_scale"]
                        and a["true_load_scale"] == b["true_load_scale"]
                    ),
                    "nominal_state": a["state"],
                    "condition_state": b["state"],
                    "nominal_best": a["best_candidate"],
                    "condition_best": b["best_candidate"],
                    "nominal_truth_in_set": a["truth_in_set"],
                    "condition_truth_in_set": b["truth_in_set"],
                    "nominal_correct_unique": a["correct_unique"],
                    "condition_correct_unique": b["correct_unique"],
                    "nominal_false_unique": a["false_unique"],
                    "condition_false_unique": b["false_unique"],
                }
            )
    return output


def main() -> None:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    formal = root / "results" / "data" / "stage7a_7" / "formal"
    audit = root / "results" / "data" / "stage7a_7" / "audit"
    # The independent audit is a prerequisite, not a source for these tables.
    assert (audit / "independent_topology_summary.csv").is_file()
    tables = {
        "condition_overview.csv": condition_overview(formal),
        "budget_attribution.csv": budget_attribution(formal),
        "view_competition.csv": view_competition(formal),
        "condition_transitions.csv": condition_transitions(formal),
    }
    for filename, rows in tables.items():
        save(audit / filename, rows)
        print(f"PASS {filename}: {len(rows)} rows")


if __name__ == "__main__":
    main()
