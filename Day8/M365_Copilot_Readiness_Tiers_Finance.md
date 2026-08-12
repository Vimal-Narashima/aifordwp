# Microsoft 365 Copilot Readiness Tiers - Finance

Department: Finance (~200 users)

Context: M365 E5 is already in place. Copilot add-on is not yet assigned. Finance content includes payroll, board packs, M&A documents, and client financial data. SharePoint permissions were inherited from a 2019 migration and have not been fully audited since.

Use this to separate rollout blockers from important but non-blocking tasks.

## MUST complete before rollout (blocking)

- [ ] Complete the Finance permissions and oversharing audit across SharePoint, OneDrive, shared drives, and any migrated legacy content.
- [ ] Remediate inherited, stale, overly broad, orphaned, and contractor access.
- [ ] Verify board packs, payroll, M&A, and client financial data are restricted to the minimum required audience.
- [ ] Remove or tightly control external sharing and any everyone-accessible links on Finance content.
- [ ] Confirm no sensitive Finance material is exposed in open team sites, ad hoc folders, or ungoverned shared drives.
- [ ] Confirm Copilot licenses will only be assigned to the approved Finance population.
- [ ] Confirm users are on supported Microsoft 365 Apps builds.
- [ ] Confirm MFA and Conditional Access are enforced for Finance users.
- [ ] Confirm sensitivity labels are in place for the highest-risk Finance data classes.

Why the permissions audit is in the MUST tier:

- Copilot can only surface what a user already has access to, so broken permissions directly become data-exposure risk.
- Finance content is highly sensitive, and this environment already has inherited SharePoint permissions from a 2019 migration that was never fully audited.
- Licensing and client version checks are important, but they are simple enablement checks; they do not change the underlying data exposure.
- If oversharing exists, rolling out Copilot first can amplify an existing access-control problem across payroll, board packs, M&A, and client financial data.
- In practice, the permissions model is the control that determines whether Copilot is safe to turn on at all.

## SHOULD complete before rollout (high risk if skipped)

- [ ] Validate label policies and default labels behave correctly for Finance data.
- [ ] Confirm encryption and access restrictions apply to highly confidential labels.
- [ ] Brief Finance managers and stakeholders on expected Copilot use.
- [ ] Prepare a Finance-specific user announcement covering safe use and data boundaries.
- [ ] Provide quick guidance on prompt hygiene, output checking, and escalation routes.
- [ ] Confirm service health is stable for Microsoft 365, SharePoint, OneDrive, Exchange, and Teams.
- [ ] Reboot and sync pilot devices that are behind on updates.

## CAN complete during or after rollout (lower risk)

- [ ] Schedule a short enablement session or quick reference guide for the pilot group.
- [ ] Expand user comms with examples and FAQs after the first pilot wave.
- [ ] Record the final remediated permissions model and ongoing review owners.
- [ ] Establish a recurring access review cadence for Finance content.
- [ ] Run a final post-remediation spot-check on search visibility and Copilot prompt exposure.
- [ ] Monitor user feedback and fine-tune guidance after initial adoption.

## Recommended rollout order

1. Finish the MUST-tier controls first, with permissions and oversharing as the first gate.
2. Complete the SHOULD-tier items to reduce rollout friction and user risk.
3. Assign Copilot licenses only after the blocking controls are signed off.
4. Deliver the CAN-tier items during the pilot and early rollout period.
