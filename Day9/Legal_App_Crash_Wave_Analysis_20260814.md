# Legal Floor 6 App Crash Wave Analysis

Date: 2026-08-14  
Analyst: GitHub Copilot  
Incident date/time window analyzed: 2024-03-25 08:00-11:00

## Scope Facts (Correlated Across Both Sources)

### Source 1: Nexthink DEX (Legal-Win11, 45 devices)
- 08:00: DEX score 91, app crash rate 0.1%, disk I/O Normal.
- 09:00: DEX score 90, app crash rate 0.2%, disk I/O Normal.
- 10:00: DEX score 58, app crash rate 6.2%, disk I/O High.
- 11:00: DEX score 55, app crash rate 6.8%, disk I/O High.
- Top crashing process during 10:00-11:00: DocManager.exe (74% of all crashes in that window).

### Source 2: SCCM Deployment
- 09:38:20: Deployment started, Legal Document Manager v2.1 to Legal-Win11 (45 devices).
- 09:44:07: Install completed on 45/45 devices, result Success, 0 failures.
- Previous version: v2.0 (stable for 6 weeks).
- Vendor note for v2.1: new auto-save feature; known limitation on devices with under 8GB RAM where auto-save indexing can cause high disk I/O and intermittent crashes during first few hours post-install.
- Fleet RAM profile: 60% with 8GB (27 devices), 40% with 4GB (18 devices).

### Cross-source Correlation (What the combined data proves)
- System state was stable before deployment (08:00 and 09:00).
- v2.1 deployment completed at 09:44.
- First major degradation appears at 10:00 (about 16 minutes after completion):
  - Crash rate jumps from 0.2% to 6.2%.
  - Disk I/O flips from Normal to High.
  - Main crash process is the newly deployed app executable (DocManager.exe).
- Degradation persists at 11:00, consistent with vendor statement that impact may continue for the first few hours after install.

This timing/content alignment is strong causal evidence and cannot be explained by either source alone.

## Ranked Top 3 Most Likely Causes (Most Probable First)

## 1) v2.1 auto-save indexing behavior on under-8GB devices (vendor-known limitation)
Why it fits the evidence:
- Matches all three key indicators simultaneously: timing (post-install), symptom type (high disk I/O), and affected process (DocManager.exe).
- Fleet has 18 devices (40%) at 4GB RAM, directly within vendor-defined risk condition (under 8GB).
- Baseline was stable on v2.0, then degraded immediately after v2.1 rollout.

Fastest check to confirm/eliminate:
1. Split crash and disk-I/O metrics by RAM tier for 10:00-11:00.
2. Confirm 4GB devices show significantly higher DocManager.exe crash frequency and I/O pressure than 8GB devices.
3. On one impacted 4GB device, stop/disable DocManager auto-save indexing process (vendor-supported method) and observe whether crash rate drops.

Specific remediation action if confirmed:
1. Emergency contain: stop further v2.1 expansion.
2. Roll back Legal-Win11 devices to v2.0 to restore stability quickly, prioritizing 4GB devices first.
3. Reintroduce v2.1 only via pilot ring using vendor-recommended configuration to limit or defer indexing on low-memory devices.

## 2) Concurrent first-run indexing storm from simultaneous deployment to all 45 devices
Why it fits the evidence:
- All devices completed install in a narrow time window, so first-run indexing likely started nearly together.
- Group-level disk I/O moved from Normal to High exactly after deployment completion.
- Even if root trigger is the v2.1 feature itself, full parallel rollout amplifies impact.

Fastest check to confirm/eliminate:
1. Check endpoint telemetry for spike concurrency of DocManager indexing threads/tasks starting between 09:45-10:15.
2. Compare with a staged/pilot rollout cohort (if available) to see whether staggered install lowers crash/I/O peaks.

Specific remediation action if confirmed:
1. Change deployment to staged waves (for example 10-20% rings with soak periods).
2. Schedule heavy first-run operations outside peak business hours.
3. Add temporary resource-throttling policy if vendor supports it.

