# Root Cause Analysis (RCA) - Autopilot Enrolment Failure (0x80180014)

Date authored: 2026-08-11  
Incident date (from export): 2024-03-15  
Prepared for: DWP Desktop/Endpoint Engineering

## 1) Executive Summary

Autopilot enrolment failed because the device had a pre-existing legacy manual MDM enrolment record dated 2023-11-04. The conflicting existing enrolment blocked Autopilot MDM enrolment and prevented policy processing from completing.

## 2) Incident Scope

- Device: DESKTOP-FB099
- User context: FINBRIDGE\\rthomas
- EnrollmentType: Autopilot
- EnrollmentState: Failed
- Primary enrolment error: 0x80180014
- Error description: The device is already enrolled in MDM.
- Azure AD joined: Yes
- Existing MDM enrolment: Yes (legacy manual enrolment)
- Policy outcome: Profiles applied 0 of 4
- Policy manager last error: 0x80070005 (Access denied)
- Compliance engine result: Could not evaluate (reason: enrolment not complete)
- Licensing status: M365 = Yes, Intune P1 = Yes, Autopilot = Yes
- Network status: Required endpoints reachable, proxy not detected

## 3) Supporting Evidence

### 3.1 Evidence Extracts (from MDM diagnostic export)

- EnrollmentState : Failed
- ErrorCode : 0x80180014
- ErrorDescription : The device is already enrolled in MDM.
- MDMEnrolled : Yes (previous enrolment from 2023-11-04)
- EnrolmentSource : Legacy manual MDM enrolment
- AzureADJoined : Yes
- ProfilesApplied : 0 of 4
- LastError : 0x80070005 (Access denied)
- IntuneP1License : Yes
- AutopilotLicense : Yes
- Network : All endpoints reachable, no proxy

### 3.2 Section-by-Section Corroboration

EnrollmentStatus:
- EnrollmentType: Autopilot
- EnrollmentState: Failed
- ErrorCode: 0x80180014
- ErrorDescription: The device is already enrolled in MDM.
- Timestamp: 2024-03-15 09:18:44

PolicyManager:
- ProfilesAttempted: 4
- ProfilesApplied: 0
- LastError: 0x80070005 (Access denied)
- FailedProfile: FinBridge-Win11-Security-Baseline
- Timestamp: 2024-03-15 09:19:01

ComplianceEngine:
- EvaluationResult: Could not evaluate
- Reason: Enrolment not complete
- Timestamp: 2024-03-15 09:19:45

DeviceInfo:
- AzureADJoined: Yes
- MDMEnrolled: Yes (previous enrolment)
- EnrolmentSource: Legacy (manual MDM enrolment, 2023-11-04)

NetworkCheck:
- login.microsoftonline.com: OK
- enrollment.manage.microsoft.com: OK
- enterpriseregistration.windows.net: OK
- ProxyDetected: No

Licensing:
- M365LicenseFound: Yes
- IntuneP1License: Yes
- AutopilotLicense: Yes

## 4) Timeline (UTC/local as per export context)

- 2023-11-04
  - Device received legacy manual MDM enrolment (persistent prior state established).

- 2024-03-15 09:18:44
  - Autopilot enrolment attempt recorded.
  - EnrollmentState = Failed.
  - ErrorCode = 0x80180014 with explicit message: already enrolled in MDM.

- 2024-03-15 09:19:01
  - PolicyManager attempted 4 profiles; applied 0.
  - LastError = 0x80070005 (Access denied).

- 2024-03-15 09:19:45
  - ComplianceEngine could not evaluate due to incomplete enrolment.

- 2024-03-15 09:22
  - Export captured with final failed state and corroborating network/license health.

## 5) Root Cause Statement

The root cause is a stale pre-existing legacy manual MDM enrolment record on the device identity path. This created a management-state conflict that blocked Autopilot enrolment completion.

## 6) 5 Whys Analysis

1. Why did Autopilot enrolment fail?
- Because enrolment ended in Failed with 0x80180014.

