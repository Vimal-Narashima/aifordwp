# Runbook - Resolve Autopilot Enrolment Failure 0x80180014 (Legacy MDM Conflict)

Date: 2026-08-11  
Source of truth: RCA_Autopilot_Enrollment_Failure_0x80180014_20260811.md  
Audience: Endpoint engineers (L2/L3), service desk escalation handlers

## 1) Purpose

Provide a repeatable procedure to restore Autopilot enrolment when failure is caused by a pre-existing legacy manual MDM enrolment conflict.

## 2) Trigger Criteria

Use this runbook only when the incident evidence shows:
- EnrollmentType: Autopilot
- EnrollmentState: Failed
- ErrorCode: 0x80180014
- ErrorDescription: The device is already enrolled in MDM.

Common corroborating signals from same export/case:
- MDMEnrolled: Yes (previous/legacy enrolment)
- EnrolmentSource: Legacy manual MDM enrolment (for incident: 2023-11-04)
- ProfilesApplied: 0 of 4
- LastError: 0x80070005 (Access denied)
- ComplianceEngine reason: Enrolment not complete

## 3) Preconditions

- You have admin access to Intune admin center.
- You have admin access to Entra admin center.
- You have physical or remote interactive access to the endpoint for local account-disconnect and reboot actions.

## 4) Required Inputs

- Device name and serial/hardware hash.
- User/ticket reference.
- Evidence capture (error code and EnrollmentState).

## 5) Procedure (Order of Operations)

1. Confirm case pattern
- Validate trigger criteria from diagnostics/log export.

2. Intune stale-object cleanup
- Intune admin center -> Devices -> All devices.
- Find stale legacy-enrolled object(s) for target hardware identity.
- Select stale object -> Retire -> confirm.
- After retire request, select stale object -> Delete -> confirm.

3. Entra stale-duplicate cleanup
- Entra admin center -> Identity -> Devices -> All devices.
- Identify stale duplicate legacy object(s) for same hardware identity.
- Delete stale duplicate object(s), preserving the intended current identity path.

4. Confirm Autopilot registration still present
- Intune admin center -> Devices -> Enroll devices -> Windows enrollment -> Devices.
- Search by serial/hardware hash.
- Confirm device registration exists and intended profile assignment remains intact.

5. Device-side cleanup (requires endpoint access)
- On device: Settings -> Accounts -> Access work or school.
- Disconnect old legacy organizational connection if present.
- Confirm legacy connection is no longer shown.

6. Restart enrolment flow
- Reboot device.
- Re-run Autopilot OOBE/enrolment flow.

## 6) Verification Steps (Must Pass)

1. Enrolment verification
- Intune admin center -> Devices -> All devices -> target device.
- Confirm successful MDM-managed state and recent check-in.

2. Autopilot deployment verification
- Intune admin center -> Devices -> Enroll devices -> Monitor -> Autopilot deployments.
- Confirm provisioning/deployment completed without blocking error.

3. Policy application verification
- Device configuration/compliance results.
- Confirm assigned profiles now apply (no longer 0 of 4 pattern).

4. Device residual-state verification
- On endpoint Access work or school, confirm only expected current organization connection remains.

## 7) Exit Criteria

Close incident only when all are true:
- No recurrence of 0x80180014 during rerun.
- Device is managed in Intune with recent check-in.
- Assigned profile/policy processing proceeds successfully.

## 8) Escalation Criteria

Escalate to endpoint engineering lead if:
- 0x80180014 persists after stale object cleanup and device-side disconnect/reboot.
- Autopilot registration is missing or incorrect after cleanup.
- Device identity mapping is ambiguous across multiple objects and cannot be resolved safely.

## 9) Preventive Control (Mandatory)

Before any Autopilot reset/redeployment, enforce a pre-flight eligibility gate:
- Check for existing legacy MDM enrolment state.
- Check for duplicate stale Intune/Entra device records.
- Complete Retire-then-Delete cleanup before Autopilot assignment/reassignment.
- Block ticket progression until checkpoint is marked complete.

## 10) Record Keeping

Document in ticket/change record:
- Original symptoms and exact error strings.
- Stale objects retired/deleted (Intune and Entra).
- Device-side actions taken.
- Verification evidence screenshots/timestamps.
- Preventive gate completion status.