## 3) Runtime regression in DocManager v2.1 not detected by SCCM install success
Why it fits the evidence:
- SCCM success validates installation completion, not runtime stability.
- Crash ownership heavily concentrated in one process (DocManager.exe 74%), indicating app-level defect/regression is plausible.
- Lower probability than Cause #1 because vendor note already predicts this specific behavior pattern.

Fastest check to confirm/eliminate:
1. Reproduce on test endpoints with 4GB and 8GB using v2.1 and monitor crash signatures.
2. Compare with v2.0 on same devices under similar workload.
3. Validate against vendor advisories/hotfix notes for v2.1.

Specific remediation action if confirmed:
1. Open vendor escalation with crash dumps and telemetry.
2. Hold production on v2.1.
3. Deploy vendor hotfix or remain on v2.0 until fixed release is validated.

## Error Code Handling Statement
- No explicit error codes were provided in the shared Nexthink/SCCM evidence.
- Therefore, no error code meanings are inferred or asserted in this analysis.

## Finalized Hypothesis (Single Best Explanation)
Primary hypothesis: The crash wave was caused by Legal Document Manager v2.1 auto-save indexing behavior on under-8GB devices, amplified by a simultaneous full-fleet rollout that concentrated first-run indexing load.

Confidence: High.

## Exact Remediation Steps (Resolution Plan)
1. Trigger incident containment:
- Freeze any further v2.1 rollout actions for Legal-Win11 immediately.

2. Restore service stability:
- Deploy rollback from Document Manager v2.1 to v2.0 for Legal-Win11.
- Prioritize 4GB devices first, then complete the remainder to normalize user impact rapidly.

3. Validate rollback completion:
- Confirm SCCM compliance shows rollback succeeded across targeted devices.

4. Confirm technical recovery in DEX:
- Verify crash rate and disk I/O begin returning toward pre-incident baseline.

5. Controlled reintroduction preparation:
- Build a pilot collection including representative 4GB and 8GB devices.
- Apply vendor-supported mitigation for auto-save indexing on low-memory devices before pilot release.

6. Re-release safely:
- Re-deploy v2.1 in staged rings only after pilot success criteria are met.

## Correct Order of Operations
1. Freeze rollout.
2. Roll back to v2.0 (4GB first, then remaining endpoints).
3. Confirm SCCM rollback success.
4. Verify DEX recovery (crash, I/O, DEX score).
5. Prepare pilot with mitigation controls.
6. Reintroduce v2.1 in staged rings with soak gates.

## Verification Checks After Remediation
Resolution is confirmed when all checks pass:
1. App crash rate in Legal-Win11 returns near baseline (target: <=0.5% sustained for at least 2 hours).
2. Disk I/O classification returns from High to Normal at group level.
3. DEX score recovers materially from 55-58 toward pre-incident range (target: >=85).
4. DocManager.exe is no longer the dominant crash process (target: substantial drop from 74% share).
5. Service desk reports show no continuing wave pattern from Floor 6 after rollback.

## Preventive Action (Stop Recurrence)
1. Introduce hardware-aware deployment gating:
- Do not deploy versions with known under-8GB risks to 4GB cohorts without mitigation.

2. Enforce ring-based rollout policy:
- Pilot -> early adopters -> broad rollout, with objective DEX thresholds between rings.

3. Add release-readiness checklist:
- Vendor known limitations review must map to actual fleet hardware profile before approval.

4. Add post-deployment guardrails:
- Automatic pause trigger if app crash rate or disk I/O crosses defined thresholds in first 60 minutes.

## Conclusion
Combined Nexthink + SCCM evidence indicates a deployment-linked runtime impact, not a random endpoint event. The fastest safe recovery path is rollback to v2.0, followed by controlled reintroduction of v2.1 with low-memory safeguards and staged deployment gates.