2. Why did 0x80180014 occur in this case?
- Because the device was already enrolled in MDM, as explicitly stated in the export error description.

3. Why was the device already enrolled when Autopilot ran?
- Because a legacy manual MDM enrolment from 2023-11-04 still existed.

4. Why was the legacy enrolment still present at redeployment time?
- Because stale enrolment records/associations were not fully retired and removed before Autopilot reprovisioning.

5. Why were stale records not removed before reprovisioning?
- Because there was no mandatory pre-Autopilot eligibility gate/checklist enforcing legacy-enrolment cleanup and duplicate record validation.

Process root cause:
- Missing operational control: no enforced pre-flight step to detect and clear legacy MDM enrolments before Autopilot assignment/redeployment.

## 7) Impact Assessment

- Technical impact:
  - Autopilot provisioning did not complete.
  - Device did not reach a valid managed state for intended baseline delivery.
  - Compliance evaluation failed because enrolment was incomplete.

- Security/compliance impact:
  - Target security baseline profile was not applied (0 of 4 profiles).
  - Device posture was temporarily unmanaged relative to intended standard.

- User/operational impact:
  - Delayed device readiness and potential service desk rework.

## 8) Corrective Actions Taken / Required

### 8.1 Immediate Corrective Actions (case level)

1. Admin center only:
- Intune admin center -> Devices -> All devices
- Locate stale legacy-enrolled object(s)
- Retire stale object(s), then delete stale object(s)

2. Admin center only:
- Entra admin center -> Identity -> Devices -> All devices
- Remove stale duplicate legacy device object(s) where applicable

3. Admin center only:
- Intune admin center -> Devices -> Enroll devices -> Windows enrollment -> Devices
- Confirm Autopilot registration/profile assignment remains intact

4. Device access required (physical or remote interactive):
- Device Settings -> Accounts -> Access work or school
- Disconnect old legacy organizational connection if present
- Reboot device
- Re-run Autopilot OOBE/enrolment flow

### 8.2 Expected Outcome After Corrective Action

- Enrolment completes successfully without recurring 0x80180014.
- Device appears managed in Intune with current check-in.
- Assigned profiles and compliance/baseline processing begins normally.

## 9) Verification Plan

1. Enrolment verification:
- Intune admin center -> Devices -> All devices -> target device
- Confirm successful MDM-managed enrolment state and recent check-in

2. Autopilot verification:
- Intune admin center -> Devices -> Enroll devices -> Monitor -> Autopilot deployments
- Confirm deployment completion status for target device

3. Policy verification:
- Target device -> configuration/compliance results
- Confirm profiles are applying (not 0 of 4)

4. Residual-state verification (device side):
- Access work or school shows only expected current organization connection

## 10) Preventive Actions (Fleet level)

1. Introduce mandatory pre-Autopilot eligibility gate:
- Validate no existing legacy MDM enrolment before Autopilot assignment/reset.
- Validate no duplicate stale Intune/Entra device objects for same hardware identity.

2. Standardize runbook control:
- Add required checkpoint: Legacy MDM conflict check completed.
- Block Autopilot redeployment ticket progression until checkpoint is passed.

3. Proactive reporting/control:
- Create scheduled report to detect devices with legacy/manual enrolment history and duplicate object risk.
- Remediate flagged devices before they enter redeployment queue.

4. Operational governance:
- Publish SOP for Retire then Delete sequence.
- Train service desk and endpoint engineers on conflict pattern and cleanup sequence.

## 11) Lessons Learned

- Healthy network, valid licensing, and Azure AD join do not guarantee Autopilot success when a legacy MDM relationship remains.
- Enrolment-state conflicts can cascade into policy and compliance failures that appear secondary.
- Pre-flight hygiene for device identity and enrolment state is critical for predictable Autopilot outcomes.

## 12) Final RCA Conclusion

This incident was caused by a legacy manual MDM enrolment conflict that blocked Autopilot enrolment. The failure pattern, timestamps, and export fields consistently support this single root cause. Preventing recurrence requires enforced pre-flight stale-enrolment checks and standardized cleanup before Autopilot reprovisioning.
