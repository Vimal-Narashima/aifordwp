# DEX Startup Performance Drop — Likely Cause Ranking
Date: 2026-08-12
Scope basis: Finance-Win11 only (215 devices) degraded immediately after 2026-08-04 02:00 config deployment; IT-Win11 comparison group (40 devices) stayed stable and did not receive the change.

## 1) Startup script added by the new security baseline is extending logon-to-desktop time
Why this fits the evidence:
- The timing is exact: degradation starts on 2026-08-04, immediately after the 02:00 profile deployment.
- The profile explicitly added a startup script for compliance logging.
- The unaffected IT-Win11 group had no config change and no startup-time shift, strongly isolating the issue to changed Finance policy content.

Fastest check to confirm or eliminate:
- On a small Finance pilot subset, temporarily remove or disable only the added startup script and measure next-login median startup time versus unchanged Finance devices over the next boot cycle.

## 2) Additional Defender scan policy in the same baseline is triggering heavy startup-time overhead
Why this fits the evidence:
- The same 02:00 baseline introduced additional Defender scan policy, matching the exact onset window.
- Startup time nearly doubled and remained elevated for multiple days, consistent with repeated startup resource contention.
- IT-Win11 remained stable without the baseline, supporting change-linked impact rather than platform-wide drift.

Fastest check to confirm or eliminate:
- Verify on affected devices whether Defender scans are starting at/near logon after policy receipt (Defender operational events and scan timestamps), then run a controlled pilot with that scan policy excluded and compare startup timing.

## 3) Combined baseline processing overhead (script + security settings) increased policy-application time at startup
Why this fits the evidence:
- The issue starts exactly at the deployment boundary and affects only the targeted group, indicating baseline-induced startup processing cost.
- Persistent elevated medians after day 1 suggest recurring startup overhead, not a one-time transient.
- Stable IT-Win11 metrics argue against external/shared causes and support a Finance-only configuration effect.

Fastest check to confirm or eliminate:
- Split the baseline into components on a pilot ring (script off, then Defender delta off) and compare startup-time deltas per variant to identify whether overhead is single-component or cumulative.
