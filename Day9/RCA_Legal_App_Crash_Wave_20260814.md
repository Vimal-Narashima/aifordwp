# Root Cause Analysis (RCA): Legal Floor 6 App Crash Wave

Date of RCA: 2026-08-14  
Incident date: 2024-03-25  
Affected group: Legal-Win11 (45 devices, Floor 6)

## Executive Summary
A wave of application crashes occurred in Legal shortly after deployment of Legal Document Manager v2.1. Correlated evidence from Nexthink DEX and SCCM shows that the incident began immediately after the deployment completed, with high disk I/O and a sharp increase in crashes dominated by DocManager.exe. The most likely root cause is the vendor-documented v2.1 auto-save indexing limitation on under-8GB RAM devices, amplified by full-fleet simultaneous rollout.

No explicit error codes were provided in the source data; this RCA does not assign meanings to any error codes.

## Scope and Impact
- User impact: multiple Legal users experienced app crashes during the morning window.
- Technical impact:
  - App crash rate rose from baseline 0.1-0.2% to 6.2-6.8%.
  - DEX score dropped from ~90 to mid-50s.
  - Disk I/O changed from Normal to High.
- Operational impact: reduced productivity and likely service desk load increase during business hours.

## Evidence Inventory

### Evidence Source 1: Nexthink DEX (Legal-Win11)
- 08:00 -> DEX 91, crashes 0.1%, disk I/O Normal.
- 09:00 -> DEX 90, crashes 0.2%, disk I/O Normal.
- 10:00 -> DEX 58, crashes 6.2%, disk I/O High.
- 11:00 -> DEX 55, crashes 6.8%, disk I/O High.
- Top crashing process in 10:00-11:00: DocManager.exe (74% of crashes).

### Evidence Source 2: SCCM Deployment
- 09:38:20 -> Deployment start: Legal Document Manager v2.1 to 45 devices.
- 09:44:07 -> Deployment complete: 45/45 success, 0 failures.
- Prior version v2.0 had stable operation for 6 weeks.
- Vendor release note for v2.1:
  - New auto-save feature.
  - Known limitation on devices under 8GB RAM: high disk I/O and intermittent crashes for first few hours while index builds.
- Fleet RAM mix:
  - 8GB: 60% (27 devices).
  - 4GB: 40% (18 devices).

## Correlation Analysis
1. Temporal correlation:
- Major degradation starts within ~16 minutes of deployment completion.
- This is a strong near-immediate post-change signal.

2. Symptom correlation:
- Vendor warning predicts high disk I/O and intermittent crashes.
- Observed data shows exactly high disk I/O and crash surge.

3. Process correlation:
- Dominant crashing executable is DocManager.exe, the just-updated application.

4. Population correlation:
- 18 endpoints meet under-8GB risk condition, sufficient to drive group-level degradation.

5. Exclusion signal:
- No instability signal before rollout in same morning window.
- v2.0 historical stability reduces likelihood of unrelated random failure.

## Timeline (With Available Timestamps)
1. 08:00 - Environment healthy (DEX 91, crashes 0.1%, I/O Normal).
2. 09:00 - Environment remains healthy (DEX 90, crashes 0.2%, I/O Normal).
3. 09:38:20 - SCCM starts v2.1 deployment to 45 Legal devices.
4. 09:44:07 - SCCM reports install success on 45/45 devices.
5. 10:00 - First measured degradation: DEX 58, crashes 6.2%, I/O High.
6. 10:00-11:00 - DocManager.exe accounts for 74% of crashes.
7. 11:00 - Degradation persists: DEX 55, crashes 6.8%, I/O High.

## 5 Whys Analysis
1. Why did Legal users experience a wave of app crashes?
- Because DocManager.exe crash frequency spiked sharply after v2.1 deployment.

2. Why did DocManager.exe crash frequency spike?
- Because v2.1 introduced auto-save indexing behavior associated with heavy disk I/O and instability during first-run indexing.

3. Why was the impact broad enough to appear as a floor-wide wave?
- Because deployment was executed to all 45 devices in one wave, synchronizing first-run indexing load.

4. Why were affected devices especially vulnerable?
- Because 40% of the fleet has 4GB RAM (under vendor's 8GB threshold risk condition).

5. Why was this risk not prevented before broad rollout?
- Because deployment governance did not enforce hardware-aware risk gating and staged rollout based on vendor known limitations.

Process root cause:
- Missing pre-deployment control that maps vendor known limitations to actual endpoint hardware and rollout strategy.

## Root Cause Statement
Primary root cause:
- Legal Document Manager v2.1 auto-save indexing limitation on under-8GB devices caused high disk I/O and intermittent crashes in the immediate post-install window.

Contributing cause:
- Simultaneous full-collection deployment amplified resource contention and user-visible impact.

## Ranked Hypotheses (Most Probable First)
1. Vendor-known v2.1 indexing limitation on under-8GB devices.
2. Simultaneous rollout-induced first-run indexing storm.
3. General runtime regression in v2.1 not represented by SCCM install success.

## Corrective Remediation (Finalized)

### Exact Steps
1. Freeze any further v2.1 rollout to Legal-Win11.
2. Execute rollback to v2.0 for Legal-Win11, prioritizing 4GB devices.
3. Confirm rollback compliance in SCCM (device-level completion).
4. Monitor DEX until crash rate and I/O return toward baseline.
5. Build a pilot group with both 4GB and 8GB devices.
6. Apply vendor-supported indexing mitigation for low-memory devices before pilot.
7. Reintroduce v2.1 in controlled rings only after pilot success.

### Order of Operations
1. Contain change (freeze).
2. Restore stability (rollback).
3. Validate technical recovery (SCCM + DEX checks).
4. Prepare controlled pilot with mitigation.
5. Re-release with ring gates and soak periods.

## Verification of Resolution
All criteria must pass:
1. Crash rate <=0.5% for at least 2 consecutive hours in Legal-Win11.
2. Disk I/O returns to Normal in the same observation period.
3. DEX score improves to >=85.
4. DocManager.exe crash share falls significantly from 74% baseline incident level.
5. Service desk trend confirms wave has ended.

## Preventive Actions
1. Hardware-aware release gating:
- Block or condition deployments where vendor notes conflict with fleet capability (for example under-8GB risk cohorts).

2. Ring deployment standard:
- Pilot (mixed hardware) -> ring 1 -> ring 2 -> broad rollout with go/no-go criteria.

3. Change approval checklist enhancement:
- Mandatory review of vendor known limitations and explicit mapping to estate profile.

4. Automated DEX guardrail:
- Auto-pause rollout if crash rate or disk I/O crosses predefined thresholds within first hour.

5. Capacity modernization plan:
- Prioritize uplift/replacement of 4GB endpoints in business-critical groups.

## Residual Risk
- If low-memory endpoints remain and future releases include heavy first-run workloads, similar incidents can recur without strict gating and phased deployment.

## Closure Criteria
1. Recovery verification metrics met and evidenced.
2. Preventive controls assigned owners and implementation dates.
3. Deployment standard updated and communicated to endpoint engineering and release management.

## Final Determination
Based on correlated timing, symptom pattern, process ownership, and vendor limitation alignment, the incident is best explained by v2.1 auto-save indexing effects on low-memory devices, amplified by one-shot fleet deployment.