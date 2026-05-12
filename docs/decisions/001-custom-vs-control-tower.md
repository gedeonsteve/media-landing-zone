# ADR-001: Custom Landing Zone vs AWS Control Tower

- **Status**: Accepted
- **Date**: 2026-05-12
- **Deciders**: Steve Etong

## Context

When building a multi-account AWS landing zone, two main approaches exist:

1. Use **AWS Control Tower**, a managed service that automates the setup of a landing zone with predefined guardrails and best practices.
2. Build a **custom landing zone** using Terraform, AWS Organizations, and individual AWS services.

We need to choose between these two approaches for this project.

## Decision

We will build a **custom Terraform-managed landing zone**, not using AWS Control Tower.

## Rationale

### Why not Control Tower

- **Cost**: Control Tower enables AWS Config in all enrolled accounts and regions, which adds ~$3/account/region/month plus per-configuration recording charges. For a 5-account multi-region setup, this can reach $40-60/month.
- **Rigidity**: Control Tower's guardrails are predefined and difficult to customize for specific compliance needs (e.g., EU data residency, broadcast-specific requirements).
- **Opacity**: When something fails, debugging Control Tower's internal state machine is complex.
- **Learning value**: Control Tower abstracts away the actual implementation, reducing pedagogical value.

### Why custom Terraform

- **Cost control**: Each AWS service (Config, GuardDuty, Security Hub) can be enabled/disabled granularly, allowing tight budget management.
- **Full transparency**: Every resource is explicitly declared in code, making the architecture fully auditable.
- **Customization**: SCPs, OU structure, and account baselines can be tailored to specific use cases.
- **Skills development**: Implementing the landing zone manually deepens understanding of AWS Organizations, IAM, and multi-account patterns.

## Consequences

### Positive

- Complete cost visibility and control
- Full ownership of architecture decisions
- Strong demonstrable AWS expertise
- Easier to adapt to specific compliance requirements

### Negative

- More upfront engineering work
- Need to manually implement features Control Tower provides out-of-the-box (Account Factory, baseline application)
- Maintenance burden falls on the team

## Alternatives Considered

- **AWS Control Tower**: Rejected for reasons above
- **Customizations for Control Tower (CfCT)**: Hybrid approach using Control Tower + Terraform overlays. Rejected because it inherits Control Tower's cost and rigidity downsides.

## References

- [AWS Multi-Account Strategy](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html)
- [AWS Control Tower documentation](https://docs.aws.amazon.com/controltower/)