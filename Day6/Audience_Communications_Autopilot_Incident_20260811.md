# Audience Communications - Autopilot Enrolment Incident

## Audience 1 - Non-technical executive

Your access and data are safe. A device setup failed because an old setup record from 2023-11-04 conflicted with the new setup process, so required settings did not apply at first. We removed the old record, reran setup, and confirmed setup completed with required settings applying. To prevent repeats, we now require a pre-check that removes old records before setup. You do not need to take any action.

## Audience 2 - Affected end-user team (10 people, non-technical)

Your access and data are safe. One device setup failed because an old setup record from 2023-11-04 conflicted with the new setup process, so required settings did not apply at first. We removed the old record, reran setup, and confirmed setup completed with required settings applying. We now run a pre-check to remove old records before setup to prevent repeats. If you see this again, contact the Service Desk and report an "Autopilot setup conflict with old enrollment record."

## Audience 3 - Engineer-to-engineer internal note

Facts to keep consistent with user comms:
- Access/data safety: no evidence of data loss or access compromise in this incident.
- Failure mechanism: Autopilot enrolment failed due to stale legacy manual MDM enrolment record dated 2023-11-04 conflicting with new enrolment.
- Immediate impact: required settings/policies did not apply during failed attempt (ProfilesApplied 0/4).

Root cause:
- Legacy manual MDM enrolment state (2023-11-04) remained associated and blocked Autopilot enrolment completion.

Exact action taken:
- Intune admin center: located stale device object, issued Retire, then Delete.
- Entra admin center: removed stale duplicate legacy device object where present.
- Device-side: disconnected old Work/School connection, rebooted, reran Autopilot flow.

Config detail / evidence points:
- EnrollmentState Failed, ErrorCode 0x80180014, ErrorDescription "The device is already enrolled in MDM."
- MDMEnrolled Yes (previous enrolment), EnrolmentSource Legacy manual MDM enrolment (2023-11-04).
- PolicyManager: ProfilesAttempted 4, ProfilesApplied 0, LastError 0x80070005 (Access denied).
- AzureADJoined Yes; licenses present (M365 found, Intune P1 Yes, Autopilot Yes); network endpoints reachable and no proxy.

Verification step:
- After cleanup and rerun, verify successful enrolment state in Intune device record, verify Autopilot deployment completed, and verify assigned profiles are applying (not 0/4).

Preventive action needed:
- Enforce mandatory pre-Autopilot eligibility gate: check and clear legacy MDM enrolments and duplicate Intune/Entra device records before redeployment.
- Enforce runbook checkpoint requiring Retire-then-Delete stale records before assigning/reassigning to Autopilot.
