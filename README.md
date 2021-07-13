# PSRule for Azure

A suite of rules to validate Azure resources and infrastructure as code (IaC) using PSRule.

![ci-badge]

Features of PSRule for Azure include:

- [Ready to go](https://azure.github.io/PSRule.Rules.Azure/features/#readytogo) - Leverage over 200 pre-built rules to validate Azure resources.
- [DevOps](https://azure.github.io/PSRule.Rules.Azure/features/#devops) - Validate resources and infrastructure code pre or post-deployment.
- [Cross-platform](https://azure.github.io/PSRule.Rules.Azure/features/#cross-platform) - Run on MacOS, Linux, and Windows.

## Project objectives

1. **Ready to go**:
   - Provide a [Azure Well-Architected Framework][AWAF] aligned suite of rules for validating Azure resources.
   - Provide meaningful information to allow remediation.
2. **DevOps**:
   - Resources and templates can be validated before deployment within DevOps workflows.
   - Allow pull request (PR) validation to prevent invalid configuration being merged.
3. **Enterprise ready**:
   - Rules can be directly adopted and additional enterprise specific rules can be layed on.
   - Provide regular baselines to allow progressive adoption.

## Support

This project uses GitHub Issues to track bugs and feature requests.
Before logging an issue please see our [troubleshooting guide].

Please search the existing issues before filing new issues to avoid duplicates.

- For new issues, file your bug or feature request as a new [issue].
- For help, discussion, and support questions about using this project, join or start a [discussion].

If you have any problems with the [PSRule][engine] engine, please check the project GitHub [issues](https://github.com/Microsoft/PSRule/issues) page instead.

Support for this project/ product is limited to the resources listed above.

## Getting the modules

This project requires the `PSRule` and `Az` PowerShell modules. For details on each see [install].

You can download and install these modules from the PowerShell Gallery.

Module             | Description | Downloads / instructions
------             | ----------- | ------------------------
PSRule.Rules.Azure | Validate Azure resources and infrastructure as code using PSRule. | [latest][module] / [instructions][install]

## Getting started

PSRule for Azure provides two methods for analyzing Azure resources:

- _Pre-flight_ - Before resources are deployed from Azure Resource Manager templates.
- _In-flight_ - After resources are deployed to an Azure subscription.

For specific use cases see [scenarios](#scenarios).
For additional details see the [FAQ](https://azure.github.io/PSRule.Rules.Azure/features/#frequentlyaskedquestionsfaq).

### Using with GitHub Actions

The following example shows how to setup Github Actions to validate templates pre-flight.

1. See [Creating a workflow file][create-workflow].
2. Export rule data from templates using PowerShell.
3. Reference `Microsoft/ps-rule` with `modules: 'PSRule.Rules.Azure'`.

For example:

```yaml
# Example: .github/workflows/analyze-arm.yaml

#
# STEP 1: Template validation
#
name: Analyze templates
on:
- pull_request
jobs:
  analyze_arm:
    name: Analyze templates
    runs-on: ubuntu-latest
    steps:

    - name: Checkout
      uses: actions/checkout@v2

    # STEP 2: Export template data for analysis
    - name: Export templates
      run: Install-Module PSRule.Rules.Azure -Force; Get-AzRuleTemplateLink | Export-AzRuleTemplateData -OutputPath 'out/templates/';
      shell: pwsh

    # STEP 3: Run analysis against exported data
    - name: Analyze Azure template files
      uses: Microsoft/ps-rule@main
      with:
        modules: 'PSRule.Rules.Azure'  # Analyze objects using the rules within the PSRule.Rules.Azure PowerShell module.
        inputPath: 'out/templates/'    # Read objects from JSON files in 'out/templates/'.
```

### Using with Azure Pipelines

The following example shows how to setup Azure Pipelines to validate templates pre-flight.

1. Install [PSRule extension][extension] for Azure DevOps marketplace.
2. Create a new YAML pipeline with the _Starter pipeline_ template.
3. Add the `Install PSRule module` task.
   - Set module to `PSRule.Rules.Azure`.
4. Export rule data from templates using PowerShell.
5. Add the `PSRule analysis` task.
   - Set input type to `Input Path`.
   - Set input files to the location rule data is exported to.
   - Set modules to `PSRule.Rules.Azure`.

For example:

```yaml
# Example: .azure-pipelines/analyze-arm.yaml

#
# STEP 2: Template validation
#
jobs:
- job: 'analyze_arm'
  displayName: 'Analyze templates'
  pool:
    vmImage: 'ubuntu-18.04'
  steps:

  # STEP 3: Install PSRule.Rules.Azure from the PowerShell Gallery
  - task: ps-rule-install@0
    displayName: Install PSRule.Rules.Azure
    inputs:
      module: 'PSRule.Rules.Azure'   # Install PSRule.Rules.Azure from the PowerShell Gallery.

  # STEP 4: Export template data for analysis
  - powershell: Get-AzRuleTemplateLink | Export-AzRuleTemplateData -OutputPath 'out/templates/';
    displayName: 'Export template data'

  # STEP 5: Run analysis against exported data
  - task: ps-rule-assert@0
    displayName: Analyze Azure template files
    inputs:
      inputType: inputPath
      inputPath: 'out/templates/'     # Read objects from JSON files in 'out/templates/'.
      modules: 'PSRule.Rules.Azure'   # Analyze objects using the rules within the PSRule.Rules.Azure PowerShell module.
```

### Using locally

The following example shows how to setup PSRule locally to validate templates pre-flight.

1. Install the `PSRule.Rules.Azure` module and dependencies from the PowerShell Gallery.
2. Export rule data from templates using PowerShell.
3. Run analysis against exported data.

For example:

```powershell
# STEP 1: Install PSRule.Rules.Azure from the PowerShell Gallery
Install-Module -Name 'PSRule.Rules.Azure' -Scope CurrentUser;

# STEP 2: Export template data for analysis
Get-AzRuleTemplateLink | Export-AzRuleTemplateData -OutputPath 'out/templates/';

# STEP 3: Run analysis against exported data
Assert-PSRule -Module 'PSRule.Rules.Azure' -InputPath 'out/templates/';
```

### Export in-flight resource data

The following example shows how to setup PSRule locally to validate resources running in a subscription.

1. Install the `PSRule.Rules.Azure` module and dependencies from the PowerShell Gallery.
2. Connect and set context to an Azure subscription from PowerShell.
3. Export the resource data with the `Export-AzRuleData` cmdlet.
4. Run analysis against exported data.

For example:

```powershell
# STEP 1: Install PSRule.Rules.Azure from the PowerShell Gallery
Install-Module -Name 'PSRule.Rules.Azure' -Scope CurrentUser;

# STEP 2: Authenticate to Azure, only required if not currently connected
Connect-AzAccount;

# Confirm the current subscription context
Get-AzContext;

# STEP 3: Exports a resource graph stored as JSON for analysis
Export-AzRuleData -OutputPath 'out/templates/';

# STEP 4: Run analysis against exported data
Assert-PSRule -Module 'PSRule.Rules.Azure' -InputPath 'out/templates/';
```

### Additional options

By default, resource data for the current subscription context will be exported.

To export resource data for specific subscriptions use:

- `-Subscription` - to specify subscriptions by id or name.
- `-Tenant` - to specify subscriptions within an Azure Active Directory Tenant by id.

For example:

```powershell
# Export data from two specific subscriptions
Export-AzRuleData -Subscription 'Contoso Production', 'Contoso Non-production';
```

To export specific resource data use:

- `-ResourceGroupName` - to filter resources by Resource Group.
- `-Tag` - to filter resources based on tag.

For example:

```powershell
# Export information from two resource groups within the current subscription context
Export-AzRuleData -ResourceGroupName 'rg-app1-web', 'rg-app1-db';
```

To export resource data for all subscription contexts use:

- `-All` - to export resource data for all subscription contexts.

For example:

```powershell
# Export data from all subscription contexts
Export-AzRuleData -All;
```

To filter results to only failed rules, use `Invoke-PSRule -Outcome Fail`.
Passed, failed and error results are shown by default.

For example:

```powershell
# Only show failed results
Invoke-PSRule -InputPath 'out/templates/' -Module 'PSRule.Rules.Azure' -Outcome Fail;
```

The output of this example is:

```text
   TargetName: storage

RuleName                            Outcome    Recommendation
--------                            -------    --------------
Azure.Storage.UseReplication        Fail       Storage accounts not using GRS may be at risk
Azure.Storage.SecureTransferRequ... Fail       Storage accounts should only accept secure traffic
Azure.Storage.SoftDelete            Fail       Enable soft delete on Storage Accounts
```

A summary of results can be displayed by using `Invoke-PSRule -As Summary`.

For example:

```powershell
# Display as summary results
Invoke-PSRule -InputPath 'out/templates/' -Module 'PSRule.Rules.Azure' -As Summary;
```

The output of this example is:

```text
RuleName                            Pass  Fail  Outcome
--------                            ----  ----  -------
Azure.ACR.MinSku                    0     1     Fail
Azure.AppService.PlanInstanceCount  0     1     Fail
Azure.AppService.UseHTTPS           0     2     Fail
Azure.Resource.UseTags              73    36    Fail
Azure.SQL.ThreatDetection           0     1     Fail
Azure.SQL.Auditing                  0     1     Fail
Azure.Storage.UseReplication        1     7     Fail
Azure.Storage.SecureTransferRequ... 2     6     Fail
Azure.Storage.SoftDelete            0     8     Fail
```

## Scenarios

For walk through examples of `PSRule.Rules.Azure` module usage see:

- [Validate Azure resources from templates with Azure Pipelines](docs/scenarios/azure-pipelines-ci/azure-pipelines-ci.md)
- [Validate Azure resources from templates with continuous integration (CI)](docs/scenarios/azure-template-ci/azure-template-ci.md)

## Rule reference

PSRule for Azure includes rules across five pillars of the [Microsoft Azure Well-Architected Framework][AWAF].

- [Rules for architecture excellence](https://azure.github.io/PSRule.Rules.Azure/en/rules/module/)
  - [Cost Optimization](https://azure.github.io/PSRule.Rules.Azure/en/rules/module/#costoptimization)
  - [Operational Excellence](https://azure.github.io/PSRule.Rules.Azure/en/rules/module/#operationalexcellence)
  - [Performance Efficiency](https://azure.github.io/PSRule.Rules.Azure/en/rules/module/#performanceefficiency)
  - [Reliability](https://azure.github.io/PSRule.Rules.Azure/en/rules/module/#reliability)
  - [Security](https://azure.github.io/PSRule.Rules.Azure/en/rules/module/#security)

To view a list of rules by Azure resources see:

- [Rules by resource](https://azure.github.io/PSRule.Rules.Azure/en/rules/resource/)

## Baseline reference

The following baselines are included within `PSRule.Rules.Azure`.

- [Azure.Default](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.Default/) - Default baseline for Azure rules.
- [Azure.Preview](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.Preview/) - Includes Azure features in preview.
- [Azure.All](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.All/) - Includes all Azure rules.
- [Azure.GA_2020_06](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.GA_2020_06/) - Baseline for GA rules released June 2020 or prior.
- [Azure.GA_2020_09](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.GA_2020_09/) - Baseline for GA rules released September 2020 or prior.
- [Azure.GA_2020_12](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.GA_2020_12/) - Baseline for GA rules released December 2020 or prior.
- [Azure.GA_2021_03](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.GA_2021_03/) - Baseline for GA rules released March 2021 or prior.
- [Azure.GA_2021_06](https://azure.github.io/PSRule.Rules.Azure/en/baselines/Azure.GA_2021_06/) - Baseline for GA rules released June 2021 or prior.

## Language reference

PSRule for Azure extends PowerShell with the following cmdlets.

### Commands

The following commands exist in the `PSRule.Rules.Azure` module:

- [Export-AzRuleData](docs/commands/Export-AzRuleData.md) - Export resource configuration data from Azure subscriptions.
- [Export-AzRuleTemplateData](docs/commands/Export-AzRuleTemplateData.md) - Export resource configuration data from Azure templates.
- [Get-AzRuleTemplateLink](docs/commands/Get-AzRuleTemplateLink.md) - Get a metadata link to a Azure template file.

### Concepts

The following conceptual topics exist in the `PSRule.Rules.Azure` module:

- [Azure metadata link](docs/concepts/about_PSRule_Azure_Metadata_Link.md)
- [Configuration](docs/concepts/about_PSRule_Azure_Configuration.md)
  - [Azure_AKSMinimumVersion](docs/concepts/about_PSRule_Azure_Configuration.md#azure_aksminimumversion)
  - [Azure_AKSNodeMinimumMaxPods](docs/concepts/about_PSRule_Azure_Configuration.md#azure_aksnodeminimummaxpods)
  - [Azure_AllowedRegions](docs/concepts/about_PSRule_Azure_Configuration.md#azure_allowedregions)
  - [Azure_MinimumCertificateLifetime](docs/concepts/about_PSRule_Azure_Configuration.md#azure_minimumcertificatelifetime)
  - [AZURE_PARAMETER_FILE_EXPANSION](docs/concepts/about_PSRule_Azure_Configuration.md#azure_parameter_file_expansion)
  - [AZURE_POLICY_WAIVER_MAX_EXPIRY](docs/concepts/about_PSRule_Azure_Configuration.md#azure_policy_waiver_max_expiry)
  - [AZURE_RESOURCE_GROUP](docs/concepts/about_PSRule_Azure_Configuration.md#azure_resource_group)
  - [AZURE_SUBSCRIPTION](docs/concepts/about_PSRule_Azure_Configuration.md#azure_subscription)

## Related projects

The following projects can also be used with PSRule for Azure.

Name                      | Description
----                      | -----------
[PSRule.Rules.CAF]        | A suite of rules to validate Azure resources against the Cloud Adoption Framework (CAF) using PSRule.
[PSRule.Monitor]          | Send and query PSRule analysis results in Azure Monitor.
[PSRule-pipelines]        | An Azure DevOps extension for using PSRule within Azure Pipelines.
[ps-rule]                 | Validate infrastructure as code (IaC) and DevOps repositories using GitHub Actions.

## Changes and versioning

This repository uses [semantic versioning](http://semver.org/) to declare breaking changes.
For a list of module changes please see the [change log](CHANGELOG.md).

> Pre-release module versions are created on major commits and can be installed from the PowerShell Gallery.
> Pre-release versions should be considered experimental.
> Modules and change log details for pre-releases will be removed as standard releases are made available.

## Contributing

This project welcomes contributions and suggestions.
If you are ready to contribute, please visit the [contribution guide](CONTRIBUTING.md).

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Maintainers

- [Bernie White](https://github.com/BernieWhite)

## License

This project is [licensed under the MIT License](LICENSE).

[issue]: https://github.com/Azure/PSRule.Rules.Azure/issues
[discussion]: https://github.com/Azure/PSRule.Rules.Azure/discussions
[install]: https://azure.github.io/PSRule.Rules.Azure/install-instructions/
[ci-badge]: https://dev.azure.com/bewhite/PSRule.Rules.Azure/_apis/build/status/PSRule.Rules.Azure-CI?branchName=main
[module]: https://www.powershellgallery.com/packages/PSRule.Rules.Azure
[engine]: https://github.com/Microsoft/PSRule
[PSRule.Rules.CAF]: https://github.com/microsoft/PSRule.Rules.CAF
[PSRule.Monitor]: https://github.com/microsoft/PSRule.Monitor
[PSRule-pipelines]: https://github.com/microsoft/PSRule-pipelines
[ps-rule]: https://github.com/microsoft/ps-rule
[AWAF]: https://docs.microsoft.com/en-gb/azure/architecture/framework/
[create-workflow]: https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file
[extension]: https://marketplace.visualstudio.com/items?itemName=bewhite.ps-rule
[troubleshooting guide]: https://azure.github.io/PSRule.Rules.Azure/troubleshooting/
