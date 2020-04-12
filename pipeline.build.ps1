# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[CmdletBinding()]
param (
    [Parameter(Mandatory = $False)]
    [String]$Build = '0.0.1',

    [Parameter(Mandatory = $False)]
    [String]$Configuration = 'Debug',

    [Parameter(Mandatory = $False)]
    [String]$ApiKey,

    [Parameter(Mandatory = $False)]
    [Switch]$CodeCoverage = $False,

    [Parameter(Mandatory = $False)]
    [String]$ArtifactPath = (Join-Path -Path $PWD -ChildPath out/modules),

    [Parameter(Mandatory = $False)]
    [String]$AssertStyle = 'AzurePipelines'
)

Write-Host -Object "[Pipeline] -- PowerShell: v$($PSVersionTable.PSVersion.ToString())" -ForegroundColor Green;
Write-Host -Object "[Pipeline] -- PWD: $PWD" -ForegroundColor Green;
Write-Host -Object "[Pipeline] -- ArtifactPath: $ArtifactPath" -ForegroundColor Green;
Write-Host -Object "[Pipeline] -- BuildNumber: $($Env:BUILD_BUILDNUMBER)" -ForegroundColor Green;
Write-Host -Object "[Pipeline] -- SourceBranch: $($Env:BUILD_SOURCEBRANCH)" -ForegroundColor Green;
Write-Host -Object "[Pipeline] -- SourceBranchName: $($Env:BUILD_SOURCEBRANCHNAME)" -ForegroundColor Green;
Write-Host -Object "[Pipeline] -- Culture: $((Get-Culture).Name), $((Get-Culture).Parent)" -ForegroundColor Green;

if ($Env:SYSTEM_DEBUG -eq 'true') {
    $VerbosePreference = 'Continue';
}

if ($Env:BUILD_SOURCEBRANCH -like '*/tags/*' -and $Env:BUILD_SOURCEBRANCHNAME -like 'v0.*') {
    $Build = $Env:BUILD_SOURCEBRANCHNAME.Substring(1);
}

$version = $Build;
$versionSuffix = [String]::Empty;

if ($version -like '*-*') {
    [String[]]$versionParts = $version.Split('-', [System.StringSplitOptions]::RemoveEmptyEntries);
    $version = $versionParts[0];

    if ($versionParts.Length -eq 2) {
        $versionSuffix = $versionParts[1];
    }
}

Write-Host -Object "[Pipeline] -- Using version: $version" -ForegroundColor Green;
Write-Host -Object "[Pipeline] -- Using versionSuffix: $versionSuffix" -ForegroundColor Green;

if ($Env:COVERAGE -eq 'true') {
    $CodeCoverage = $True;
}

# Copy the PowerShell modules files to the destination path
function CopyModuleFiles {
    param (
        [Parameter(Mandatory = $True)]
        [String]$Path,

        [Parameter(Mandatory = $True)]
        [String]$DestinationPath
    )

    process {
        $sourcePath = Resolve-Path -Path $Path;

        Get-ChildItem -Path $sourcePath -Recurse -File -Include *.ps1,*.psm1,*.psd1,*.ps1xml,*.yaml | Where-Object -FilterScript {
            ($_.FullName -notmatch '(\.(cs|csproj)|(\\|\/)(obj|bin))')
        } | ForEach-Object -Process {
            $filePath = $_.FullName.Replace($sourcePath, $destinationPath);

            $parentPath = Split-Path -Path $filePath -Parent;

            if (!(Test-Path -Path $parentPath)) {
                $Null = New-Item -Path $parentPath -ItemType Directory -Force;
            }

            Copy-Item -Path $_.FullName -Destination $filePath -Force;
        };
    }
}

function Get-RepoRuleData {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $False)]
        [String]$Path = $PWD
    )
    process {
        GetPathInfo -Path $Path -Verbose:$VerbosePreference;
    }
}

function GetPathInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [String]$Path
    )
    begin {
        $items = New-Object -TypeName System.Collections.ArrayList;
    }
    process {
        $Null = $items.Add((Get-Item -Path $Path));
        $files = @(Get-ChildItem -Path $Path -File -Recurse -Include *.ps1,*.psm1,*.psd1,*.cs | Where-Object {
            !($_.FullName -like "*.Designer.cs") -and
            !($_.FullName -like "*/bin/*") -and
            !($_.FullName -like "*/obj/*") -and
            !($_.FullName -like "*\obj\*") -and
            !($_.FullName -like "*\bin\*") -and
            !($_.FullName -like "*\out\*") -and
            !($_.FullName -like "*/out/*")
        });
        $Null = $items.AddRange($files);
    }
    end {
        $items;
    }
}

task VersionModule ModuleDependencies, {
    $modulePath = Join-Path -Path $ArtifactPath -ChildPath PSRule.Rules.Azure;
    $manifestPath = Join-Path -Path $modulePath -ChildPath PSRule.Rules.Azure.psd1;
    Write-Verbose -Message "[VersionModule] -- Checking module path: $modulePath";

    if (![String]::IsNullOrEmpty($Build)) {
        # Update module version
        if (![String]::IsNullOrEmpty($version)) {
            Write-Verbose -Message "[VersionModule] -- Updating module manifest ModuleVersion";
            Update-ModuleManifest -Path $manifestPath -ModuleVersion $version;
        }

        # Update pre-release version
        if (![String]::IsNullOrEmpty($versionSuffix)) {
            Write-Verbose -Message "[VersionModule] -- Updating module manifest Prerelease";
            Update-ModuleManifest -Path $manifestPath -Prerelease $versionSuffix;
        }
    }

    $manifest = Test-ModuleManifest -Path $manifestPath;
    $requiredModules = $manifest.RequiredModules | ForEach-Object -Process {
        if ($_.Name -eq 'PSRule' -and $Configuration -eq 'Release') {
            @{ ModuleName = 'PSRule'; ModuleVersion = '0.15.0' }
        }
        else {
            @{ ModuleName = $_.Name; ModuleVersion = $_.Version }
        }
    };
    Update-ModuleManifest -Path $manifestPath -RequiredModules $requiredModules;
    $manifestContent = Get-Content -Path $manifestPath -Raw;
    $manifestContent = $manifestContent -replace 'PSRule = ''System.Collections.Hashtable''', 'PSRule = @{ Baseline = ''Azure.Default'' }';
    $manifestContent | Set-Content -Path $manifestPath;
}

# Synopsis: Publish to PowerShell Gallery
task ReleaseModule VersionModule, {
    $modulePath = (Join-Path -Path $ArtifactPath -ChildPath PSRule.Rules.Azure);
    Write-Verbose -Message "[ReleaseModule] -- Checking module path: $modulePath";

    if (!(Test-Path -Path $modulePath)) {
        Write-Error -Message "[ReleaseModule] -- Module path does not exist";
    }
    elseif (![String]::IsNullOrEmpty($ApiKey)) {
        Publish-Module -Path $modulePath -NuGetApiKey $ApiKey;
    }
}

# Synopsis: Install NuGet provider
task NuGet {
    if ($Null -eq (Get-PackageProvider -Name NuGet -ErrorAction Ignore)) {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser;
    }
}

# Synopsis: Install Pester module
task Pester NuGet, {
    if ($Null -eq (Get-InstalledModule -Name Pester -MinimumVersion 4.9.0 -ErrorAction Ignore)) {
        Install-Module -Name Pester -MinimumVersion 4.9.0 -Scope CurrentUser -Force -SkipPublisherCheck;
    }
    Import-Module -Name Pester -Verbose:$False;
}

# Synopsis: Install PSScriptAnalyzer module
task PSScriptAnalyzer NuGet, {
    if ($Null -eq (Get-InstalledModule -Name PSScriptAnalyzer -MinimumVersion 1.18.3 -ErrorAction Ignore)) {
        Install-Module -Name PSScriptAnalyzer -MinimumVersion 1.18.3 -Scope CurrentUser -Force;
    }
    Import-Module -Name PSScriptAnalyzer -Verbose:$False;
}

# Synopsis: Install PSRule
task PSRule NuGet, {
    if ($Null -eq (Get-InstalledModule -Name PSRule -MinimumVersion 0.16.0 -ErrorAction Ignore)) {
        Install-Module -Name PSRule -Repository PSGallery -MinimumVersion 0.16.0 -Scope CurrentUser -Force;
    }
    Import-Module -Name PSRule -Verbose:$False;
}

