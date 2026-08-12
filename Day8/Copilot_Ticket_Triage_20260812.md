# Copilot Support Ticket Triage
Date: 2026-08-12  
Engineer note: Default assumption is non-Copilot cause unless all other causes are ruled out.

---

## Ticket 1 — Finance lead: Copilot won't summarise Q3 board pack in SharePoint

**Likely cause (ranked):**
1. Sensitivity label restriction — board packs routinely carry high sensitivity labels that block Copilot processing
2. Permissions/access boundary — the file may be in a restricted library with unique permissions despite being visible to the user's browser session
3. Data indexing lag — large or recently updated files can lag in the Microsoft Search index

**Fastest check:** Check the sensitivity label applied to the file; if it carries a label configured to block AI processing, that is your answer.

**Is this actually a Copilot bug?** No — visible-in-browser does not mean indexed or accessible to Copilot. Sensitivity labels and permission boundaries are the most common causes here.

---

## Ticket 2 — New hire (started yesterday): Copilot in Outlook knows nothing about recent emails

**Likely cause (ranked):**
1. Data indexing lag — new mailboxes take 24–72 hours to be fully indexed by Microsoft Search
2. License/client prerequisite issue — Copilot licence may not yet be fully provisioned; licence assignment and index seeding both take time
3. Permissions/access boundary — provisioning may be incomplete

**Fastest check:** Check the licence assignment date and confirm Microsoft 365 Copilot is fully assigned (not pending) in the admin centre.

**Is this actually a Copilot bug?** No — this is a textbook indexing/provisioning lag for a brand-new account. Expected behaviour within the first 24–72 hours.

---

## Ticket 3 — HR manager: Copilot in Word returns "I don't have access to that content" for salary review spreadsheet

**Likely cause (ranked):**
1. Sensitivity label restriction — salary review data is highly likely to carry a restricted or confidential label configured to block Copilot
2. Permissions/access boundary — the spreadsheet may be in a site or library where the HR manager's Copilot session lacks the required delegated access
3. Data indexing lag — if the file is newly created or recently relabelled

**Fastest check:** Inspect the sensitivity label on the spreadsheet; confirm whether the label policy blocks Copilot/AI processing for that classification.

**Is this actually a Copilot bug?** No — the error message "I don't have access to that content" is the expected Copilot response when a sensitivity label or permission boundary blocks access. This is working as designed.

---

## Ticket 4 — Sales rep: Copilot in Teams can't find a client contract shared via a guest link from another org

**Likely cause (ranked):**
1. Guest/external sharing limitation — Copilot does not traverse content shared via external guest links or content held in another organisation's tenant
2. Permissions/access boundary — guest-link sharing grants browser access but typically does not grant Microsoft Search index access in the user's own tenant
3. Sensitivity label restriction — the external org's label policy may further restrict the file

**Fastest check:** Confirm whether the file is actually stored in the user's own tenant or only accessible via an external guest link; Copilot only searches content indexed in the user's home tenant.

**Is this actually a Copilot bug?** No — this is a documented limitation. Copilot cannot index or retrieve content from another organisation's tenant via a guest link.

---

## Ticket 5 — IT admin: Copilot stopped working for the whole Finance team this morning, was fine yesterday

**Likely cause (ranked):**
1. License/client prerequisite issue — a licence change, bulk assignment error, or licence expiry affecting the Finance group is the most likely single change to impact a whole team simultaneously
2. Permissions/access boundary — a group policy or conditional access change overnight could have revoked access for the Finance OU/group
3. Genuine Copilot fault — a tenant-wide or group-scoped service incident is possible but should be confirmed via the Microsoft 365 Service Health Dashboard first

**Fastest check:** Check the Microsoft 365 admin centre Service Health Dashboard for any active Copilot incidents, then immediately cross-reference licence assignments for the Finance group.

**Is this actually a Copilot bug?** Unclear — a sudden team-wide outage with no individual trigger is more likely to be a licence/group change than a Copilot fault, but a service incident cannot be ruled out without checking the health dashboard first.

---

## Ticket 6 — Manager: Copilot surfaced a file I don't remember opening, from a folder I forgot I had access to

**Likely cause (ranked):**
1. Permissions/access boundary — Copilot correctly retrieved a file the user legitimately has access to; this is expected behaviour, not a fault

**Fastest check:** Confirm in SharePoint/OneDrive that the user does have direct or inherited permissions on that folder and file.

**Is this actually a Copilot bug?** No — Copilot is designed to surface any content the signed-in user has permission to access, regardless of whether they consciously navigated to it. This is working as intended. It may be worth reviewing whether the permission grant is still appropriate.

---

## Ticket 7 — Analyst: Copilot gives generic answers, never uses internal SharePoint content

**Likely cause (ranked):**
1. Data indexing lag — SharePoint sites that are new, recently migrated, or have crawl errors may not be indexed in Microsoft Search
2. Permissions/access boundary — the analyst may not have permissions to the SharePoint sites containing the expected content
3. License/client prerequisite issue — the Copilot licence may be assigned but the Microsoft Search connector or SharePoint indexing may not be fully configured for the tenant

**Fastest check:** Run a Microsoft Search query for a known internal document the analyst should be able to access; if Search returns nothing, the issue is indexing, not Copilot itself.

**Is this actually a Copilot bug?** No — Copilot answers are only as good as what Microsoft Search indexes and the user can access. Generic answers with no internal content strongly indicate an indexing or permission issue upstream of Copilot.

---

## Ticket 8 — Executive assistant: Copilot in Outlook can't see a shared mailbox calendar managed on behalf of director

**Likely cause (ranked):**
1. Permissions/access boundary — Copilot in Outlook operates on the signed-in user's own mailbox context; delegate/"on behalf of" access to a shared mailbox calendar is not currently surfaced to Copilot
2. License/client prerequisite issue — the shared mailbox itself does not hold a Copilot licence; Copilot does not extend into unlicensed shared mailboxes
3. Guest/external sharing limitation — if the director's mailbox is in a separate tenant or has restricted delegation settings

**Fastest check:** Confirm whether the shared mailbox has a Microsoft 365 Copilot licence assigned; without one, Copilot cannot process that mailbox's content even with full delegate rights.

**Is this actually a Copilot bug?** No — Copilot's scope is the licensed user's own mailbox. Shared mailbox and delegate calendar access is a known current limitation, not a fault.
