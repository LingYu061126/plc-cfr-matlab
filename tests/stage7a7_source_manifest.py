"""Hash Stage 7A.7 source and result bytes without touching older stages."""

from __future__ import annotations

import csv
import hashlib
import subprocess
import sys
from pathlib import Path


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def tracked(root: Path, relative: Path) -> bool:
    proc = subprocess.run(
        ["git", "ls-files", "--error-unmatch", "--", relative.as_posix()],
        cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        check=False,
    )
    return proc.returncode == 0


def write(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    assert head == "c011521314f95b013d88a2f0beeda9df63dd1cac", head
    paths = [
        "config/stage7a7_config.m",
        "docs/stage7a7_protocol.md",
        "docs/stage7a7_report.md",
        "experiments/exp_stage7a7_study.m",
        "experiments/exp_stage7a7_cost_profile.m",
        "run_stage7a7_study.m",
        "src/stage7a7_candidate_space.m",
        "src/stage7a7_condition_identity.m",
        "src/stage7a7_expand_candidates.m",
        "src/stage7a7_graph_edit_neighbors.m",
        "src/stage7a7_score_observation.m",
        "src/stage7a7_split_main_edit.m",
        "tests/stage7a7_independent_audit.py",
        "tests/stage7a7_report_tables.py",
        "tests/stage7a7_source_manifest.py",
        "tests/test_stage7a7_candidate_space.m",
        "tests/test_stage7a7_result_integrity.m",
        "tests/test_stage7a7_search_and_identity.m",
    ]
    source_rows = []
    for name in paths:
        relative = Path(name)
        path = root / relative
        assert path.is_file(), path
        source_rows.append(
            {
                "relative_path": relative.as_posix(),
                "sha256": digest(path),
                "size_bytes": path.stat().st_size,
                "git_tracked": int(tracked(root, relative)),
                "baseline_commit": head,
                "source_status": "uncommitted_stage7a7",
            }
        )
    directory = root / "results" / "data" / "stage7a_7"
    audit = directory / "audit"
    audit.mkdir(parents=True, exist_ok=True)
    excluded = {"source_inventory.csv", "artifact_manifest.csv"}
    artifacts = sorted(
        p for p in directory.rglob("*") if p.is_file() and p.name not in excluded
    )
    artifacts.append(root / "docs" / "stage7a7_report.md")
    artifact_rows = []
    for path in artifacts:
        relative = path.relative_to(root)
        artifact_rows.append(
            {
                "relative_path": relative.as_posix(),
                "sha256": digest(path),
                "size_bytes": path.stat().st_size,
                "artifact_type": path.suffix.lstrip("."),
                "stage": "stage7a7",
                "source_status": "uncommitted_stage7a7",
                "baseline_commit": head,
            }
        )
    write(
        audit / "source_inventory.csv",
        ["relative_path", "sha256", "size_bytes", "git_tracked", "baseline_commit", "source_status"],
        source_rows,
    )
    write(
        audit / "artifact_manifest.csv",
        ["relative_path", "sha256", "size_bytes", "artifact_type", "stage", "source_status", "baseline_commit"],
        artifact_rows,
    )
    print(f"PASS source inventory: {len(source_rows)} source files")
    print(f"PASS artifact manifest: {len(artifact_rows)} artifacts")


if __name__ == "__main__":
    main()
