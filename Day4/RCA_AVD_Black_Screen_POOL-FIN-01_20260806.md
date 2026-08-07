# Root Cause Analysis (RCA)
## Incident: AVD Black Screen Post Login - POOL-FIN-01

- Date: 2026-08-06
- Incident window: First user impact observed around 07:00; service stabilized and verified at 10:00
- Affected environment: POOL-FIN-01
- Unaffected comparator: POOL-FIN-02
- Severity: Major user-impacting login instability (partial pool impact)
- Current status: Resolved

## 1) Executive Summary
At approximately 07:00, users on POOL-FIN-01 began experiencing a black/blank screen immediately after login. Some sessions recovered after about 30 seconds; others disconnected or remained unusable. Approximately 40% of users on POOL-FIN-01 were affected. POOL-FIN-02 remained fully unaffected.

Evidence showed repeated Desktop Window Manager (DWM) application crashes on affected hosts, with faulting module `igdumd64.dll` and immediate session disconnect behavior after successful logon. This pattern started after an overnight image update applied only to POOL-FIN-01 at 02:00. The issue was resolved after applying the recommended mitigation/remediation approach, and by 10:00 verified users were logging in successfully to POOL-FIN-01 with no further reported issues.

## 2) Scope and Impact
- Symptom: Blank screen after sign-in; transient for some users, persistent for others.
- User impact: ~40% of users on POOL-FIN-01.
- Business impact: Delayed start of workday and session instability for finance user group.
- Isolation clue: POOL-FIN-02 (not updated overnight) had no impact.

## 3) Supporting Evidence
### 3.1 Change Evidence
- Overnight image update applied to POOL-FIN-01 at approximately 02:00.
- POOL-FIN-02 was not updated.

### 3.2 Host Event Log Evidence (Affected Host: SHFIN-01-A)
Time window reviewed: 07:00-07:30 (Application + System logs)

- 07:02:10 - Microsoft-Windows-TerminalServices-LocalSessionManager, Event ID 21
  - Session logon succeeded (user FINBRIDGE\\mlopez, session 3)
- 07:02:14 - Microsoft-Windows-Kernel-General, Event ID 1
  - Host boot time 02:03:11 (post-update reboot indicator)
- 07:02:16 - Application Error, Event ID 1000
  - Faulting application: dwm.exe
  - Faulting module: igdumd64.dll (v31.0.101.4146)
  - Exception code: 0xc0000005
- 07:02:17 - Microsoft-Windows-TerminalServices-LocalSessionManager, Event ID 40
  - Session disconnected
- 07:02:18 - Desktop Window Manager, Event ID 9009
  - DWM exited with error code 0x40010004
- 07:02:44 - Event ID 21 (reconnect logon succeeded)
- 07:02:46 - Event ID 1000 (repeat dwm.exe fault in igdumd64.dll)
- 07:02:47 - Event ID 40 (repeat disconnect)
- 07:03:01 - Event ID 9009 (repeat DWM exit)
- 07:03:10 - Event ID 21 (second reconnect logon succeeded, new session)
- 07:08:22 - Event ID 21 (another user logon succeeded)
- 07:08:24 - Event ID 1000 (same dwm.exe/igdumd64.dll crash signature)

### 3.3 Comparator Evidence (Unaffected Host: SHFIN-02-A, POOL-FIN-02)
- 07:01:44 - Event ID 21 (logon succeeded)
- 07:01:46 - Desktop Window Manager, Event ID 9011 (DWM started successfully)
- No Application Error Event ID 1000 in reviewed period

### 3.4 Evidence Interpretation
The consistent sequence on affected hosts is:
1. Logon success (Event 21)
2. DWM crash in graphics module (Event 1000, igdumd64.dll)
3. Session disconnect (Event 40)
4. DWM termination event (Event 9009)

This supports a display stack regression on updated hosts, not a generic authentication or profile-delay-only issue.

## 4) Timeline (UTC/local as captured in logs)
- 02:00 - Image update deployed to POOL-FIN-01.
- 02:03 - Affected host rebooted (Kernel-General Event ID 1 boot-time indicator).
- ~07:00 - User-facing symptoms begin (first reports of black screen post-login).
- 07:02-07:08 - Repeated DWM crash/disconnect pattern recorded on SHFIN-01-A.
- 07:00-09:xx - Triage and hypothesis elimination performed using event evidence and pool comparison.
- 09:xx - Recommended mitigation/remediation steps applied to POOL-FIN-01.
- 10:00 - Issue resolved; verified users successfully logging in to POOL-FIN-01; no active issue reports.

