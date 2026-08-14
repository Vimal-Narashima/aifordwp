# JAMF macOS Security Baseline Build Guide (Based on Typical JAMF Pro UI)

Date: 2026-08-14  
Role context: DWP Desktop/Endpoint Engineering  
Fleet scope: Design team, 25 managed macOS devices

## Verification Discipline (Same Rule as Day 6 Intune Labs)

JAMF Pro UI labels, payload locations, and compliance feature names can change by JAMF Pro version and macOS generation.

Every control below that includes **Verify label in your JAMF instance** must be checked against your own tenant UI before deployment. Do not trust exact wording in this guide as a universal constant.

---

## Navigation in your tenant

Use this path to create the baseline profile:

- Computers -> Configuration Profiles -> New

Also prepare the following companion areas:

- Computers -> Smart Computer Groups (for version/compliance targeting)
- Computers -> Policies (if you enforce update actions via policy)
- Computers -> Inventory (for per-device verification)

---

## Build sequence overview

Create one primary configuration profile for controls 1, 2, 4, and 5, and manage controls 3 and 6 with compliance/update logic that may span Smart Groups + Software Update settings.

Recommended implementation order:

1. Create static or smart pilot scope (3-5 devices).
2. Build profile payloads for FileVault, Gatekeeper, Firewall, and password-after-sleep.
3. Build minimum macOS version logic using Smart Group criteria.
4. Build automatic security update enforcement.
5. Validate on pilot, then expand to all 25 devices.

---

## Step-by-step profile build

### 1) General tab

Set:

- Name: macOS Security Baseline - Design Fleet
- Description: Baseline controls for FileVault, Gatekeeper, minimum macOS version, firewall, wake authentication, and automatic security updates.
- Level: Computer Level
- Distribution Method: Install Automatically
- User Removable: No

Then select Save (or continue to payload selection, depending on UI flow).

### 2) Payload: FileVault

Payload type: **Security & Privacy -> FileVault** (or dedicated FileVault payload) - **Verify label in your JAMF instance**

Set:

- Enable FileVault: Enabled
- Recovery key type: Institutional and/or Personal Recovery Key per your standard
- Escrow location: JAMF Pro
- Defer enablement options: Keep minimal; avoid indefinite deferrals

Effect:

- Enforces full-disk encryption and supports enterprise recovery workflows.

Common false-positive risk:

- Device reports noncompliant while encryption is still progressing or before escrow confirmation appears in inventory.

### 3) Payload: Gatekeeper (identified developers only)

Payload type: **Restrictions** or **Security & Privacy** app execution controls - **Verify label in your JAMF instance**

Set:

- Allow apps from: App Store and identified developers
- Do not allow "Anywhere" exception baseline-wide

Effect:

- Blocks unsigned/untrusted software by default.

Common false-positive risk:

- Admin/user one-time overrides (right-click Open) and unusual signing chains can make healthy devices look inconsistent in spot checks.

### 4) Payload: Firewall

Payload type: **Security & Privacy -> Firewall** - **Verify label in your JAMF instance**

Set:

- Firewall: Enabled
- Optionally enable stealth mode if this is part of your formal security standard
- Keep "block all incoming" aligned with design tooling requirements to avoid workflow breakage

Effect:

- Reduces inbound attack surface via host firewall enforcement.

Common false-positive risk:

- Local app allow-list behavior or third-party endpoint tools can be misread as firewall disabled.

### 5) Payload: Password required after sleep or screen saver

Payload type: **Security & Privacy** authentication/wake lock controls - **Verify label in your JAMF instance**

Set:

- Require password after sleep or screen saver: Enabled
- Grace period: Immediately (or lowest approved value)

Effect:

- Prevents unattended access after wake/screen saver exit.

Common false-positive risk:

- Delayed profile application, conflicting legacy local preference, or accessibility exceptions can temporarily mask enforcement.

### 6) Automatic security updates

Payload type: **Software Update** management controls - **Verify label in your JAMF instance**

Set:

- Automatically check for updates: Enabled
- Download new updates when available: Enabled
- Install system data files and security updates: Enabled
- Apply update deferrals only where formally approved

Effect:

- Keeps security patches flowing with minimal manual user action.

Common false-positive risk:

- Restart pending, network/CDN delays, or temporary Apple update catalog issues.

### 7) Minimum macOS version (current stable minus one point release)

Important: This is usually not a single payload checkbox. Implement using Smart Group compliance logic plus update workflow/policy linkage.

Implementation pattern:

1. Determine current stable macOS point release in your release governance process.
2. Set baseline minimum version to one point release behind.
3. Build Smart Group criteria to detect devices below this minimum.
4. Scope update policy/notifications/remediation to that Smart Group.

Example math:

$$
	ext{Minimum Allowed} = \text{Current Stable} - 1\text{ point release}
$$

If current stable is 15.5, minimum allowed is 15.4.

Common false-positive risk:

- Inventory not refreshed, beta/dev seed version strings, or powered-off endpoints missing latest check-in.

---

## Scope and assignment model (25-device design fleet)

Recommended groups:

