#
# Validation rules for Azure Virtual Machines
#

# Synopsis: Virtual machines should use managed disks
Rule 'Azure.VirtualMachine.UseManagedDisks' -If { ResourceType 'Microsoft.Compute/virtualMachines' } -Tag @{ severity = 'Single point of failure'; category = 'Reliability' } {
    # Check OS disk
    $Null -ne $TargetObject.properties.storageProfile.osDisk.managedDisk.id

    # Check data disks
    if ($TargetObject.properties.storageProfile.dataDisks.Count -gt 0) {
        $count = ($TargetObject.properties.storageProfile.dataDisks.managedDisk.id | Measure-Object).Count
        $count -eq $TargetObject.properties.storageProfile.dataDisks.Count
    }
}

# Synopsis: VMs much use premium disks or use availability sets/ zones to meet SLA requirements
Rule 'Azure.VirtualMachine.Standalone' -If { ResourceType 'Microsoft.Compute/virtualMachines' } -Tag @{ severity = 'Single point of failure'; category = 'Reliability' } {
    Recommend 'Virtual machines should use availability sets or only premium disks'

    $types = @(
        $TargetObject.properties.storageProfile.osDisk.managedDisk.storageAccountType
        $TargetObject.properties.storageProfile.dataDisks.managedDisk.storageAccountType
    )

    $premiumCount = $types | Where-Object { $_ -eq 'Premium_LRS' };

    AnyOf {
        # A member of an availability set
        $Null -ne $TargetObject.properties.availabilitySet.id

        $premiumCount -eq (($TargetObject.properties.storageProfile.dataDisks | Measure-Object).Count + 1)
    }
}

# Synopsis: Check disk caching is configured correctly for the workload
Rule 'Azure.VirtualMachine.DiskCaching' -If { ResourceType 'Microsoft.Compute/virtualMachines' } -Tag @{ severity = 'Important'; category = 'Performance' } {
    # Check OS disk
    $TargetObject.properties.storageProfile.osDisk.caching -eq 'ReadWrite'

    # Check data disks
    $dataDisks = @($TargetObject.properties.storageProfile.dataDisks)

    foreach ($disk in $dataDisks) {
        if ($disk.managedDisk.storageAccountType -eq 'Premium_LRS') {
            $disk.caching -eq 'ReadOnly'
        }
        else {
            $disk.caching -eq 'None'
        }
    }
}

# Synopsis: Network interfaces should inherit from virtual network
Rule 'Azure.VirtualMachine.UniqueDns' -If { ResourceType 'Microsoft.Network/networkInterfaces' } -Tag @{ severity = 'Awareness'; category = 'Operations management' } {
    Recommend 'Network interfaces with DNS settings may increase complexity'

    $TargetObject.Properties.dnsSettings.dnsServers.Length -eq 0
}

# Synopsis: Managed disks should be attached to virtual machines
Rule 'Azure.VirtualMachine.DiskAttached' -If { (ResourceType 'Microsoft.Compute/disks') -and ($TargetObject.ResourceName -notlike '*-ASRReplica') } -Tag @{ severity = 'Awareness'; category = 'Operations management' } {
    Recommend 'Disks that are not attached may not be required'

    # Disks should be attached unless they are used by ASR, which are not attached until failover
    # Disks for VMs that are off are marked as Reserved
    $TargetObject.properties.diskState -eq 'Attached' -or $TargetObject.properties.diskState -eq 'Reserved'
}

# TODO: Check IOPS

# Synopsis: Managed disk is smaller than SKU size
Rule 'Azure.VirtualMachine.DiskSizeAlignment'  -If { ResourceType 'Microsoft.Compute/disks' } -Tag @{ severity = 'Awareness'; category = 'Cost optimisation' } {
    $diskSize = @(32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768)
    $actualSize = $TargetObject.properties.diskSizeGB

    # Find the closest disk size
    $i = 0;
    while ($actualSize -gt $diskSize[$i]) {
        $i++;
    }

    # Actual disk size should be the disk size within 5GB
    $actualSize -ge ($diskSize[$i] - 5);
}

# TODO: Check number of disks

# Synopsis: Use Hybrid Use Benefit
Rule 'Azure.VirtualMachine.UseHybridUseBenefit' -If { (IsWindowsOS) } -Tag @{ severity = 'Awareness'; category = 'Cost optimisation' } {
    Within 'properties.licenseType' 'Windows_Server'
}

# Synopsis: Enabled accelerated networking for supported operating systems
Rule 'Azure.VirtualMachine.AcceleratedNetworking' -If { (SupportsAcceleratedNetworking) } -Tag @{ severity = 'Important'; category = 'Performance optimisation' } {
    $networkInterfaces = $TargetObject.resources | Where-Object { $_.ResourceType -eq 'Microsoft.Network/networkInterfaces' };

    foreach ($interface in $networkInterfaces) {
        ($interface.Properties.enableAcceleratedNetworking -eq $True)
    }
}

# Synopsis: Availability sets should be aligned
Rule 'Azure.VirtualMachine.ASAlignment' -If { ResourceType 'Microsoft.Compute/availabilitySets' } -Tag @{ severity = 'Single point of failure'; category = 'Reliability' } {
    $TargetObject.sku.name -eq 'aligned'
}

# Synopsis: Availability sets should be deployed with at least two members
Rule 'Azure.VirtualMachine.ASMinMembers' -If { ResourceType 'Microsoft.Compute/availabilitySets' } -Tag @{ severity = 'Single point of failure'; category = 'Reliability' } {
    ($TargetObject.properties.virtualmachines.id | Measure-Object).Count -ge 2
}
