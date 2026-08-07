# Root Cause Analysis (RCA) - User Logon Failure

Date: 2026-08-07  
Incident Type: Single-user authentication failure and account lockout  
Affected User: FINBRIDGE\cthompson  
Primary Host: DESKTOP-FB022  
Incident Status: Resolved

## 1. Executive Summary
At approximately 08:40, user FINBRIDGE\cthompson reported inability to log in. Security logs show repeated wrong-password attempts from DESKTOP-FB022 followed by account lockout, then continued Kerberos wrong-password attempts from a second source IP (10.10.8.112). Resolution actions were applied, and service was restored. Successful interactive logon was confirmed at 09:09:01, with no further issues reported.

## 2. Scope and Impact
- Scope: One affected user only (FINBRIDGE\cthompson).
- Business impact: User could not access workstation session during incident window.
- Start time: Approximately 08:40.
- End time: 09:09 (confirmed successful logon).
- Platform impact: No evidence of wider authentication platform outage.

## 3. Supporting Evidence
### 3.1 Failure-chain evidence
- 08:44:01 - Event 4776 (Audit Failure): Domain credential validation failed, error 0xC000006A (wrong password), account FINBRIDGE\cthompson, source DESKTOP-FB022.
- 08:44:03 - Event 4625 (Audit Failure): Interactive logon failure (type 2), bad username/password, source DESKTOP-FB022.
- 08:44:28 - Event 4625 (Audit Failure): Interactive logon failure (type 2), bad username/password, source DESKTOP-FB022.
- 08:44:55 - Event 4625 (Audit Failure): Interactive logon failure (type 2), bad username/password, source DESKTOP-FB022.
- 08:44:56 - Event 4740 (Audit Failure): Account locked out, account FINBRIDGE\cthompson, caller DESKTOP-FB022.
- 08:45:10 - Event 4625 (Audit Failure): Unlock attempt (type 7) failed due to account locked out, source DESKTOP-FB022.
- 08:45:44 - Event 4771 (Audit Failure): Kerberos pre-auth failed, failure code 0x18 (wrong password), source IP 10.10.8.112.
- 08:46:01 - Event 4771 (Audit Failure): Kerberos pre-auth failed, failure code 0x18 (wrong password), source IP 10.10.8.112.
- 08:46:33 - Event 4771 (Audit Failure): Kerberos pre-auth failed, failure code 0x18 (wrong password), source IP 10.10.8.112.

### 3.2 Recovery and closure evidence
- 09:08:14 - Event 4722 (Audit Success): User account enabled, account FINBRIDGE\cthompson, action by FINBRIDGE\helpdesk-admin.
- 09:09:01 - Event 4624 (Audit Success): Successful interactive logon (type 2), account FINBRIDGE\cthompson, source DESKTOP-FB022.
- User validation: User confirmed access restored and no further issue reported.

## 4. Timeline (End-to-End)
1. ~08:40 - User reports inability to log in.
2. 08:44:01 to 08:44:55 - Repeated wrong-password failures recorded from DESKTOP-FB022 (Events 4776 and 4625).
3. 08:44:56 - Account lockout triggered (Event 4740).
4. 08:45:10 - Unlock attempt fails because account remains locked (Event 4625, type 7).
5. 08:45:44 to 08:46:33 - Continued wrong-password Kerberos attempts from secondary source 10.10.8.112 (Event 4771).
6. 09:08:14 - Account enabled by helpdesk-admin (Event 4722).
7. 09:09:01 - Successful interactive logon on DESKTOP-FB022 (Event 4624).
8. Post 09:09 - User confirms normal access; incident closed.

## 5. Root Cause Statement
The login failure was caused by account lockout after repeated invalid credential submissions for FINBRIDGE\cthompson. Evidence indicates invalid password attempts from the primary workstation and an additional secondary source (10.10.8.112), consistent with stale or saved credentials continuing to replay and driving lockout.

## 6. 5-Why Analysis
1. Why did the user fail to log in?
The account was in a locked-out state.

2. Why was the account locked?
The lockout threshold was reached by repeated bad-password attempts.

3. Why were repeated bad-password attempts occurring?
Wrong credentials were submitted multiple times from DESKTOP-FB022 and also from source IP 10.10.8.112.

4. Why were wrong credentials still being submitted from more than one source?
A saved/cached credential source was still using outdated credentials after the valid credential state changed.

5. Why was this not prevented earlier?
There was no immediate containment step to identify and clear all secondary credential stores/sources at first detection, allowing continued replay attempts.

## 7. Resolution Actions Applied
1. Account was re-enabled by helpdesk admin (Event 4722 at 09:08:14).
2. User re-attempted sign-in on DESKTOP-FB022.
3. Successful interactive authentication was recorded (Event 4624 at 09:09:01).
4. User confirmed restoration of service with no immediate recurrence.

## 8. Preventive Actions
1. Implement a lockout triage checklist requiring mandatory review of secondary auth sources (mobile mail, VPN profiles, mapped drives, scheduled tasks, service accounts, legacy apps) for every lockout case.
2. Add rapid source-correlation step in triage using lockout and Kerberos failure events to identify non-primary source IPs before unlock/reset.
3. Require credential cache cleanup on user endpoint as part of closure criteria (Credential Manager and affected apps).
4. Add short monitoring window after unlock/reset (minimum 30 minutes) with explicit check for recurrence of Events 4776, 4625, 4771.
5. Publish user guidance for password-change hygiene: update saved credentials across all devices immediately after password change/reset.

## 9. Verification and Closure Criteria
- Technical verification met: Event 4624 success at 09:09:01 confirms restored interactive logon.
- Administrative verification met: Event 4722 confirms account enabled action completed.
- User verification met: User confirmed successful login and no ongoing issue.
- Incident disposition: Resolved and closed.
