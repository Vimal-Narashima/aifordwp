# Runbook: AVD Black Screen Post Login — Graphics Stack Regression

| Field | Detail |
|---|---|
| **Title** | AVD Black Screen Post Login — Graphics Stack Regression |
| **Version** | 1.0 |
| **Date** | 07/08/2026 |
| **Author** | Sathishbabu |
| **Reviewed by** | Self |
| **Status** | Draft |
| **Change** | Initial version from RCA |

**Linked RCA:** RCA_AVD_Black_Screen_POOL-FIN-01_20260806.md
**Severity class:** Major — partial pool login failure

---

## 1. Prerequisites

Work through every checklist item below and tick it off before you start the procedure. If any item is unchecked, stop — do not proceed until it is resolved.

---

### Checklist A — Access Rights

Verify each role in the Azure portal:
`https://portal.azure.com → click your account icon (top-right) → View account → Azure role assignments`

- [ ] **Desktop Virtualization Host Pool Contributor** (or higher) on the POOL-FIN-01 host pool resource
  - *Needed for: setting drain mode, sending messages, logging off sessions*
  - *If missing: raise an access request with your Azure subscription admin before continuing*
- [ ] **Virtual Machine Contributor** (or higher) on the resource group containing POOL-FIN-01 session host VMs
  - *Needed for: reimaging VMs in Phase B*
  - *If missing: raise an access request before continuing — you cannot complete this runbook without it*
- [ ] **Gallery Image Version Contributor** (or higher) on the Azure Compute Gallery holding AVD images
  - *Needed for: reading the known-good image version in Step 6*
  - *If missing: ask the image team to supply the exact image version string before you start*
- [ ] **Local administrator** on each POOL-FIN-01 session host VM
  - *Needed for: reading Event Viewer remotely in Steps 2, 10, 11*
  - *Verify by running in PowerShell on your workstation:*
    ```powershell
    Invoke-Command -ComputerName <hostname> -ScriptBlock { whoami }
    ```
  - *Expected: returns your admin username with no access-denied error*
- [ ] **Read/write access to the incident ticket** in your ITSM tool
  - *Needed for: recording every action taken and closing the incident at the end*

> **Flag:** Steps 3, 5, and 7 require elevated Azure RBAC. Do not skip the checks above.

---

### Checklist B — Tools Ready on Your Workstation

- [ ] **Web browser signed in to `https://portal.azure.com`** with the account that holds the roles in Checklist A
  - *Verify: in the portal search bar type `Azure Virtual Desktop`, click the result, click **Host pools** — POOL-FIN-01 must appear in the list*
- [ ] **PowerShell 7+** installed with the Az module available
  - *Verify by running:*
    ```powershell
    $PSVersionTable.PSVersion        # Major must be 7 or higher
    Get-Module Az -ListAvailable | Select-Object Name, Version   # must return Az module entries
    ```
  - *If Az is missing:* `Install-Module Az -Scope CurrentUser -Force`
- [ ] **Remote Desktop client** available on your workstation
  - *Verify: press `Win + R`, type `mstsc`, press Enter — the Remote Desktop Connection window must open*
- [ ] **Remote Event Log access** (WinRM) enabled from your workstation to POOL-FIN-01 hosts
  - *Verify by running (replace with an actual host name):*
    ```powershell
    Test-WSMan -ComputerName <hostname>
    ```
  - *Expected: returns a response object. If it errors, raise with your network/firewall team — remote log access is required for Steps 2, 10, and 11*

---

### Checklist C — Mandatory Information from the Reporter / Ticket

Collect every item below from the incident ticket or the person who raised the issue. Write the answers into the ticket before starting.

- [ ] **Affected host pool:** confirmed as `POOL-FIN-01`
- [ ] **Unaffected comparator pool:** confirmed as `POOL-FIN-02`
- [ ] **Full list of session host VM names in POOL-FIN-01**
  - *Get from: `portal.azure.com → Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts` — copy every name from the Name column (e.g. SHFIN-01-A, SHFIN-01-B)*
