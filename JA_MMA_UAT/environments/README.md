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

> **JA_MMA_Archtecture-Design - v3.0.pdf** (recommended to add this file to the repo root or link to it)

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

```text
.
├── modules/                          # Reusable Terraform modules
│   ├── shared/                       # rg-ja-shared (hub + platform services)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md                 (optional - create if needed)
│   └── environment/                  # Per-environment spoke resources
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md                 (optional)
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
└── README.md                         # ← You are here
