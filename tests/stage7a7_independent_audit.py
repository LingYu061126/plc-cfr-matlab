"""Independent standard-library audit of Stage 7A.7 MATLAB CSV outputs.

Usage: python3 tests/stage7a7_independent_audit.py [repo_root]
Reads all formal condition directories and writes only stage7a_7/audit outputs.
"""

from __future__ import annotations

import csv
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path


CONDITIONS = (
    "nominal",
    "zin3",
    "zin6",
    "missing_half",
    "parameter_shift",
)
COUNT_FIELDS = {
    "correct_unique_k": "correct_unique",
    "false_unique_k": "false_unique",
    "generated_by_edit_k": "generated_by_edit",
    "added_by_completion_k": "added_by_completion",
    "active_k": "active",
    "truth_in_set_k": "truth_in_set",
    "nonempty_set_k": "nonempty_set",
    "truncated_k": "search_truncated",
    "pool_exhausted_k": "pool_exhausted",
}
STATE_FIELDS = {
    "rejected_k": "REJECTED",
    "ambiguous_k": "MULTIPLE_AMBIGUOUS",
    "low_confidence_k": "LOW_CONFIDENCE",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def bit(value: str) -> int:
    if value.lower() in ("true", "1"):
        return 1
    if value.lower() in ("false", "0"):
        return 0
    raise ValueError(f"Unexpected logical CSV value: {value}")


def wilson(k: int, n: int) -> tuple[float, float]:
    z = 1.959963984540054
    p = k / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt((p * (1 - p) + z * z / (4 * n)) / n) / denom
    return max(0.0, center - half), min(1.0, center + half)


def recompute(rows: list[dict[str, str]], scenario: bool) -> dict[tuple[str, ...], dict[str, object]]:
    groups: dict[tuple[str, ...], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        key = (row["split"], row["scheme"], row["flow"])
        if scenario:
            key += (row["scenario"],)
        groups[key].append(row)
    out = {}
    for key, subset in groups.items():
        n = len(subset)
        result: dict[str, object] = {"n": n}
        for aggregate, field in COUNT_FIELDS.items():
            if field == "nonempty_set":
                result[aggregate] = sum(int(r["set_size"]) > 0 for r in subset)
            else:
                result[aggregate] = sum(bit(r[field]) for r in subset)
        for aggregate, state in STATE_FIELDS.items():
            result[aggregate] = sum(r["state"] == state for r in subset)
        for metric in ("correct_unique", "false_unique", "generated_by_edit"):
            lo, hi = wilson(int(result[f"{metric}_k"]), n)
            prefix = "generated" if metric == "generated_by_edit" else metric
            result[f"{prefix}_low"] = lo
            result[f"{prefix}_high"] = hi
        result["mean_set_size"] = sum(int(r["set_size"]) for r in subset) / n
        result["mean_scored_candidates"] = sum(int(r["candidate_count"]) for r in subset) / n
        result["mean_optimizer_evaluations"] = (
            sum(int(r["optimizer_evaluations"]) for r in subset) / n
        )
        result["mean_wall_clock_s"] = sum(float(r["wall_clock_s"]) for r in subset) / n
        out[key] = result
    return out


def audit_summary(source: list[dict[str, str]], saved: list[dict[str, str]], scenario: bool) -> int:
    expected = recompute(source, scenario)
    assert len(expected) == len(saved), (len(expected), len(saved))
    for row in saved:
        key = (row["split"], row["scheme"], row["flow"])
        if scenario:
            key += (row["scenario"],)
        assert key in expected, key
        result = expected[key]
        for field, value in result.items():
            if isinstance(value, int):
                assert int(row[field]) == value, (key, field, row[field], value)
            else:
                assert math.isclose(float(row[field]), value, rel_tol=1e-9, abs_tol=1e-9), (
                    key, field, row[field], value
                )
    return len(expected)


def audit_condition(directory: Path) -> list[dict[str, object]]:
    samples = read_csv(directory / "samples.csv")
    candidates = read_csv(directory / "candidate_audit.csv")
    summaries = read_csv(directory / "summary.csv")
    topology = read_csv(directory / "topology_summary.csv")
    inventory = read_csv(directory / "topology_inventory.csv")
    metadata = read_csv(directory / "metadata.csv")
    assert len(inventory) == 39
    assert sum(bit(r["in_new_pool"]) for r in inventory) == 37
    assert len({r["signature"] for r in inventory}) == 39
    assert len(samples) == int(metadata[0]["test_observations"]) * len(read_csv(directory / "calibration.csv"))
    candidate_groups = Counter((r["sample_id"], r["scheme"], r["flow"]) for r in candidates)
    rank1 = Counter((r["sample_id"], r["scheme"], r["flow"]) for r in candidates if r["rank"] == "1")
    for row in samples:
        key = row["sample_id"], row["scheme"], row["flow"]
        assert candidate_groups[key] == int(row["candidate_count"]), key
        assert rank1[key] == 1, key
        assert bit(row["correct_unique"]) + bit(row["false_unique"]) <= 1
        assert bit(row["truth_in_set"]) <= bit(row["active"])
        if row["flow"] == "C37":
            assert int(row["candidate_count"]) == 37
            assert bit(row["pool_exhausted"]) == 1
            assert bit(row["search_truncated"]) == 0
        if row["flow"] in ("C5", "C12"):
            assert bit(row["search_truncated"]) == 1
            assert int(row["candidate_count"]) <= int(row["budget"])
    n_summary = audit_summary(samples, summaries, False)
    n_topology = audit_summary(samples, topology, True)
    combined = recompute(samples, True)
    output = []
    for key, result in sorted(combined.items()):
        output.append(
            {
                "condition": directory.name,
                "split": key[0],
                "scheme": key[1],
                "flow": key[2],
                "scenario": key[3],
                "n": result["n"],
                "correct_unique_k": result["correct_unique_k"],
                "false_unique_k": result["false_unique_k"],
                "rejected_k": result["rejected_k"],
                "ambiguous_k": result["ambiguous_k"],
                "low_confidence_k": result["low_confidence_k"],
                "generated_by_edit_k": result["generated_by_edit_k"],
                "added_by_completion_k": result["added_by_completion_k"],
                "active_k": result["active_k"],
                "truth_in_set_k": result["truth_in_set_k"],
                "correct_unique_low": result["correct_unique_low"],
                "correct_unique_high": result["correct_unique_high"],
                "false_unique_low": result["false_unique_low"],
                "false_unique_high": result["false_unique_high"],
            }
        )
    print(f"PASS {directory.name}: {len(samples)} decisions, {len(candidates)} candidate rows, "
          f"{n_summary} summary groups, {n_topology} topology groups")
    return output


def check_paired_h_only(formal: Path) -> None:
    """Changing only Zin RMS must leave every H-only scientific row unchanged."""
    fields = (
        "sample_id", "split", "scenario", "scheme", "flow", "budget",
        "truth_id", "truth_signature", "parameter_seed", "noise_seed",
        "true_main_scale", "true_load_scale", "generated_by_edit",
        "added_by_completion", "active", "truth_in_set", "candidate_count",
        "pool_exhausted", "search_truncated", "unvisited_count",
        "best_candidate", "second_candidate", "truth_rank", "truth_distance",
        "closest_competitor", "competitor_distance", "distance_1",
        "distance_2", "margin", "candidate_set", "set_size",
        "fit_statistic", "fit_threshold", "fit_pass", "state", "reason",
        "correct_unique", "false_unique",
    )
    original = {
        (r["sample_id"], r["flow"]): r
        for r in read_csv(formal / "nominal" / "samples.csv")
        if r["scheme"] == "H50" and r["flow"] in ("B", "C37")
    }
    for condition in ("zin3", "zin6"):
        comparison = {
            (r["sample_id"], r["flow"]): r
            for r in read_csv(formal / condition / "samples.csv")
            if r["scheme"] == "H50"
        }
        assert original.keys() == comparison.keys(), condition
        for key, first in original.items():
            second = comparison[key]
            for field in fields:
                assert first[field] == second[field], (condition, key, field)
    print(f"PASS paired H-only invariance: {len(original)} rows each across 1/3/6 ohm Zin conditions")


def main() -> None:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    formal = root / "results" / "data" / "stage7a_7" / "formal"
    records = []
    for condition in CONDITIONS:
        records.extend(audit_condition(formal / condition))
    check_paired_h_only(formal)
    destination = root / "results" / "data" / "stage7a_7" / "audit"
    destination.mkdir(parents=True, exist_ok=True)
    path = destination / "independent_topology_summary.csv"
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(records[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(records)
    print(f"PASS independent aggregate: {len(records)} topology/flow/view rows")


if __name__ == "__main__":
    main()