- [ ] **Time users first reported the black screen** (e.g. 07:00) — ask the reporter or check the ticket timestamp
- [ ] **Number of users affected** — ask the reporter, or in the portal go to `Session hosts → [each host] → Sessions` and count active sessions
- [ ] **Test account username** that has an assigned desktop in POOL-FIN-01 — confirm with the service desk or your Azure AD admin; this is used in Step 9 and must not be a live user account
- [ ] **Change ticket number authorising the rollback** — obtain change authority approval before touching any host

---

### Checklist D — Symptom Confirmation Gate

Do not skip this. Only proceed if **all three** statements are true:

- [ ] Users on POOL-FIN-01 describe a black or blank screen that appears **immediately after login** (within 5 seconds of the desktop starting to load)
- [ ] The following event sequence appears on at least one POOL-FIN-01 host in Event Viewer (you will check this in Step 2):
  `Event ID 21 → Event ID 1000 (faulting app: dwm.exe, module: igdumd64.dll) → Event ID 40 → Event ID 9009` — all within 10 seconds of each other
- [ ] The same sequence is **absent** on a POOL-FIN-02 host checked in the same time window

> If any statement is false, **stop**. This runbook does not apply to this incident. Raise with your senior engineer and describe exactly what you found.

---

## 2. Procedure

### Phase A — Protect Users (Drain the Pool)

---

**Step 1 — Open the POOL-FIN-01 session host list**

1. Open a browser and go to `https://portal.azure.com`.
2. In the **top search bar**, type `Azure Virtual Desktop` and click the **Azure Virtual Desktop** result under Services.
3. In the left-hand menu of the Azure Virtual Desktop blade, click **Host pools**.
4. In the host pools list, click **POOL-FIN-01**.
5. In the left-hand menu of the POOL-FIN-01 blade, click **Session hosts**.

Expected result: A table appears listing every session host VM in POOL-FIN-01. You can see the **Name**, **Health status**, **Status**, and **Sessions** columns. Leave this browser tab open throughout Phase A.

---

**Step 2 — Identify which hosts were updated overnight (suspect hosts)**

For each host shown in Step 1, run the following PowerShell command from your workstation. Replace `<hostname>` with each actual VM name.

```powershell
Get-WinEvent -ComputerName <hostname> -FilterHashtable @{
    LogName      = 'System'
    ProviderName = 'Microsoft-Windows-Kernel-General'
    Id           = 1
} -MaxEvents 1 | Select-Object TimeCreated, Message
```

- The `Message` field contains a line beginning with `The system boot time is`. Read that timestamp.
- If the boot time is **between 02:00 and 03:00 on the incident date** → mark the host as **SUSPECT** (updated).
- If the boot time is earlier than 02:00 on the incident date → mark the host as **CLEAN** (not updated).

Write a list in your notes before continuing:
```
SHFIN-01-A  boot 02:03  → SUSPECT
SHFIN-01-B  boot 02:04  → SUSPECT
SHFIN-01-C  boot 19:45 (previous day)  → CLEAN
```

Expected result: Every host is assigned SUSPECT or CLEAN. Only SUSPECT hosts are acted on in Steps 3–8.

> **Flag:** Requires local admin rights on each host (confirmed in Checklist A).

**Log location:** `Event Viewer → Windows Logs → System` — Source: `Microsoft-Windows-Kernel-General` — Event ID `1`

---

**Step 3 — Set Drain Mode ON for every SUSPECT host**

Repeat these sub-steps for each SUSPECT host, one at a time:

1. In the Session hosts list (from Step 1), click the **hostname** of the first SUSPECT host. The host's detail blade opens on the right.
2. At the top of the blade, click **Properties** (it appears as a tab or button in the toolbar).
3. Locate the **Allow new sessions** toggle. Click it so it shows **Off** (toggle turns grey/white).
4. Click **Save** at the top of the Properties pane.
5. Click **Session hosts** in the breadcrumb trail at the top of the page to return to the host list.
6. Repeat sub-steps 1–5 for each remaining SUSPECT host.

