# Known-Error Record - Login Lockout (FINBRIDGE\cthompson)

Symptom: User FINBRIDGE\cthompson was unable to log in from approximately 08:40. During the incident window, logon attempts on DESKTOP-FB022 failed until service was restored.

Cause: The verified root cause was account lockout after repeated invalid credential submissions for FINBRIDGE\cthompson. Evidence shows wrong-password attempts from DESKTOP-FB022 and an additional source IP 10.10.8.112, consistent with saved or cached credentials replaying invalid passwords.

Scope: This incident affected one user only: FINBRIDGE\cthompson. The primary host in scope was DESKTOP-FB022, with additional failed Kerberos attempts recorded from source IP 10.10.8.112.

Workaround: Re-enable the user account and have the user sign in again on DESKTOP-FB022. This restored access in this incident, confirmed by successful logon at 09:09:01.

Permanent fix: Identify and clear the secondary credential source(s) replaying bad credentials, then remove or update stale saved credentials. The RCA preventive controls require secondary-source correlation, cached-credential cleanup, and a short post-recovery monitoring window.

How to spot it: Look for Event 4776 with error 0xC000006A (wrong password), multiple Event 4625 failures (including logon type 2 and type 7 locked-out attempt), Event 4740 account lockout, and Event 4771 with failure code 0x18 from a secondary source. Recovery is validated by Event 4722 (account enabled) followed by Event 4624 (successful interactive logon).