- Include group: Design-macOS-Production (25 devices)
- Pilot include group: Design-macOS-Pilot (3-5 devices)
- Exclusion group: Approved temporary exceptions (time-bounded)

Assignment sequence:

1. Deploy to pilot group.
2. Validate for 24 hours.
3. Expand to production group.
4. Keep exclusion group narrow, approved, and expiry-tracked.

---

## Post-assignment validation steps (after test device check-in)

### 1) Where to verify policy application and payload state

Use profile-centric view first:

- Computers -> Configuration Profiles
- Select macOS Security Baseline - Design Fleet
- Open scope/deployment status and failed/pending device views

Use device-centric view as cross-check:

- Computers -> Inventory
- Select a test Mac
- Review Profiles, Security, and OS version details

### 2) Status interpretation and access impact

- Profile Installed / Applied:
	- Meaning: Baseline payload reached device and is active.
	- Access impact: Device can satisfy downstream conditional access/compliance gates if other prerequisites are met.

- Pending:
	- Meaning: Device has not yet completed check-in/install cycle.
	- Access impact: May still fail compliance-driven access if relying system expects fresh state.

- Failed:
	- Meaning: Payload install error, conflict, unsupported setting, or scope issue.
	- Access impact: Device may remain noncompliant for controls tied to access policies.

---

## False-positive triage: top causes and fastest checks

### A) FileVault appears noncompliant but is actually encrypting

- Why it happens: Encryption/escrow state lags inventory refresh.
- Fastest check on endpoint:
	- Run `fdesetup status`
	- Confirm encryption state, then force inventory update/check-in and re-verify escrow record.

### B) macOS minimum version appears below baseline incorrectly

- Why it happens: Last inventory timestamp is stale or device is on seed build naming.
- Fastest check:
	- Compare local `sw_vers` output to JAMF inventory version field.
	- Trigger recon/check-in and re-evaluate Smart Group membership.

### C) Firewall/Gatekeeper mismatch in console view

- Why it happens: Local override history, tool conflict, or delayed profile apply after reboot.
- Fastest check:
	- On endpoint, verify firewall and Gatekeeper state with native commands/preferences.
	- Reconcile with profile install timestamp in JAMF.

---

## First 24-hour monitoring checklist

- Deployment trend:
	- Monitor installed vs pending vs failed in profile deployment view every 2-4 hours.

- Setting-level spike detection:
	- Identify whether failures cluster on one payload (commonly FileVault escrow timing or update restart).

- Hardware/model correlation:
	- Check whether failures are concentrated by Mac model, chip generation, or OS ring.

- Update and restart behavior:
	- Confirm whether security updates were downloaded/applied and whether restart deferrals are blocking completion.

- Exception hygiene:
	- Ensure temporary exclusions are approved, documented, and time-limited.

---

## Requirement-to-setting map (final)

### Requirement 1: FileVault disk encryption must be enabled

- Payload type: Security & Privacy -> FileVault (**Verify label in your JAMF instance**)
- Value: Enable FileVault and escrow recovery key to JAMF
- Effect: Encrypts data at rest and enforces managed recovery
- False-positive risk: Encryption/escrow status lag during in-progress or first post-enable check-in

### Requirement 2: Gatekeeper must be enabled (identified developers only)

- Payload type: Restrictions or Security & Privacy app security control (**Verify label in your JAMF instance**)
- Value: Allow apps from App Store and identified developers
- Effect: Blocks untrusted/unsigned app execution by default
- False-positive risk: One-time local override behavior and nonstandard app signing chains

### Requirement 3: Minimum macOS version = current stable minus one point release

- Payload type: Smart Group/compliance criteria plus update policy linkage (**Verify label in your JAMF instance**)
- Value: Minimum OS = stable - 1 point release
- Effect: Flags and remediates devices lagging behind allowed patch level
- False-positive risk: Stale inventory, seed builds, and check-in timing gaps

### Requirement 4: Firewall must be enabled

- Payload type: Security & Privacy -> Firewall (**Verify label in your JAMF instance**)
- Value: Enable firewall (plus stealth mode if mandated)
- Effect: Enforces inbound network protection at host level
- False-positive risk: Reporting interpretation issues from local exceptions or third-party tooling interactions

### Requirement 5: Login password required after sleep/screen saver

- Payload type: Security & Privacy wake authentication controls (**Verify label in your JAMF instance**)
- Value: Require password immediately after sleep/screen saver
- Effect: Prevents unattended post-wake access
- False-positive risk: Policy conflict, delayed application, or approved temporary accessibility exception

### Requirement 6: Automatic security updates enabled

- Payload type: Software Update controls (**Verify label in your JAMF instance**)
- Value: Enable automatic checks/download and security update install
- Effect: Reduces vulnerability window by enforcing regular patch intake
- False-positive risk: Restart postponement, Apple update service latency, or short-term network outage

---

## Operational recommendations

1. Keep this as a baseline profile only; avoid mixing unrelated UX restrictions in the same object.
2. Pair profile enforcement with clear user comms for restarts and update windows.
3. Re-validate every payload name/value after JAMF upgrades and major macOS releases.
4. Maintain an exception register with owner, reason, approval, and expiry.
