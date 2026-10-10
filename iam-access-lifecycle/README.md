# Entra ID Access Lifecycle Lab

A PowerShell + Microsoft Graph lab that runs the full identity access lifecycle in a Microsoft Entra ID tenant: **access requests with approval checks, periodic access reviews with remediation, and offboarding**, with every action written to an audit log.

Built and run in a lab Entra ID tenant (free tier) on October 10, 2026. The tenant domain in the evidence files is redacted to `<tenant>.onmicrosoft.com`.

## Results

| Phase | What happened |
|---|---|
| **Access requests** | 5 tickets processed: **2 granted**, **3 rejected** (self-approval / separation of duties, pending approval, role not in catalog) |
| **Access review** | 9 users reviewed, **4 least-privilege violations found**: privilege creep, Security Admin rights outside role, and a disabled account that still had 2 groups |
| **Remediation** | All 4 removed, each logged with reason and review ID; follow-up review: **0 findings** |
| **Offboarding** (TERM-2001) | Account disabled, all sign-in sessions revoked, 2 groups removed; follow-up review still **0 findings** |

Evidence in this folder:
- `access_requests.csv`: the 5 sample tickets
- `AccessReview_*-1720.csv`: first review (4 findings)
- `AccessReview_*-1731.csv`: final review (0 findings)
- `iam_audit.jsonl`: complete audit trail (timestamp, operator, event, ticket, target, detail, result)

## How it works

**Role-based access (least privilege).** Each role maps to the only groups it should hold:

| Role | Groups |
|---|---|
| Claims-Processor | IAM-Claims-Read, IAM-Claims-Edit |
| Claims-Supervisor | IAM-Claims-Read, IAM-Claims-Edit, IAM-Claims-Approve |
| Billing-Specialist | IAM-Billing-Read, IAM-Billing-Edit |
| Security-Admin | IAM-Security-Admin |

**Request rules.** A ticket is granted only if it is Approved, has an approver, the approver is neither the requester nor the user, the role exists, and the account is active. Role changes remove access the old role had that the new role doesn't.

**Review rules.** For every user, actual group membership is compared with the role:
- Group not allowed by role → privilege creep (admin groups flagged as excessive privilege)
- Disabled account with any access → flagged for removal
- Required group missing → flagged for review

**Offboarding.** Disable account → revoke all sign-in sessions → remove every role group → mark role as Terminated.

**Safety.** Every changing action supports `-WhatIf` to preview changes first.

## Control mapping (NIST SP 800-53)

| Control | Where it's enforced |
|---|---|
| AC-2 Account Management | Approved provisioning, role changes, offboarding |
| AC-5 Separation of Duties | Self-approved tickets rejected |
| AC-6 Least Privilege | Role catalog + access review + remediation |
| AU-2 / AU-12 Audit Events | Every grant, rejection, removal and review logged to JSONL |

## Run it

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups -Scope CurrentUser
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.Read.All" -TenantId "<tenant>.onmicrosoft.com"

$env:ENTRA_LAB_DOMAIN = "<tenant>.onmicrosoft.com"   # or pass -Domain on each call
.\IAM-AccessLifecycle.ps1 -Action Setup
.\IAM-AccessLifecycle.ps1 -Action Request -WhatIf
.\IAM-AccessLifecycle.ps1 -Action Request
.\IAM-AccessLifecycle.ps1 -Action Review
.\IAM-AccessLifecycle.ps1 -Action Review -Remediate -WhatIf
.\IAM-AccessLifecycle.ps1 -Action Review -Remediate
.\IAM-AccessLifecycle.ps1 -Action Offboard -User iam.mgarcia -Ticket TERM-2001
.\IAM-AccessLifecycle.ps1 -Action Cleanup
```

## Lessons learned

- **Disabled ≠ offboarded.** The review caught an account that had been disabled but still belonged to 2 groups, a common gap when offboarding stops at "disable."
- **Test your own logic.** The first version of the review flagged that same disabled account as "missing access" after cleanup. Fixing it made the rule explicit: a disabled account should hold no access at all.

> Lab use only. Never run against a production tenant.

