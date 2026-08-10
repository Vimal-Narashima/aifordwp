# L2/L3 Knowledge Base: AVD Black Screen Post Login (POOL-FIN-01)

| Field | Detail |
|---|---|
| Version | 1.0 |
| Date | 07/08/2026 |
| Status | Draft |

---

## Background

POOL-FIN-01 and POOL-FIN-02 provide virtual desktops for finance users. Reliable post-login desktop rendering is critical because failed sign-in flows block access to line-of-business systems at start of day. In this incident pattern, authentication succeeds, but the interactive desktop fails to initialize on updated hosts, causing black screen or immediate disconnect for a subset of users.

Why this matters:
- Business impact appears quickly (typically morning login burst).
- User experience can look like an identity issue, but root cause is in post-logon render path.
- Wrong first action (for example profile reset) delays restoration.

---

## Symptom

### What users report
- Black or blank screen immediately after sign-in.
- Some sessions recover after ~30 seconds, others disconnect.
- Reconnect loop: successful sign-in followed by disconnect.

### What engineer observes
- Impact isolated to POOL-FIN-01.
- POOL-FIN-02 remains unaffected in same time window.
- Approximately partial pool impact (not necessarily all hosts/users).

---

## Root Cause

Graphics/display stack regression introduced by overnight updated host image lineage in POOL-FIN-01.

### Confirming evidence
- Change evidence:
  - Overnight update applied to POOL-FIN-01 at ~02:00.
  - POOL-FIN-02 not updated.
- Affected host event sequence (example SHFIN-01-A):
  - Event ID 21 (logon succeeded)
  - Event ID 1000 (Application Error: faulting app `dwm.exe`, faulting module `igdumd64.dll`, exception `0xc0000005`)
  - Event ID 40 (session disconnected)
  - Event ID 9009 (Desktop Window Manager exited with error)
- Comparator host sequence (example SHFIN-02-A in POOL-FIN-02):
  - Event ID 21 followed by Event ID 9011 (DWM started successfully)
  - No Event ID 1000 for `dwm.exe`

Conclusion: post-logon render failure on updated POOL-FIN-01 image lineage, not generic authentication failure.

---

## Detection

Use this fast path to confirm in under 3 minutes before making any changes.

### D1. Set host variables and time window (PowerShell)
Action:

```powershell
# Replace with actual hostnames
$AffectedHost   = 'SHFIN-01-A'   # POOL-FIN-01
$ComparatorHost = 'SHFIN-02-A'   # POOL-FIN-02
$StartTime      = (Get-Date).AddMinutes(-60)
```

Expected result:
- Variables are set for one affected and one comparator host.

### D2. Confirm affected signature on POOL-FIN-01 (command-first)
Action:

```powershell
# Application log: Event ID 1000 (Application Error)
$app1000 = Get-WinEvent -ComputerName $AffectedHost -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'Application Error'
    Id           = 1000
    StartTime    = $StartTime
} | Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' }

# Application log: Event ID 9009 (Desktop Window Manager exit)
$dwm9009 = Get-WinEvent -ComputerName $AffectedHost -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'Desktop Window Manager'
    Id           = 9009
    StartTime    = $StartTime
}

# Session manager operational log: Event IDs 21 and 40
$lsm2140 = Get-WinEvent -ComputerName $AffectedHost -FilterHashtable @{
    LogName   = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
    Id        = 21,40
    StartTime = $StartTime
}

$app1000 | Select-Object -First 3 TimeCreated, Id, Message
$dwm9009 | Select-Object -First 3 TimeCreated, Id, Message
$lsm2140 | Select-Object -First 6 TimeCreated, Id, Message
```

Exact log locations and required checks:
- Application log: Event Viewer -> Windows Logs -> Application
  - Event ID `1000` (Source: `Application Error`)
  - Required fields in General/Message: faulting app `dwm.exe`, faulting module `igdumd64.dll` (explicit match), typically exception `0xc0000005`
- Application log: Event Viewer -> Windows Logs -> Application
  - Event ID `9009` (Source: `Desktop Window Manager`)
- Operational log: Event Viewer -> Applications and Services Logs -> Microsoft -> Windows -> TerminalServices-LocalSessionManager -> Operational
  - Event IDs `21` and `40`

Expected result:
- On the affected host, all of the following are present in the same incident window:
  - Event `21`
  - Event `1000` with `dwm.exe` and `igdumd64.dll`
  - Event `40`
  - Event `9009`

