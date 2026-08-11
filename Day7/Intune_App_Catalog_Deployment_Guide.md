# Intune App Catalog: Adding a Windows LOB App
## Step-by-Step Guide for DWP Desktop/Endpoint Engineers

**Worked Example:** FinBridge Connect v3.1 — Windows LOB app (.intunewin package)
**Audience:** Engineers with no prior Intune app-deployment experience
**Date:** August 2026

---

> **Data Handling Reminder:** Do not enter real hostnames, internal network paths, or production device names into Intune fields when following this guide in a lab or training context. Use anonymised or synthetic values until deploying to production under a live change record.

---

## Part 1 — Where to Add an App in Intune

### 1.1 Navigate to the Apps section

1. Open a browser and go to the Microsoft Intune admin center:
   `https://intune.microsoft.com`
2. Sign in with your Intune administrator credentials.
3. In the left-hand navigation pane, select **Apps**.
4. Under **Apps**, select **All apps**.
5. Click **+ Add** in the toolbar at the top of the app list. A **Select app type** pane will open. The first field displayed is a **Platform** dropdown — select **Windows** to reveal the app type options.

> **UI VARIANCE WARNING:** The exact label and position of the **+ Add** button may differ depending on your tenant's Intune portal version. If you do not see **+ Add**, look for **Create**, **New app**, or a **+** icon in the toolbar. The **Platform** dropdown is the current confirmed UI pattern (verified August 2026) — earlier tenant versions may show app type options directly without a platform step. Verify against your live tenant before proceeding.

---

### 1.2 Select the correct app type

After selecting **Windows** in the **Platform** dropdown, an **App type** field will appear. Choose the type that matches your package:

| Scenario | App Type to Select |
|---|---|
| Windows LOB app packaged as a `.intunewin` file | **Line-of-business app** (under the *App type* dropdown, select **Windows app (Win32)**) |
| App available in the Microsoft Store | **Microsoft Store app (new)** |
| Web-based tool you want pinned as a shortcut | **Web link** |

> **UI VARIANCE WARNING:** The label **Windows app (Win32)** is the current standard name for Win32/`.intunewin` deployments. In some tenant versions this may appear as **Win32 app** or **Windows (Win32)**. If you are unsure, look for the option that references `.intunewin` packaging. Verify against your live tenant.

**For our worked example:** Select **Windows app (Win32)**.

Click **Select** to proceed.

---

## Part 2 — Required Fields When Creating a LOB Windows App

You will work through a series of configuration tabs. Complete every field marked with an asterisk (*) before the app can be saved.

---

### 2.1 App information

This tab captures the identity of the app as it will appear in the portal and on devices.

| Field | What to Enter | Worked Example |
|---|---|---|
| **Name** * | Display name shown to users and in reports | `FinBridge Connect` |
| **Description** * | Plain-language summary of what the app does | `FinBridge Connect v3.1 — financial data integration client for DWP desktop users.` |
| **Publisher** * | Vendor or internal team responsible for the package | `FinBridge Ltd` |
| **App version** | Version string for your records (not used for detection) | `3.1` |
| **Category** | Optional grouping (e.g., Business, Productivity) | `Business` |
| **Logo** | Upload a `.png` icon if available | *(optional — upload vendor icon)* |

Click **Next** when complete.

---

### 2.2 Program

This tab tells Intune how to silently install and remove the app, and in which security context to run the installer.

| Field | Guidance | Worked Example |
|---|---|---|
| **Install command** * | Full command Intune runs to install. Must be silent/unattended. | `FinBridgeConnect_Setup.exe /silent` |
| **Uninstall command** * | Full command to silently remove the app. | `FinBridgeConnect_Setup.exe /uninstall /silent` |
| **Install behavior** * | **System** context runs as SYSTEM (recommended for machine-wide installs). **User** context runs as the logged-in user. | `System` |
| **Device restart behavior** | Controls whether Intune reboots after install. Set to **No specific action** unless your installer requires a restart. | `No specific action` |

> **Important — Install behavior:** Choose **System** for any app that writes to `HKLM`, installs drivers, or needs elevation. Choose **User** only for per-user applications that install into the user profile. FinBridge Connect writes to `HKLM`, so **System** is correct here.

> **UI VARIANCE WARNING:** The **Install behavior** field may be labelled **Run as account** or **Execution context** in some tenant versions. Verify against your live tenant.

Click **Next** when complete.

---

### 2.3 Requirements

Requirements define the minimum device conditions that must be met before Intune attempts to install the app. Devices that do not meet requirements will show **Not applicable** — this is expected and correct behaviour.

The tab header sequence confirmed in the portal is: **App information → Program → Requirements → Detection rules → Dependencies → Supersedence**. This guide covers the steps relevant to a standard first-time deployment; Dependencies and Supersede can be left at defaults unless your app requires them.

#### Required fields

**Check operating system architecture** *

This field uses radio buttons:
- **Yes. Specify the systems the app can be installed on.** — selecting this reveals architecture checkboxes (e.g., 32-bit, 64-bit). Choose this option to restrict deployment to specific architectures.
- **No. Allow this app to be installed on all systems.** — Intune will not filter by architecture.

