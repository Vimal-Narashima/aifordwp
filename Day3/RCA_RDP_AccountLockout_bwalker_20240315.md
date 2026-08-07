# Root Cause Analysis — RDP Account Lockout
**Reference:** RCA-RDP-2024-0315  
**Date of Incident:** 2024-03-15  
**Date of RCA:** 2024-03-15  
**Analyst:** DWP Desktop/Endpoint Engineer  
**Severity:** Medium  
**Status:** Resolved

---

## 1. Incident Summary

At 14:01 on 2024-03-15, user account `FINBRIDGE\bwalker` was locked out of Active Directory following three consecutive failed Remote Desktop Protocol (RDP) logon attempts originating from client IP `10.10.5.44`. The account was subsequently unlocked and a successful RDP session was established at 14:22, confirming the lockout was not caused by a persistent attacker.

---

## 2. Timeline of Events

| Time | Event ID | Source | Description |
|------|----------|--------|-------------|
| 14:01:02 | 56 | TermDD | RDP security layer detected protocol stream error; client disconnected |
| 14:01:02 | 140 | RdpCoreTS | RDP connection rejected — incorrect username or password |
| 14:01:04 | 4625 | Security | Failed logon — FINBRIDGE\bwalker — Attempt 1 (Logon Type 10, RemoteInteractive) |
| 14:03:18 | 4625 | Security | Failed logon — FINBRIDGE\bwalker — Attempt 2 (Logon Type 10, RemoteInteractive) |
| 14:05:33 | 4625 | Security | Failed logon — FINBRIDGE\bwalker — Attempt 3 (Logon Type 10, RemoteInteractive) |
| 14:05:34 | 4740 | Security | Account FINBRIDGE\bwalker locked out by AD policy — triggered from 10.10.5.44 |
| 14:22:07 | 131 | RdpCoreTS | New TCP connection accepted from 10.10.5.44:52341 (post-unlock reconnect) |
| 14:22:09 | 4624 | Security | Successful logon — FINBRIDGE\bwalker — Logon Type 10, RemoteInteractive |

**Total lockout duration:** approximately 17 minutes (14:05:34 to ~14:22:07).

---

## 3. Impact Assessment

| Area | Detail |
|------|--------|
| User affected | 1 (FINBRIDGE\bwalker) |
| Service disrupted | Remote Desktop access |
| Data loss | None |
| Security risk | Low — single-source IP, same account, successful auth post-unlock |
| Business impact | User unable to access remote session for ~17 minutes |

---

## 4. Evidence Summary

- **Three Event ID 4625** records confirm exactly three failed logon attempts — all Logon Type 10 (RDP), same source IP (`10.10.5.44`), same account.
- **Event ID 4740** fired one second after the third failure, consistent with the AD lockout threshold being set to 3 invalid attempts.
- **No additional source IPs** were observed — ruling out a distributed brute-force or credential-stuffing attack.
- **Event ID 56 / 140** at 14:01:02 indicate the very first attempt also failed at the transport/security layer, suggesting stale or cached credentials were being used automatically (e.g. Windows Credential Manager).
- **Event ID 4624** at 14:22:09 — successful logon from the same IP confirms the correct password was known to the user; the earlier failures were not a deliberate attack.

---

## 5. Five Why Analysis

### Problem Statement
The Active Directory account `FINBRIDGE\bwalker` was locked out, preventing RDP access for approximately 17 minutes.

---

**Why 1 — Why was the account locked out?**  
Because the AD account lockout policy triggered after three consecutive failed logon attempts within the observation window.

*Evidence: Event ID 4740 at 14:05:34, one second after the third Event ID 4625.*

---

**Why 2 — Why did three failed logon attempts occur?**  
Because the RDP client at `10.10.5.44` presented incorrect credentials on each connection attempt.

*Evidence: All three Event ID 4625 records show "Unknown username or bad password"; Event ID 140 confirms the same at the RDP layer.*

---

