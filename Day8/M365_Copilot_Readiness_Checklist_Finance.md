# Microsoft 365 Copilot Readiness Checklist - Finance

Department: Finance (~200 users)

Context: M365 E5 is already licensed for all users. Copilot add-on is not yet assigned. SharePoint permissions were inherited from a 2019 migration and have not been fully audited since. Data includes payroll, board packs, M&A documents, and client financial data.

Use this as a practical go/no-go checklist before enabling Microsoft 365 Copilot in Finance.

## 1. Highest-priority control: permissions and oversharing review

This is the main readiness gate for Finance. Do not treat it as a routine admin check. If shared drive, SharePoint, or OneDrive permissions are still inherited, stale, or overly broad, Copilot can surface content that users were never intended to see.

- [ ] Inventory all Finance SharePoint sites, document libraries, shared drives, and any legacy migration content.
- [ ] Identify all sites and folders that still carry inherited permissions from the 2019 migration.
- [ ] Review every Finance site with broken inheritance, unique permissions, or nested group access.
- [ ] Confirm board packs, payroll, M&A, and client financial data are restricted to the minimum required audience.
- [ ] Check for everyone-accessible links, broad security groups, shared mailboxes, and old migration groups with access to Finance content.
- [ ] Remove expired, duplicate, orphaned, and contractor access where no longer required.
- [ ] Verify external sharing is disabled or tightly controlled for Finance content.
- [ ] Confirm no sensitive Finance content is stored in open team sites, ad hoc folders, or ungoverned shared drives.
- [ ] Validate OneDrive sharing policies so users cannot overshare Finance material through personal storage.
- [ ] Sample-test search visibility: user A should not be able to discover user B's restricted Finance documents through search or Copilot prompts.
- [ ] Record the remediated permissions model and the owners responsible for ongoing access reviews.
- [ ] Re-run a final oversharing spot-check after remediation and before license assignment.

## 2. Licensing and tenant readiness

- [ ] Confirm Microsoft 365 E5 is active for all intended Finance users.
- [ ] Confirm Copilot for Microsoft 365 add-on licensing is approved for the Finance pilot or rollout group.
- [ ] Confirm licenses are assigned only to the approved Finance population.
- [ ] Confirm any prerequisites in the tenant for Microsoft 365 Copilot have been reviewed and are ready.
- [ ] Confirm service health is stable for Microsoft 365, SharePoint, OneDrive, Exchange, and Teams.

## 3. Microsoft 365 Apps client readiness

- [ ] Confirm users are on supported Microsoft 365 Apps versions for Copilot.
- [ ] Confirm the update channel in Finance is current enough for Copilot features to work as expected.
- [ ] Check that Word, Excel, PowerPoint, Outlook, and Teams are all on compliant builds.
- [ ] Confirm devices are receiving updates reliably and not stuck on outdated builds.
- [ ] Reboot and sync any pilot devices that are behind before enablement.

## 4. Identity and MFA readiness

- [ ] Confirm users sign in with Entra ID accounts protected by MFA.
- [ ] Confirm MFA is enforced for Finance users and not bypassed by legacy exceptions.
- [ ] Confirm Conditional Access policies are applied consistently to Finance users.
- [ ] Remove or remediate legacy authentication paths that weaken access controls.
- [ ] Confirm joiner/mover/leaver processes are working so access is removed promptly when people change roles.

## 5. Sensitivity labelling and information protection

- [ ] Confirm sensitivity labels are defined for Finance data classes such as Public, Internal, Confidential, and Highly Confidential.
- [ ] Apply labels to payroll, board packs, M&A documents, and client financial data where appropriate.
- [ ] Confirm labels persist across SharePoint, OneDrive, Exchange, and Office apps.
- [ ] Confirm encryption and access restrictions are configured for the most sensitive labels.
- [ ] Validate that users understand when to label content manually versus relying on defaults.
- [ ] Check that label policies are not blocking legitimate Finance work or creating unsafe workarounds.

## 6. End-user communication and enablement

- [ ] Prepare a Finance-specific announcement explaining what Copilot is, what it is not, and the data boundaries.
- [ ] Tell users that Copilot respects existing permissions and will only surface content they are already allowed to access.
- [ ] Brief managers and key Finance stakeholders before rollout so they can reinforce safe use.
- [ ] Provide short guidance on safe prompts, handling confidential content, and checking outputs before use.
- [ ] Include a clear support route for access issues, unexpected results, or suspected oversharing.
- [ ] Schedule a short enablement session or quick reference guide for the pilot group.

## 7. Go-live decision

- [ ] Permissions and oversharing review completed and signed off by the content owners.
- [ ] Licensing, client version, identity, MFA, and labelling checks are complete.
- [ ] End-user comms and enablement are ready.
- [ ] Finance pilot group is approved for Copilot license assignment.
- [ ] Any remaining high-risk content locations have an owner and a remediation plan.

## Recommended order of work

1. Finish the permissions and oversharing review first.
2. Remediate any open access, stale groups, and inherited permissions.
3. Confirm labels and identity controls.
4. Validate Microsoft 365 Apps client versions.
5. Prepare user comms and enablement.
6. Assign Copilot licenses to the approved Finance pilot or rollout group.