**For our worked example:** Select **Yes**, then check **64-bit** only.

**Minimum operating system** *

Select the lowest Windows version the app supports from the dropdown. The dropdown starts at **Windows 10 1607** and lists each feature update build in sequence.

**For our worked example:** Select **Windows 10 21H2** or the nearest available build your organisation supports. If your required version does not appear exactly, select the nearest available option and note the discrepancy in your change record.

> **UI VARIANCE WARNING:** OS version labels in the dropdown change as Microsoft adds new builds. Verify the available options against your live tenant.

#### Optional hardware requirement fields

The following fields are visible on the tab but can be left blank unless your app has specific hardware prerequisites:

| Field | Purpose |
|---|---|
| **Disk space required (MB)** | Minimum free disk space on the device |
| **Physical memory required (MB)** | Minimum RAM |
| **Minimum number of logical processors required** | Minimum CPU core count |
| **Minimum CPU speed required (MHz)** | Minimum processor speed |
| **Configure additional requirement rules** | Link to add custom script-based or registry-based requirement rules |

Leave all optional fields blank for FinBridge Connect unless the vendor documentation specifies hardware minimums.

Click **Next** when complete.

---

### 2.4 Detection rules

Detection rules tell Intune how to verify the app installed successfully. Intune re-evaluates these rules on each device check-in. An app is only reported as **Installed** when the detection rule returns a positive match.

The tab opens with a single required field:

**Rules format** * — a **Select one** dropdown. You must choose a format before any further options appear.

| Rules format option | When to use |
|---|---|
| **Manually configure detection rules** | Standard choice — lets you add individual registry, file, or MSI product code rules |
| **Use a custom detection script** | Use only when no static rule can reliably detect the app (e.g., complex version logic) |

**For our worked example:** Select **Manually configure detection rules**. A **+ Add** button will appear below.

**Rule types available after selecting manual rules:**

| Rule type | When to use |
|---|---|
| **Registry** | App writes a version key to the registry (most common for LOB apps) |
| **MSI product code** | App is an MSI and has a known product GUID |
| **File** | No registry key — detect by the presence of a file or folder |

#### Setting up a Registry detection rule (worked example)

1. From the **Rules format** dropdown, select **Manually configure detection rules**.
2. Click **+ Add**.
3. Set **Rule type** to **Registry**.
3. Complete the fields as follows:

| Field | Value |
|---|---|
| **Key path** | `HKEY_LOCAL_MACHINE\SOFTWARE\FinBridge\Connect` |
| **Value name** | `Version` |
| **Detection method** | `String comparison` |
| **Operator** | `Equals` |
| **Value** | `3.1` |
| **Associated with a 32-bit app on 64-bit clients** | Leave unchecked unless the app is 32-bit |

> **Important:** The key path entered here must exactly match what the installer writes. Test this on a reference machine by running the installer manually and then inspecting the registry with `regedit` or `Get-ItemProperty` in PowerShell before finalising the rule.

> **UI VARIANCE WARNING:** Field labels within the detection rule editor (e.g., **Detection method** vs **Comparison type**) vary between portal versions. Verify against your live tenant.

Click **OK** to save the rule, then **Next** to continue.

---

### 2.5 Return codes

Return codes tell Intune how to interpret the exit code your installer returns. Default codes are pre-populated — review them and add any app-specific codes.

| Exit code | Default meaning | When to change |
|---|---|---|
| `0` | Success | Standard — leave as-is |
| `1707` | Success | Standard — leave as-is |
| `3010` | Soft reboot required | Standard — leave as-is |
| `1641` | Hard reboot required | Standard — leave as-is |
| `1618` | Retry | Standard — leave as-is |

