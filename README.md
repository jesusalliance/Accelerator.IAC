# Jesus Alliance MMA Portal – Infrastructure as Code (Terraform)

**Repository:** `jesusalliance/Accelerator.IAC`  
**Architecture Version:** v3.0  
**Status:** Production-ready | Actively maintained

---

## Overview

This repository contains the complete **Terraform Infrastructure as Code (IaC)** for the **Jesus Alliance MMA Portal** running on Microsoft Azure.

It implements the exact target architecture defined in the official design document:
- **Hub-Spoke networking** with centralized egress via Azure Firewall
- Three isolated environments (DEV, UAT, PROD) in dedicated resource groups
- Private-by-default (all PaaS services accessed via private endpoints)
- Shared platform services in `rg-ja-shared` (zone-redundant)
- Single Frontend Portal + single Backend API container per environment using Azure Container Apps (with native horizontal autoscaling)
- Production-grade HA, security, backup, and CI/CD readiness

**Core Principles (from v3.0 Design)**
- Infrastructure as Code (Terraform)
- Centralized egress & inspection (Azure Firewall replaces NAT Gateway)
- Private endpoints + Private DNS Zones
- Multi-AZ / zone-redundant in PROD and shared services
- GitHub OIDC + managed identities for zero static secrets

---

## Architecture Reference

Full details are in the design document:

> **JA_MMA_Archtecture-Design - v3.0.pdf** (recommended to add this file to the repo root)

Key sections covered by this IaC:
- 2.0 Resource Group Structure
- 3.0 Shared Resources (Hub VNet, Firewall, ACR Premium, Key Vault, Front Door + WAF, Log Analytics)
- 4.0–9.0 Hub-Spoke topology, subnet design, routing (UDRs), NSGs
- 5.0–7.0 Environment-specific diagrams (DEV/UAT single-AZ, PROD multi-AZ)
- 8.0 Scaling (Container Apps replicas)
- 10.0 Security & Compliance
- 11.0 Backup & Recovery
- 12.0–13.0 Deployment & GitHub OIDC Federation

---

## Repository Structure

```bash
.
├── modules/                          # Reusable Terraform modules
│   ├── shared/                       # rg-ja-shared (hub + platform services)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── environment/                  # Per-environment spoke resources
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
│
├── environments/                     # Environment-specific configuration
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── dev.tfvars
│   ├── uat.tfvars
│   ├── prod.tfvars
│   ├── dev-plan.tfplan
│   ├── shared-plan.tfplan
│   └── .terraform.lock.hcl
│
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── dev-plan.tfplan
├── shared-plan.tfplan
└── README.md





CI/CD & Promotion Flow (Section 12.0)
The design uses a GitHub-first workflow:

Push to dev branch → auto-deploy to DEV
Manual promote to UAT (PR or workflow dispatch)
Manual promote to PROD (separate workflow)

Current state: Manual Terraform apply (plans provided)
Next step: Add .github/workflows/ (see modules/shared/README.md and architecture doc Section 13.0 for OIDC guidance).

Security & Best Practices (Implemented)

All spoke traffic routed through Azure Firewall (UDRs)
Private endpoints + Private DNS for ACR, Cosmos DB, Key Vault
NSGs strictly scoped
System-assigned & user-assigned managed identities
WAF Policy on Front Door (UAT & PROD)
Soft-delete + purge protection on Key Vault & ACR
Diagnostic settings to shared Log Analytics
Tagging strategy for backup & cost allocation


GitHub OIDC Federation (Recommended – Section 13.0)
To eliminate static secrets:

Create user-assigned identity id-ja-github-ci in rg-ja-shared
Add federated credentials for this repo
Grant minimal roles (AcrPush + ContainerApp Contributor + Key Vault Secrets User)

Then use the official azure/login GitHub Action.

Backup & Recovery
All backup-eligible resources are tagged:

backup-enabled: true
backup-policy: daily
environment: dev/uat/prod
cost-center: ja-mma-portal

See Section 11.0 of the design document.

Contributing

Create a feature branch
Update the relevant module (modules/shared or modules/environment)
Test in DEV environment
Update plan files
Submit PR

All changes must align with v3.0 architecture.

Support & Contact

Architecture Owner: Jesus Alliance Portal Team
Questions: Open an issue in this repo
Full Design:JA_MMA_Archtecture-Design - v3.0.pdf            # ← You are here
