#
# Validation rules for Azure SQL Database
#

#region SQL Database

# Synopsis: Determine if there is an excessive number of firewall rules
Rule 'Azure.SQL.FirewallRuleCount' -If { ResourceType 'Microsoft.Sql/servers' } -Tag @{ severity = 'Awareness'; category = 'Operations management' } {
    Recommend 'SQL Server has > 10 firewall rules, some rules may not be needed';

    $firewallRules = @($TargetObject.resources | Where-Object -FilterScript {
        $_.Type -eq 'Microsoft.Sql/servers/firewallRules'
    })
    $firewallRules.Length -le 10;
}

# Synopsis: Determine if access from Azure services is required
Rule 'Azure.SQL.AllowAzureAccess' -If { ResourceType 'Microsoft.Sql/servers' } -Tag @{ severity = 'Important'; category = 'Security configuration' } {
    $firewallRules = @($TargetObject.resources | Where-Object -FilterScript {
        $_.Type -eq 'Microsoft.Sql/servers/firewallRules' -and
        (
            $_.ResourceName -eq 'AllowAllWindowsAzureIps' -or
            ($_.properties.StartIpAddress -eq '0.0.0.0' -and $_.properties.EndIpAddress -eq '0.0.0.0')
        )
    })
    $firewallRules.Length -eq 0;
}

# Synopsis: Determine if there is an excessive number of permitted IP addresses
Rule 'Azure.SQL.FirewallIPRange' -If { ResourceType 'Microsoft.Sql/servers' } -Tag @{ severity = 'Important'; category = 'Security configuration' } {
    $summary = GetIPAddressSummary
    $summary.Public -le 10;
}

# Synopsis: Enable threat detection for Azure SQL logical server
Rule 'Azure.SQL.ThreatDetection' -If { ResourceType 'Microsoft.Sql/servers' } -Tag @{ severity = 'Important'; category = 'Security configuration' } {
    $policy = $TargetObject.resources | Where-Object -FilterScript {
        $_.Type -eq 'Microsoft.Sql/servers/securityAlertPolicies'
    }
    $policy | Within 'Properties.state' 'Enabled'
}

# Synopsis: Enable auditing for Azure SQL logical server
Rule 'Azure.SQL.Auditing' -If { ResourceType 'Microsoft.Sql/servers' } -Tag @{ severity = 'Important'; category = 'Security configuration' } {
    $policy = $TargetObject.resources | Where-Object -FilterScript {
        $_.Type -eq 'Microsoft.Sql/servers/auditingSettings'
    }
    $policy | Within 'Properties.state' 'Enabled'
}

#endregion SQL Database

#region SQL Managed Instance

#endregion SQL Managed Instance
