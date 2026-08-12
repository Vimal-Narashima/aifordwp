# Copilot Support — End User Communications
Date: 2026-08-12

---

## Ticket 1 — Finance Lead: Unable to summarise Q3 board pack

**Hi,**

Thanks for getting in touch. We've looked into why Copilot couldn't summarise your Q3 board pack.

The most likely reason is that the file has a **sensitivity label** applied to it (for example, "Highly Confidential" or similar). These labels are set by your organisation to protect certain documents, and one of the protections they can apply is preventing AI tools — including Copilot — from reading or processing the file's contents. This isn't a fault; it's the label doing exactly what it's designed to do.

**What to do next:**
- Check the sensitivity label shown on the document (visible in the toolbar in Word/SharePoint). If it shows a restricted classification, that is almost certainly the cause.
- If you believe the label has been applied incorrectly, please raise a request with your Information Management team to review the classification.
- If the label is correct and the restriction is intentional, the document will need to be processed manually rather than through Copilot.

If you're still unsure, please reply to this ticket and we'll investigate further.

---

## Ticket 2 — New Hire: Copilot seems unaware of recent emails

**Hi,**

Welcome to the team! Thanks for flagging this.

This is completely normal for brand-new accounts. When a new mailbox is set up, Microsoft needs time to **index your emails** so that Copilot can search and reference them. This process typically takes **24 to 72 hours** from when your account was created. Until indexing is complete, Copilot won't be able to see your recent emails.

**What to do next:**
- If your account was created yesterday, please **wait until tomorrow** and try again — this should resolve on its own.
- If the problem persists beyond 72 hours from your account creation, please contact the IT helpdesk and we'll check that your Copilot licence has been fully provisioned.

No action is needed from you right now — just give it a little time.

---

## Ticket 3 — HR Manager: "I don't have access to that content" error for salary spreadsheet

**Hi,**

Thanks for your message. The error you're seeing — *"I don't have access to that content"* — is Copilot telling you that it has been blocked from reading that file. This is most likely because the **salary review spreadsheet carries a sensitivity label** that restricts AI processing.

Salary and HR data is typically classified at a high protection level, and those classifications are designed to prevent tools like Copilot from reading the content — even if you personally have permission to open the file.

**What to do next:**
- Check the sensitivity label shown on the spreadsheet. If it is classified as "Confidential" or higher, the restriction is working as intended.
- If you need to extract data from this file, you will need to do so manually by opening the spreadsheet directly.
- If you believe the sensitivity label is incorrect for this document, please contact your Information Management team to request a review.

This is not a fault with Copilot — it is a security control operating correctly.

---

## Ticket 4 — Sales Rep: Copilot can't find a client contract shared via a guest link

**Hi,**

Thanks for raising this. We understand how frustrating it is when you can see a file but Copilot can't find it.

The reason is that the contract was **shared with you via a guest link from another organisation**. Copilot can only search content that is stored and indexed within **your own organisation's Microsoft 365 environment**. Files shared from an external organisation via a guest link remain in that company's systems — Copilot has no ability to reach across into another organisation's tenant to retrieve them.

**What to do next:**
- If you need Copilot to work with this contract, ask the external party to **send you the file directly** (as an email attachment or a file transfer) so you can save a copy into your own OneDrive or a SharePoint site you have access to.
- Once saved in your tenant, Copilot should be able to find and reference it (subject to any sensitivity labels applied).

This is a current platform limitation, not a bug.

---

## Ticket 5 — IT Admin: Copilot stopped working for the whole Finance team

**Hi,**

Thanks for flagging this urgently. A Copilot outage affecting an entire team at once is most commonly caused by a **change to licence assignments or group membership**, rather than a fault with Copilot itself.

**What to check first:**
1. Review the **Microsoft 365 admin centre Service Health Dashboard** for any active Copilot or Microsoft 365 service incidents.
2. Check the **Copilot licence assignments** for the Finance group — confirm no licences have been removed, expired, or reassigned overnight.
3. Review any **conditional access or group policy changes** that may have been applied to the Finance OU or group since yesterday.

**Next steps:**
- If a service incident is showing on the health dashboard, monitor it and communicate updates to the Finance team.
- If a licence change is identified, restore the assignments and allow up to 30 minutes for access to recover.
- If no obvious cause is found via the above checks, raise a support case with Microsoft and reference the team name, tenant ID, and the approximate time the issue began.

Please keep us updated on findings.

---

## Ticket 6 — Manager: Copilot surfaced a file I don't remember accessing

**Hi,**

Thanks for letting us know — we can understand why that felt unexpected.

To reassure you: **Copilot has not done anything wrong here.** It is designed to surface any file or content that you have permission to access in Microsoft 365, even if you haven't visited that folder recently or consciously navigated to it. If your account has (or had) permission to a folder, Copilot can find content within it.

**What this likely means:**
- At some point, your account was granted access to that folder — possibly as part of a project, team site, or inherited permissions from a group you belong to.

**Suggested next steps:**
- If you don't recognise why you have access to that folder, it may be worth asking your IT team or the site owner to review whether the permission is still appropriate.
- If you're concerned the file was sensitive and should not have been accessible to you, please flag it to your IT admin team so they can review the permission settings.

No security incident has occurred — this is Copilot working as intended.

---

## Ticket 7 — Analyst: Copilot only gives generic answers, ignores internal content

**Hi,**

Thanks for getting in touch. If Copilot is giving you generic answers and not referencing any of your organisation's internal SharePoint content, this usually points to one of two things: the content **hasn't been indexed yet**, or your account **doesn't have permission** to access the SharePoint sites you'd expect it to use.

Copilot can only work with content that (a) you have permission to access, and (b) has been indexed by Microsoft Search. If either of those conditions isn't met, Copilot falls back to general knowledge.

**What to do next:**
- Try searching for a specific internal document directly in **Microsoft Search** (the search bar at the top of SharePoint or office.com). If you can't find it there either, the issue is with indexing or permissions — not Copilot.
- If you can find the document in Search but Copilot still ignores it, please reply to this ticket with an example and we'll investigate further.
- If SharePoint Search also returns nothing, please contact the IT helpdesk so we can check site indexing and your access permissions.

---

## Ticket 8 — Executive Assistant: Copilot can't see the shared mailbox calendar

**Hi,**

Thanks for raising this. We can see why this would be inconvenient given the nature of your role.

The reason Copilot can't see your director's shared mailbox calendar comes down to how **Copilot licences work**. Copilot in Outlook is tied to the **signed-in user's own licensed mailbox**. Shared mailboxes do not hold their own Copilot licence, so Copilot cannot process or reference their content — even if you have full delegate or "send on behalf of" access.

This is a **current platform limitation**, not a fault.

**What to do next:**
- For now, you will need to **open the shared mailbox calendar directly** in Outlook to view and manage it, as you would normally.
- If this is a business-critical requirement, please speak to your line manager about raising it formally — Microsoft is continuing to develop Copilot's support for delegate and shared mailbox scenarios, and this is a frequently requested improvement.
- We will monitor for any updates from Microsoft on shared mailbox support and communicate changes when they become available.

We're sorry we can't resolve this immediately — the limitation sits with the platform at this time.
