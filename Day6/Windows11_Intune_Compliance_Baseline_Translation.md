# Windows 11 Intune Compliance Policy Build Guide (Based on Your Current UI)

Date: 2026-08-11  
Role context: DWP Desktop/Endpoint Engineering

## Navigation in your tenant
Use this path to create the policy:

Devices -> Manage devices -> Compliance -> Policies -> Create policy

Platform: Windows 10 and later  
Profile type: Compliance policy

---

## Tab 1: Basics
Select the following:

- Name: Windows 11 Compliance Baseline - DWP
- Description: Baseline controls for BitLocker, Secure Boot, OS build, Defender real-time protection, Firewall, and sign-in credential
- Platform: Windows 10 and later
- Profile type: Compliance policy

Then select Next.

---

## Tab 2: Compliance settings
You should see these sections exactly as in your screenshot:

1. Custom Compliance
2. Device Health
3. Device Properties
4. Configuration Manager Compliance
5. System Security
6. Microsoft Defender for Endpoint
7. Windows Subsystem for Linux (WSL)

Set each section as follows.

### 1) Custom Compliance
- Selection: Leave Not configured
- Why: No custom JSON/script rule is needed for these 7 baseline requirements.

### 2) Device Health
Set:

- Require BitLocker: Require
- Require Secure Boot to be enabled on the device: Require

Leave other Device Health settings Not configured unless your baseline separately mandates them.

### 3) Device Properties
Set:

- Minimum OS version: 10.0.22621.2861

Leave Maximum OS version Not configured unless you have a formal upper build cap.

### 4) Configuration Manager Compliance
Set:

- Require device compliance from Configuration Manager: Not configured

Use Require only if the device population is co-managed with Configuration Manager and you intentionally depend on ConfigMgr compliance state.

### 5) System Security
Configure by subsection.

Password subsection:
- Require a password to unlock mobile devices: Require
- Password type: Device default

Defender subsection:
- Real-time protection: Require

Device security subsection:
- Firewall: Require

Other System Security options:
- Leave Not configured unless explicitly required by your written baseline.

### 6) Microsoft Defender for Endpoint
Requirement 7 (jailbroken/rooted) is not a native Windows compliance setting. Use the nearest Windows compromise signal:

- Require the device to be at or under the machine risk score: Low

If Low creates too many operational false positives, use Medium only with security approval.

### 7) Windows Subsystem for Linux (WSL)
- Selection: Leave Not configured
- Why: This baseline does not define Linux distro/version controls.

Then select Next.

---

## Tab 3: Actions for noncompliance
Set as follows:

- Mark device noncompliant: Immediately (default)

Add at least one scheduled action at 7 days to meet your grace-period requirement operationally:

- Action: Send email to end user
- Schedule: 7 days after noncompliance

Optional additional 7-day action (if approved by operations/security):

- Action: Remotely lock device or Retire device
- Schedule: 7+ days

Important behavior note:
Mark device noncompliant is immediate; grace periods in this tab delay follow-up actions, not the noncompliant state itself.

Then select Next.

---

## Tab 4: Assignments
Select your target group(s):

- Include groups: Windows 11 production device group (recommended: device group)
- Exclude groups: Known unsupported hardware test/exemption group (for legacy Secure Boot/TPM edge cases)

Then select Next.

---

## Tab 5: Review + create
Validate before create:

- Require BitLocker = Require
- Require Secure Boot to be enabled on the device = Require
- Minimum OS version = 10.0.22621.2861
- Real-time protection = Require
- Firewall = Require
- Require a password to unlock mobile devices = Require
- Password type = Device default
- Require device at or under machine risk score = Low
- Noncompliance action schedule includes 7-day user notification

Select Create.

---

## Post-assignment validation steps (after test device sync)

### 1) Exactly where to see this device status for this specific policy
Use the policy-centric path first (best for this check):

- Devices -> Manage devices -> Compliance -> Policies
- Select Windows 11 Compliance Baseline - DWP
- Open Device status
- Search for the test device name
- Select the device row to open setting-level results

Use the device-centric path as a cross-check:

- Devices -> All devices -> select the test device
- Open Device compliance
- Select Windows 11 Compliance Baseline - DWP to view per-setting status

### 2) Status meaning and Conditional Access impact

- Compliant:
	- Meaning: Device passed all required checks (or unresolved checks are not policy-breaking).
	- CA impact: If a CA policy requires compliant device, access is allowed (subject to other CA controls).

- Not compliant:
	- Meaning: Device failed one or more required checks.
	- CA impact: If CA requires compliant device, access is blocked.

- In grace period:
	- Meaning: Device failed policy checks, but the policy is in a delayed noncompliance window before mark-noncompliant action executes.
	- CA impact: Usually not blocked by compliance CA until it flips to Not compliant. If another assigned policy already marks the device Not compliant, CA can still block immediately.
	- Important for this policy: Because Mark device noncompliant is set to Immediately, you normally will not see an extended In grace period state for this policy.

