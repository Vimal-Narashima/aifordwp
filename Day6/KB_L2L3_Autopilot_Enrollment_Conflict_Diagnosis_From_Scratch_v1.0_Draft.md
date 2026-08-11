# L2/L3 Knowledge Base Article - Autopilot Enrolment Failure (Legacy MDM Conflict)

Version: v 1.0  
Date: 07/08/2026  
Status: Draft

## Background

Windows Autopilot is used to provision and enroll Windows endpoints into Intune so device configuration, security baseline, and compliance controls can apply automatically. This matters because a failed Autopilot enrolment leaves the device without intended managed-state assurance, delays user readiness, and can block policy-driven access outcomes.

## Symptom

What the engineer observes:
- Autopilot enrolment attempt shows EnrollmentState as Failed.
- Error code is 0x80180014 with description stating the device is already enrolled in MDM.
- Policy processing does not complete in the same attempt, with ProfilesApplied showing 0 of 4.

What the user reports:
- Device setup did not complete successfully.
- Device is not fully ready for normal business use after enrolment attempt.

## Root Cause

Specific technical cause:
- A pre-existing legacy manual MDM enrolment record (dated 2023-11-04 in the verified case) remained associated with the device identity path, creating a conflict with Autopilot enrolment.

Evidence that confirms this cause:
- EnrollmentState: Failed.
- ErrorCode: 0x80180014.
- ErrorDescription: The device is already enrolled in MDM.
- MDMEnrolled: Yes (previous enrolment).
- EnrolmentSource: Legacy manual MDM enrolment.
- ProfilesApplied: 0 of 4.
- ComplianceEngine reason: Enrolment not complete.
- Licensing and network checks are healthy in the same export.

## Detection

Use this detection sequence before making changes.

### Step 1 - Confirm primary fault signal from MDM diagnostic export

Log location:
- MDM Diagnostic Export -> EnrollmentStatus section

Fields to check and required values:
- EnrollmentType = Autopilot
- EnrollmentState = Failed
- ErrorCode = 0x80180014
- ErrorDescription = The device is already enrolled in MDM.

Decision:
- If all values match, continue to Step 2.
- If not, stop and follow a different incident path.

### Step 2 - Confirm stale enrolment evidence

Log location:
- MDM Diagnostic Export -> DeviceInfo section

Fields to check and required values:
- MDMEnrolled = Yes (previous enrolment)
- EnrolmentSource = Legacy manual MDM enrolment
- AzureADJoined = Yes

Decision:
- If legacy enrolment is confirmed, continue to Step 3.
- If legacy enrolment is not present, do not execute this runbook.

### Step 3 - Confirm secondary impact pattern

Log location:
- MDM Diagnostic Export -> PolicyManager and ComplianceEngine sections

Fields to check and required values:
- ProfilesAttempted = 4
- ProfilesApplied = 0
- LastError = 0x80070005 (Access denied)
- ComplianceEngine EvaluationResult = Could not evaluate
- ComplianceEngine Reason = Enrolment not complete

Decision:
- If this pattern is present, it supports the same enrolment conflict root cause.

### Step 4 - Rule out license and connectivity blockers using same export

Log location:
- MDM Diagnostic Export -> Licensing section
- MDM Diagnostic Export -> NetworkCheck section

Fields to check and required values:
- M365LicenseFound = Yes
- IntuneP1License = Yes
- AutopilotLicense = Yes
- EndpointReach login.microsoftonline.com = OK
- EndpointReach enrollment.manage.microsoft.com = OK
- EndpointReach enterpriseregistration.windows.net = OK
- ProxyDetected = No

Decision:
- If all values are healthy, diagnosis remains legacy enrolment conflict.

### Step 5 - Comparison check (affected vs known-good control device)

Comparison target:
- Compare affected device to one known-good Autopilot-completed device in the same tenant and same deployment wave.

Log locations and fields to compare:
- MDM Diagnostic Export -> EnrollmentStatus: EnrollmentState, ErrorCode, ErrorDescription
- MDM Diagnostic Export -> DeviceInfo: MDMEnrolled, EnrolmentSource
- MDM Diagnostic Export -> PolicyManager: ProfilesApplied

Expected comparison outcome:
- Affected device shows Failed plus 0x80180014 and legacy enrolment indicators.
- Known-good device does not show legacy previous enrolment conflict pattern and has successful enrolment outcome.

### Event IDs

Specific event IDs in verified RCA evidence:
- None captured in the verified RCA/export set.

Operational note:
- Diagnosis for this incident is confirmed using the export fields above, not Event Viewer event IDs.

## Resolution

Follow in exact order.

### Step 1 - Identify stale device objects in Intune

Azure portal path:
- Intune admin center -> Devices -> All devices

Action:
- Search by device name and serial/hardware identity.
- Identify stale legacy-enrolled object(s).

Expected result:
- Stale object candidates are identified and recorded before change.

### Step 2 - Retire stale Intune object

