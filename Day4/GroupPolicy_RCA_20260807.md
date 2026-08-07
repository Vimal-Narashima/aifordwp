# Root Cause Analysis (RCA)
## Incident: Floor 3 Win11 Group Policy Failure (Resolved)

- Document date: 2026-08-07
- Incident date/time window: 2024-03-15 07:40-07:55 (primary failure window)
- Environment: Windows 11 endpoints, OU=Finance, Floor 3 subnet
- Affected sample: 3 of 4 machines
- Reference affected host: DESKTOP-FB031
- Comparator unaffected host: DESKTOP-FB029
- Current status: Resolved
- Closure verification: Suggested resolution applied; user successfully logged in to host; no issues reported.

## 1) Executive Summary
On 2024-03-15, multiple Floor 3 Windows 11 endpoints failed Group Policy processing at startup. Event evidence showed a dependency chain of DNS resolution failure, domain controller (DC) discovery failure, and then Group Policy processing failure. The affected hosts were assigned a decommissioned DNS server by DHCP, while an unaffected comparator host in the same OU received the correct DNS server and applied policy successfully.

The issue was resolved after applying the suggested remediation to correct DNS assignment path and refresh clients. Post-fix verification confirms successful user logon to host and no further issues reported.

## 2) Impact and Scope
- User impact: Incomplete/failed domain policy processing at startup on impacted devices.
- Technical impact: Startup-time Group Policy processing failures due to inability to resolve/reach domain controller and SYSVOL.
- Business impact: Finance-area endpoint policy inconsistency and service desk disruption at start of business.
- Scope observed: 3 of 4 sampled endpoints in affected subnet path.

## 3) Supporting Evidence

### 3.1 Affected Host Event Evidence (DESKTOP-FB031)
Startup window reviewed: 07:40-07:55

1. 07:40:02 - Service Control Manager, Event ID 7036  
   Network Location Awareness service entered running state.

2. 07:40:08 - Netlogon, Event ID 5719 (Error)  
   Secure channel setup failed; no domain controller available.  
   DNS query for FINBRIDGE-DC01.finbridge.local returned no response.

