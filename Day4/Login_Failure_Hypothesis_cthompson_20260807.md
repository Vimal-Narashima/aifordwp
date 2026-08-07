# Login Failure Analysis and Hypotheses

Date: 2026-08-07  
Incident Scope: Single-user login failure (cthompson), started around 08:40, no declared change.

## Ranked Most-Likely Causes (Most Probable First)

1. **Account lockout triggered by repeated bad credentials from a saved source**
- Why this fits scope facts:
  - Only one user is affected, which strongly suggests a user-specific identity/authentication issue rather than a broad platform outage.
  - A sudden start time (~08:40) is consistent with lockout threshold being reached when the user began normal activity.
  - "No change" is still compatible with lockout, because background retries from cached credentials (phone mail app, mapped drive, scheduled task, old VPN profile) can trigger it without a deliberate user change.
- Single fastest check:
  - Check AD/Azure sign-in/lockout status for cthompson immediately (locked/unlocked + recent failed sign-in events and source).

2. **Password expired or password recently changed but old password is still being used on one endpoint/app**
- Why this fits scope facts:
  - Single-user impact aligns with credential lifecycle issues.
  - Morning onset is common when users first authenticate after password policy boundary or after overnight token/session expiry.
  - "No change" from user perspective can still occur if expiry window was reached automatically.
- Single fastest check:
  - Verify password expiry/change timestamp for cthompson and attempt a password validation/reset flow to confirm whether auth succeeds with current credential.

3. **User account disabled/restricted (temporary admin action, policy flag, or sign-in restriction)**
- Why this fits scope facts:
  - User-only failure with no wider blast radius can be caused by account state flags (disabled, restricted logon hours, workstation restrictions, risk-based blocks).
  - The specific start time supports a state transition happening before business hours.
- Single fastest check:
  - Inspect account state attributes and sign-in restrictions in identity admin console for cthompson (enabled status, restrictions, risk blocks).

4. **Corrupted local credential cache/profile on the user’s primary device**
- Why this fits scope facts:
  - A one-user incident can also be one-device + one-user, especially if identity is healthy but local logon processing fails.
  - Sudden start with no declared change is consistent with local cache/token/profile corruption or stale credential provider state.
- Single fastest check:
  - Attempt same-user sign-in on a known-good second device/session path; if successful there, the issue is likely local to the original endpoint.

5. **MFA/Conditional Access challenge failure specific to user registration/state**
- Why this fits scope facts:
  - Single-user impact fits user-bound MFA method issues (outdated authenticator registration, denied prompt, unreachable second factor).
  - Morning onset is common when fresh sign-in requires step-up auth after token expiry.
- Single fastest check:
  - Review the most recent sign-in failure reason for cthompson in Entra/Azure sign-in logs to confirm MFA/CA failure code.

## Notes
- This is a scope-based hypothesis set only; no single root cause is confirmed yet.
- Next action should be to run the fastest check for item 1 first, then proceed in rank order until one hypothesis is confirmed/eliminated.

## Evidence Assessment Against Each Hypothesis (Security Log 2024-03-15 08:44-09:12)

### 1) Account lockout triggered by repeated bad credentials from a saved source
- Judgement: **Supports**
- Why:
  - Repeated bad-password failures are recorded first from the desktop, then the account is explicitly locked out.
  - Additional wrong-password Kerberos failures continue from a different source IP, consistent with another saved credential source continuing retries.
- Determining events:
  - 08:44:01 Event 4776, error 0xC000006A (wrong password), source workstation DESKTOP-FB022.
  - 08:44:03 / 08:44:28 / 08:44:55 Event 4625 (bad password), logon type 2, source DESKTOP-FB022.
  - 08:44:56 Event 4740 (account locked out), caller computer DESKTOP-FB022.
  - 08:45:44 / 08:46:01 / 08:46:33 Event 4771, failure code 0x18 (wrong password), source IP 10.10.8.112.

### 2) Password expired or password recently changed but old password is still being used on one endpoint/app
- Judgement: **Supports**
- Why:
  - Wrong-password failures are consistent with stale credentials in use.
  - The second source IP (10.10.8.112) repeatedly submitting wrong credentials supports the "old password still cached somewhere" pattern.
  - No event here explicitly shows password-expired code, so support is pattern-based rather than conclusive.
- Determining events:
  - 08:44:01 Event 4776, error 0xC000006A (wrong password).
  - 08:45:44 / 08:46:01 / 08:46:33 Event 4771, failure code 0x18 (wrong password), source IP 10.10.8.112.

### 3) User account disabled/restricted (temporary admin action, policy flag, or sign-in restriction)
- Judgement: **Contradicts**
- Why:
  - Failures before lockout are bad-password failures, not disabled/restricted-account failures.
  - A lockout event is explicitly present, indicating the account was active enough to process invalid attempts up to threshold.
