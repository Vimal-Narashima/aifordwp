Symptom     : Users see a black/blank screen immediately after login on POOL-FIN-01. Some sessions recover after about 30 seconds, while others disconnect or remain unusable.

Cause       : A graphics/display stack regression was introduced by the 02:00 overnight image update to POOL-FIN-01. This was evidenced by repeated dwm.exe crashes faulting in igdumd64.dll with exception 0xc0000005 immediately after successful logon.

Scope       : Approximately 40% of users on POOL-FIN-01 were affected during the 2026-08-06 incident window (first impact around 07:00, stabilized and verified by 10:00). POOL-FIN-02 was unaffected.

Workaround  : Drain affected POOL-FIN-01 hosts from new sessions and route new sessions to POOL-FIN-02 while mitigation is applied. Enforce software rendering for RDS session rendering on impacted POOL-FIN-01 hosts and reboot in controlled waves.

Permanent fix: Rebuild from the last known-good image baseline, remove/roll back the problematic graphics driver package, and pin a known-stable display stack for the next image release. Publish the corrected image and block the faulty image from future assignment.

How to spot it: Look for the recurring event sequence on affected hosts: Event ID 21 (logon success) -> Event ID 1000 (Application Error: dwm.exe faulting in igdumd64.dll, exception 0xc0000005) -> Event ID 40 (session disconnected) -> Event ID 9009 (DWM exited). On unaffected comparator hosts, DWM starts successfully (Event ID 9011) and Event ID 1000 is absent in the same window.