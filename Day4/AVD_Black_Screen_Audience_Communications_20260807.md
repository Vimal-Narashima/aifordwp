# AVD Black Screen - Audience Communications (Fact-Consistent)
Date: 2026-08-07
Source basis: AVD_Black_Screen_Analysis_20260806 + RCA_AVD_Black_Screen_POOL-FIN-01_20260806

## Audience 1 - Non-technical executive
Your access and data are safe. On 6 Aug, about 40% of users in finance desktop group POOL-FIN-01 had a black screen after sign-in between roughly 07:00 and 10:00; some recovered in about 30 seconds, others disconnected. POOL-FIN-02 was unaffected. The cause was a faulty 02:00 image update to POOL-FIN-01, now fixed and verified. If this reappears, sign out, sign back in, then contact IT Service Desk.

## Audience 2 - Affected end-user team (non-technical)
Your access and data are safe. On 6 Aug, between about 07:00 and 10:00, around 40% of people in the finance desktop group (POOL-FIN-01) saw a black screen after sign-in because a 02:00 overnight software image update introduced a display startup fault; some sessions recovered in about 30 seconds, others disconnected, and POOL-FIN-02 was unaffected. The fix has been applied and successful logins were verified by 10:00. If you see this again, sign out, sign back in, and contact the IT Service Desk.

## Audience 3 - Engineer-to-engineer internal note
Root cause:
- Primary cause: graphics/display stack regression introduced by the 02:00 image update to POOL-FIN-01.
- Failure mode: post-auth session init instability leading to black screen and/or disconnect.
- Event pattern on affected hosts: Event 21 (logon success) -> Event 1000 (dwm.exe crash) -> Event 40 (session disconnect) -> Event 9009 (DWM exit).
- Fault signature observed: dwm.exe faulting module igdumd64.dll, exception 0xc0000005 (sample host showed igdumd64.dll v31.0.101.4146).
- Isolation clue: POOL-FIN-02 had successful logons and no matching Event 1000 pattern in reviewed window.

Exact action taken:
- Containment:
	- Drained affected POOL-FIN-01 hosts from new sessions.
	- Routed new sessions to POOL-FIN-02 during mitigation.
- Mitigation:
	- Enforced software rendering path for RDS session rendering on impacted POOL-FIN-01 hosts.
	- Rebooted hosts in controlled waves to preserve capacity.
- Remediation:
	- Rebuilt from known-good image baseline.
	- Removed/rolled back problematic graphics driver package associated with the fault signature.
	- Pinned a known-stable display stack for redeployment.
	- Blocked faulty image from further assignment.

Config detail:
- Affected pool: POOL-FIN-01.
- Comparator pool: POOL-FIN-02 (unchanged overnight during incident start).
- Incident timing:
	- Image update at ~02:00 (POOL-FIN-01 only).
	- First user impact observed around ~07:00.
	- Service stabilized and verified by 10:00.
- User impact: approximately 40% of POOL-FIN-01 users.
- Symptom profile: black screen post-login; some sessions self-recovered at ~30s, others disconnected.

Verification step:
- Per-host technical checks (post-fix):
	- No new Application Error Event 1000 for dwm.exe faulting in igdumd64.dll during sign-in window.
	- No DWM termination Event 9009 during sign-in.
	- No immediate Event 40 disconnect trend after Event 21 logon success.
- Service checks:
	- Successful user logins to POOL-FIN-01 verified by 10:00.
	- No active issue reports at closure point.

Preventive action needed:
- Keep faulty image blocked and retain tested rollback path to last known-good image.
- Enforce canary deployment for AVD image changes before full pool rollout.
- Add hard promotion gates:
	- No Event 1000 (dwm.exe) in soak window.
	- No DWM error termination events (including 9009) during sign-in tests.
	- No Event 21 -> Event 1000 -> Event 40 correlation burst.
- Pin approved graphics driver baseline; require explicit approval for driver stack changes.
- Add post-rollout comparator checks against non-updated control pool.
- If recurrence is reported by users, instruct sign-out/sign-in retry and route to IT Service Desk while engineering triages event pattern above.