## 5) Hypothesis Review Outcome
Initial ranked hypotheses were tested against evidence:
- FSLogix/profile attach regression: Contradicted by immediate DWM crash pattern.
- Shell initialization/display path regression: Supported.
- Synchronous logon processing (GPO/script/task): Contradicted by crash-first pattern.
- AVD component skew after refresh: Indirectly supported by post-update isolation.
- Resource contention: Contradicted by deterministic crash signature.

Surviving hypothesis became the working root-cause path:
- DWM/shell initialization failure due to graphics stack regression introduced in updated POOL-FIN-01 image.

## 6) Root Cause Statement
The black screen incident on POOL-FIN-01 was caused by a graphics/display stack regression introduced by the overnight image update, evidenced by repeated `dwm.exe` crashes in `igdumd64.dll` immediately after successful user logon on affected hosts. Because POOL-FIN-02 was not updated and remained unaffected, the failure was isolated to the updated image lineage.

## 7) 5-Why Analysis
1. Why did users see a black screen and/or disconnect after login?
- Because Desktop Window Manager (DWM) crashed during session initialization.

2. Why did DWM crash?
- Because `dwm.exe` repeatedly faulted in `igdumd64.dll` with access violation `0xc0000005`.

3. Why was that graphics fault occurring in production sessions?
- Because the overnight updated image in POOL-FIN-01 introduced an unstable/incompatible display driver stack for this AVD session scenario.

4. Why did the unstable driver stack reach the production pool?
- Because pre-release validation did not sufficiently exercise multi-user AVD sign-in/render scenarios against the exact image/driver combination.

5. Why was validation insufficient?
- Because the image promotion gate lacked mandatory session-host graphics stability checks (DWM crash scan, reconnect stress, and cross-pool canary validation) before broad pool rollout.

Process-level root cause:
- Image release governance gap: missing hard quality gates for graphics/render stability in AVD host image promotion.

## 8) Resolution Implemented
The previously recommended mitigation/remediation path was applied to POOL-FIN-01, then validated through user sign-in outcomes and incident monitoring.

Implemented outcome:
- Service stabilized by 10:00.
- Verified users successfully logged into POOL-FIN-01 hosts.
- No further active issue reports at closure point.

## 9) Preventive and Corrective Actions (CAPA)
### 9.1 Immediate Corrective Controls
- Keep faulty image version blocked from further host assignments.
- Preserve impacted host logs and image metadata for post-incident review.
- Maintain a tested rollback path to last known-good image for the pool.

### 9.2 Preventive Engineering Controls
- Introduce mandatory image canary phase:
  - Deploy to small subset of hosts first.
  - Require successful sign-in/reconnect cycles with representative users.
- Add automated validation gates before production promotion:
  - No Event ID 1000 for dwm.exe in soak window.
  - No DWM error termination events (e.g., 9009) during sign-in tests.
  - No immediate post-logon disconnect trend (Event 40 after Event 21).
- Pin approved graphics driver baseline for AVD images and require exception approval for driver changes.
- Add pool-to-pool comparator checks in release checklist (updated vs non-updated control pool).

### 9.3 Operational Process Improvements
- Update AVD image release SOP with explicit go/no-go criteria and rollback trigger thresholds.
- Create an incident runbook for black-screen triage with event-sequence decision tree.
- Require documented sign-off from endpoint engineering and service owner before image promotion.

### 9.4 Monitoring and Alerting
- Add alert rule for burst of Application Error Event ID 1000 where faulting app is `dwm.exe`.
- Add correlation alert for Event 21 -> Event 1000 -> Event 40 within a short interval.
- Track login success latency and disconnect rate per pool after each image rollout.

## 10) Validation at Closure
- Resolution time confirmed: 10:00.
- User validation: confirmed successful logins to POOL-FIN-01.
- Monitoring signal at closure: no ongoing issue reports.

## 11) Residual Risk
- Medium until corrected image has passed canary and full business-cycle soak with enforced validation gates.

## 12) Lessons Learned
- Pool-isolation timing clues can quickly narrow probable root-cause domain.
- Event-sequence patterning (Event 21 + Event 1000 + Event 40 + Event 9009) is high-value for rapid elimination.
- Graphics stack changes in AVD images require stricter pre-production validation than generic OS patch checks.

## 13) Follow-up Owners and Target Dates
- Endpoint Engineering: Implement image gating automation and driver baseline policy.
- AVD Operations: Add event-correlation alerting and post-rollout health dashboard.
- Service Management: Update release SOP and incident runbook.
- Target: Complete CAPA actions before next scheduled image refresh.

---
Document prepared for incident record and post-incident review.
