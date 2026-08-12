# FinBridge Connect v3.1 Intune Phased Deployment Plan
Date: 2026-08-12
Deadline: 2026-09-02 (3 weeks)
Scope: 10,000 Windows 11 endpoints

## 1. RING STRUCTURE

Ring design assumes production deployment to all 10,000 endpoints by deadline, with controlled exposure and measurable quality gates.

| Ring | Size | Duration | Who to include | Purpose | Intune assignment group type |
|---|---:|---|---|---|---|
| Ring 1 (Pilot) | 300 devices (3%) | 5 calendar days (2 days deployment + 3 days monitoring) | IT endpoint engineers, service desk champions, application owners, mixed hardware sample including at least 30 devices from the 4GB RAM cohort | Validate install, detection, launch, sign-in, and basic workflows on representative estate before broader exposure | Assigned (static) Microsoft Entra device security group: `APP-FinBridge-v3.1-Ring1-Pilot-Devices` |
| Ring 2 (Early) | 2,200 devices (22%) | 7 calendar days (3 days staged deployment + 4 days monitoring) | Early-adopter business units, selected operations teams, non-critical departments; exclude unresolved-risk cohorts | Validate scale behavior, support load, and business process fit before broad rollout | Dynamic Microsoft Entra device group (rule-based) with explicit exclusions for blocked cohorts: `APP-FinBridge-v3.1-Ring2-Early-Devices` |
| Ring 3 (Broad) | 7,500 devices (75%) | 9 calendar days (5 days staged rollout + 4 days hypercare) | All remaining in-scope Win11 endpoints not in exclusion groups | Complete rollout to full estate while maintaining controlled throttle and rollback readiness | Dynamic Microsoft Entra device group for remainder population: `APP-FinBridge-v3.1-Ring3-Broad-Devices` |

Staging notes:
- Use device-targeted Required assignment for all rings to ensure predictable endpoint compliance reporting.
- Keep a dedicated at-risk hardware group (4GB RAM) throughout: `APP-FinBridge-4GB-RAM-AtRisk-Devices`.
- Maintain v3.0 app object and assignments in disabled-ready state for immediate rollback reuse.

## 2. ADVANCE CRITERIA

Advance gates are evaluated from Intune Win32 app install status plus service desk incident tagging (`FinBridge-v3.1`) at ring level.

### Ring 1 to Ring 2 (Gate check at end of Ring 1 monitoring window)
- Install success rate: at least 97.0% `Installed` status among Ring 1 targeted devices within 72 hours of assignment.
- Error rate threshold: at most 2.0% in `Failed` status within same 72-hour window.
- User-reported issue threshold: at most 3.0 tickets per 100 deployed users over the 72-hour monitoring period.
- Monitoring period minimum: do not evaluate before 72 continuous hours after last pilot device receives assignment.

### Ring 2 to Ring 3 (Gate check at end of Ring 2 monitoring window)
- Install success rate: at least 98.0% `Installed` status among Ring 2 targeted devices within 96 hours of assignment.
- Error rate threshold: at most 1.5% in `Failed` status within same 96-hour window.
- User-reported issue threshold: at most 2.0 tickets per 100 deployed users over the 96-hour monitoring period.
- Monitoring period minimum: do not evaluate before 96 continuous hours after last Ring 2 wave assignment.

### Hold condition (pause without full rollback)
Trigger a controlled hold (pause next wave) when a non-critical but repeatable defect exceeds trend threshold:
- Hold trigger: same defect category appears in 1.0% to 2.9% of active ring users over any rolling 24-hour window, while install success and failure thresholds are still within gate.
- Action: pause new assignments for the next ring, keep current ring running, open vendor/internal fix track, and re-evaluate after 24 hours of post-fix telemetry.
- Specific example: after Ring 2 starts, 28 of 2,200 users (1.27%) report intermittent export-to-CSV failure, but app launches and installs remain healthy. Pause Ring 3 assignment until defect fix or workaround is validated.

## 3. ROLLBACK TRIGGERS

A rollback trigger halts expansion immediately. Depending on severity, response is either full reversion to v3.0 or targeted isolation.

### Trigger A: Install failure rate automatic halt
- Threshold: failure rate at or above 5.0% in any active ring over a rolling 6-hour window after assignment.
- Decision owner: Endpoint Engineering Lead (primary) with Major Incident Manager informed.
- Decision window: 30 minutes from threshold confirmation.
- Exact Intune action:
  1) Remove or set uninstall for v3.1 Required assignment on active ring groups.
  2) Assign FinBridge v3.0 as Required to same ring groups (`APP-FinBridge-v3.1-RingX-*` groups reused as v3.0 targets).
  3) Freeze progression by disabling next-ring assignment schedule.

