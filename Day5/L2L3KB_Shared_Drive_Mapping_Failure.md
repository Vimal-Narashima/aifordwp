# L2/L3 Knowledge Base: Finance Shared Drive Mapping Failure
v 1.0, 07/08/2026, status : Draft

## Background
Finance users access shared files through mapped drive S:, which points to \\finbridge-fs01\Finance. This mapping must occur in user sign-in context because access tokens and user profile mappings are user-scoped. If mapping runs too early in startup or in system context, users lose access to core Finance working files, causing immediate business impact.

## Symptom
Engineer observes:
- Repeated mapping failures on DESKTOP-FB* devices.
- S: drive missing after sign-in.
- Script execution failure around startup.

User reports:
- "Finance drive is missing."
- "I cannot open or save Finance files."
- "Issue started after morning sign-in."

## Root Cause
Specific technical cause:
- Drive mapping was migrated from user-context GPO logon execution to system-context Intune script execution.
- Script executed before network dependency readiness and without retry logic.

Evidence that confirms root cause:
- Script output shows `Script context = SYSTEM account`.
- Script output shows `Exit code 1` and `Network name cannot be found`.
- Event ID 7036 (Workstation service running) occurs after first mapping failure.
- Event ID 1500 confirms Group Policy processing success (rules out GP failure as primary cause).
- Event ID 98 shows S: mapping failure.

## Detection
Target time: under 3 minutes using commands, not manual clicking.

Use one affected device and one healthy comparison device (same user group, same network condition).

Healthy baseline for comparison:
- No Application log Event ID 1000 for the incident timeframe.
- No Application log Event ID 9009 for the incident timeframe.
- No Event ID 1000 where `Faulting module name` equals `igdumd64.dll`.
- Intune mapping log shows successful user-context mapping (no `Exit code 1`).

1. Pull Application log crash/signature events from affected device.
- Exact log location: Event Viewer > Windows Logs > Application
- Exact Event IDs: `1000` and `9009`
- Fields to check: `TimeCreated`, `Id`, `ProviderName`, `Message`
- PowerShell command:
```powershell
$since = (Get-Date).AddHours(-4)
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,9009; StartTime=$since} |
Select-Object TimeCreated, Id, ProviderName, Message |
Format-List
```
- Confirm this indicator: at least one Event `1000` or `9009` exists during the failure window.

2. Confirm the required faulting module in Event 1000.
- Exact log location: Event Viewer > Windows Logs > Application
- Exact Event ID: `1000`
- Field to check: `Message` field value `Faulting module name`
- PowerShell command:
```powershell
$since = (Get-Date).AddHours(-4)
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=$since} |
Where-Object { $_.Message -match 'Faulting module name:\s*igdumd64.dll' } |
Select-Object TimeCreated, Id, ProviderName, Message |
Format-List
```
- Confirm this indicator: Event `1000` explicitly contains `Faulting module name: igdumd64.dll`.

