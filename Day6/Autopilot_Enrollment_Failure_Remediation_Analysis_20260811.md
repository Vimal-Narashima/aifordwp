# Autopilot Enrolment Failure Analysis and Remediation Runbook

Date: 2026-08-11  
Audience: DWP Desktop/Endpoint Engineering

## Incident Summary

- EnrollmentType: Autopilot
- EnrollmentState: Failed
- ErrorCode: 0x80180014
- ErrorDescription: The device is already enrolled in MDM.
- MDMEnrolled: Yes (legacy manual enrolment dated 2023-11-04)
- AzureADJoined: Yes
- Licensing: Intune P1 = Yes, Autopilot = Yes, M365 license found = Yes
- Network: Required endpoints reachable, no proxy

## Confirmed Root Cause

Autopilot enrolment failed because the device already had an existing legacy manual MDM enrolment record (2023-11-04). The pre-existing enrolment created a conflict that prevented Autopilot MDM enrolment from completing.

## Remediation Steps (Exact, With Access Type)

### Phase 1: Admin-side cleanup in Intune and Entra

1. Open Intune admin center and locate device objects.  
Access type: Admin center only.

Path:
- Devices -> All devices
- Search by device name and serial number
- Record all matching objects (especially older objects with last check-in far in the past)

2. Retire the stale Intune-managed device object tied to the legacy manual enrolment.  
Access type: Admin center only.

Path:
- Devices -> All devices -> select stale device object
- Select Retire
- Confirm retirement

3. Delete stale Intune device object after retirement is issued.  
Access type: Admin center only.

Path:
- Devices -> All devices -> stale object
- Select Delete
- Confirm delete

4. Remove stale Entra device object if duplicate/conflicting records exist.  
Access type: Admin center only.

Path:
- Entra admin center -> Identity -> Devices -> All devices
- Find duplicate/legacy object for same hardware
- Delete only the stale object (retain intended current identity path)

5. Confirm Autopilot device registration still exists and is assigned to the intended profile.  
Access type: Admin center only.

Path:
- Intune admin center -> Devices -> Enroll devices -> Windows enrollment -> Devices
- Search device serial/hardware hash
- Verify profile assignment (for example FinBridge-Autopilot-Standard)

### Phase 2: Device-side cleanup and restart of enrolment

6. Remove old work/school connection on the endpoint if legacy connection remains.  
Access type: Device access required (physical or remote interactive session).

Path on device:
- Settings -> Accounts -> Access work or school
- Select old connected work account
- Disconnect

7. Trigger local MDM unenrolment cleanup if residual management artifacts remain.  
Access type: Device access required (physical or remote interactive session with local admin where needed).

Actions:
- Confirm device is no longer showing connected legacy MDM account
- Ensure no stale management session remains before reprovision

8. Reboot device.  
Access type: Device access required (physical or remote).

9. Re-run Autopilot provisioning sequence (OOBE/sign-in flow) for the target user/device.  
Access type: Device access required (physical or remote-assisted user session).

## Correct Order of Operations

1. Confirm stale legacy enrolment evidence and identify stale records.
2. Retire stale Intune device object.
3. Delete stale Intune device object.
4. Delete stale duplicate Entra device object if present.
5. Confirm Autopilot registration/profile assignment is intact.
6. On device, disconnect legacy work/school MDM account.
7. Ensure local legacy MDM state is cleared.
8. Reboot device.
9. Re-attempt Autopilot enrolment.
10. Validate successful enrolment and profile/policy application.

## Verification Checks (Post-remediation)

Use all checks below to declare success.

1. Enrolment status check (primary)
- Intune admin center -> Devices -> All devices -> target device
- Confirm:
	- EnrollmentState = Succeeded
	- MDM managed by Intune
	- Recent successful check-in timestamp

2. Autopilot deployment check
- Intune admin center -> Devices -> Enroll devices -> Monitor -> Autopilot deployments
- Confirm target device provisioning completed without blocking error state

3. Policy application check
- Device record -> Device configuration / compliance status
- Confirm previously failed baseline now applies (not 0 of 4)

4. Local device check (if accessible)
- Settings -> Accounts -> Access work or school
- Confirm only expected current organizational connection exists

Success criteria:
- No recurrence of 0x80180014 during enrolment
- Device appears as correctly managed in Intune
- Assigned profile and baseline policies begin applying successfully

## Preventive Action (For Fleet Recurrence Prevention)

Implement a pre-Autopilot eligibility gate for re-used or migrated devices:

1. Pre-flight stale-enrolment screening
- Before assigning/reassigning devices to Autopilot, run an admin-side check for:
	- existing MDM-enrolled state
	- duplicate Intune or Entra device objects
	- legacy manual enrolment history

2. Standardized cleanup workflow
- Mandate Retire + Delete of stale legacy records before Autopilot reassignment.

3. Operational control
- Add a service desk runbook step: "Legacy MDM conflict check completed" as a required checkpoint before Autopilot reset/redeployment.

4. Reporting
- Create a periodic Intune report/query to flag devices with old enrolment patterns and duplicate object risk, then remediate proactively.

## Notes on Error Codes Used in This Analysis

- 0x80180014 treated as provided in evidence: device already enrolled in MDM.
- 0x80070005 treated as provided in evidence: access denied during policy manager phase.

No alternate error-code interpretation is used in this document.