### Trigger B: Application crash rate rollback consideration
- Threshold: crash rate at or above 2.0 crashes per 100 active devices in 24 hours, sustained for two consecutive 24-hour periods in the same ring.
- Data source: endpoint app reliability telemetry correlated to FinBridge executable version 3.1.
- Decision owner: CAB delegate (Change Manager) with Endpoint Lead and App Owner.
- Decision window: 4 hours after second 24-hour breach confirmation.
- Exact Intune action if approved:
  1) Halt v3.1 assignments to all not-yet-deployed rings.
  2) For affected deployed rings, deploy v3.0 as Required.
  3) Keep v3.1 only on controlled troubleshooting cohort (`APP-FinBridge-v3.1-Diagnostics-Devices`, max 50 devices).

### Trigger C: Business-critical failure immediate rollback
- Specific scenario: authenticated Finance users cannot submit payment batch approvals in FinBridge v3.1 (core revenue-impacting workflow blocked) with confirmed reproducibility in production.
- Threshold: one confirmed reproducible incident is sufficient; no percentage threshold required.
- Decision owner: Incident Manager plus Finance Service Owner (joint immediate authority).
- Decision window: 15 minutes from technical confirmation.
- Exact Intune action:
  1) Immediate stop of all v3.1 assignments across all rings.
  2) Assign v3.0 Required to every group currently targeted by v3.1.
  3) Mark v3.1 deployment as blocked in change record until defect fix and retest complete.

### Trigger D: 4GB RAM at-risk device failure ring isolation
- Threshold: at or above 8.0% install failure OR at or above 10.0% severe performance incidents (startup time >60s or repeated app not responding) within the 4GB group over a 24-hour window.
- Decision owner: Endpoint Engineering Lead.
- Decision window: 2 hours from breach detection.
- Exact Intune action:
  1) Remove `APP-FinBridge-4GB-RAM-AtRisk-Devices` from all v3.1 Required assignments.
  2) Assign v3.0 Required to `APP-FinBridge-4GB-RAM-AtRisk-Devices`.
  3) Continue v3.1 rollout for non-4GB cohorts if other rollback triggers are not met.

## 4. FINANCE DEADLINE RESOLUTION

Finance requires 500 users by end of week 1. Base ring cadence risks missing this unless timeline is adjusted.

### Option A - Compress pilot to place Finance in Ring 2 by end of week 1
- Minimum safe pilot duration: 72 hours total (24-hour deployment + 48-hour monitoring) with at least 200 pilot devices including 20 from 4GB cohort.
- Risk introduced: lower observation time may miss latent stability/performance defects that appear after longer usage cycles.
- Compensating control: increase Ring 2 throttle for Finance to 3 waves (200, 200, 100) every 8 hours with live war-room monitoring and immediate pause authority.

### Option B - Create Finance Priority Ring 0 before main pilot
- Ring 0 structure: 500 Finance users/device targets split into 5 waves of 100 devices over 2 days; include only Finance endpoints and finance-critical support contacts.
- Ring 0 advance conditions to continue each wave:
  - At least 98.0% install success per completed wave within 8 hours.
  - At most 1.0% failed installs per wave.
  - At most 2 high-severity tickets per 100 users per wave in first 8 hours.
- Ring 0 rollback plan:
  - If any wave breaches thresholds or any payment approval workflow failure is confirmed, stop remaining waves immediately and assign v3.0 Required back to Finance group.
  - Decision owner: Incident Manager + Finance Service Owner.
  - Decision window: 15 minutes for critical workflow break, 60 minutes for threshold breach.

### Recommendation (single decision)
Recommend Option B (Finance Priority Ring 0).

Justification:
- Meets mandatory Finance deadline by end of week 1 with explicit protection for revenue-critical workflows.
- Preserves integrity of main Ring 1 pilot for broader estate learning instead of shortening telemetry windows for all users.
- Contains business risk to the group with urgent need while keeping overall 3-week rollout governance intact.
- Uses v3.0 availability as a fast safety net specifically for Finance if workflow regression appears.

Execution order with Option B:
1. Run Ring 0 (Finance 500) in week 1 days 1-2 with strict wave gates.
2. Run standard Ring 1 pilot in parallel starting week 1 day 1 (separate population).
3. Progress to Ring 2 and Ring 3 only when Section 2 criteria are met.
4. Complete full estate by week 3 deadline with hypercare through end of rollout window.
