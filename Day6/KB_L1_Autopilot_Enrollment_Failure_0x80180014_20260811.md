# L1 Knowledge Base - Autopilot Enrolment Failure 0x80180014

Date: 2026-08-11  
Audience: Service Desk L1  
Based on: Verified RCA (legacy manual MDM conflict)

## Issue Summary

Autopilot setup can fail when the device already has an older manual MDM enrolment. In the verified incident, this appeared as error 0x80180014 with the message that the device is already enrolled in MDM.

## What the User Sees

- Device setup/enrolment fails during Autopilot.
- Device is not fully ready because required settings did not apply in that attempt.

## Confirming Signals for L1

Confirm at least these signals in diagnostics or engineer-provided evidence:
- EnrollmentState: Failed
- ErrorCode: 0x80180014
- ErrorDescription: The device is already enrolled in MDM.

If available, corroborating signals include:
- MDMEnrolled: Yes (previous/legacy enrolment)
- ProfilesApplied: 0 of 4
- LastError: 0x80070005 (Access denied)
- ComplianceEngine reason: Enrolment not complete

## What L1 Should Do

1. Validate and record the exact error evidence in ticket notes.
2. Do not attempt workaround outside approved steps.
3. Escalate to endpoint engineering using this reason:
- Suspected stale legacy MDM enrolment conflict blocking Autopilot (0x80180014).
4. Request device access coordination (physical or remote interactive) because device-side disconnect/reboot may be required.

## What Engineering Will Do (Reference for L1)

- Retire then delete stale Intune legacy device record.
- Remove stale duplicate Entra device object where present.
- Confirm Autopilot registration/profile assignment remains correct.
- On device, disconnect old Work/School connection, reboot, rerun Autopilot.

## When to Update User as Restored

Only after engineering confirms:
- Enrolment is successful in Intune with recent check-in.
- Autopilot deployment completed.
- Profile/policy application resumed (no longer 0 of 4 pattern).

## Preventive Step to Reference in Ticket Closure

Pre-Autopilot eligibility gate is required for redeployments:
- Legacy enrolment conflict check.
- Duplicate Intune/Entra record check.
- Retire-then-Delete cleanup completed before Autopilot reassignment.

## Suggested Ticket Notes Template (L1)

- Symptom: Autopilot enrolment failed.
- Evidence: EnrollmentState Failed, 0x80180014, device already enrolled in MDM.
- Action: Escalated to endpoint engineering for stale enrolment cleanup workflow.
- User status: Informed that remediation requires backend cleanup and rerun of enrolment.
