# Root Cause Analysis — Account Lockout Incident
**Incident Reference:** INC-20260806-001  
**Date of Incident:** 2026-08-06  
**Date of RCA:** 2026-08-06  
**Analyst:** DWP Desktop/Endpoint Engineering  
**Classification:** LOW — Single user, no data loss, no security breach  

---

## 1. Incident Summary

User account `jsmith` was locked out at workstation `DESKTOP-FB001` following two consecutive failed interactive logon attempts between 08:02 and 08:06. The account remained locked for approximately 16 minutes until re-enabled by `FINBRIDGE\helpdesk-admin` at 08:22. The user successfully logged on at 08:23.

**Total user impact:** ~21 minutes of lost access (08:02 to 08:23).

---

## 2. Timeline of Events

| Time     | Event ID | Type          | Description |
|----------|----------|---------------|-------------|
| 08:02:14 | 4625     | Audit Failure | Interactive logon failed — "Unknown username or bad password" — `jsmith` at `DESKTOP-FB001` |
| 08:04:22 | 4625     | Audit Failure | Second interactive logon failed — same reason, same machine |
| 08:06:01 | 4740     | Audit Failure | Account `jsmith` locked out — triggered from `DESKTOP-FB001` |
| 08:07:45 | 4625     | Audit Failure | Workstation unlock attempt failed — failure reason now "Account locked out" (Logon type 7) |
| 08:22:10 | 4722     | Audit Success | Account `jsmith` re-enabled by `FINBRIDGE\helpdesk-admin` |
| 08:23:44 | 4624     | Audit Success | `jsmith` logged on successfully |

---

## 3. Evidence Assessment

### What the events confirm
- All failed logon attempts originated from a single machine (`DESKTOP-FB001`)
- Logon type 2 (Interactive) on the first two events confirms physical keyboard entry at the console — not a remote session, service account, or scheduled task
- Logon type 7 on the 08:07 event confirms the session had locked and the user attempted to unlock it — the account was already locked by this point
- The failure reason shifts from "Unknown username or bad password" (pre-lockout) to "Account locked out" (post-lockout), confirming the credential was correct once the account was re-enabled
- Re-enablement via helpdesk admin account indicates a standard support call was raised, consistent with a forgotten password scenario

### What the events rule out
- **Remote/network-based attack:** No remote logon types (3, 8, 10) present; all activity is from a single local console session
- **Credential stuffing or brute force:** Only two failed attempts visible; originating machine matches the user's assigned workstation
- **Malicious insider misuse:** Pattern (forgotten password → helpdesk call → immediate successful logon) is inconsistent with malicious activity
- **Service or script using stale credentials:** Logon type 2 is exclusive to interactive console sessions; a misconfigured service would typically show logon type 5

---

## 4. Root Cause Analysis — Five Whys

**Problem statement:** User `jsmith` was locked out of `DESKTOP-FB001` and unable to work for approximately 21 minutes.

---

**Why 1: Why was the account locked out?**  
The account lockout policy threshold was reached after multiple failed logon attempts from `DESKTOP-FB001` (Event 4740, 08:06:01).

---

**Why 2: Why did the logon attempts fail?**  
The password entered by `jsmith` did not match the credential stored for the account — Event 4625 failure reason: "Unknown username or bad password" (08:02:14 and 08:04:22). The account name itself was valid.

---

**Why 3: Why did the user enter the wrong password?**  
The most probable explanation, supported by the evidence (single machine, interactive logon, immediate successful logon after re-enablement), is that `jsmith` had forgotten their current password. This commonly occurs after:
- A recent forced password change (e.g., 90-day policy expiry)
- Return from annual leave or an extended period of absence
- Muscle memory from a previous password persisting

No password change event (4723/4724) is visible in the provided log window, but the absence of such an event in a 30-minute extract does not exclude a recent change.

---

**Why 4: Why did the user not recover without helpdesk involvement?**  
Once an account is locked out under domain policy, end users cannot self-unlock. There is no self-service password reset (SSPR) mechanism referenced in the available evidence. The user's only recourse was to call the helpdesk, which introduced the 16-minute delay between lockout (08:06) and re-enablement (08:22).

---

**Why 5: Why is there no self-service recovery path?**  
No SSPR solution (e.g., Microsoft Entra SSPR, on-premises equivalent) appears to be in place or accessible to this user. This may be due to:
- SSPR not yet deployed or licensed for this user population
- SSPR deployed but not communicated to / enrolled by the user
- The user not being aware of the self-service option

This is the systemic gap that converted a minor user error into a 21-minute productivity loss requiring helpdesk resource.

---

## 5. Root Cause Statement

**Immediate cause:** The user entered an incorrect password at their workstation console, reaching the account lockout threshold.

**Underlying cause:** The absence of an accessible self-service password reset mechanism meant the user could not recover independently, amplifying the impact of a routine user error into a 21-minute outage requiring helpdesk intervention.

---

## 6. Contributing Factors

| Factor | Detail |
|--------|--------|
| Account lockout threshold | Policy triggered after a small number of failures (≤2 observed; exact threshold TBC) |
| No SSPR available/enrolled | User unable to self-recover without helpdesk |
| Helpdesk response time | ~16 minutes elapsed between lockout and re-enablement |
| Password complexity/expiry policy | May have prompted a recent change the user had not fully memorised |

---

## 7. Impact Assessment

| Category | Detail |
|----------|--------|
| Users affected | 1 (`jsmith`) |
| Duration | ~21 minutes (08:02 – 08:23) |
| Data loss | None |
| Security breach | No |
| Helpdesk resource consumed | Yes — 1 re-enablement action by `FINBRIDGE\helpdesk-admin` |
| Business impact | Low — single user, short duration |

---

## 8. Recommendations

| Priority | Recommendation | Owner |
|----------|---------------|-------|
| HIGH | Verify whether SSPR is licensed and available; if so, ensure `jsmith` (and the wider user base) is enrolled and aware | Identity / IAM team |
| MEDIUM | Review account lockout policy threshold — consider whether the current setting (appears ≤2 attempts) is appropriate vs. usability trade-off | Security / GPO team |
| MEDIUM | Check whether a password expiry event preceded this lockout; if so, ensure users receive advance notification with clear reset instructions | Identity / Comms team |
| LOW | Add a user communication / intranet article on what to do when locked out, including SSPR steps if available | Service Desk / Comms |

---

## 9. Immediate Actions Taken

| Action | By | Time |
|--------|----|------|
| Account re-enabled | `FINBRIDGE\helpdesk-admin` | 08:22:10 |
| User confirmed successful logon | (inferred from Event 4624) | 08:23:44 |

No further immediate actions required. No security investigation warranted based on available evidence.

---

## 10. Lessons Learned

- A single user error (mistyped password) resulted in 21 minutes of lost productivity and consumed helpdesk time — the systemic gap is the lack of self-service recovery, not the lockout policy itself.
- Event ID correlation (4625 → 4740 → 4722 → 4624) provides a clear, auditable trail that makes this type of incident straightforward to diagnose and close quickly.
- If SSPR were in place and enrolled, this incident would have been resolved by the user in under 2 minutes with zero helpdesk involvement.

---

*RCA produced using anonymised/sanitised event log data in accordance with DWP Personal AI Usage Charter v1.0.*  
*All system references in this document should be verified against live records before use in formal change or incident management processes.*