Expected result: Every SUSPECT host shows **Drain mode: On** in the Session hosts list (visible in the Status or Drain mode column). New user sessions will not be routed to these hosts from this point.

> **Flag:** Requires Desktop Virtualization Host Pool Contributor role.

---

**Step 4 — Warn active users to save their work**

For each SUSPECT host where the **Sessions** column shows a number greater than 0:

1. Click the **hostname** of that host in the Session hosts list.
2. In the host blade's left-hand menu, click **Sessions**.
3. If the sessions list is not empty: tick the **checkbox at the top** of the list to select all sessions.
4. Click **Send message** in the toolbar above the list.
5. In the message dialogue, paste this text exactly:
   > `We are resolving a login issue on this host. Please save all open work now. You will be disconnected within 10 minutes and will need to reconnect.`
6. Click **Send**.
7. A green success notification appears in the top-right corner of the portal. Note the time you sent it in the incident ticket.
8. Click **Session hosts** in the breadcrumb to return to the list and repeat for the next SUSPECT host with active sessions.

Expected result: A green success toast appears after each Send. Users on those hosts see the message pop up on their screen immediately.

---

**Step 5 — Force log off all sessions from SUSPECT hosts**

Wait **5 minutes** after Step 4 to give users time to save work. Then, for each SUSPECT host:

1. Click the **hostname** of the host in the Session hosts list.
2. In the left-hand menu, click **Sessions**.
3. If the sessions list is not empty: tick the **checkbox at the top** to select all sessions.
4. Click **Log off** in the toolbar.
5. A confirmation prompt appears: "Are you sure you want to log off the selected sessions?" Click **Log off**.
6. Wait 10–15 seconds. The sessions list should empty. If sessions remain, tick them all and click **Log off** again.
7. Confirm the Sessions list shows **0 entries**.
8. Return to Session hosts and repeat for each remaining SUSPECT host.

Expected result: Every SUSPECT host shows **0** in the Sessions column.

> **Flag:** Force log-off requires Desktop Virtualization Host Pool Contributor. If acting outside normal business hours, confirm with the affected team's line manager before proceeding.

---

### Phase B — Roll Back the Image

---

**Step 6 — Find the known-good image version from Azure Compute Gallery**

1. In the Azure portal **top search bar**, type `Azure Compute Gallery` and click the **Azure Compute Gallery** result.
2. In the gallery list, click the gallery used for AVD Finance images. The name will be in the change record from the overnight update; it typically contains "avd" or "fin".
3. In the gallery blade's left-hand menu, click **Image definitions**.
4. Click the image definition used for the Finance pool (e.g. `avd-finance-win11` or similar — check the change record if unsure).
5. In the image definition blade's left-hand menu, click **Versions**.
6. The versions list appears with columns including **Version**, **Published date**, and **Replication status**.
   - Find the version whose **Published date** is immediately **before** the overnight update (the update ran at ~02:00 on the incident date, so look for a published date one or more days prior).
   - That earlier version is your rollback target.
7. Click that version's row. In the **Overview** pane, copy the full string shown under **Version number** (format: `1.0.YYYYMMDD`, e.g. `1.0.20260801`).
8. Write the version string in your incident notes.

> **Confirm before proceeding:** Open a new portal tab. Go to `Azure Virtual Desktop → Host pools → POOL-FIN-02 → Session hosts`, click any host, click **Properties**, and read its **Image version** field. It must match the version you just recorded. If it does not match, **stop and escalate** — do not reimage until the correct version is confirmed.

Expected result: You have the exact known-good image version string recorded and cross-checked against POOL-FIN-02.

---

**Step 7 — Reimage each SUSPECT host to the known-good image version**

Process **one host at a time**. Do not start the next host until the current reimagine shows **Succeeded**.

