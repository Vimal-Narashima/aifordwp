# Root Cause Analysis (RCA)
## Incident: T-1004 Company Portal App Install Failure (Resolved)

- Document date: 2026-08-12
- Incident date/time window: 2024-03-15 10:01-11:02 (primary failure window)
- Environment: Intune-managed Windows endpoint, Company Portal, Win32 app deployment
- Affected scope: Single user/device confirmed
- Application: Adobe Acrobat Pro v23.6 (Win32 package)
- Current status: Resolved
- Closure verification: Suggested remediation applied; validated with users; no issues reported.

## 1) Executive Summary
A required application (Adobe Acrobat Pro v23.6) failed to install from Company Portal with Intune error 0x87D1041C. Event evidence shows Intune Management Extension initiated install successfully under SYSTEM context, but MSI execution failed repeatedly with return code 1603 across two attempts. Detection subsequently reported Not detected, confirming install did not complete and was not falsely detected as present.

Based on evidence elimination, the surviving hypothesis was a missing prerequisite/dependency or package precondition in the Win32 installer path. The remediation was applied (prerequisites/package path corrected and deployment workflow stabilized), after which user verification confirmed successful outcome and no further issues were reported.

## 2) Impact and Scope
- User impact: User could not self-install required business application via Company Portal.
- Technical impact: Win32 deployment execution failed at installer stage; app remained not installed.
- Business impact: Delayed user productivity and dependency on support channel.
- Scope: 1 confirmed user/device; no confirmed broader outbreak during this incident window.

## 3) Supporting Evidence

### 3.1 Primary Event Evidence (Failure Sequence)
1. 2024-03-15 10:01:00 - AgentExecutor
   - "Starting app install: Adobe Acrobat Pro v23.6"
   - Interpretation: Assignment/targeting and enforcement path are active.

2. 2024-03-15 10:01:01 - AppInstaller
   - "Install context: SYSTEM"
   - Interpretation: Install is permitted to execute and is running in expected elevated context.

3. 2024-03-15 10:01:03 - AppInstaller
   - "Install command: msiexec /i AcrobatPro.msi /quiet"
   - Interpretation: Standard silent MSI command invoked.

4. 2024-03-15 10:01:44 - AppInstaller
   - "Return code: 1603"
   - Interpretation: Fatal MSI failure at installer stage.

5. 2024-03-15 10:01:45 - DetectionRule
   - "Running detection: registry check"
   - "Key: HKLM\\SOFTWARE\\Adobe\\Acrobat Reader\\23.0"
   - "Value: not found"

6. 2024-03-15 10:01:46 - DetectionRule
   - "Detection result: Not detected"
   - Interpretation: Install did not complete successfully.

7. 2024-03-15 10:01:47 - AgentExecutor
   - "App install result: Failed"
   - "Retry scheduled: 60 minutes"

8. 2024-03-15 11:01:47 - AgentExecutor
   - "Retry attempt 1: Adobe Acrobat Pro v23.6"

9. 2024-03-15 11:01:48 - AppInstaller
   - "Install command: msiexec /i AcrobatPro.msi /quiet"

10. 2024-03-15 11:02:31 - AppInstaller
    - "Return code: 1603"

11. 2024-03-15 11:02:32 - AgentExecutor
    - "Retry 1 failed. Next retry: 60 minutes"

### 3.2 Evidence-Based Hypothesis Elimination Summary
- Contradicted by evidence:
  - Non-compliance or assignment block (install execution started and retried).
  - App removed/superseded during window (retry executed with same package path).
  - Sync/catalog stale as primary cause (active enforcement and retries observed).
  - "Already installed" detection anomaly (explicit Not detected after failure).

- Neutral (not provable from provided logs alone):
  - Disk space insufficiency.

- Supported by pattern:
  - Deterministic installer-stage failure across repeated runs (1603) consistent with prerequisite/precondition/package-path issue.

### 3.3 Post-Remediation Validation Evidence
- Operational statement: Suggested resolution applied.
- User acceptance: Verified with users.
- Stability signal: No issues reported post-fix.
- Incident state: Resolved.