### 3) BitLocker false-positive triage: top 3 causes and fastest check

Cause 1: Device Health Attestation state is stale until reboot
- Why it happens: Require BitLocker in Device Health is boot-attestation based.
- Fastest check:
	- On the device, run manage-bde -status and confirm OS drive is Fully Encrypted and Protection On.
	- Then restart once, sync from Company Portal or Settings, and recheck status in Device status.

Cause 2: Sync/check-in race right after migration or policy assignment
- Why it happens: Compliance evaluation can occur before latest local security state is uploaded.
- Fastest check:
	- Compare Last check-in time on device record with the time BitLocker was enabled/completed.
	- Trigger manual sync and re-evaluate after one full check-in cycle.

Cause 3: Firmware/TPM attestation edge case despite encryption being on
- Why it happens: Legacy TPM/UEFI/firmware combinations can produce attestation mismatch.
- Fastest check:
	- Confirm Secure Boot and TPM presence/version in Windows Security or tpm.msc.
	- Compare failure pattern across same hardware model in policy Device status; if model-clustered, this is likely platform attestation behavior rather than real encryption failure.

### First 24-hour monitoring checklist

- Policy-level trend:
	- Devices -> Manage devices -> Compliance -> Policies -> Windows 11 Compliance Baseline - DWP -> Overview
	- Watch Compliant vs Not compliant trend every 2-4 hours.

- Setting-level spike detection:
	- In the same policy, open Device status and filter failures where Require BitLocker is the failing setting.
	- If most failures clear after reboot + sync, classify as transient false positives.

- Hardware correlation:
	- Check if BitLocker failures cluster by model/firmware generation.
	- If clustered, use temporary assignment exclusion for affected model cohort while firmware remediation is planned.

- Conditional Access impact:
	- Confirm whether users on test devices are blocked from compliant-required apps.
	- If unexpected blocks occur, validate whether failure comes from this policy or another assigned compliance policy.

---

## Requirement-to-setting map (final)

### Requirement 1: BitLocker must be enabled on the OS drive
- Settings name: Require BitLocker
- Value: Require
- Effect: Device is noncompliant if OS drive BitLocker state is not valid.
- False-positive risk: BitLocker DHA check updates at boot; device may need reboot to report compliant.
- Recommendation: Keep Require and communicate reboot requirement after encryption/remediation.

### Requirement 2: Secure Boot must be enabled
- Settings name: Require Secure Boot to be enabled on the device
- Value: Require
- Effect: Device is noncompliant if Secure Boot is disabled/not attested.
- False-positive risk: Legacy hardware/firmware reporting limitations.
- Recommendation: Keep Require and exclude unsupported hardware by assignment, not by weakening the control.

### Requirement 3: Minimum OS build 22621.2861
- Settings name: Minimum OS version
- Value: 10.0.22621.2861
- Effect: Devices below that version are noncompliant.
- False-positive risk: Update installed but reboot pending, or check-in lag.
- Recommendation: Align update deadlines and restart policy with compliance timelines.

### Requirement 4: Windows Defender real-time protection must be on
- Settings name: Real-time protection
- Value: Require
- Effect: Device is noncompliant when Defender real-time monitoring is off.
- False-positive risk: Service startup or telemetry lag after reboot.
- Recommendation: Keep Require and avoid mixed AV control models for same population.

### Requirement 5: Firewall must be enabled for all profiles
- Settings name: Firewall
- Value: Require
- Effect: Device is noncompliant if firewall state is off/not compliant.
- False-positive risk: GPO conflicts and immediate post-reboot sync timing.
- Recommendation: Remove firewall GPO conflicts and manage firewall policy in Intune.

### Requirement 6: A PIN or password must be configured
- Settings name: Require a password to unlock mobile devices
- Value: Require
- Effect: Device requires a local sign-in secret (PIN/password policy path).
- False-positive risk: Counterintuitive label for Windows and kiosk/shared device edge cases.
- Recommendation: Pair with Password type = Device default unless stricter auth is mandated.

### Requirement 7: Device must not be jailbroken or rooted
- Settings name: Not available as a Windows compliance setting
- Value: N/A
- Effect: No direct Windows jailbreak/root toggle exists in this policy type.
- False-positive risk: Trying to force a non-existent setting leads to implementation drift.
- Recommendation: Use Microsoft Defender for Endpoint machine risk score as the approved Windows-equivalent compromise signal.

### Grace period requirement: 7 days
- Settings name: Actions for noncompliance
- Value: Add scheduled user notification at 7 days
- Effect: Follow-up remediation actions occur at 7 days; noncompliant state itself remains immediate.
- False-positive risk: Expectation mismatch with Conditional Access timing.
- Recommendation: Document immediate CA impact and use staged notifications.
