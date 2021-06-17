---
severity: Awareness
pillar: Operational Excellence
category: Repeatable Infrastructure
resource: Policy
online version: https://github.com/Microsoft/PSRule.Rules.Azure/blob/main/docs/en/rules/Azure.Policy.WaiverExpiry.md
---

# Policy waiver exemptions must expire

## SYNOPSIS

Configure policy waiver exemptions to expire.

## DESCRIPTION

Azure Policy waiver exemptions are intended to be temporary acceptance of a non-compliance state.
Use the `Mitigated` category when the issue intent has been met through an another method.

## RECOMMENDATION

Consider configuring an expiry for policy exemption waivers within the maximum threshold.

## EXAMPLES

### Azure templates

To deploy policy assignments that pass this rule:

- Set the `properties.expiresOn` property with a valid date earlier than the maximum number of days.

For example:

```json
{
    "comments": "An example exemption.",
    "name": "exemption-001",
    "type": "Microsoft.Authorization/policyExemptions",
    "apiVersion": "2020-07-01-preview",
    "properties": {
        "policyAssignmentId": "<assignment_id>",
        "policyDefinitionReferenceIds": [],
        "exemptionCategory": "Waiver",
        "expiresOn": "2021-04-27T14:00:00Z",
        "displayName": "Exemption 001",
        "description": "An example exemption.",
        "metadata": {
            "requestedBy": "Apps team",
            "approvedBy": "Security team",
            "createdBy": "DevOps pipeline"
        }
    }
}
```

## NOTES

This rule fails:

- When the exemption is configured not to expire.
- The exemption expiry date is greater than the maximum threshold.

Configure `AZURE_POLICY_WAIVER_MAX_EXPIRY` to set the maximum expiry date threshold.

```yaml
# YAML: The default AZURE_POLICY_WAIVER_MAX_EXPIRY configuration option
configuration:
  AZURE_POLICY_WAIVER_MAX_EXPIRY: 366
```

## LINKS

- [Azure Policy exemption structure](https://docs.microsoft.com/azure/governance/policy/concepts/exemption-structure)
- [Azure template reference](https://docs.microsoft.com/azure/templates/microsoft.authorization/policyexemptions)
- [Repeatable Infrastructure](https://docs.microsoft.com/azure/architecture/framework/devops/automation-infrastructure)