If the FinBridge Connect installer returns a non-standard success code (check the vendor's release notes or test in a lab), click **+ Add** and define it here.

> **Tip:** If you are unsure of the installer's return codes, run the install manually in a test environment and capture the exit code with `echo $LASTEXITCODE` in PowerShell. Any code not listed here that the installer returns will be treated as a **failure** by Intune.

Click **Next** to continue.

---

## Part 3 — Assignment Basics

### 3.1 Assignment types explained

On the **Assignments** tab you control who receives the app and in what manner.

| Assignment type | What it does | When to use |
|---|---|---|
| **Required** | Intune installs the app automatically on assigned devices or for assigned users. The user cannot decline. | Mandatory tooling — security agents, core business apps |
| **Available for enrolled devices** | The app appears in Company Portal; the user installs it voluntarily. | Optional or role-specific tools the user may choose to install |
| **Uninstall** | Intune removes the app from assigned devices. | End-of-life apps, licence reclamation, emergency removal |

**For FinBridge Connect:** Use **Required** because this is a business-critical financial client that must be present on all assigned devices.

---

### 3.2 Why you must start with a pilot group — not the full fleet

**Never assign a new or updated app directly to your full device population on first deployment.**

DWP manages approximately 10,000 devices. Assigning directly to all of them means:

- A misconfigured install command or detection rule affects every device simultaneously.
- A failed deployment generates 10,000 failure events, creating significant incident noise.
- Rolling back requires a second fleet-wide operation.

**Correct approach — phased assignment:**

1. **Phase 1 — Pilot (Day 1):** Assign as **Required** to a dedicated test/pilot Azure AD group containing 5–20 known test devices or willing early-adopter users. Monitor for 24–48 hours.
2. **Phase 2 — Broader pilot (Day 3–5):** If Phase 1 shows no failures, expand to a larger representative sample (e.g., 100–200 devices across different hardware models and OS versions).
3. **Phase 3 — Full rollout:** Only after Phase 2 reports acceptable success rates (typically ≥ 95%) proceed with assigning to the full fleet group.

> **DWP Change Process Note:** Each phase expansion should be covered by your change record. Record that AI tooling assisted in producing this guide, in line with the DWP AI usage charter.

#### Adding the pilot assignment

1. On the **Assignments** tab, under **Required**, click **+ Add group**.
2. Search for and select your pilot Azure AD group (e.g., `SG-Intune-AppPilot-FinBridge`).
3. Do **not** add the full fleet group at this stage.
4. Click **Next**.

---

## Part 4 — Verification Steps

### 4.1 Confirm the app appears correctly in the catalog

1. In the Intune admin center, navigate to **Apps > All apps**.
2. Search for `FinBridge Connect` in the search bar.
3. Verify the following columns show the expected values:

| Column | Expected value |
|---|---|
| Name | `FinBridge Connect` |
| Type | `Windows app (Win32)` |
| Publisher | `FinBridge Ltd` |
| Assigned | `Yes` |

4. Click the app name to open its detail pane and confirm:
   - The **Program** tab shows the correct install and uninstall commands.
   - The **Detection rules** tab shows the registry rule for `HKLM\SOFTWARE\FinBridge\Connect\Version = 3.1`.
   - The **Assignments** tab shows only the pilot group under **Required**.

---

### 4.2 Check install status on an assigned test device

1. In the Intune admin center, navigate to **Devices > All devices**.
2. Search for the name of your test device and open it.
3. Select **Managed apps** (or **App install status** — label varies by tenant version).

> **UI VARIANCE WARNING:** The navigation path to per-device app status differs between tenant versions. You may find it under **Monitor > App install status**, or under the device record directly. Verify against your live tenant.

4. Locate **FinBridge Connect** in the list.
5. Review the **Install status** column.

You can also trigger an immediate Intune sync on the test device to speed up policy evaluation:
- On the device: **Settings > Accounts > Access work or school > [your account] > Info > Sync**
- Or via PowerShell (run as administrator):
  ```powershell
  # Trigger an Intune management extension sync
  Get-ScheduledTask -TaskName "PushLaunch" | Start-ScheduledTask
  ```

---

### 4.3 Understanding install status values

| Status | Meaning | Action |
|---|---|---|
| **Installed** | Detection rule returned a positive match. The app is present on the device. | No action needed. Monitor for future compliance drift. |
| **Failed** | The installer returned an unrecognised exit code, the package could not be downloaded, or the installer itself errored. | Check the **Device install status** detail for the specific error code. Review the Intune Management Extension log at `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`. |
| **Not applicable** | The device did not meet the Requirements rules (wrong OS architecture, OS version below minimum, or device excluded by scope). This is expected for devices outside the target scope. | Verify requirements are correctly set if this appears on a device that should be in scope. |
| **Pending** | Intune has queued the installation but the device has not yet checked in or the install has not started. | Wait for the device to check in (typically within 8 hours on a corporate network, or trigger a manual sync). |
| **Not installed** | The device is in scope and requirements are met, but the app has not yet been installed. The install is pending or was never attempted. | Check that the device has checked in recently. Review IME logs if the state persists beyond 24 hours. |

---

## Quick Reference Checklist

Use this checklist to confirm you have completed every required step before declaring the app ready for Phase 2 expansion.

- [ ] App uploaded as Windows app (Win32) with correct `.intunewin` package
- [ ] App name, description, publisher, and version entered correctly
- [ ] Install command: `FinBridgeConnect_Setup.exe /silent`
- [ ] Uninstall command: `FinBridgeConnect_Setup.exe /uninstall /silent`
- [ ] Install behavior set to **System**
- [ ] Requirements: 64-bit, minimum OS version confirmed
- [ ] Detection rule: Registry — `HKLM\SOFTWARE\FinBridge\Connect\Version` equals `3.1`
- [ ] Return codes reviewed; custom codes added if required
- [ ] Assignment scoped to pilot group only — full fleet group NOT assigned
- [ ] App visible in **All apps** catalog with correct metadata
- [ ] Test device shows **Installed** status after check-in
- [ ] IME log reviewed — no unexpected errors

---

*This guide was produced with AI assistance. All portal navigation paths and UI labels should be verified against your live Intune tenant before execution. Follow the DWP change management process for all production deployments.*