### D3. Confirm healthy baseline on POOL-FIN-02 (unaffected control)
Action:

```powershell
# Comparator baseline: Event ID 9011 must be present
$dwm9011 = Get-WinEvent -ComputerName $ComparatorHost -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'Desktop Window Manager'
    Id           = 9011
    StartTime    = $StartTime
}

# Comparator should not show matching Event 1000 for dwm.exe/igdumd64.dll
$cmp1000 = Get-WinEvent -ComputerName $ComparatorHost -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'Application Error'
    Id           = 1000
    StartTime    = $StartTime
} | Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' }

$dwm9011 | Select-Object -First 3 TimeCreated, Id, Message
$cmp1000 | Select-Object -First 3 TimeCreated, Id, Message
```

Exact log locations and required checks:
- Application log: Event Viewer -> Windows Logs -> Application
  - Event ID `9011` (Source: `Desktop Window Manager`) must exist on POOL-FIN-02
- Application log: Event Viewer -> Windows Logs -> Application
  - Event ID `1000` (Source: `Application Error`) with `dwm.exe` + `igdumd64.dll` must be absent on POOL-FIN-02

Expected result:
- Comparator host in POOL-FIN-02 shows Event `9011` and no matching Event `1000` (`dwm.exe`/`igdumd64.dll`).

### D4. Decision rule (go/no-go)
Proceed to Resolution only if all are true:
- Affected POOL-FIN-01 host shows Event `1000` in Application log with `dwm.exe` + `igdumd64.dll`.
- Affected POOL-FIN-01 host shows Event `9009` in Application log.
- Affected POOL-FIN-01 host shows session pattern Event `21` then `40` in LSM Operational log near the same timestamps.
- Unaffected POOL-FIN-02 control host shows Event `9011` and no matching Event `1000`.

---

## Resolution

Operator target: complete setup/actions in 5-10 minutes. VM reimage execution can run longer in background.

### Required fast variables (run first)

```powershell
# Fill these before executing commands
$SubId          = '<subscription-id>'
$HostPoolRg     = '<resource-group-containing-host-pool>'
$HostPoolName   = 'POOL-FIN-01'
$ComparatorPool = 'POOL-FIN-02'
$VmRg           = '<resource-group-containing-session-host-vms>'
$SuspectHosts   = @('SHFIN-01-A','SHFIN-01-B')
$KnownGoodImage = '<gallery-image-id-or-version-confirmed-from-POOL-FIN-02>'
```

### R1. Drain suspect hosts in POOL-FIN-01
Exact portal path and option:
- `https://portal.azure.com -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> <host> -> Properties -> Allow new sessions = Off -> Save`

Fast command path (Azure CLI):

```powershell
az login
az account set --subscription $SubId

foreach ($h in $SuspectHosts) {
  az desktopvirtualization session-host update `
    --resource-group $HostPoolRg `
    --host-pool-name $HostPoolName `
    --name $h `
    --allow-new-session false
}
```

Expected result:
- Session hosts in POOL-FIN-01 show `Allow new sessions = No` (Drain mode On).

