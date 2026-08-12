# T-1004 Company Portal App Install Failure (0x87D1041C)

Date: 2026-08-12

## Surviving Hypothesis
Missing dependency or prerequisite condition in the Win32 package install path, presenting as MSI return code 1603.

## Why This Hypothesis Survives
- Install execution is allowed and runs in SYSTEM context, so this is not a pre-install targeting or compliance block.
- The same silent MSI install command fails twice with return code 1603, one hour apart, indicating a deterministic installer-state or prerequisite issue.
- Detection reports Not detected after failure, so this is not an already-installed false positive.

## Evidence Used
- 2024-03-15 10:01:01 - AppInstaller: Install context SYSTEM
- 2024-03-15 10:01:44 - AppInstaller: Return code 1603
- 2024-03-15 10:01:46 - DetectionRule: Detection result Not detected
- 2024-03-15 11:01:48 - AppInstaller: Install command retried
- 2024-03-15 11:02:31 - AppInstaller: Return code 1603

## Detailed Resolution Steps

1. Reproduce with full MSI logging
- Run install with verbose log:
  msiexec /i "AcrobatPro.msi" /qn /L*v "C:\Windows\Temp\AcrobatPro_install.log"
- In the log, locate first fatal indicators:
  - Return value 3
  - CustomAction failures
  - LaunchCondition failures
  - Lines immediately preceding Error 1603

2. Validate prerequisite stack
- Confirm vendor prerequisites for this Acrobat Pro package version:
  - Supported Windows build
  - VC++ redistributables
  - .NET/runtime requirements
  - Any shared components documented by vendor
- Deploy missing prerequisites as explicit Intune Win32 dependencies.

3. Eliminate known installer-state blockers
- Confirm no pending reboot state.
- Check for Adobe product conflicts or remnants from prior installs.
- If conflicts are found, remove conflicting components, reboot, and retry.

4. Verify Intune packaging correctness
- Confirm packaged content includes the correct MSI and all required payload files.
- Validate silent install command contains required properties/transforms for enterprise deployment.
- Repackage if command line or payload is incomplete.

5. Confirm execution context and path access
- Ensure IME has fully staged content before execution.
- Verify SYSTEM access to installer and temp paths used by custom actions.
- Review IME logs at failure timestamps for staging/download anomalies.

6. Align detection rule after install path is stable
- Use detection that matches Acrobat Pro (not Reader keys).
- Prefer MSI product code detection for the exact build, or a Pro-specific registry/file version rule.
- Validate detection independently after successful manual install.

7. Pilot and redeploy
- Test on a clean device and a device with previous Adobe footprint.
- If both pass, publish updated app package/dependencies/detection in Intune.
- Monitor first retry cycle for recurrence.

## Resolution Success Criteria
- Installer returns success (0) instead of 1603.
- Detection returns Detected on first post-install check.
- No further retry scheduling for this app.
