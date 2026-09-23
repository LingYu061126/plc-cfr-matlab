# Stage 7A Post-commit Verification and Result Summary

Verification date: 2026-09-23 UTC. The clean-tree verification source was commit `64c2ec2258b14d4eb02d15b88cdbb6672e992548` on `main`, based on the Stage 6 archive-closure commit `81b95a63c5ce7e4ba6985de52cd5177768f68a59`. This is a post-commit verification record, not a rerun of the Stage 7A formal experiment or a replacement for its canonical Stage 7A CSV.

## Execution and test coverage

MATLAB version: `24.1.0.2537033 (R2024a)`; platform: Linux `glnxa64`. Both commands ran serially with an independent temporary `MATLAB_PREFDIR`, `-nodisplay -nosplash -softwareopengl -batch`, and the machine's existing MATLAB-compatible library path. No parallel pool was used. Commands below are relative to the repository root:

```matlab
addpath('src','config','experiments','tests'); run_tests()
addpath('src','config','experiments','tests'); test_stage7a_profile_search()
```

| Verification | Exit status | Result | Log |
|---|---:|---|---|
| Complete registered `run_tests()` suite | 0 | PASS, including Stage 4A clean-source identity and Stage 6 archive integrity | [`stage7a_full_run_tests_post_commit.log`](../results/logs/stage7a/stage7a_full_run_tests_post_commit.log) |
| Independent Stage 7A targeted test | 0 | PASS | [`stage7a_targeted_post_commit.log`](../results/logs/stage7a/stage7a_targeted_post_commit.log) |

The full-suite command took approximately 19.3 s wall-clock including startup; the independent Stage 7A command took approximately 6.8 s. The full log contains six pre-existing `lsqnonlin` warnings that the trust-region-reflective algorithm had fewer equations than variables and switched to Levenberg–Marquardt; all affected tests passed. The MATLAB startup probe inside the restricted sandbox stalled at `client-v1`; the same version probe and tests completed with exit status 0 in the approved execution environment. `tests/run_tests.m` was not edited: its original byte hash remains covered by the Stage 6 closure manifest. Consequently, the complete registered suite and the Stage 7A test are two separate commands, not a claim that Stage 7A was registered into `run_tests()`.

## Formal result summary

The following figures are read from the already archived Stage 7A formal [`stage7a_summary.csv`](../results/data/stage7a/formal/stage7a_summary.csv), [`stage7a_safety.csv`](../results/data/stage7a/formal/stage7a_safety.csv), and [`stage7a_resources.csv`](../results/data/stage7a/formal/stage7a_resources.csv). They were not produced by the post-commit test commands.

| Controlled comparison | Stage 6B baseline | Stage 7A |
|---|---:|---:|
| Parameter-mismatch replay: correct `UNIQUE_CONFIDENT` | 10/70 | 50/70 |
| Independent in-domain: correct `UNIQUE_CONFIDENT` | 5/10 | 10/10 |
| Out-of-domain: `REJECTED` | 10/10 | 10/10 |
| Wrong-open and wrong-closed: `REJECTED` | 14/14 | 14/14 |
| T3/T5 and three-topology-close: `MULTIPLE_AMBIGUOUS` | 2/2 | 2/2 |
| Candidate scale 3/7/23: correct `UNIQUE_CONFIDENT` | 10/10, 10/10, 10/10 | 7/10, 8/10, 4/10 |

The formal safety table reports zero false-unique outcomes and zero library-outside acceptances for both methods on these samples. Stage 7A candidate-set truth coverage for the 3-candidate scale is 8/10 versus 10/10 for the baseline. The 23-candidate Stage 7A model occupies 1,516,657 bytes by MATLAB `whos` versus 933,268 bytes for Stage 6B; cache construction takes 0.448221 s versus 0.031022 s in that recorded run. These are model-size and wall-clock measurements, not peak process memory or general speed guarantees.

## Scope and disposition

The clean-tree tests passed, but the formal candidate-scale confirmation regression remains unresolved. Stage 7A passes its pre-specified safety gate on this controlled sample set; it is **not** promoted over Stage 6B as the default baseline and does **not** satisfy an automatic gate to the next algorithm round. The work verifies a controlled synthetic MATLAB model, not a real PLC transceiver or field distribution network. `UNIQUE_CONFIDENT` does not prove globally unique physical topology; 14/14 wrong-prior rejection does not generalize to arbitrary prior errors. No Stage 4A/5B.1 frozen source or results, Stage 6A/6B canonical results, scientific thresholds, or `tests/run_tests.m` were changed during this post-commit verification.