### R2. Notify users and log off active sessions on drained hosts
Exact portal path and option:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> <host> -> Sessions -> Send message`
- Wait 5 minutes
- `Sessions -> Select all -> Log off`

Fast command path (Azure CLI):

```powershell
foreach ($h in $SuspectHosts) {
  $sessions = az desktopvirtualization user-session list `
    --resource-group $HostPoolRg `
    --host-pool-name $HostPoolName `
    --session-host-name $h | ConvertFrom-Json

  foreach ($s in $sessions) {
    az desktopvirtualization user-session send-message `
      --resource-group $HostPoolRg `
      --host-pool-name $HostPoolName `
      --session-host-name $h `
      --user-session-id $s.name.Split('/')[-1] `
      --message-title 'Service notice' `
      --message-body 'Login issue remediation in progress. Save work. Session will be logged off in 5 minutes.'
  }
}

Start-Sleep -Seconds 300

foreach ($h in $SuspectHosts) {
  $sessions = az desktopvirtualization user-session list `
    --resource-group $HostPoolRg `
    --host-pool-name $HostPoolName `
    --session-host-name $h | ConvertFrom-Json

  foreach ($s in $sessions) {
    az desktopvirtualization user-session delete `
      --resource-group $HostPoolRg `
      --host-pool-name $HostPoolName `
      --session-host-name $h `
      --user-session-id $s.name.Split('/')[-1] `
      --yes
  }
}
```

Expected result:
- Active session count becomes 0 for each suspect host.

### R3. Confirm known-good image against unaffected control
Exact portal path and option:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts -> <host> -> Properties -> Image version`
- `Azure Compute Gallery -> <gallery> -> Image definitions -> <finance image> -> Versions`

Fast command path (Azure CLI):

```powershell
# View POOL-FIN-02 session hosts and pick one known-good control host
az desktopvirtualization session-host list `
  --resource-group $HostPoolRg `
  --host-pool-name $ComparatorPool `
  --query "[].{Host:name,Status:status,AllowNew:allowNewSession}" -o table

# Confirm image reference on suspect VMs before reimage
foreach ($h in $SuspectHosts) {
  az vm show --resource-group $VmRg --name $h --query "storageProfile.imageReference" -o json
}
```

Expected result:
- Known-good image version/reference is documented and approved before reimage.

### R4. Reimage suspect VMs to known-good version
Exact portal path and option:
- `Azure portal -> Virtual machines -> <suspect-vm> -> Overview -> Reimagine`
- Reimagine pane options:
  - `Image source = Azure Compute Gallery`
  - `Image definition = <finance image>`
  - `Image version = <known-good>`
  - Click `Apply`

Fast command path (Azure CLI):

```powershell
foreach ($h in $SuspectHosts) {
  az vm reimage --resource-group $VmRg --name $h
}
```

Expected result:
- Reimage job starts for each host; VM restarts.

### R5. Confirm host returns healthy in POOL-FIN-01
Exact portal path and option:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts`
- Check columns: `Status`, `Health status`, `Allow new sessions`

Fast command path (Azure CLI):

```powershell
az desktopvirtualization session-host list `
  --resource-group $HostPoolRg `
  --host-pool-name $HostPoolName `
  --query "[].{Host:name,Status:status,AllowNew:allowNewSession,UpdateState:updateState}" -o table
```

Expected result:
- Reimaged hosts show available/healthy state and remain drained until verification passes.

### R6. Reopen remediated hosts
Exact portal path and option:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> <host> -> Properties -> Allow new sessions = On -> Save`

Fast command path (Azure CLI):

```powershell
foreach ($h in $SuspectHosts) {
  az desktopvirtualization session-host update `
    --resource-group $HostPoolRg `
    --host-pool-name $HostPoolName `
    --name $h `
    --allow-new-session true
}
```

Expected result:
- Reimaged hosts are accepting new sessions.

---

## Verification

### V1. Verify host state and routing in Azure
Exact portal path and option:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts`
- Confirm per host:
  - `Status = Available`
  - `Health status = Available`
  - `Allow new sessions = Yes`

Fast command path (Azure CLI):

```powershell
az desktopvirtualization session-host list `
  --resource-group $HostPoolRg `
  --host-pool-name $HostPoolName `
  --query "[].{Host:name,Status:status,AllowNew:allowNewSession,UpdateState:updateState}" -o table
```

Expected result:
- All remediated hosts are healthy and open for new sessions.

### V2. Verify no crash signature in Application log
Fast command path (PowerShell):

```powershell
foreach ($h in $SuspectHosts) {
  "=== $h ==="
  Get-WinEvent -ComputerName $h -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'Application Error'
    Id           = 1000
    StartTime    = (Get-Date).AddMinutes(-30)
  } | Where-Object { $_.Message -match 'dwm\.exe' -or $_.Message -match 'igdumd64\.dll' } |
  Select-Object TimeCreated, Id, Message
}
```

Exact log path and field:
- `Event Viewer -> Windows Logs -> Application`
- `Source = Application Error`, `Event ID = 1000`
- Message field must not contain `dwm.exe` or `igdumd64.dll`

Expected result:
- No matching output on any remediated host.

### V3. Verify DWM healthy marker present and failure marker absent
Fast command path (PowerShell):

```powershell
foreach ($h in $SuspectHosts) {
  "=== $h ==="
  Get-WinEvent -ComputerName $h -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'Desktop Window Manager'
    Id           = 9009,9011
    StartTime    = (Get-Date).AddMinutes(-30)
  } | Select-Object TimeCreated, Id, Message | Sort-Object TimeCreated
}
```

Exact log path and field:
- `Event Viewer -> Windows Logs -> Application`
- `Source = Desktop Window Manager`
- `Event 9011 must exist`, `Event 9009 must not occur after fix`

Expected result:
- Event 9011 observed; no new Event 9009 after remediation window.

### V4. Functional sign-in test
Exact portal path to pick target host:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts`
- Choose one remediated host marked Available.

