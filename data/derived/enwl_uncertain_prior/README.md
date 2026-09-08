# ENWL-derived controlled uncertain prior

This directory contains a small, auditable derived subnetwork for Stage
4A.7.2-R.1. It is not a copy of the ENWL archive and is not a claim that the
published OpenDSS model contains unresolved field errors.

The reference rows are used only to construct an offline evaluation truth and
to generate the observed engineering ledger. Candidate generation consumes
the shared observed ledger and never receives the hidden reference label.

The local OpenDSS cable categories are mapped to the existing model's two
controlled PLC cable types by the R.1 configuration. This is a simulation
mapping, not a frequency-domain calibration of ENWL line-code impedances.
