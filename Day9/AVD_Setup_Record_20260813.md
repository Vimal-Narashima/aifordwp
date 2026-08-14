# Azure Virtual Desktop Setup Record

Date executed: 2026-08-13
Subscription: 9a89dd7c-2c36-41b4-9f7a-b7f73e94be56
Resource Group: dwpai-lab-rg
Region: East US
Tenant: zippyops.in
Requested user: p60@zippyops.in

## Permission Pre-Check
- Signed-in identity: traininguser80@zippyops.in
- Effective role on subscription: Owner
- Effective role on resource group: Owner
- Role assignment capability: Confirmed

## Deployed AVD Components
- Host pool: POOL-FIN-01
- Host pool type: Pooled
- Load balancing: BreadthFirst
- Max sessions per host: 5
- Desktop app group: POOL-FIN-01-DAG
- Workspace: FinBridge-Workspace
- App group registration to workspace: Completed

## Session Host VM
- VM name: avd-fin-01
- VM size: Standard_B2ms
- Image: MicrosoftWindowsDesktop:windows-11:win11-24h2-avd:latest
- Security type: TrustedLaunch
- Secure Boot: Enabled
- vTPM: Enabled
- Join state target: Microsoft Entra ID joined only

## Access Assignments Applied
- p60@zippyops.in -> Virtual Machine User Login (scope: avd-fin-01)
- p60@zippyops.in -> Desktop Virtualization User (scope: POOL-FIN-01-DAG)

## Diagnostics and Remediation
- VM provisioning failures diagnosed via ARM deployment errors.
- Cause identified: incompatible patch settings with selected image.
- Fix applied: patch mode set to Manual with automatic updates disabled.
- Session host Unavailable state diagnosed using VM-side logs and dsregcmd.
- Join issue corrected; post-fix validation showed:
  - AzureAdJoined: YES
  - DomainJoined: NO

## Final Status Verification
- Session host resource: POOL-FIN-01/avd-fin-01
- Session host status: Available
- Allow new sessions: True
- Current sessions: 0

## Notes
- The Desktop Virtualization CLI extension in this environment did not expose direct session host subcommands.
- Session host status was verified using az rest against Microsoft.DesktopVirtualization API.
