# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#
# Unit tests for Azure SQL Database rules
#

[CmdletBinding()]
param ()

# Setup error handling
$ErrorActionPreference = 'Stop';
Set-StrictMode -Version latest;

if ($Env:SYSTEM_DEBUG -eq 'true') {
    $VerbosePreference = 'Continue';
}

# Setup tests paths
$rootPath = $PWD;
Import-Module (Join-Path -Path $rootPath -ChildPath out/modules/PSRule.Rules.Azure) -Force;
$here = (Resolve-Path $PSScriptRoot).Path;

Describe 'Azure.SQL' -Tag 'SQL' {
    $dataPath = Join-Path -Path $here -ChildPath 'Resources.SQL.json';

    Context 'Conditions' {
        $invokeParams = @{
            Baseline = 'Azure.All'
            Module = 'PSRule.Rules.Azure'
            WarningAction = 'Ignore'
            ErrorAction = 'Stop'
        }
        $result = Invoke-PSRule @invokeParams -InputPath $dataPath;

        It 'Azure.SQL.FirewallRuleCount' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.FirewallRuleCount' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-B';
            $ruleResult.Reason | Should -BeLike "The number of firewall rules (*) exceeded 10.";

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 2;
            $ruleResult.TargetName | Should -BeIn 'server-A', 'server-C';
        }

        It 'Azure.SQL.AllowAzureAccess' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.AllowAzureAccess' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-B';

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 2;
            $ruleResult.TargetName | Should -BeIn 'server-A', 'server-C';
        }

        It 'Azure.SQL.FirewallIPRange' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.FirewallIPRange' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-B';
            $ruleResult.Reason | Should -BeLike "The number of public IP addresses permitted (*) exceeded 10.";

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 2;
            $ruleResult.TargetName | Should -BeIn 'server-A', 'server-C';
        }

        It 'Azure.SQL.ThreatDetection' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.ThreatDetection' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 2;
            $ruleResult.TargetName | Should -Be 'server-B', 'server-C';
            $ruleResult[0].Reason[0] | Should -Be 'A sub-resource of type ''Microsoft.Sql/servers/securityAlertPolicies'' has not been specified.';

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-A';
        }

        It 'Azure.SQL.Auditing' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.Auditing' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 2;
            $ruleResult.TargetName | Should -Be 'server-B', 'server-C';
            $ruleResult[0].Reason[0] | Should -Be 'A sub-resource of type ''Microsoft.Sql/servers/auditingSettings'' has not been specified.';
            $ruleResult[1].Reason[0] | Should -Be 'The field ''Properties.state'' is set to ''Disabled''.';

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-A';
        }

        It 'Azure.SQL.AAD' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.AAD' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 2;
            $ruleResult.TargetName | Should -BeIn 'server-B', 'server-C';
            $ruleResult[0].Reason[0] | Should -Be 'A sub-resource of type ''Microsoft.Sql/servers/administrators'' has not been specified.';
            $ruleResult[1].Reason[0] | Should -Be 'A sub-resource of type ''Microsoft.Sql/servers/administrators'' has not been specified.';

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-A';
        }

        It 'Azure.SQL.MinTLS' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.MinTLS' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 2;
            $ruleResult.TargetName | Should -BeIn 'server-B', 'server-C';

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-A';
        }

        It 'Azure.SQL.TDE' {
            $filteredResult = $result | Where-Object { $_.RuleName -eq 'Azure.SQL.TDE' };

            # Fail
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Fail' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -BeIn 'server-A/database-A';
            $ruleResult[0].Reason[0] | Should -Be 'A sub-resource of type ''Microsoft.Sql/servers/databases/transparentDataEncryption'' has not been specified.';

            # Pass
            $ruleResult = @($filteredResult | Where-Object { $_.Outcome -eq 'Pass' });
            $ruleResult | Should -Not -BeNullOrEmpty;
            $ruleResult.Length | Should -Be 1;
            $ruleResult.TargetName | Should -Be 'server-A/database-B';
        }
    }

    Context 'Resource name - Azure.SQL.ServerName' {
        $invokeParams = @{
            Baseline = 'Azure.All'
            Module = 'PSRule.Rules.Azure'
            WarningAction = 'Ignore'
            ErrorAction = 'Stop'
        }
        $validNames = @(
            'sqlserver1'
            'sqlserver-1'
            '1sqlserver'
        )
        $invalidNames = @(
            '-sqlserver1'
            'sqlserver1-'
            'sqlserver.1'
            'sqlserver_1'
            'SQLServer1'
        )
        $testObject = [PSCustomObject]@{
            Name = ''
            ResourceType = 'Microsoft.Sql/servers'
        }

        # Pass
        foreach ($name in $validNames) {
            It $name {
                $testObject.Name = $name;
                $ruleResult = $testObject | Invoke-PSRule @invokeParams -Name 'Azure.SQL.ServerName';
                $ruleResult | Should -Not -BeNullOrEmpty;
                $ruleResult.Outcome | Should -Be 'Pass';
            }
        }

        # Fail
        foreach ($name in $invalidNames) {
            It $name {
                $testObject.Name = $name;
                $ruleResult = $testObject | Invoke-PSRule @invokeParams -Name 'Azure.SQL.ServerName';
                $ruleResult | Should -Not -BeNullOrEmpty;
                $ruleResult.Outcome | Should -Be 'Fail';
            }
        }
    }

    Context 'Resource name - Azure.SQL.DBName' {
        $invokeParams = @{
            Baseline = 'Azure.All'
            Module = 'PSRule.Rules.Azure'
            WarningAction = 'Ignore'
            ErrorAction = 'Stop'
        }
        $validNames = @(
            'DB1'
            'DB-1'
            '!data$base 1'
            'database.1'
            'database(1)'
            'database@1'
            'database~1'
            'database`1'
            'servername/db1'
        )
        $invalidNames = @(
            'database1 '
            'database1.'
        )
        $testObject = [PSCustomObject]@{
            Name = ''
            ResourceType = 'Microsoft.Sql/servers/databases'
        }

        # Pass
        foreach ($name in $validNames) {
            It $name {
                $testObject.Name = $name;
                $ruleResult = $testObject | Invoke-PSRule @invokeParams -Name 'Azure.SQL.DBName';
                $ruleResult | Should -Not -BeNullOrEmpty;
                $ruleResult.Outcome | Should -Be 'Pass';
            }
        }

        # Fail
        foreach ($name in $invalidNames) {
            It $name {
                $testObject.Name = $name;
                $ruleResult = $testObject | Invoke-PSRule @invokeParams -Name 'Azure.SQL.DBName';
                $ruleResult | Should -Not -BeNullOrEmpty;
                $ruleResult.Outcome | Should -Be 'Fail';
            }
        }
    }

    Context 'Resource name - Azure.SQL.FGName' {
        $invokeParams = @{
            Baseline = 'Azure.All'
            Module = 'PSRule.Rules.Azure'
            WarningAction = 'Ignore'
            ErrorAction = 'Stop'
        }
        $validNames = @(
            'fgroup1'
            'fgroup-1'
            '1fgroup'
        )
        $invalidNames = @(
            '-fgroup1'
            'fgroup1-'
            'fgroup.1'
            'fgroup_1'
            'FGroup1'
        )
        $testObject = [PSCustomObject]@{
            Name = ''
            ResourceType = 'Microsoft.Sql/servers/failoverGroups'
        }

        # Pass
        foreach ($name in $validNames) {
            It $name {
                $testObject.Name = $name;
                $ruleResult = $testObject | Invoke-PSRule @invokeParams -Name 'Azure.SQL.FGName';
                $ruleResult | Should -Not -BeNullOrEmpty;
                $ruleResult.Outcome | Should -Be 'Pass';
            }
        }

        # Fail
        foreach ($name in $invalidNames) {
            It $name {
                $testObject.Name = $name;
                $ruleResult = $testObject | Invoke-PSRule @invokeParams -Name 'Azure.SQL.FGName';
                $ruleResult | Should -Not -BeNullOrEmpty;
                $ruleResult.Outcome | Should -Be 'Fail';
            }
        }
    }
}
