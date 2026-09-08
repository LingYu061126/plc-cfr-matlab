# ENWL LVNS source manifest

## Source and retrieval

- Provider: Electricity North West / University of Manchester, Low Voltage Network Solutions.
- Model archive URL: <https://www.enwl.co.uk/globalassets/innovation/lvns/lvns-academic/lv-network-models-2.zip>
- Summary report URL: <https://www.enwl.co.uk/globalassets/innovation/lvns/lvns-academic/summary-report.pdf>
- Closedown report URL: <https://www.ofgem.gov.uk/sites/default/files/docs/2017/04/lvns_closedown_report.pdf>
- Local retrieval date: 2026-09-08.
- Original files: supplied locally under `materials/external_data/enwl_lvns/source/`; not committed.
- Public-use note: the reports describe the processed OpenDSS models as made available for academic use; the original ENWL background/IPR and redistribution conditions remain distinct. This project does not redistribute the original archive.

| File | Size (bytes) | SHA256 |
|---|---:|---|
| `lv-network-models-2.zip` | 12600354 | `5ac19bcc5c0857c5d996c0e24d3d15c1e8fe4326eea0253b227576bb50d8bd51` |
| `summary-report.pdf` | 2553572 | `7bd3bd6bf67416c98e5837b3cdbc1057b4fdd892f068eeb7ebce99de32a2f739` |
| `lvns_closedown_report.pdf` | 2034087 | `9cc9046a27c22e06457f685ba6223c9c6ed78ff1f23663a4ffbf8334893b66fa` |

## Reading evidence

The summary report identifies 25 released LV networks, 131 feeders, 5952
customers and approximately 172 km of LV cable. Sections 2.1 and 2.1.3
describe GIS connectivity repair, including millimetre-to-centimetre gaps and
component reconnection before OpenDSS export. The closedown report describes
validation against feeder-head monitoring and notes that unavailable data may
require explicit assumptions. These reports therefore support the provenance
of the processed models, but they do not turn the processed files into a raw
uncertain GIS ledger.

## Selected derived feeder

- Source dataset: ENWL LVNS processed OpenDSS archive.
- Network: `network_13`.
- Feeder: `Feeder_3`.
- Local subnetwork: nodes `32,33,34,35,36,37,38,39`.
- Source node: `32`.
- Receiver node: `39`.
- Kept reference edges: `32-33-34-35-36-37-39` plus leaf edge `36-38`.
- Reason for boundary: a compact local induced subnetwork compatible with the
  project's source-to-receiver plus first-level-leaf forward adapter. Deeper
  feeder edges incident to the retained boundary nodes are recorded as
  excluded context rather than silently compressed into the subnetwork.
- OpenDSS `LineCode` values are retained as provenance categories. They are not
  used as 2--30 MHz PLC RLGC values. The project maps the two local cable
  categories to the existing model's controlled cable types 0 and 1.

The exact retained records and their source line identifiers are in
`data/derived/enwl_uncertain_prior/stage4a7_2_r1_selected_public_subnetwork.csv`.
