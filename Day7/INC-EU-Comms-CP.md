# Copilot Support — End User Communications
Date: 2026-08-12 | IT Support Team

---

## Ticket 1 — Paralegal: Unable to access SharePoint document via Copilot

**To:** Paralegal  
**Subject:** Your Copilot query — document access

Hi,

Thank you for getting in touch. We've looked into why Copilot returned "I don't have access to that content" when you asked it to summarise the NDA.

**What's happening:**
Copilot can only read files that you already have permission to open yourself. The folder containing that NDA hasn't been shared with you directly, so Copilot is correctly telling you it can't reach it — it's not a fault with Copilot, it's simply respecting the existing security on that document.

**Your next steps:**
1. Contact the document owner or your matter lead and ask them to grant you access to that SharePoint folder.
2. Once access is confirmed, try your Copilot request again — it should work straight away.

If you're not sure who owns the folder, let us know and we can help you find out.

---

## Ticket 2 — New Associate: Copilot can't find case emails in Outlook

**To:** New Associate  
**Subject:** Copilot in Outlook — what to expect in your first week

Hi and welcome to the team!

Thank you for letting us know Copilot isn't finding your case emails yet. This is completely normal for new starters and is not a fault.

**What's happening:**
When a new Microsoft 365 account is created, it can take up to 72 hours for your emails and files to be fully indexed by Microsoft's search service. Until that process completes, Copilot doesn't have enough content to search through, so results will be limited or empty.

**Your next steps:**
1. Please give it until the end of your third working day and try again — the index should be complete by then.
2. In the meantime, you can still open and read emails manually in Outlook as normal.
3. If Copilot still isn't finding emails after 72 hours, please raise a follow-up ticket and we'll check your licence assignment.

Apologies for any inconvenience during your first few days — this should resolve itself shortly.

---

## Ticket 3 — Partner: Copilot showed a document from an unassigned matter

**To:** Partner  
**Subject:** Important — Copilot surfaced a document you weren't expecting to see

Hi,

Thank you for flagging this promptly — this is exactly the right thing to report and we're treating it seriously.

**What's happening:**
Copilot only ever surfaces documents that you already have permission to access in SharePoint. The fact that it showed you that draft settlement means your account has read access to that matter's folder — most likely through a broad permission group or site-level setting, rather than a deliberate grant.

This is **not** a Copilot fault. It has correctly shown you something your permissions allow. The issue is that the underlying folder permissions are wider than they should be.

**Your next steps:**
1. Please do not share, copy, or act on the content of that document.
2. We are raising this with the matter site owner and the information governance team to review and tighten the folder permissions.
3. You don't need to do anything further — we will update you once the permissions have been corrected.

Thank you again for bringing this to our attention straight away.

---

## Ticket 4 — Legal Team: All 40 users have lost Copilot access

**To:** All Legal Team Members  
**Subject:** Copilot access — we are investigating and working to restore it

Hi everyone,

We are aware that Copilot for Microsoft 365 stopped working for the Legal team this morning and we are actively investigating.

**What's happening:**
We believe this is related to a licensing or account configuration change that affected the team's access. This is not something you have done wrong — it appears to be an admin-side change that we are working to identify and reverse.

**What we're doing:**
- We are checking licence assignments in the Microsoft 365 Admin Centre right now.
- We are also monitoring the Microsoft 365 Service Health dashboard for any wider service issues.
- We will provide a further update within **2 hours**.

**Your next steps:**
1. You can continue to use all other Microsoft 365 applications (Outlook, Teams, Word, SharePoint) as normal — only Copilot is affected.
2. No action is needed from you. Please do not attempt to sign out and back in or reinstall anything.
3. If your work is time-critical and depends on Copilot, please contact your manager to discuss workarounds in the meantime.

We apologise for the disruption and will get this resolved as quickly as possible.

---

## Ticket 5 — Contract Specialist: Copilot giving generic answers about contract templates

**To:** Contract Specialist  
**Subject:** Copilot and your contract templates library — what we found

Hi,

Thank you for reporting this. We've looked into why Copilot is giving you vague, generic answers instead of pulling from your actual contract templates.

**What's happening:**
For Copilot to reference the content of documents, those files need to appear in Microsoft's search index. If the templates library is relatively new, was recently moved, or contains files with certain security labels applied, the search index may not have fully processed them yet — meaning Copilot is answering from general knowledge rather than your actual documents.

**Your next steps:**
1. As a quick check, try searching for one of the template file names in the Microsoft Search bar (the search box at the top of Office.com or SharePoint). If the file doesn't appear in results, that confirms an indexing issue.
2. If the files do appear in search but Copilot still won't read them, let us know — it may be that a sensitivity label on the library is preventing Copilot from accessing the content.
3. Raise a follow-up ticket with the name of the templates library and we will check the indexing status and label settings on your behalf.

We expect this to be straightforward to resolve once we've identified the root cause.

---

*Communications drafted with AI assistance and reviewed by IT Support. No real user data or system identifiers were used in production.*