# Synopsis: Install PSDocs
task PSDocs NuGet, {
    if ($Null -eq (Get-InstalledModule -Name PSDocs -MinimumVersion 0.6.3 -ErrorAction Ignore)) {
        Install-Module -Name PSDocs -Repository PSGallery -MinimumVersion 0.6.3 -Scope CurrentUser -Force;
    }
    Import-Module -Name PSDocs -Verbose:$False;
}

# Synopsis: Install PlatyPS module
task platyPS {
    if ($Null -eq (Get-InstalledModule -Name PlatyPS -MinimumVersion 0.14.0 -ErrorAction Ignore)) {
        Install-Module -Name PlatyPS -Scope CurrentUser -MinimumVersion 0.14.0 -Force;
    }
}

# Synopsis: Install module dependencies
task ModuleDependencies NuGet, PSRule, {
    if ($Null -eq (Get-InstalledModule -Name Az.Accounts -MinimumVersion 1.5.2 -ErrorAction Ignore)) {
        Install-Module -Name Az.Accounts -Scope CurrentUser -MinimumVersion 1.5.2 -Force;
    }
    if ($Null -eq (Get-InstalledModule -Name Az.Resources -MinimumVersion 1.4.0 -ErrorAction Ignore)) {
        Install-Module -Name Az.Resources -Scope CurrentUser -MinimumVersion 1.4.0 -Force;
    }
}

task BuildDotNet {
    exec {
        # Build library
        # Add build version -p:versionPrefix=$ModuleVersion
        dotnet publish src/PSRule.Rules.Azure -c $Configuration -f netstandard2.0 -o $(Join-Path -Path $PWD -ChildPath out/modules/PSRule.Rules.Azure) -p:version=$Build
    }
}

task TestDotNet {
    if ($CodeCoverage) {
        exec {
            # Test library
            dotnet test --collect:"Code Coverage" --logger trx -r (Join-Path $PWD -ChildPath reports/) tests/PSRule.Rules.Azure.Tests
        }
    }
    else {
        exec {
            # Test library
            dotnet test --logger trx -r (Join-Path $PWD -ChildPath reports/) tests/PSRule.Rules.Azure.Tests
        }
    }
}

task CopyModule {
    CopyModuleFiles -Path src/PSRule.Rules.Azure -DestinationPath out/modules/PSRule.Rules.Azure;

    # Copy third party notices
    Copy-Item -Path ThirdPartyNotices.txt -Destination out/modules/PSRule.Rules.Azure;
}

# Synopsis: Build modules only
task BuildModule BuildDotNet, CopyModule

task TestModule ModuleDependencies, Pester, PSScriptAnalyzer, {
    # Run Pester tests
    $pesterParams = @{ Path = (Join-Path -Path $PWD -ChildPath tests/PSRule.Rules.Azure.Tests); OutputFile = 'reports/pester-unit.xml'; OutputFormat = 'NUnitXml'; PesterOption = @{ IncludeVSCodeMarker = $True }; PassThru = $True; };

    if ($CodeCoverage) {
        $pesterParams.Add('CodeCoverage', (Join-Path -Path $PWD -ChildPath 'out/modules/**/*.psm1'));
        $pesterParams.Add('CodeCoverageOutputFile', (Join-Path -Path $PWD -ChildPath 'reports/pester-coverage.xml'));
    }

    if (!(Test-Path -Path reports)) {
        $Null = New-Item -Path reports -ItemType Directory -Force;
    }

    $results = Invoke-Pester @pesterParams;

    # Throw an error if pester tests failed
    if ($Null -eq $results) {
        throw 'Failed to get Pester test results.';
    }
    elseif ($results.FailedCount -gt 0) {
        throw "$($results.FailedCount) tests failed.";
    }
}