**Why 3 — Why were incorrect credentials being presented?**  
Because the client was likely using saved/cached credentials (Windows Credential Manager or an RDP `.rdp` file with embedded credentials) that had not been updated following a recent password change.

*Evidence: Event ID 56 (TermDD protocol error at 14:01:02) indicates the first attempt failed before interactive input, consistent with automatic credential submission. The 2-minute gap between attempts 1–2 and 2–3 is consistent with a user manually retrying rather than an automated tool, but the initial automatic submission points to a cached credential as the trigger.*

---

**Why 4 — Why were the cached credentials not updated when the password changed?**  
Because there is no enforced process or user notification to prompt clearing or updating saved RDP credentials after a password change. Users are not routinely reminded to audit Credential Manager entries.

*Evidence: Inferred from the pattern — the user knew the correct password (successful logon at 14:22:09) but cached credentials contained the old one.*

---

**Why 5 — Why is there no process to clear or update saved RDP credentials after a password change?**  
Because the current end-user password change workflow (Active Directory self-service or helpdesk reset) does not include a step to notify the user to review and update stored credentials in Windows Credential Manager or saved RDP connection files.

*Evidence: Gap in documented password change runbook — no credential cache remediation step exists.*

---

## 6. Root Cause

**Stale cached RDP credentials in Windows Credential Manager (or a saved `.rdp` file) were automatically submitted after a password change, triggering the AD lockout policy before the user could intervene with the correct credentials.**

---

## 7. Contributing Factors

| Factor | Detail |
|--------|--------|
| AD lockout threshold | Set to 3 attempts — low threshold provides security but reduces tolerance for cached-credential scenarios |
| No credential cache notification | Password change process does not prompt users to clear saved credentials |
| RDP client behaviour | Windows RDP client silently retries with saved credentials without warning the user |
| No pre-lockout alert | No mechanism to warn the user or service desk that failed attempts are accumulating |

---

## 8. Corrective Actions

| # | Action | Owner | Priority | Target Date |
|---|--------|-------|----------|-------------|
| CA-01 | Update the password change runbook to include a step instructing users to clear saved credentials from Windows Credential Manager | Desktop Engineering / Service Desk | High | +7 days |
| CA-02 | Add a knowledge article to the self-service portal: "After changing your password, remove saved RDP credentials" | Knowledge Management | High | +7 days |
| CA-03 | Review AD lockout observation window — consider increasing from current value to reduce sensitivity to rapid cached-credential retries, balanced against brute-force risk | Identity & Access Management | Medium | +14 days |
| CA-04 | Investigate feasibility of a GPO or logon script that clears cached generic credentials on password change event (Event ID 4723/4724) | Desktop Engineering | Medium | +21 days |
| CA-05 | Include RDP cached credential guidance in the next security awareness communication to staff | Security Awareness | Low | +30 days |

---

## 9. Lessons Learned

- A short lockout threshold combined with automatic credential submission can cause legitimate users to lock themselves out without any malicious activity present.
- The successful logon at 14:22:09 from the same IP is a key differentiator from a brute-force scenario — always correlate Event ID 4740 with post-lockout 4624 events before escalating as a security incident.
- RDP Event IDs 56 and 140 provide early-stage transport/authentication context that complements Security log 4625 entries and should be included in standard lockout investigations.

---

## 10. References

| Reference | Detail |
|-----------|--------|
| Event ID 56 | TermDD — RDP security layer protocol error |
| Event ID 131 / 140 | RemoteDesktopServices-RdpCoreTS — TCP accepted / credential failure |
| Event ID 4625 | Security — Failed logon (Logon Type 10 = RemoteInteractive) |
| Event ID 4740 | Security — Account lockout |
| Event ID 4624 | Security — Successful logon |
| AD Lockout Policy | Default Domain Policy → Account Lockout Threshold |

---

*Document prepared in accordance with the DWP Personal AI Usage Charter. All account references reflect log data provided for analysis. No live PII or system secrets are included.*
