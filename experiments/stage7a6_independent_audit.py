"""Independent CSV-only audit of archived Stage 7A.5 and Stage 7A.6 results.

No MATLAB model or result is modified. This script reads canonical sample/candidate
tables and writes derived, one-row-per-observation and grouped audit tables.
"""

from __future__ import annotations

import csv
import hashlib
import math
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "results/data/stage7a_5/formal_v2"
NEW = ROOT / "results/data/stage7a_6/formal"
OUT = ROOT / "results/data/stage7a_6/audit"
BUDGETS = (3, 5, 7, 10, 17)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def yes(value: str) -> int:
    return int(float(value) != 0)


def wilson(k: int, n: int) -> tuple[float, float]:
    if not n:
        return math.nan, math.nan
    z = 1.959963984540054
    p = k / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return center - half, center + half


def audit_old() -> None:
    samples = read_csv(OLD / "samples.csv")
    candidates = read_csv(OLD / "candidate_audit.csv")
    cursor = 0
    by_key: dict[tuple[str, str, str, str], dict] = {}
    for sample in samples:
        count = int(sample["candidate_count"])
        block = candidates[cursor : cursor + count]
        cursor += count
        assert len(block) == count
        assert all(
            item["split"] == sample["split"]
            and item["scenario"] == sample["scenario"]
            and item["scheme"] == sample["scheme"]
            and item["flow"] == sample["flow"]
            and item["truth_id"] == sample["truth_id"]
            for item in block
        )
        if sample["split"] != "T" or sample["scheme"] != "H50":
            continue
        if yes(sample["truth_in_library"]) == 0:
            continue
        key = (
            sample["scenario"],
            sample["parameter_seed"],
            sample["noise_seed"],
            sample["truth_id"],
        )
        assert (key, sample["flow"]) not in by_key
        true = [item for item in block if item["candidate_id"] == sample["truth_id"]]
        other = [item for item in block if item["candidate_id"] != sample["truth_id"]]
        assert len(true) == 1 and other
        competitor = min(other, key=lambda item: float(item["distance"]))
        by_key[(key, sample["flow"])] = {
            "sample": sample,
            "true_distance": float(true[0]["distance"]),
            "competitor": competitor["candidate_id"],
            "competitor_distance": float(competitor["distance"]),
        }
    assert cursor == len(candidates)
    rows = []
    for key, flow in by_key:
        if flow != "B":
            continue
        assert (key, "C") in by_key
        b = by_key[(key, "B")]
        c = by_key[(key, "C")]
        bs, cs = b["sample"], c["sample"]
        loss = yes(bs["correct_unique"]) and not yes(cs["correct_unique"])
        rows.append({
            "scenario": key[0],
            "parameter_seed": key[1],
            "noise_seed": key[2],
            "truth_id": key[3],
            "B_state": bs["state"],
            "C_state": cs["state"],
            "C_reason": cs["reason"],
            "B_correct_unique": yes(bs["correct_unique"]),
            "C_correct_unique": yes(cs["correct_unique"]),
            "B_false_unique": yes(bs["false_unique"]),
            "C_false_unique": yes(cs["false_unique"]),
            "correct_unique_lost": int(loss),
            "B_candidate_set": bs["candidate_set"],
            "C_candidate_set": cs["candidate_set"],
            "B_set_size": bs["set_size"],
            "C_set_size": cs["set_size"],
            "B_truth_distance": b["true_distance"],
            "C_truth_distance": c["true_distance"],
            "C_competitor": c["competitor"],
            "C_competitor_distance": c["competitor_distance"],
            "C_margin": cs["margin"],
            "C_fit_statistic": cs["fit_statistic"],
            "C_fit_threshold": cs["fit_threshold"],
            "C_search_truncated": cs["search_truncated"],
            "C_truth_generated": cs["truth_generated"],
            "C_truth_pruned": cs["truth_pruned"],
            "C_truth_covered": cs["truth_covered"],
        })
    rows.sort(key=lambda row: (row["scenario"], int(row["parameter_seed"])))
    assert len(rows) == 90
    assert sum(row["B_correct_unique"] for row in rows) == 62
    assert sum(row["C_correct_unique"] for row in rows) == 27
    assert sum(row["correct_unique_lost"] for row in rows) == 35
    write_csv(OUT / "paired_stage7a5_h50.csv", rows, list(rows[0]))
    counts: dict[tuple[str, str], int] = defaultdict(int)
    for row in rows:
        if row["correct_unique_lost"]:
            counts[(row["C_state"], row["C_reason"])] += 1
    summary = [
        {"C_state": state, "C_reason": reason, "lost_count": count, "denominator": 35}
        for (state, reason), count in sorted(counts.items())
    ]
    write_csv(OUT / "paired_stage7a5_loss_reasons.csv", summary, list(summary[0]))
    print("Stage 7A.5 H50 paired audit: 90 samples, 35 B-to-C losses", summary)


