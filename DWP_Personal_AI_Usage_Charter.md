# Personal AI Usage Charter — DWP Desktop/Endpoint Engineer
**Version 1.0 | Effective: August 2026 | Owner: [Your Name]**

---

## 1. Appropriate Uses of Public AI Assistants

I may use public LLM tools (e.g. GitHub Copilot, ChatGPT) for:

- **Scripting and automation** — drafting PowerShell, Python, or Bash scripts for device management, patching, or log parsing, using synthetic or anonymised test data only.
- **Documentation** — writing runbooks, how-to guides, and internal process notes that contain no live system details (no real hostnames, IPs, or account names).
- **Troubleshooting research** — explaining error codes, Windows Event IDs, SCCM/Intune behaviour, or GPO logic using generic examples.
- **Learning and upskilling** — understanding concepts (e.g. certificate chains, WSUS internals, registry structure) and exploring best-practice patterns.
- **Code review assistance** — asking the LLM to review a sanitised script for logic errors, security issues, or style improvements.
- **Draft communications** — structuring technical emails, change requests, or incident summaries before populating them with real detail offline.

---

## 2. Uses That Are Prohibited

I must **not** submit the following to any public AI tool:

| Category | Examples |
|---|---|
| End-user personal data | Names, National Insurance numbers, claim reference numbers, addresses, dates of birth |
| Credentials or secrets | Passwords, API keys, service account tokens, certificate private keys, PAT tokens |
| Internal network detail | Hostnames, IP ranges, domain names, AD OU structures, firewall rules |
| Security configuration | AV exclusions, EDR policy detail, vulnerability scan output, patch compliance reports |
| Incident/case data | Support tickets containing user detail, SIEM alerts with real asset names |
| Unreleased policy or audit content | Unpublished DWP guidance, internal audit findings, security architecture diagrams |

If a task requires any of the above as input, I will complete it using approved internal tooling only.

---

## 3. Data-Handling Rule for End-User PII and Credentials

> **Before pasting anything into a public AI chat, I will ask: "Does this contain real user data or a real secret?"**

- **Anonymise first:** Replace names with `USER_A`, NI numbers with `XX123456X`, and hostnames with `HOST-01` before submitting.
- **Never paste credentials** — not even to ask "is this password strong enough?". Use an offline password manager or internal tooling.
- **No screenshots of live systems** in public AI tools; crop or redact before upload.
- **If I accidentally submit PII or a credential**, I will immediately rotate the credential, report the incident via the DWP security reporting process, and record the disclosure date and scope.

---

## 4. Personal 'Generate Then Verify' Rule for Scripts and System Changes

AI-generated scripts and configuration changes are **drafts, not solutions**. I will follow this workflow for every script or system change produced with AI assistance:

```
GENERATE  →  READ  →  TEST  →  VERIFY  →  DEPLOY
```

1. **Generate** — obtain the draft from the AI tool using sanitised inputs.
2. **Read** — read every line before running anything; I am accountable for code I execute.
3. **Test** — run in a non-production environment (test VM, isolated OU, or staging tenant) first.
4. **Verify** — confirm the output matches the intended behaviour; check for unintended scope (e.g. a script targeting `*` instead of a specific OU).
5. **Deploy** — follow the standard change process; record that AI assistance was used in the change record.

I will never execute an AI-generated script with elevated privileges without completing steps 2–4. I will never use "the AI wrote it" as justification for bypassing change control.

---

*This charter supplements, and does not replace, DWP's Acceptable Use Policy and Government Cyber Security guidance. Review annually or after any significant AI tooling change.*