3. 07:40:09 - GroupPolicy, Event ID 1058 (Error)  
   Failed to access SYSVOL path:  
   \\FINBRIDGE-DC01\sysvol\finbridge.local\Policies\{3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\gpt.ini  
   Error code: 0x3.

4. 07:40:10 - GroupPolicy, Event ID 1030 (Warning)  
   Could not query list of Group Policy objects.  
   Error code: 0x546.

5. 07:40:11 - GroupPolicy, Event ID 1058 (Error)  
   Repeated failure to access same policy path.

6. 07:40:12 - GroupPolicy, Event ID 1129 (Error)  
   Group Policy failed due to no network connectivity to a domain controller.

7. 07:41:05 - DNS Client Events, Event ID 1014 (Warning)  
   Name resolution for FINBRIDGE-DC01.finbridge.local timed out.  
   None of configured DNS servers responded.

8. 07:42:18 - DHCP Client, Event ID 50036 (Information)  
   Lease obtained; DNS assigned: 10.10.3.250 (old/decommissioned DNS).

9. 07:44:01 - GroupPolicy, Event ID 1129 (Error)  
   Repeated Group Policy failure due to no DC connectivity.

### 3.2 Comparator Host Evidence (DESKTOP-FB029, Same OU, Unaffected)
1. 07:40:05 - DHCP Client, Event ID 50036  
   DNS assigned: 10.10.0.10 (correct DNS).

2. 07:40:11 - GroupPolicy, Event ID 1500 (Information)  
   Group Policy settings processed successfully.

### 3.3 Infrastructure Comparison Evidence
- Affected endpoints received retired DNS value from DHCP scope path.
- Comparator endpoint had correct DNS assignment (manually aligned before migration) and succeeded.
- Migration note: old DNS server for Floor 3 path had been decommissioned overnight; DHCP dependency path was not aligned on impacted clients.

### 3.4 Resolution Verification Evidence
- Suggested remediation applied to correct DNS assignment path and client refresh.
- Validation outcome: user successfully logged in to host; no issues reported.
- Incident state changed to resolved.

## 4) Timeline
1. 02:00 - Legacy DNS service in migration path decommissioned.
2. 07:40:02 - NLA service running confirmed (Event 7036).
3. 07:40:08 - DC discovery/secure channel failure begins (Event 5719).
4. 07:40:09 - First Group Policy SYSVOL access failure (Event 1058, 0x3).
5. 07:40:10 - Group Policy object query failure (Event 1030, 0x546).
6. 07:40:12 - Group Policy no-DC-connectivity failure logged (Event 1129).
7. 07:41:05 - DNS timeout confirms unresolved DC FQDN (Event 1014).
8. 07:42:18 - DHCP confirms incorrect DNS assignment to affected host (Event 50036).
9. 07:44:01 - Group Policy failure repeats with no DC connectivity (Event 1129).
10. 07:40:05-07:40:11 (comparator path) - Correct DNS assigned and Group Policy processed successfully (Events 50036, 1500).
11. Post-triage - Suggested remediation implemented.
12. Post-fix - User verified successful logon; no further issues reported; incident resolved.

## 5) Root Cause Statement
The incident was caused by incorrect DNS assignment to affected endpoints, resulting in DNS resolution failure for the domain controller, which blocked secure channel setup and SYSVOL access during startup Group Policy processing.

Technical root cause:
- Clients in affected path received a retired DNS server address, causing domain resolution and DC connectivity failures.

Process root cause:
- Dependency validation between DNS migration and client/DHCP delivery path was insufficient prior to production cutover completion.

## 6) 5-Why Analysis
1. Why did Group Policy fail on affected endpoints?  
   Because endpoints could not contact a domain controller/SYSVOL during startup.

2. Why could endpoints not contact a domain controller?  
   Because FINBRIDGE-DC01 name resolution timed out and secure channel initialization failed.

3. Why did name resolution fail?  
   Because affected endpoints used a DNS server value that was no longer valid/reachable for this service path.

4. Why did endpoints have the wrong DNS value?  
   Because DNS assignment in the affected delivery path was not aligned to the post-migration target value.

5. Why was this misalignment not prevented before impact?  
   Because migration governance lacked a mandatory end-to-end client validation gate that checks actual DHCP-delivered DNS and DC resolution per affected subnet before finalizing decommission steps.

## 7) Corrective Actions Implemented
1. Applied the suggested DNS assignment correction on the affected path.
2. Refreshed endpoint network configuration on affected hosts.
3. Re-tested logon and policy behavior after correction.
4. Confirmed successful user logon with no ongoing issue reports.

## 8) Preventive Actions

### 8.1 Technical Preventive Controls
1. Enforce post-change subnet validation: verify DHCP-delivered DNS on representative clients per subnet.
2. Add automated checks for references to retired DNS IPs in DHCP scopes/reservations.
3. Add synthetic DC-resolution health checks from each user subnet during change windows.
4. Add event-correlation alert for startup pattern: Netlogon 5719 + DNS 1014 + GroupPolicy 1129 within a defined interval.

### 8.2 Process Preventive Controls
1. Update migration runbook to include DHCP and client-delivery dependency validation before DNS decommission closure.
2. Introduce a formal hold point: do not retire legacy DNS until client-side validation passes in all affected subnets.
3. Require comparator-host evidence (affected vs unaffected) in every closure package.
4. Require rollback criteria and owner sign-off for dependency changes.

### 8.3 Operational Controls
1. Publish triage quick-check sequence for frontline engineers:
   - Check DHCP Event 50036 for DNS values.
   - Check DNS Client Event 1014 for resolution failure.
   - Check Netlogon 5719 and GroupPolicy 1058/1030/1129 sequence.
2. Add daily report during migration periods for clients receiving deprecated infrastructure IPs.

## 9) Validation and Closure
- Resolution status: Resolved.
- User validation: Successful logon to host after remediation.
- Service desk validation: No issues reported after fix.
- Closure recommendation: Keep monitoring startup event patterns for 24-48 hours in affected subnet and then close problem record if stable.

## 10) Residual Risk
- Low, provided no remaining reservations or alternate DHCP option paths still distribute retired DNS values.
- Residual risk can be reduced to minimal after a full subnet-wide DHCP option audit.

---
Prepared for incident record, audit trail, and operational learning.