def stage7a6_rows() -> list[dict[str, str]]:
    all_rows = []
    baseline: dict[tuple[str, str, str], dict] = {}
    for budget in BUDGETS:
        folder = NEW / f"budget_{budget:02d}"
        samples = read_csv(folder / "samples.csv")
        candidates = read_csv(folder / "candidate_audit.csv")
        assert len(samples) == 960
        assert len(candidates) == sum(int(row["candidate_count"]) for row in samples)
        assert all(row["budget"] == ("0" if row["flow"] == "B" else str(budget)) for row in samples)
        for row in samples:
            row["run_budget"] = str(budget)
            if row["flow"] != "B":
                continue
            key = (row["sample_id"], row["scheme"], row["flow"])
            fields = (
                "state", "reason", "candidate_set", "best_candidate",
                "correct_unique", "false_unique", "fit_threshold",
            )
            if key in baseline:
                assert all(row[name] == baseline[key][name] for name in fields), (
                    "Fixed baseline drift", budget, key,
                )
            else:
                baseline[key] = row
        all_rows += samples
    assert len(baseline) == 480
    return all_rows


def group_summary(rows: list[dict[str, str]], group_fields: tuple[str, ...]) -> list[dict]:
    grouped: dict[tuple[str, ...], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[tuple(row[field] for field in group_fields)].append(row)
    output = []
    for key, block in sorted(grouped.items(), key=lambda pair: pair[0]):
        n = len(block)
        metrics = {
            "correct_unique": sum(yes(row["correct_unique"]) for row in block),
            "false_unique": sum(yes(row["false_unique"]) for row in block),
            "rejected": sum(row["state"] == "REJECTED" for row in block),
            "ambiguous": sum(row["state"] == "MULTIPLE_AMBIGUOUS" for row in block),
            "low_confidence": sum(row["state"] == "LOW_CONFIDENCE" for row in block),
            "generated": sum(yes(row["generated"]) for row in block),
            "not_generated": sum(yes(row["not_generated"]) for row in block),
            "pruned": sum(yes(row["pruned"]) for row in block),
            "active": sum(yes(row["active"]) for row in block),
            "truth_in_set": sum(yes(row["truth_in_set"]) for row in block),
            "nonempty_set": sum(int(row["set_size"]) > 0 for row in block),
            "fit_pass": sum(yes(row["fit_pass"]) for row in block),
            "truncated": sum(yes(row["search_truncated"]) for row in block),
        }
        output_row = {field: value for field, value in zip(group_fields, key)}
        output_row["n"] = n
        for name, count in metrics.items():
            low, high = wilson(count, n)
            output_row[name + "_k"] = count
            output_row[name + "_low95"] = low
            output_row[name + "_high95"] = high
        for name in (
            "set_size", "candidate_count", "profile_evaluations",
            "optimizer_evaluations", "forward_calls", "wall_clock_s",
        ):
            output_row["mean_" + name] = sum(float(row[name]) for row in block) / n
        output.append(output_row)
    return output


def main() -> None:
    audit_old()
    rows = stage7a6_rows()
    for name, group_fields in (
        ("cross_budget_summary.csv", ("run_budget", "scheme", "flow", "split")),
        ("cross_budget_topology.csv", ("run_budget", "scheme", "flow", "split", "scenario")),
    ):
        summary = group_summary(rows, group_fields)
        write_csv(OUT / name, summary, list(summary[0]))
    files = [
        Path(__file__).resolve(),
        ROOT / "experiments/exp_stage7a6_exhaustive_control.m",
        ROOT / "docs/stage7a6_report.md",
        ROOT / "README.md",
        OLD / "samples.csv", OLD / "candidate_audit.csv",
        OUT / "paired_stage7a5_h50.csv",
        OUT / "paired_stage7a5_loss_reasons.csv",
        OUT / "cross_budget_summary.csv",
        OUT / "cross_budget_topology.csv",
        OUT / "exhaustive17_control.csv",
        OUT / "mirror_noiseless_control.csv",
        OUT / "extended_noiseless_control.csv",
    ]
    for budget in BUDGETS:
        folder = NEW / f"budget_{budget:02d}"
        files.extend((folder / "samples.csv", folder / "candidate_audit.csv"))
    identity = []
    for path in files:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        identity.append({
            "relative_path": path.relative_to(ROOT).as_posix(),
            "sha256": digest,
            "size_bytes": path.stat().st_size,
        })
    write_csv(OUT / "audit_input_identity.csv", identity, list(identity[0]))
    print("Stage 7A.6 independent audit: 4,800 decisions; fixed B identical across budgets")


if __name__ == "__main__":
    main()