Azure portal path:
- Intune admin center -> Devices -> All devices -> select stale object -> Retire

Action:
- Issue Retire on stale legacy object.

Expected result:
- Retire action accepted for stale object.

### Step 3 - Delete stale Intune object

Azure portal path:
- Intune admin center -> Devices -> All devices -> select stale object -> Delete

Action:
- Delete the same stale object after retire action is issued.

Expected result:
- Stale Intune object no longer remains as active conflict candidate.

### Step 4 - Remove stale duplicate Entra device object (if present)

Azure portal path:
- Microsoft Entra admin center -> Identity -> Devices -> All devices

Action:
- Locate stale duplicate legacy object linked to same hardware identity.
- Delete stale duplicate object, preserving intended current identity.

Expected result:
- Duplicate identity conflict risk is removed.

### Step 5 - Confirm Autopilot registration is intact

Azure portal path:
- Intune admin center -> Devices -> Enroll devices -> Windows enrollment -> Devices

Action:
- Search by serial/hardware hash.
- Confirm device registration exists and correct profile assignment remains in place.

Expected result:
- Autopilot registration path is valid for rerun.

### Step 6 - Clear device-side legacy connection

Device console path:
- Windows Settings -> Accounts -> Access work or school

Action:
- Disconnect old organizational connection associated with legacy manual enrolment, if present.

Expected result:
- Legacy connection is no longer shown locally.

### Step 7 - Reboot and rerun Autopilot

Device action:
- Reboot endpoint.
- Re-run Autopilot OOBE/enrolment flow.

Expected result:
- Enrolment proceeds without the previous conflict error.

## Verification

### Verification 1 - Intune managed enrolment state

Portal path:
- Intune admin center -> Devices -> All devices -> target device

Confirm:
- Successful managed enrolment state
- Recent successful check-in

### Verification 2 - Autopilot deployment status

Portal path:
- Intune admin center -> Devices -> Enroll devices -> Monitor -> Autopilot deployments

Confirm:
- Target device deployment completed without blocking failure state

### Verification 3 - Policy/application recovery

Portal path:
- Intune admin center -> Devices -> All devices -> target device -> Device configuration and Device compliance

Confirm:
- Previous 0 of 4 application pattern is no longer present
- Assigned profile/policy processing is active

### Verification 4 - Local residual-state check

Device console path:
- Windows Settings -> Accounts -> Access work or school

Confirm:
- Only expected current organization connection remains

## Rollback

Use this if impact increases or wrong-object cleanup occurred.

### Rollback trigger conditions

- Wrong active device object was retired/deleted.
- Device cannot proceed in Autopilot after cleanup and now has broader service impact.
- Multiple devices show unintended impact from the same operator action.

### Rollback actions

1. Contain scope immediately
- Remove any broad assignment or change wave continuation for similar devices until review completes.

2. Re-establish device registration path
- Intune admin center -> Devices -> Enroll devices -> Windows enrollment -> Devices.
- If target device record is missing, re-import hardware hash and reassign intended Autopilot profile.

3. Recreate intended management path for affected endpoint
- Start clean enrolment run on device after confirming only intended identity records remain.

4. Service restoration fallback
- If primary endpoint cannot be restored in required timeframe, issue alternate managed endpoint for user continuity while engineering completes identity cleanup.

5. Incident control
- Escalate to endpoint engineering lead for object-level reconciliation before resuming standard rollout.

Expected rollback outcome:
- User service continuity is restored and uncontrolled spread is prevented while corrective identity mapping is rebuilt.

## Preventive

Implement these specific process/tooling changes:

1. Mandatory pre-Autopilot eligibility gate in ticket workflow
- Add hard checkpoint fields that must be completed before Autopilot reset/redeployment can proceed:
  - Legacy MDM enrolment present: Yes or No
  - Duplicate Intune object check completed: Yes or No
  - Duplicate Entra object check completed: Yes or No
  - Retire then Delete cleanup completed (if applicable): Yes or No

2. Change workflow enforcement
- Configure service workflow so Autopilot redeployment task cannot move to execution state unless all four checkpoint fields are completed and approved.

3. Scheduled detection report
- Create recurring Intune/Entra operational report for devices with legacy manual enrolment history and duplicate object indicators, and review before redeployment waves.

4. Runbook control standardization
- Make Retire then Delete sequence a controlled SOP step with peer check sign-off for object identity confirmation prior to deletion.

## Related

- Primary RCA: Day6/RCA_Autopilot_Enrollment_Failure_0x80180014_20260811.md
- Remediation analysis: Day6/Autopilot_Enrollment_Failure_Remediation_Analysis_20260811.md
- L1 KB: Day6/KB_L1_Autopilot_Enrollment_Failure_0x80180014_20260811.md
- Known error record: Day6/Known_Error_Record_Autopilot_Enrollment_Conflict_20260811.md
- Closure note: Day6/Closure_Note_Autopilot_Enrollment_Failure_20260811.txt
