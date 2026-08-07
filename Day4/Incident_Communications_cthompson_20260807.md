# Incident Communications - Same Facts, Three Audiences

Date: 2026-08-07
Incident reference: cthompson login failure (resolved)

## Audience 1 - Non-technical executive
Your access is restored, and your data is safe. This morning, one user (cthompson) could not sign in from about 08:40 because repeated incorrect sign-in attempts temporarily locked the account, including attempts from the user computer and another saved sign-in source. Support re-enabled the account at 09:08 and sign-in succeeded at 09:09, with no further issues reported. No action is needed unless the issue returns; if it does, contact the helpdesk.

## Audience 2 - Affected end-user team (10 people, non-technical)
Hi team, this issue affected one user (cthompson) from around 08:40 until resolution at 09:09: repeated incorrect sign-in attempts from the user PC and another saved sign-in source temporarily locked the account, then support re-enabled it at 09:08 and login worked normally at 09:09 with no further issues. If you see the same problem, stop retrying your password and contact the helpdesk immediately so we can clear saved sign-in details and restore access quickly. Contact: IT Helpdesk.

## Audience 3 - Engineer-to-engineer internal note
Summary:
- Single-user incident: FINBRIDGE\cthompson unable to log on starting ~08:40.
- Resolved at 09:09 with successful interactive logon and user confirmation.

Root cause:
- Account lockout caused by repeated invalid credential submissions.
- Evidence indicates dual-source replay pattern: primary endpoint DESKTOP-FB022 plus secondary source IP 10.10.8.112 using wrong credentials.

Supporting evidence:
- 08:44:01 Event 4776 failure, 0xC000006A wrong password, source workstation DESKTOP-FB022.
- 08:44:03 / 08:44:28 / 08:44:55 Event 4625 failures, logon type 2 interactive, bad password, source DESKTOP-FB022.
- 08:44:56 Event 4740 account locked out, caller DESKTOP-FB022.
- 08:45:10 Event 4625 failure, logon type 7 unlock attempt, reason account locked out.
- 08:45:44 / 08:46:01 / 08:46:33 Event 4771 failures, pre-auth 0x18 wrong password, source IP 10.10.8.112.

Exact action taken:
- Account re-enabled by FINBRIDGE\helpdesk-admin.
- Re-authentication performed on DESKTOP-FB022.

Recovery verification:
- 09:08:14 Event 4722 success, account enabled, done by FINBRIDGE\helpdesk-admin.
- 09:09:01 Event 4624 success, logon type 2 interactive, source DESKTOP-FB022.
- User validated successful login and reported no further issues.

Config/detail notes:
- Host context: DESKTOP-FB022.
- Secondary failing source observed: 10.10.8.112 (not the primary desktop IP).
- Incident pattern aligns with stale saved credential replay from at least one additional source.

Preventive action needed:
- On future lockout cases, run mandatory secondary-source sweep before/at unlock: identify non-primary source IPs from 4740/4771/4625 chain, clear cached credentials across endpoint/apps/profiles, and monitor 30 minutes post-recovery for recurrence of 4776/4625/4771.