- Determining events:
  - 08:44:01 Event 4776, error 0xC000006A (wrong password).
  - 08:44:56 Event 4740 (account locked out).
  - 08:45:10 Event 4625 (failure reason: account locked out), indicating lockout state rather than disabled/restriction as primary cause.

### 4) Corrupted local credential cache/profile on the user’s primary device
- Judgement: **Neutral**
- Why:
  - Desktop interactive failures at 08:44:03/08:44:28/08:44:55 are compatible with local stale credentials or user mistype.
  - However, repeated wrong-password Kerberos failures from a different IP (10.10.8.112) show at least one non-local source is also involved, so local profile/cache corruption is not singled out by this evidence.
- Determining events:
  - 08:44:03 / 08:44:28 / 08:44:55 Event 4625 from DESKTOP-FB022.
  - 08:45:44 / 08:46:01 / 08:46:33 Event 4771 from source IP 10.10.8.112.

### 5) MFA/Conditional Access challenge failure specific to user registration/state
- Judgement: **Contradicts**
- Why:
  - All provided failures are primary credential failures (wrong password) and lockout outcomes.
  - There are no MFA/Conditional Access specific failure events in this dataset.
- Determining events:
  - 08:44:01 Event 4776, error 0xC000006A (wrong password).
  - 08:45:44 / 08:46:01 / 08:46:33 Event 4771, failure code 0x18 (wrong password).
  - 08:45:10 Event 4625 (account locked out).

## Assessment Constraint
- This section evaluates evidence per hypothesis only and intentionally does not select a single winning cause yet.

## Elimination Outcome (Now Selected)

Surviving hypothesis: **Account lockout triggered by repeated bad credentials from a saved source**.

### Evidence chain supporting the selected hypothesis
- 08:44:01 Event 4776 records wrong password (0xC000006A) for FINBRIDGE\cthompson from DESKTOP-FB022.
- 08:44:03, 08:44:28, and 08:44:55 Event 4625 records repeated interactive bad-password failures (logon type 2) from DESKTOP-FB022.
- 08:44:56 Event 4740 confirms the account lockout for FINBRIDGE\cthompson, caller computer DESKTOP-FB022.
- 08:45:10 Event 4625 shows follow-on failure reason "Account locked out" (logon type 7 unlock attempt).
- 08:45:44, 08:46:01, and 08:46:33 Event 4771 records continued wrong-password Kerberos pre-auth failures (0x18) from 10.10.8.112, indicating an additional credential source continuing retries.

### Conclusion statement
- The failure pattern is consistent with bad credential replay leading to lockout, not a platform-wide authentication outage.

## Incident Addendum - Event Details, Survived Hypothesis, Resolution

Date added: 2026-08-07

### Event details (incident window 08:44-09:12)
- 08:44:01 - Event 4776 (Audit Failure): DC credential validation failed for FINBRIDGE\cthompson, error 0xC000006A (wrong password), source workstation DESKTOP-FB022.
- 08:44:03 - Event 4625 (Audit Failure): Interactive logon failure (type 2), bad username/password, source DESKTOP-FB022.
- 08:44:28 - Event 4625 (Audit Failure): Interactive logon failure (type 2), bad username/password, source DESKTOP-FB022.
- 08:44:55 - Event 4625 (Audit Failure): Interactive logon failure (type 2), bad username/password, source DESKTOP-FB022.
- 08:44:56 - Event 4740 (Audit Failure): Account FINBRIDGE\cthompson locked out, caller computer DESKTOP-FB022.
- 08:45:10 - Event 4625 (Audit Failure): Unlock attempt failure (type 7), failure reason account locked out, source DESKTOP-FB022.
- 08:45:44 - Event 4771 (Audit Failure): Kerberos pre-auth failed, code 0x18 (wrong password), source IP 10.10.8.112.
- 08:46:01 - Event 4771 (Audit Failure): Kerberos pre-auth failed, code 0x18 (wrong password), source IP 10.10.8.112.
- 08:46:33 - Event 4771 (Audit Failure): Kerberos pre-auth failed, code 0x18 (wrong password), source IP 10.10.8.112.

### Survived hypothesis
- **Account lockout triggered by repeated bad credentials from a saved source** (desktop plus secondary source at 10.10.8.112 continuing wrong-password attempts).

### Resolution
- 1. Unlock account FINBRIDGE\cthompson and force password reset to a known-good value.
- 2. Re-authenticate user on DESKTOP-FB022 with new credentials.
- 3. Identify asset/service using source IP 10.10.8.112 and remove/update cached credentials (mail client, mapped drives, scheduled task, mobile profile, VPN profile, or service binding).
- 4. Remove stale saved credentials from Windows Credential Manager and any connected apps for cthompson.
- 5. Validate closure by confirming successful logon and no new Event 4776/4625/4771 failures for at least 15-30 minutes after remediation.
