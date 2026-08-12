# Copilot Support Ticket Triage
Date: 2026-08-12 | Engineer: DWP Desktop/Endpoint

> **Triage principle:** Default to non-Copilot causes. "Genuine Copilot fault" is last resort only.

---

## Ticket 1 — Paralegal: "I don't have access to that content" (SharePoint NDA)

**Context:** File is in a folder she has never opened; she learned of it via a meeting.

| Field | Detail |
|---|---|
| **Likely cause (ranked)** | 1. Permissions/access boundary — she has never navigated to the folder and almost certainly has no explicit permission grant on it. Copilot enforces the same ACL as SharePoint. 2. Sensitivity label restriction — NDA files are commonly labelled; label policy may scope access to specific groups. |
| **Fastest check** | Ask her to navigate directly to the SharePoint folder in a browser. If she gets "Access denied", the cause is confirmed as permissions — nothing to do with Copilot. |
| **Is this actually a Copilot bug?** | **No.** Copilot correctly surfaced her real access level. The error message is expected behaviour when the user lacks permission to the underlying content. |

---

## Ticket 2 — New Associate (started this week): Copilot in Outlook can't find case emails

**Context:** User is brand-new; mailbox and account provisioned this week.

| Field | Detail |
|---|---|
| **Likely cause (ranked)** | 1. Data indexing lag — new mailboxes can take 24–72 hours to be fully crawled by Microsoft Search; Copilot cannot surface content that hasn't been indexed yet. 2. License/client prerequisite issue — Copilot license may not have been assigned at provisioning, or the M365 Apps version is below the required build. |
| **Fastest check** | Confirm the Copilot license is assigned in the M365 Admin Centre (Users → Active users → Licenses). If licensed, check mailbox index status via Microsoft Search admin or simply wait 48 hours and retest. |
| **Is this actually a Copilot bug?** | **No.** New-account indexing lag is a known, documented behaviour. Verify the license first; indexing is the expected second cause. |

---

## Ticket 3 — Partner: Copilot surfaced a draft settlement from a matter they're not assigned to

**Context:** Partner did not expect to see this document and was unaware they could access the folder.

| Field | Detail |
|---|---|
| **Likely cause (ranked)** | 1. Permissions/access boundary (overly permissive) — Copilot only surfaces content the user already has read access to. If the document appeared, the partner has existing SharePoint/OneDrive permissions — probably via a broad group membership, site-level inheritance, or an "Everyone except external users" grant on the matter site. |
| **Fastest check** | Check the SharePoint site/folder permissions for that matter directly (Site Settings → Site Permissions). Identify which group or permission level grants this partner access. |
| **Is this actually a Copilot bug?** | **No.** This is a permissions over-exposure issue in SharePoint. Copilot did exactly what it should: it surfaced content the user is already permitted to see. The fix is tightening the underlying permissions, not changing Copilot config. Escalate to the site owner and information governance team. |

---

## Ticket 4 — Legal Ops Manager: All 40 Legal team members lost Copilot access simultaneously this morning

**Context:** Worked fine all last week; sudden, team-wide, simultaneous loss.

| Field | Detail |
|---|---|
| **Likely cause (ranked)** | 1. License/client prerequisite issue — a bulk license change, group-based licensing recalculation, or policy change applied overnight may have removed the Copilot SKU from the Legal team's assigned group. 2. Permissions/access boundary — an admin change to the security group or conditional access policy could block the Copilot entitlement. 3. Genuine Copilot fault — a tenant-scoped service outage cannot be ruled out for a simultaneous all-users event, but exhaust the above first. |
| **Fastest check** | M365 Admin Centre → Billing → Licenses: confirm Copilot for Microsoft 365 licenses are still assigned to the Legal group. Also check the M365 Service Health dashboard for any active Copilot incidents. |
| **Is this actually a Copilot bug?** | **Unclear.** Simultaneous loss for an entire group is more consistent with a licensing or group policy change than a user-side fault. However, if licenses are intact and Service Health shows an active incident, escalate to Microsoft support. Do not assume a bug until admin-side causes are eliminated. |

---

## Ticket 5 — Contract Specialist: Vague, generic answers about contract templates library

**Context:** Copilot doesn't appear to read the actual documents; answers are generic.

| Field | Detail |
|---|---|
| **Likely cause (ranked)** | 1. Data indexing lag — if the templates library was recently created, migrated, or heavily updated, Microsoft Search may not have fully crawled it; Copilot has no content to ground answers on. 2. Sensitivity label restriction — labels with "Do Not Forward" or encryption policies can prevent Copilot from reading ciphertext content even when the user can open the file manually. 3. Permissions/access boundary — library-level or item-level permissions may limit Copilot's effective read scope to fewer files than the user expects. |
| **Fastest check** | Open one of the template files directly in Word/browser and confirm it is readable without prompts. Then run a Microsoft Search query (`site:<library URL> filetype:docx`) to verify the files appear in search results — if they don't appear, indexing is the cause. |
| **Is this actually a Copilot bug?** | **No.** Generic answers without document grounding are a known symptom of missing search index coverage or label-enforced encryption. Test search index coverage first before considering a Copilot fault. |

---

*Triage produced with AI assistance. All ticket text has been treated as synthetic/training data. No real user PII or system identifiers were used.*