3. Pull mapping script evidence from Intune logs on affected device.
- Exact log location: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log`
- Fields to check: timestamped message lines
- PowerShell command:
```powershell
Select-String -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log' -Pattern 'Map-FinBridgeDrives.ps1|Script context =|Exit code|Network name cannot be found|No retry configured' |
Select-Object LineNumber, Line
```
- Confirm this indicator: log contains `Script context = SYSTEM account` and `Exit code 1` with `Network name cannot be found`.

4. Confirm timing dependency in System log on affected device.
- Exact log location: Event Viewer > Windows Logs > System
- Exact Event IDs: `7036`, `1500`, `98`
- Fields to check: `TimeCreated`, `Id`, `ProviderName`, `Message`
- PowerShell command:
```powershell
$since = (Get-Date).AddHours(-4)
Get-WinEvent -FilterHashtable @{LogName='System'; Id=7036,1500,98; StartTime=$since} |
Select-Object TimeCreated, Id, ProviderName, Message |
Sort-Object TimeCreated |
Format-Table -AutoSize
```
- Confirm this indicator: mapping failure evidence appears before/around Workstation readiness (`7036`), GP success (`1500`) is present, and drive map warning (`98`) is present.

5. Run affected vs healthy comparison quickly.
- Exact sources: Application log + System log + AgentExecutor.log on both devices.
- Fields to compare: Event ID presence, `Faulting module name`, and timestamp order.
- PowerShell command (run on each device and compare output):
```powershell
$since=(Get-Date).AddHours(-4)
Write-Host '---Application 1000/9009---'
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,9009; StartTime=$since} | Select-Object TimeCreated,Id,ProviderName -First 20
Write-Host '---Application 1000 igdumd64.dll---'
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=$since} | Where-Object {$_.Message -match 'igdumd64.dll'} | Select-Object TimeCreated,Id,ProviderName
Write-Host '---System 7036/1500/98---'
Get-WinEvent -FilterHashtable @{LogName='System'; Id=7036,1500,98; StartTime=$since} | Select-Object TimeCreated,Id,ProviderName | Sort-Object TimeCreated
```
- Confirm this indicator: affected device shows required failure pattern; healthy device does not.

6. Pull script assignment details without portal clicking (Azure CLI).
- Command purpose: quickly confirm script assignment exists and detect context/migration drift.
- Azure CLI command:
```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
az rest --method GET --url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts?$filter=displayName eq 'Map-FinBridgeDrives.ps1'"
```
- Optional assignment check command:
```bash
az rest --method GET --url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/<SCRIPT_ID>/assignments"
```
- Confirm this indicator: only intended assignment remains and script metadata matches expected deployment model.

Proceed to Resolution only when all of the following are true:
- Application log contains Event `1000` and/or `9009` in incident window.
- Event `1000` includes `Faulting module name: igdumd64.dll`.
- Intune mapping log shows system-context mapping failure pattern.
- Affected vs healthy comparison shows clear deviation on affected device.

## Resolution
1. Open Azure portal path: Azure portal > Microsoft Intune > Devices > Scripts and remediations > Platform scripts > Map-FinBridgeDrives.ps1 > Properties > Script settings.
- Option to set: Run this script using the logged on credentials = Yes.
- Expected result: Mapping executes in user context, not system context.

2. In the same script, open Azure portal path: Azure portal > Microsoft Intune > Devices > Scripts and remediations > Platform scripts > Map-FinBridgeDrives.ps1 > Properties > Script.
- Option to set: Add pre-checks for Workstation service running and UNC reachability to \\finbridge-fs01\Finance, then add retry (3 attempts, 20-second delay).
- Expected result: Script waits for readiness and retries transient failures.

3. Open Azure portal path: Azure portal > Microsoft Intune > Devices > Scripts and remediations > Platform scripts > Map-FinBridgeDrives.ps1 > Assignments.
- Option to set: Keep only Finance target groups; remove duplicate system-context mapping assignment.
- Expected result: Only intended user-context assignment remains.

4. Open Azure portal path: Azure portal > Microsoft Intune > Devices > All devices > <validation-device> > Sync.
- Option to select: Sync.
- Expected result: Device receives updated script policy.

5. If validation device is an AVD session host, open Azure portal path: Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01.
- Option to check: Host status = Available.
- Option to check: Host details > Source image reference (image) matches approved baseline used by working hosts.
- Expected result: Host is available and image baseline matches healthy hosts.

6. Run Azure CLI to update/check script quickly.
- Command:
```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
SCRIPT_ID=$(az rest --method GET --url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts?$filter=displayName eq 'Map-FinBridgeDrives.ps1'" --query "value[0].id" -o tsv)
az rest --method GET --url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$SCRIPT_ID"
az rest --method GET --url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$SCRIPT_ID/assignments"
```
- Expected result: Script id and assignment set are returned for validation.

7. Run remote PowerShell on validation endpoint to force immediate user-context remap test.
- Command:
```powershell
net use S: /delete /y
net use S: "\\finbridge-fs01\Finance" /persistent:yes
Test-Path "S:\"
```
- Expected result: `Test-Path` returns `True`.

## Verification
1. Verify Intune assignment state in portal.
- Azure portal path: Azure portal > Microsoft Intune > Devices > Scripts and remediations > Platform scripts > Map-FinBridgeDrives.ps1 > Assignments.
- Option to verify: No system-context duplicate assignment; Finance targets only.
- Expected result: Assignment scope is correct.

2. Verify endpoint policy receipt in portal.
- Azure portal path: Azure portal > Microsoft Intune > Devices > All devices > <validation-device> > Device status > Managed app and script status.
- Option to verify: Script run status = Succeeded.
- Expected result: Latest run is successful.

3. Verify AVD host baseline if endpoint is in host pool.
- Azure portal path: Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01 > Properties.
- Option to verify: Source image reference equals healthy peer host in POOL-FIN-01.
- Expected result: FIN01 image setting matches baseline.

4. Verify user access on device.
- Command:
```powershell
Test-Path "S:\"
Get-ChildItem "S:\" | Select-Object -First 5
```
- Expected result: `Test-Path` is `True` and listing returns folders/files.

5. Verify persistence after sign-out/sign-in.
- Action: Sign out, sign in as affected user, run `Test-Path "S:\"` again.
- Expected result: Drive remains present.

6. Verify no fresh failures in logs.
- Command:
```powershell
$since=(Get-Date).AddMinutes(-30)
Select-String -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log' -Pattern 'Map-FinBridgeDrives.ps1|Exit code 1|Network name cannot be found' |
Where-Object { $_.Line -match 'Map-FinBridgeDrives.ps1|Exit code 1|Network name cannot be found' }
Get-WinEvent -FilterHashtable @{LogName='System'; Id=98; StartTime=$since} | Select-Object TimeCreated,Id,Message
```
- Expected result: No new mapping `Exit code 1`; no new System Event ID `98` during verification window.

## Rollback
Use immediately if blast radius increases or mapping failure rate rises after deployment.

1. Revert script to last known-good revision.
- Azure portal path: Azure portal > Microsoft Intune > Devices > Scripts and remediations > Platform scripts > Map-FinBridgeDrives.ps1 > Properties.
- Option to set: Restore previous script content and previous execution mode.
- Expected result: Prior known-good behavior is reinstated.

2. Disable current problematic assignment immediately.
- Azure portal path: Azure portal > Microsoft Intune > Devices > Scripts and remediations > Platform scripts > Map-FinBridgeDrives.ps1 > Assignments.
- Option to set: Remove affected target group assignment.
- Expected result: Broken deployment stops propagating.

3. Re-enable prior known-good assignment.
- Azure portal path: Azure portal > Microsoft Intune > Devices > Scripts and remediations > Platform scripts > <previous-known-good-script> > Assignments.
- Option to set: Assign Finance target groups used before incident.
- Expected result: Stable mapping policy is active.

4. If AVD host-specific regression is detected, roll back host to healthy pool/image state.
- Azure portal path: Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01 > Properties.
- Option to set: Confirm FIN01 image setting matches healthy peer; if changed, revert to approved image reference used by healthy hosts.
- Expected result: FIN01 host configuration aligns with baseline.

5. Force device sync and retest.
- Azure portal path: Azure portal > Microsoft Intune > Devices > All devices > <validation-device> > Sync.
- Option to select: Sync, then sign out/sign in and test S:.
- Expected result: Rollback state applied; S: restored.

6. Execute command-line rollback for speed.
- Azure CLI:
```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
SCRIPT_ID=$(az rest --method GET --url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts?$filter=displayName eq 'Map-FinBridgeDrives.ps1'" --query "value[0].id" -o tsv)
az rest --method GET --url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$SCRIPT_ID/assignments"
```
- PowerShell on endpoint:
```powershell
net use S: /delete /y
net use S: "\\finbridge-fs01\Finance" /persistent:yes
Test-Path "S:\"
```
- Expected result: Temporary user access restored while policy rollback completes.

## Preventive
Implement these specific controls:

1. Change gate for execution-context changes (user <-> system).
- Owner: Change manager | Timing: Before deployment | Mode: Manual.
- Pass/Signal: Change record contains completed checklist fields (identity, dependency timing, rollback owner, pilot scope) and CAB approval ID.
- Fail action: Block release and return to DWP engineer for checklist completion; no assignment changes allowed.

2. Staged rollout rings for Intune mapping scripts.
- Owner: Release engineer | Timing: During deployment | Mode: Automated [REQUIRES: Intune assignment ring process].
- Pass/Signal: Ring 0 -> Ring 1 -> Ring 2 with minimum 24-hour hold, and each ring shows script success >= 98% with < 5 failures.
- Fail action: Freeze promotion to next ring and open rollback decision with change manager.

3. Script framework standard for readiness and retry.
- Owner: DWP engineer | Timing: Before deployment | Mode: Manual (can be lint-automated).
- Pass/Signal: Script contains Workstation service check, UNC check to \\finbridge-fs01\Finance, and retry = 3 attempts with 20s backoff.
- Fail action: Reject PR/change package; if manual today, automate with CI regex checks on script content.

4. Structured log markers in script output.
- Owner: DWP engineer | Timing: Before deployment | Mode: Manual (can be automated) [REQUIRES: script logging template].
- Pass/Signal: Output includes Context, DependencyCheck, RetryAttempt, FinalResult, FailureCategory on every run.
- Fail action: Do not approve deployment; automate by Pester test validating marker presence in script output.

5. In-flight monitoring alert during rollout window.
- Owner: Service desk lead | Timing: During deployment | Mode: Automated [REQUIRES: Log Analytics + alert rule].
- Pass/Signal: Alert fires if script exit code != 0 on >= 5 devices in 15 minutes OR System Event ID 98 appears on >= 5 devices in 15 minutes.
- Fail action: Trigger incident, pause rollout, and notify release engineer and change manager immediately.

6. Monthly KPI reporting for mapping reliability.
- Owner: Service desk lead | Timing: After deployment | Mode: Automated [REQUIRES: KPI workbook/dashboard].
- Pass/Signal: Published monthly values for first-logon success rate, retry recovery rate, and mean time to restore; targets met for 2 consecutive months.
- Fail action: Open continuous-improvement action with DWP engineer and release engineer.

7. Pre-deployment smoke test gate (missing layer coverage).
- Owner: DWP engineer | Timing: Before deployment | Mode: Manual (can be automated).
- Pass/Signal: On test device, S: maps at sign-in, Test-Path S:\ = True, and no new System Event ID 98 within 10 minutes.
- Fail action: Cancel release window; automate via Intune Proactive Remediation detection script.

8. Post-deployment validation before change closure (missing layer coverage).
- Owner: Change manager | Timing: After deployment | Mode: Manual.
- Pass/Signal: 1 validation device + 2 additional Finance devices pass sign-in mapping, and AgentExecutor log shows no Exit code 1 in 30 minutes.
- Fail action: Keep change open, assign corrective tasks, and block closure evidence sign-off.

9. Rollback trigger threshold (missing layer coverage).
- Owner: Release engineer | Timing: During deployment | Mode: Automated [REQUIRES: rollout guardrail rule].
- Pass/Signal: Rollout continues only while failures stay below 5 devices/15 minutes and Event ID 98 stays below 5 devices/15 minutes.
- Fail action: Automatic assignment disable for current ring and immediate rollback to last known-good assignment.

10. Knowledge update control from incident learnings (missing layer coverage).
- Owner: Service desk lead | Timing: After deployment | Mode: Manual.
- Pass/Signal: Runbook, checklist, and L1 article updated within 2 business days; version/date and approver recorded.
- Fail action: Raise process non-conformance in change review and prevent similar change type from fast-track path.

## Related
- RCA source: Day4/Share_Drive_RCA.txt
- L1 end-user article: Day5/L1KB_Runbook_shared drives.txt
- Related pattern: startup-sequenced access failures caused by dependency readiness mismatch.