Action:
1. Sign in with test account.
2. Observe for 30 seconds.

Expected result:
- Desktop is usable; no black screen or forced disconnect.

### V5. Comparator sanity check (unaffected control still healthy)
Exact portal path:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts`

Fast command path (PowerShell):

```powershell
Get-WinEvent -ComputerName $ComparatorHost -FilterHashtable @{
  LogName      = 'Application'
  ProviderName = 'Desktop Window Manager'
  Id           = 9011
  StartTime    = (Get-Date).AddMinutes(-30)
} | Select-Object -First 5 TimeCreated, Id, Message
```

Expected result:
- Comparator host still shows healthy Event 9011 baseline.

---

## Rollback

Use if verification fails or user impact increases after remediation.

### RB1. Re-drain POOL-FIN-01 immediately
Exact portal path and option:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> <host> -> Properties -> Allow new sessions = Off -> Save`

Fast command path (Azure CLI):

```powershell
foreach ($h in $SuspectHosts) {
  az desktopvirtualization session-host update `
    --resource-group $HostPoolRg `
    --host-pool-name $HostPoolName `
    --name $h `
    --allow-new-session false
}
```

Expected result:
- All suspect hosts stop accepting new sessions.

### RB2. Force logoff residual sessions
Exact portal path and option:
- `Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> <host> -> Sessions -> Select all -> Log off`

Fast command path (Azure CLI):

