# Root Cause Analysis (RCA): Citrix Session Failure (AVD-backed)

Date of RCA: 2026-08-14  
Incident reference: Day9 session failure scenario  
Environment: AVD host pool POOL-FIN-01, session host avd-fin-01

## Executive Summary
A user session failure occurred while attempting to access the published desktop. The most direct and evidenced technical cause was session host unavailability linked to an incorrect/incomplete Entra join and registration state. Once join state was corrected and registration health restored, the host became Available and accepted sessions.

No explicit platform error codes were included in the provided dataset; no error code interpretation is asserted in this RCA.

## Supporting Evidence
1. Setup record confirms session host had an Unavailable period prior to remediation.
2. VM-side diagnostics and dsregcmd were explicitly used to identify the join issue.
3. Post-fix identity state was validated as:
   - AzureAdJoined: YES
   - DomainJoined: NO
4. Final control-plane state confirmed:
   - Session host status: Available
   - Allow new sessions: True
   - Current sessions: 0
5. Access prerequisites were already in place:
   - Desktop Virtualization User assigned on DAG scope.
   - Virtual Machine User Login assigned on VM scope.
6. Separate earlier provisioning failure existed (image/patch incompatibility), corrected by patch mode Manual + automatic updates disabled.

## Timeline (Based on Recorded Sequence)
Note: Exact clock timestamps were not captured in supplied evidence; sequence below reflects confirmed order.

1. AVD stack deployed (host pool, DAG, workspace, VM).
2. User access assignments applied.
3. VM provisioning issue encountered (incompatible patch settings with selected image).
4. Provisioning configuration corrected (Manual patch mode, automatic updates disabled).
5. Session host observed as Unavailable.
6. Diagnostics executed on VM and control plane; join issue identified.
7. Join issue remediated; dsregcmd validated expected Entra-only state.
8. Final verification showed session host Available and accepting new sessions.

## Impact Statement
- User-facing impact: inability to establish remote desktop session during failure window.
- Service impact scope: at least the targeted host/user path; wider pool impact not evidenced in provided data.
- Business impact: delayed desktop access and potential productivity loss.

## Technical Root Cause
Primary root cause:
- Session host registration/availability breakdown due to incorrect or incomplete Entra join state at the time of failure.

Contributing factor:
- Initial infrastructure instability from VM image and patch configuration mismatch increased setup fragility and likely delayed stabilization.

## 5 Whys Analysis
1. Why did the user session fail?
- Because the broker could not place/maintain the session on a healthy available host.

2. Why was the host not healthy/available?
- Because the host was in Unavailable state and not reliably registered for session brokering.

3. Why was host registration unhealthy?
- Because Entra join/registration state on the VM was incorrect/incomplete for the intended Entra-only join model.

4. Why was this not prevented before user validation?
- Because release gating did not enforce mandatory pre-flight checks for join-state correctness and host registration health.

5. Why were pre-flight controls missing?
- Because deployment focused on resource creation success, not end-to-end readiness validation (identity, agent, entitlement, and image-policy compatibility).

Root process gap identified:
- Absence of a standardized go-live health gate for session hosts.

## Final Corrective Actions Implemented
1. Corrected Entra join issue on session host.
2. Validated dsregcmd expected state (AzureAdJoined YES / DomainJoined NO).
3. Confirmed session host control-plane recovery to Available with AllowNewSessions=True.
4. Earlier in sequence, corrected image-policy mismatch by setting Manual patch mode and disabling automatic updates.

## Correct Order of Operations for Recovery (Runbook)
1. Confirm host pool session host status and allow-new-sessions flag.
2. On affected VM, validate join state with dsregcmd /status.
3. Repair Entra join/registration state if incorrect.
4. Validate/re-register host with host pool if stale.
5. Restart AVD agent services.
6. Re-check control-plane status until Available.
7. Validate user entitlement path (DAG assignment + workspace linkage).
8. Execute test user session launch and confirm stable sign-in.

## Verification of Resolution
Resolution is confirmed when all checks below are true:
1. Session host status is Available.
2. AllowNewSessions is True.
3. dsregcmd /status shows expected Entra-only join outcome.
4. Test user can launch desktop without failure/disconnect.
5. No new critical broker/agent registration errors appear during validation window.

## Preventive Actions
1. Introduce a mandatory pre-release health gate for each new session host:
- Join-state compliance check.
- Agent/registration health check.
- Entitlement check for pilot user.
- Image/patch policy compatibility check.

2. Add deployment policy guardrails:
- Enforce validated VM image + patch policy combinations through IaC policy rules.

3. Add operational monitoring:
- Alert when host transitions to Unavailable or fails registration heartbeat.

4. Add post-change validation standard:
- Require successful pilot sign-in before declaring service ready.

## Residual Risk
- If only one host exists in pool, any single-host health issue can reintroduce outage risk.
- Mitigation: maintain at least two healthy hosts for production-grade resilience.

## Closure Recommendation
Close incident only after:
1. Evidence artifacts are attached (dsregcmd output, host status proof, successful user launch).
2. Health-gate automation is scheduled/implemented with ownership and due date.
3. Monitoring alert rules for host availability are active.