Repeat these sub-steps for each SUSPECT host:

1. In the Azure portal top search bar, type `Virtual machines` and click the **Virtual machines** result.
2. In the VM list, find and click the SUSPECT host name (e.g. `SHFIN-01-A`).
3. The VM's Overview blade opens. Confirm the VM name in the page header matches the host you intend to reimage.
4. In the top toolbar of the Overview blade, click **Reimagine**. If you do not see it, click the **...** (ellipsis / More) button in the toolbar to find it in the dropdown.
5. A **Reimagine** panel slides in from the right. Fill in the fields:
   - **Image source**: select **Azure Compute Gallery**
   - **Gallery**: select the same gallery from Step 6
   - **Image definition**: select the Finance image definition from Step 6
   - **Image version**: select the known-good version string you recorded in Step 6
6. Read back the version shown in the panel. Confirm it matches your noted version exactly.
7. Click **Apply** (button label may say **Reimagine** in some portal versions).
8. Monitor the job: click the **bell (Notifications) icon** in the top-right of the portal. Look for the entry `Reimagining virtual machine <hostname>`. Wait until it shows **Succeeded** — this typically takes 5–10 minutes.
9. After Succeeded, wait a further **2–3 minutes** for the VM to boot fully and for the AVD agent to re-register.
10. Return to sub-step 1 for the next SUSPECT host.

Expected result: Every SUSPECT host's reimagine notification shows **Succeeded**. The VM restarts automatically as part of the reimagine process.

> **Flag:** Requires Virtual Machine Contributor role. Reimaging overwrites the OS disk — this cannot be undone. Verify the image version in sub-step 6 before clicking Apply.

---

**Step 8 — Confirm each reimaged host re-registers with the host pool**

For each reimaged host, after its reimagine shows Succeeded:

1. Go to `https://portal.azure.com → Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts`.
2. Locate the host in the list and check the **Health status** column:
   - **Available** → proceed to Step 9.
   - **Loading** or blank → wait 2 minutes, press F5 to refresh, check again.
   - **Unavailable** or **Needs Assistance** → click the host name, click **Health** in the left menu, read the health check failure reason, and **escalate to your senior engineer** before going further.

Expected result: All reimaged hosts show **Health status: Available** within 5 minutes of VM startup.

---

### Phase C — Test Logon Before Full Release

---

**Step 9 — Run a test logon on one reimaged host**

Use the test account identified in Checklist C. Do not use a live user account.

1. On your workstation, press `Win + R`, type `mstsc`, press Enter.
2. In the **Computer** field of the Remote Desktop Connection window, type the full hostname of one reimaged host (e.g. `SHFIN-01-A.finbridge.local` — use the format your team uses for direct host connections; check with your senior engineer if unsure of the FQDN).
3. Click **Connect**.
4. At the credential prompt, enter the **test account** username and password.
5. Watch the screen for up to 30 seconds:
   - Full desktop appears and stays stable → **PASS** — continue to Step 10.
   - Black screen that does not clear after 30 seconds → **FAIL** — go immediately to the Rollback section.
   - Automatic disconnection within 10 seconds of login → **FAIL** — go immediately to the Rollback section.
6. If the desktop loads successfully, leave the session open and continue to Step 10.

Expected result: The test account desktop appears and remains stable within 30 seconds. No black screen. No disconnection.

---

**Step 10 — Check the Application event log on the test host for DWM crashes**

Run this PowerShell command from your **workstation** (not inside the test session). Replace `<hostname>` with the host from Step 9.

```powershell
Get-WinEvent -ComputerName <hostname> -FilterHashtable @{
    LogName   = 'Application'
    Id        = 1000
    StartTime = (Get-Date).AddMinutes(-15)
} | Where-Object { $_.Message -like '*dwm.exe*' } | Select-Object TimeCreated, Message
```

Expected result: The command returns **no output** — an empty result means no DWM crashes in the last 15 minutes. If any rows are returned showing `dwm.exe`, **stop and go to Rollback**.

