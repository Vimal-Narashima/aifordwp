Symptom: Users on impacted Floor 3 Finance Windows 11 endpoints experienced incomplete or failed Group Policy processing at startup. The user-facing condition was startup sign-in settings not applying correctly.

Cause: The verified root cause was incorrect DNS assignment to affected endpoints, specifically a retired DNS server value (10.10.3.250) delivered on the affected path. This caused domain controller name-resolution failure, which then blocked secure channel setup and SYSVOL access during startup Group Policy processing.

Scope: The incident affected Floor 3 Finance subnet Windows 11 endpoints in OU=Finance, with 3 of 4 sampled machines impacted. Comparator host DESKTOP-FB029 in the same OU was unaffected and processed policy successfully.

Workaround: Apply the suggested DNS assignment correction on the affected path and refresh endpoint network configuration on affected hosts. Re-test sign-in/policy processing after refresh.

Permanent fix: Correct the DNS assignment path so clients receive 10.10.0.10 and remove stale retired DNS references. Keep the preventive controls from the RCA in place, including mandatory post-change subnet validation and runbook hold points before decommission closure.

How to spot it: Look for this event pattern on affected clients: Netlogon Event ID 5719 (no domain controller available), DNS Client Event ID 1014 (name resolution timed out), GroupPolicy Event IDs 1058/1030/1129 (SYSVOL and DC connectivity failures), and DHCP Client Event ID 50036 showing DNS 10.10.3.250. In the verified incident, key timestamps included 07:40:08 (5719), 07:41:05 (1014), 07:42:18 (50036), and repeated 1129 at 07:40:12 and 07:44:01.