```powershell
foreach ($h in $SuspectHosts) {
  $sessions = az desktopvirtualization user-session list `
    --resource-group $HostPoolRg `
    --host-pool-name $HostPoolName `
    --session-host-name $h | ConvertFrom-Json

  foreach ($s in $sessions) {
    az desktopvirtualization user-session delete `
      --resource-group $HostPoolRg `
      --host-pool-name $HostPoolName `
      --session-host-name $h `
      --user-session-id $s.name.Split('/')[-1] `
      --yes
  }
}
```

Expected result:
- Active sessions reduced to 0 on suspect hosts.

### RB3. Keep service available through POOL-FIN-02
Exact portal path and option:
- `Azure Virtual Desktop -> Application groups -> <Finance app group> -> Assignments -> Add`
- Ensure required user/group assignment targets POOL-FIN-02 delivery path.

Fast command path (Azure CLI, if app-group reassignment is automated in your environment):

```powershell
# Validate POOL-FIN-02 host readiness before redirect
az desktopvirtualization session-host list `
  --resource-group $HostPoolRg `
  --host-pool-name $ComparatorPool `
  --query "[].{Host:name,Status:status,AllowNew:allowNewSession}" -o table
```

Expected result:
- Users can continue work via POOL-FIN-02 while POOL-FIN-01 remains drained.

### RB4. Capture rollback evidence before next attempt
Fast command path (PowerShell):

```powershell
foreach ($h in $SuspectHosts) {
  wevtutil epl Application "C:\Temp\App_${h}_$(Get-Date -Format yyyyMMdd_HHmm).evtx" /r:$h
  wevtutil epl System      "C:\Temp\Sys_${h}_$(Get-Date -Format yyyyMMdd_HHmm).evtx" /r:$h

  Get-WinEvent -ComputerName $h -FilterHashtable @{
    LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-60)
  } | Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' } |
  Select-Object -First 5 TimeCreated, Id, Message
}
```

Exact log paths exported:
- `Event Viewer -> Windows Logs -> Application`
- `Event Viewer -> Windows Logs -> System`

Expected result:
- Evidence package ready for escalation with precise failure markers.

### RB5. Escalation handoff
Required handoff data:
- Host pool: `POOL-FIN-01`
- Control pool: `POOL-FIN-02`
- Commands/output used
- Reimage attempt timestamps
- Event IDs observed: `1000`, `9009`, `21`, `40`, and control `9011`

Expected result:
- Engineering owner has complete rollback evidence and can approve next action quickly.

---

## Preventive

Implement all items below as release gates and monitoring controls.

### P1. Canary rollout gate (mandatory)
- Owner: release engineer | Timing: during deployment | Type: automated [REQUIRES: CI/CD promotion gate `AVD-Canary-DWM-Health`]
- Pass/Fail signal: canary scope <=10% of POOL-FIN-01 for >=60 minutes, and Application log Event ID `1000` with `dwm.exe` count = 0.
- If fail: block promotion immediately, keep canary hosts drained, and open incident linked to change record.

### P2. Event-correlation quality gate
- Owner: DWP engineer | Timing: before deployment | Type: automated [REQUIRES: scripted pre-promotion check in pipeline]
- Pass/Fail signal: sequence `21 -> 1000 -> 40` on canary hosts within 120 seconds occurs 0 times; any count >=1 is fail.
- If fail: pipeline exits non-zero, release engineer cancels rollout, image owner investigates failure host logs.

### P3. Driver baseline control
- Owner: image owner | Timing: before deployment | Type: automated [REQUIRES: build step `Driver-Baseline-Compare` + signed baseline manifest]
- Pass/Fail signal: installed graphics driver version exactly matches approved manifest; any drift or unapproved version is fail.
- If fail: block image publication, require change manager-approved exception before retest.

### P4. Comparator validation gate
- Owner: DWP engineer | Timing: during deployment | Type: manual [REQUIRES: ITSM change template with mandatory evidence fields]
- Pass/Fail signal: POOL-FIN-01 canary shows no Event `1000`/`9009` and POOL-FIN-02 control shows Event `9011` in same window.
- If fail: stop cutover and hold traffic on control path; automation approach: script evidence export and auto-attach to change ticket.

### P5. Monitoring and alerting hardening
- Owner: service desk lead | Timing: during deployment | Type: automated [REQUIRES: alert rules + dashboard]
- Pass/Fail signal: alert A = Event `1000` + `dwm.exe` >=3 per 10 min per host; alert B = correlated `21 -> 1000 -> 40` within 2 min.
- If fail: trigger major incident workflow, notify DWP engineer/release engineer, and pause rollout until cleared.

### P6. Pre-deployment smoke test gate (added)
- Owner: DWP engineer | Timing: before deployment | Type: manual
- Pass/Fail signal: two test sign-ins on pre-prod canary host complete <30s each, with Event `9011` present and no Event `1000`/`9009`.
- If fail: do not start production rollout; automation approach: scripted sign-in + Get-WinEvent check in release pipeline.

### P7. In-flight rollout watch window (added)
- Owner: service desk lead | Timing: during deployment | Type: automated [REQUIRES: rollout watch dashboard/workbook]
- Pass/Fail signal: for first 30 minutes, disconnect rate increase <=2% over baseline and Event `1000` count remains 0 on canary hosts.
- If fail: freeze rollout at current percentage and invoke rollback trigger (P9).

### P8. Post-deployment validation gate (added)
- Owner: change manager | Timing: after deployment | Type: manual [REQUIRES: change closure checklist]
- Pass/Fail signal: all POOL-FIN-01 hosts `Available`, `Allow new sessions = Yes`, and zero Event `1000`/`9009` for 30 minutes post-open.
- If fail: change remains open, service returned to rollback state, and closure approval withheld.

### P9. Rollback trigger threshold (added)
- Owner: release engineer | Timing: during deployment | Type: automated [REQUIRES: rollback playbook integration]
- Pass/Fail signal: trigger rollback if any host records Event `1000` with `dwm.exe`+`igdumd64.dll`, or >=2 affected user sessions within 10 minutes.
- If fail: auto-set Allow new sessions = Off for affected hosts, route users to POOL-FIN-02, and page on-call DWP engineer.

### P10. Knowledge and checklist update control (added)
- Owner: change manager | Timing: after deployment | Type: manual
- Pass/Fail signal: runbook, known-error record, and release checklist updated within 2 business days; ticket links added and peer-reviewed.
- If fail: block next image-change CAB approval until documentation debt is closed; automation approach: ITSM policy check for required links.

Expected preventive outcome:
- Faulty render stack changes are blocked before full rollout and detected within minutes if introduced.

---

## Related

- Primary incident RCA: RCA_AVD_Black_Screen_POOL-FIN-01_20260806.md
- Technical runbook: Runbook_AVD_Black_Screen_POOL-FIN-01.md
- Known error record: Known_Error_Record_AVD_Black_Screen_20260807.md
- Audience communications: AVD_Black_Screen_Audience_Communications_20260807.md
- Closure note: Closure_Note_AVD_Black_Screen_20260807.txt