**Log location:** `Event Viewer → Windows Logs → Application` — Source: `Application Error` — Event ID `1000`

To check the same log interactively in Event Viewer:
1. Press `Win + R` on your workstation, type `eventvwr.msc /server:<hostname>`, press Enter.
2. In the left pane, expand **Windows Logs** → click **Application**.
3. In the right-hand **Actions** pane, click **Filter Current Log…**
4. In the **Event sources** field, type `Application Error`. In the **\<All Event IDs\>** box, type `1000`. Click **OK**.
5. Scan the filtered results: look at the **General** tab of each entry. Any entry mentioning `dwm.exe` is a failure.

---

**Step 11 — Confirm DWM started cleanly (no crash-exit event)**

From your workstation, run:

```powershell
Get-WinEvent -ComputerName <hostname> -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'Desktop Window Manager'
    StartTime    = (Get-Date).AddMinutes(-15)
} | Select-Object TimeCreated, Id, Message | Sort-Object TimeCreated
```

Read the output:
- **Event ID 9011** must be present (DWM started successfully).
- **Event ID 9009** must be absent (DWM terminated with error).

If Event ID 9009 appears, **stop and go to Rollback**.

**Log location:** `Event Viewer → Windows Logs → Application` — Source: `Desktop Window Manager` — Event IDs `9009` (bad) / `9011` (good)

Expected result: Output contains at least one Event ID 9011. No Event ID 9009 is present.

---

**Step 12 — Release all reimaged hosts to users**

Only proceed after Steps 9, 10, and 11 have all passed on the test host.

For each reimaged SUSPECT host (including the one used for the test):

1. Go to `Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts`.
2. Click the **hostname** of the host.
3. Click **Properties** in the left-hand menu.
4. Set the **Allow new sessions** toggle to **On** (toggle turns blue).
5. Click **Save**.
6. Click **Session hosts** in the breadcrumb and repeat for each remaining reimaged host.

Expected result: Every reimaged host shows **Drain mode: Off** in the Session hosts list. User sessions are being routed to these hosts again.

---

## 3. Verification

Complete all four checks in order. Do not close the incident ticket until every check shows the expected result.

---

**V1 — Live user logon test**

1. Open **mstsc** (`Win + R` → type `mstsc` → Enter).
2. In the **Computer** field, type the hostname of one reimaged POOL-FIN-01 host (e.g. `SHFIN-01-A.finbridge.local`).
3. Click **Connect**. At the credential prompt, log in with the **test account** from Checklist C.
4. Watch the screen for 30 seconds.

Expected result: A full Windows desktop appears and stays stable. No black screen. No automatic disconnection. If it fails, do not close the incident — go to Rollback.

---

**V2 — No DWM crash events on any reimaged host (Application log check)**

Run this once per reimaged host from your workstation. Replace `<hostname>` each time.

```powershell
Get-WinEvent -ComputerName <hostname> -FilterHashtable @{
    LogName   = 'Application'
    Id        = 1000
    StartTime = (Get-Date).AddMinutes(-30)
} | Where-Object { $_.Message -like '*dwm.exe*' } | Select-Object TimeCreated, Message
```

Expected result: **No output** for every host. Any row returned means DWM is still crashing — do not close the incident.

**Log location:** `Event Viewer → Windows Logs → Application`
  - Source filter: `Application Error`
  - Event ID filter: `1000`
  - Look in the **General** tab for any entry where the description mentions `dwm.exe` and module `igdumd64.dll`

To open Event Viewer on a specific host remotely:
1. Press `Win + R` on your workstation, type `eventvwr.msc /server:<hostname>`, press Enter.
2. In the left pane expand **Windows Logs** → click **Application**.
3. In the **Actions** pane (far right) click **Filter Current Log…**
4. In the **Event sources** box type `Application Error`. In the **\<All Event IDs\>** box type `1000`. Click **OK**.
5. Scan results — any `dwm.exe` entry is a fail.