# Synopsis: Run validation
task Rules PSRule, {
    $assertParams = @{
        Path = './.ps-rule/'
        Style = $AssertStyle
        OutputFormat = 'NUnit3'
        ErrorAction = 'Stop'
    }
    Import-Module (Join-Path -Path $PWD -ChildPath out/modules/PSRule.Rules.Azure) -Force;
    Get-RepoRuleData -Path $PWD |
        Assert-PSRule @assertParams -OutputPath reports/ps-rule-file.xml;

    $rules = Get-PSRule -Module PSRule.Rules.Azure;
    $rules | Assert-PSRule @assertParams -OutputPath reports/ps-rule-file2.xml;
}

# Synopsis: Run script analyzer
task Analyze Build, PSScriptAnalyzer, {
    Invoke-ScriptAnalyzer -Path out/modules/PSRule.Rules.Azure;
}

# Synopsis: Build table of content for rules
task BuildRuleDocs Build, PSRule, PSDocs, {
    Import-Module (Join-Path -Path $PWD -ChildPath out/modules/PSRule.Rules.Azure) -Force;
    $Null = Invoke-PSDocument -Name module -OutputPath .\docs\rules\en\ -Path .\RuleToc.Doc.ps1;
}

# Synopsis: Build help
task BuildHelp BuildModule, PlatyPS, {
    if (!(Test-Path out/modules/PSRule.Rules.Azure/en/)) {
        $Null = New-Item -Path out/modules/PSRule.Rules.Azure/en/ -ItemType Directory -Force;
    }
    if (!(Test-Path out/modules/PSRule.Rules.Azure/en-US/)) {
        $Null = New-Item -Path out/modules/PSRule.Rules.Azure/en-US/ -ItemType Directory -Force;
    }
    if (!(Test-Path out/modules/PSRule.Rules.Azure/en-AU/)) {
        $Null = New-Item -Path out/modules/PSRule.Rules.Azure/en-AU/ -ItemType Directory -Force;
    }
    if (!(Test-Path out/modules/PSRule.Rules.Azure/en-GB/)) {
        $Null = New-Item -Path out/modules/PSRule.Rules.Azure/en-GB/ -ItemType Directory -Force;
    }

    $Null = Copy-Item -Path docs/rules/en/*.md -Destination out/modules/PSRule.Rules.Azure/en/;

    # Avoid YamlDotNet issue in same app domain
    exec {
        $pwshPath = (Get-Process -Id $PID).Path;
        &$pwshPath -Command {
            # Generate MAML and about topics
            Import-Module -Name PlatyPS -Verbose:$False;
            $Null = New-ExternalHelp -OutputPath 'out/docs/PSRule.Rules.Azure' -Path '.\docs\commands\PSRule.Rules.Azure\en-US', '.\docs\concepts\PSRule.Rules.Azure\en-US' -Force;

             # Copy generated help into module out path
            $Null = Copy-Item -Path out/docs/PSRule.Rules.Azure/* -Destination out/modules/PSRule.Rules.Azure/en-US/ -Recurse;
            $Null = Copy-Item -Path out/docs/PSRule.Rules.Azure/* -Destination out/modules/PSRule.Rules.Azure/en-AU/ -Recurse;
            $Null = Copy-Item -Path out/docs/PSRule.Rules.Azure/* -Destination out/modules/PSRule.Rules.Azure/en-GB/ -Recurse;
        }
    }

    if (!(Test-Path -Path 'out/docs/PSRule.Rules.Azure/PSRule.Rules.Azure-help.xml')) {
        throw 'Failed find generated cmdlet help.';
    }
}

task ScaffoldHelp Build, BuildRuleDocs, {
    Import-Module (Join-Path -Path $PWD -ChildPath out/modules/PSRule.Rules.Azure) -Force;
    Update-MarkdownHelp -Path '.\docs\commands\PSRule.Rules.Azure\en-US';
}

# Synopsis: Add shipit build tag
task TagBuild {
    if ($Null -ne $Env:BUILD_DEFINITIONNAME) {
        Write-Host "`#`#vso[build.addbuildtag]shipit";
    }
}

# Synopsis: Remove temp files.
task Clean {
    Remove-Item -Path out,reports -Recurse -Force -ErrorAction SilentlyContinue;
}

task Build Clean, BuildModule, VersionModule, BuildHelp

task Test Build, Rules, TestDotNet, TestModule

task Release ReleaseModule, TagBuild

# Synopsis: Build and test. Entry point for CI Build stage
task . Build, Rules, TestDotNet