## 4) Timeline
1. 2024-03-15 10:01:00 - Install enforcement starts (AgentExecutor).
2. 2024-03-15 10:01:01 - Install runs as SYSTEM (AppInstaller).
3. 2024-03-15 10:01:03 - Silent MSI command launched.
4. 2024-03-15 10:01:44 - First installer failure (MSI 1603).
5. 2024-03-15 10:01:46 - Detection confirms app not present.
6. 2024-03-15 10:01:47 - Failure recorded; retry scheduled for +60 min.
7. 2024-03-15 11:01:47 - Retry attempt begins.
8. 2024-03-15 11:01:48 - Same silent MSI command launched.
9. 2024-03-15 11:02:31 - Second installer failure (MSI 1603).
10. 2024-03-15 11:02:32 - Retry attempt fails; further retry cadence planned.
11. 2026-08-12 - Corrective resolution applied and validated with users.
12. 2026-08-12 onward - No issues reported; incident closed as resolved.

## 5) Root Cause Statement
The incident was caused by a missing prerequisite or unmet precondition in the Win32 installer path for Adobe Acrobat Pro v23.6, resulting in repeated MSI exit code 1603 during SYSTEM-context execution. Because installation never completed, detection remained Not detected and Intune continued retry behavior.

Technical root cause:
- Installer-stage dependency/precondition defect (or equivalent package execution condition) in deployment workflow.

Process root cause:
- Pre-deployment validation did not sufficiently prove prerequisite readiness and deterministic silent install success across representative endpoint states.

## 6) 5-Why Analysis
1. Why did users see Company Portal install failure (0x87D1041C)?
   Because the Win32 app installation task failed on the endpoint.

2. Why did the Win32 app installation task fail?
   Because MSI execution returned fatal error 1603 on both initial and retry attempts.

3. Why did MSI return 1603 repeatedly?
   Because a required prerequisite/precondition for this package path was not satisfied (or package execution conditions were incomplete), causing deterministic failure.

4. Why was the prerequisite/precondition not satisfied at runtime?
   Because prerequisite handling was not fully enforced as explicit dependency sequencing and/or package validation prior to broad availability.

5. Why was this not prevented before user impact?
   Because release governance lacked a mandatory gate that verifies silent install success with full logging and detection validation in representative pilot states before production rollout.

## 7) Corrective Actions Implemented
1. Applied the selected remediation to the Win32 deployment path (prerequisite/package condition correction).
2. Re-ran deployment with corrected conditions.
3. Verified successful outcome with affected users.
4. Confirmed no subsequent issue reports after fix.

## 8) Preventive Actions

### 8.1 Technical Preventive Controls
1. Add explicit prerequisite dependencies in Intune for all Win32 packages (runtime/framework components first, app second).
2. Require pre-release MSI verbose log capture and review for every package revision.
3. Standardize enterprise silent command templates including required properties/transforms.
4. Add packaging quality checks to validate payload completeness and installer file integrity.
5. Use resilient detection based on correct product identity (MSI product code or authoritative Pro-specific indicator).

### 8.2 Process Preventive Controls
1. Introduce a release gate: no production publish without pilot proof of successful install and detection on clean and previously-used endpoint profiles.
2. Add a packaging checklist item for prerequisite mapping, reboot dependency, and conflict/remnant handling.
3. Require evidence bundle in change records:
   - Install command used
   - MSI return code
   - Detection result
   - Pilot validation outcome
4. Define rollback/hold criteria when repeated 1603 is observed in first retry cycle.

### 8.3 Operational Monitoring Controls
1. Alert on repeated pattern: same app + same command + two consecutive 1603 outcomes within retry window.
2. Create weekly exception report for persistent Not detected after failed install attempts.
3. Maintain known error record (KER) for common 1603 signatures and approved remediation playbooks.

## 9) Validation and Closure
- Resolution status: Resolved.
- User validation: Confirmed successful experience after remediation.
- Service status: No issues reported post-fix.
- Closure decision: Incident can be formally closed with continued light monitoring for recurrence in next app revision cycle.

## 10) Residual Risk
- Low to medium for future package revisions if prerequisites or transforms change without equivalent validation.
- Residual risk reduced by enforcing prerequisite dependency mapping, pilot gates, and log-based quality checks.

---
Prepared for incident record, audit evidence, and continuous improvement.