---

**V3 — All POOL-FIN-01 hosts show Available with Drain Mode Off**

1. Go to `https://portal.azure.com`.
2. In the top search bar type `Azure Virtual Desktop` → click the **Azure Virtual Desktop** service result.
3. In the left menu click **Host pools** → click **POOL-FIN-01**.
4. In the left menu click **Session hosts**.
5. In the session hosts table, check every row:
   - **Health status** column must show **Available** for every host.
   - **Allow new sessions** column (Drain mode) must show **Yes** / **On** for every reimaged host.

Expected result: All reimaged hosts show `Health status: Available` and `Drain mode: Off`. If any host shows **Unavailable**, **Needs Assistance**, or **Drain mode: On**, do not close the incident — investigate that host before proceeding.

---

**V4 — No active DWM crash alerts in the monitoring platform**

1. Open your organisation's alerting platform (Azure Monitor, SCOM, or equivalent — use the URL your team uses).
2. Navigate to the **Alerts** view and filter by:
   - **Resource:** POOL-FIN-01 session hosts
   - **Severity:** any
   - **Time range:** last 30 minutes
3. Look for any alert whose name or description references `dwm.exe`, `Event ID 1000`, or `Application Error`.

Expected result: No active or firing alerts for POOL-FIN-01 in the last 30 minutes.

---

Only update the incident ticket status to **Resolved** after V1, V2, V3, and V4 have all passed.

---

## 4. Rollback

**Trigger:** Use this section if — after completing Steps 7–12 — reimaged hosts still produce a black screen, DWM crash (Event ID 1000 / `dwm.exe`), or automatic session disconnection.

> Target: complete R1–R4 within 3 minutes. R5 (log export) runs in the background after users are safe.

---

**R1 — Drain all POOL-FIN-01 hosts immediately** *(~60 seconds)*

1. Go to `https://portal.azure.com` → top search bar → type `Azure Virtual Desktop` → click the service result.
2. Left menu → **Host pools** → click **POOL-FIN-01** → left menu → **Session hosts**.
3. For **every host** in the list:
   - Click the host **name** → click **Properties** → set **Allow new sessions** to **Off** → click **Save**.
   - Click **Session hosts** in the breadcrumb and repeat for the next host.

Expected result: Every host in the Session hosts list shows **Drain mode: On**. No new users will be routed to POOL-FIN-01.

---

**R2 — Force log off all active sessions** *(~30 seconds)*

For each host in the Session hosts list that still shows sessions:

1. Click the host **name** → left menu → **Sessions**.
2. Tick the **top checkbox** to select all → click **Log off** in the toolbar → click **Log off** to confirm.
3. Return to Session hosts (breadcrumb) and repeat for remaining hosts.

Expected result: All hosts show **0** in the Sessions column.

---

**R3 — Redirect users to POOL-FIN-02** *(~30 seconds)*

Tell affected users to connect immediately via POOL-FIN-02. Send this message via your team chat or email:

> `POOL-FIN-01 is currently unavailable. Please connect via POOL-FIN-02 using your normal AVD client. Select the POOL-FIN-02 workspace when prompted.`

If your environment uses Application Groups to control user assignment:
1. In the Azure portal top search bar type `Azure Virtual Desktop` → left menu → **Application groups**.
2. Click the Finance application group (e.g. `AppGroup-Finance`).
3. Left menu → **Assignments** → click **Add** → assign the Finance users or group to POOL-FIN-02's application group if not already assigned.

Expected result: Finance users can log in and work via POOL-FIN-02 while POOL-FIN-01 remains drained.

> **Hard stop:** Do not push any image or make any further changes to POOL-FIN-01 or POOL-FIN-02 until you have escalated in R4.

---

**R4 — Escalate with evidence** *(do immediately after R3)*

Call or message your **AVD platform / image engineering team** and the **change authority** who approved the overnight update. Provide:

