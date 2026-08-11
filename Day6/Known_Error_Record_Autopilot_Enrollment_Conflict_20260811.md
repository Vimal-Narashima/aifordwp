# Known Error Record - Autopilot Enrolment Failure (0x80180014)

Symptom :
Users experience Autopilot enrolment failure during provisioning. The device shows EnrollmentState as Failed with error 0x80180014, and policy application does not complete (ProfilesApplied: 0 of 4).

Cause :
The verified root cause is a pre-existing legacy manual MDM enrolment record dated 2023-11-04. This stale enrolment conflicts with Autopilot and prevents enrolment completion.

Scope :
Affected scope is devices that have both an Autopilot enrolment attempt and an existing legacy/manual MDM enrolment state. In the verified incident, the affected endpoint was DESKTOP-FB099 in user context FINBRIDGE\\rthomas.

Workaround :
To restore service, remove the stale management conflict by retiring and deleting the legacy Intune device record, removing stale duplicate Entra device objects where present, and disconnecting any old work/school account on the device. Reboot and re-run the Autopilot enrolment flow.

Permanent fix:
Implement a mandatory pre-Autopilot eligibility gate that checks for and clears legacy MDM enrolments and duplicate Intune/Entra device records before redeployment. Enforce the Retire-then-Delete cleanup sequence as a required runbook checkpoint.

How to spot it:
Look for EnrollmentState: Failed with ErrorCode: 0x80180014 and ErrorDescription: The device is already enrolled in MDM. Confirm corroborating signals of MDMEnrolled: Yes (previous/legacy enrolment), ProfilesApplied: 0 of 4, LastError: 0x80070005 (Access denied), and ComplianceEngine reason: Enrolment not complete.