- The known-good image version you reimaged to (recorded in Step 6 of your incident notes).
- The Event ID 1000 detail from one still-failing host — get it now by running:
  ```powershell
  Get-WinEvent -ComputerName <hostname> -FilterHashtable @{
      LogName   = 'Application'
      Id        = 1000
      StartTime = (Get-Date).AddMinutes(-30)
  } | Where-Object { $_.Message -like '*dwm.exe*' } |
  Select-Object TimeCreated, Message | Select-Object -First 3
  ```
  **Log location:** `Event Viewer → Windows Logs → Application` — Source: `Application Error` — Event ID `1000`
- A screenshot of the Azure portal Notifications panel showing the reimagine job status:
  `portal.azure.com → bell icon (top-right) → find "Reimagining virtual machine <hostname>" → screenshot the status`

---

**R5 — Preserve logs before any further changes** *(run in the background after R3/R4)*

On each still-failing host, run from your workstation:

```powershell
# Replace <hostname> and <YYYYMMDD> before running
wevtutil epl Application "C:\Temp\App_<hostname>_<YYYYMMDD>.evtx" /r:<hostname>
wevtutil epl System     "C:\Temp\Sys_<hostname>_<YYYYMMDD>.evtx"  /r:<hostname>
```

Copy both `.evtx` files to a network share or attach to the incident ticket before any further reimagine is attempted.

**Log locations being exported:**
- `Event Viewer → Windows Logs → Application` (contains Event ID 1000 DWM crashes)
- `Event Viewer → Windows Logs → System` (contains Kernel-General Event ID 1 boot-time evidence)

---

## 5. Notes

### Edge Cases

- **Some hosts in POOL-FIN-01 were not updated overnight:** If Kernel-General Event ID 1 on a host shows a boot time *before* 02:00 on the incident date, that host was not updated. Do not reimage it — it may already be running the good image. Verify by checking its image version in the Azure portal before acting.

- **Transient recovery (black screen clears after ~30 seconds):** Some sessions may appear to recover. This is a partial DWM restart, not a fix. The crash-and-reconnect cycle will repeat. Do not allow those users to continue working on updated hosts — drain the host as per Step 3.

- **Test account has no profile yet:** If using a fresh test account in Step 10, FSLogix profile creation may add 10–15 seconds to first logon. This is normal. Wait the full 30 seconds before judging the logon a failure.

- **Host shows Available in portal but users still can't log in:** The portal health check reflects AVD agent registration, not DWM stability. Always perform the Event Viewer check (Steps 11–12) alongside the portal check.

### Warnings

- **Do not reimage a host with active user sessions.** Always confirm session count = 0 (Step 5) before running Step 7.
- **The faulty image version must not be assigned to any new host.** After incident resolution, raise a task with the image team to block that version in Azure Compute Gallery before the next scheduled host refresh.
- **igdumd64.dll version 31.0.101.4146 is the confirmed bad driver.** If this version appears in an Event ID 1000 on any host outside POOL-FIN-01, treat it as the same root cause and escalate immediately.

### Related Incidents

- This incident: RCA_AVD_Black_Screen_POOL-FIN-01_20260806.md
- See also: Known_Error_Record_AVD_Black_Screen_20260807.md
- CAPA tracking: AVD image release SOP update and automated gating — assigned to Endpoint Engineering, target before next image refresh.

### Key Event IDs for Reference

| Event ID | Source | Meaning |
|---|---|---|
| 21 | TerminalServices-LocalSessionManager | Logon succeeded |
| 40 | TerminalServices-LocalSessionManager | Session disconnected |
| 1000 | Application Error | Application crash (check faulting module) |
| 9009 | Desktop Window Manager | DWM exited with error |
| 9011 | Desktop Window Manager | DWM started successfully |
| 1 | Kernel-General | System boot time |

---
*Runbook derived from RCA_AVD_Black_Screen_POOL-FIN-01_20260806.md | Prepared 2026-08-07*
