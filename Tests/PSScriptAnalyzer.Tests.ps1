Try { Set-BuildEnvironment -Path "${PSScriptRoot}\.." -ErrorAction SilentlyContinue -Force } Catch { }

Remove-Module ${env:BHProjectName} -ErrorAction SilentlyContinue -Force -Confirm:$False
$Script:Module = Import-Module ${env:BHPSModuleManifest} -Force -PassThru

Describe "General project validation: ${env:BHProjectName}" {

    Context 'Basic Module Testing' {
        # Original idea from: https://kevinmarquette.github.io/2017-01-21-powershell-module-continious-delivery-pipeline/
        $scripts = Get-ChildItem ${env:BHModulePath} -Include *.ps1, *.psm1, *.psd1 -Recurse
        $testCase = $scripts | Foreach-Object {
            @{
                FilePath = $_.fullname
                FileName = $_.Name

            }
        }
        It "Script <FileName> should be valid powershell" -TestCases $testCase {
            param(
                $FilePath,
                $FileName
            )

            $FilePath | Should Exist

            $contents = Get-Content -Path $FilePath -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
            $errors.Count | Should Be 0
        }

        It "Module '${env:BHProjectName}' can import cleanly" {
            { $Script:Module = Import-Module ${env:BHPSModuleManifest} -Force -PassThru } | Should Not Throw
        }
    }

    Context 'Manifest Testing' {
        It 'Valid Module Manifest' {
            {
                $Script:Manifest = Test-ModuleManifest -Path ${env:BHPSModuleManifest} -ErrorAction Stop -WarningAction SilentlyContinue
            } | Should Not Throw
        }
        It 'Valid Manifest Name' {
            $Script:Manifest.Name | Should be ${env:BHProjectName}
        }
        It 'Generic Version Check' {
            $Script:Manifest.Version -as [Version] | Should Not BeNullOrEmpty
        }
        It 'Valid Manifest Description' {
            $Script:Manifest.Description | Should Not BeNullOrEmpty
        }
        It 'Valid Manifest Root Module' {
            $Script:Manifest.RootModule | Should Be "${env:BHProjectName}.psm1"
        }
        It 'Valid Manifest GUID' {
            $Script:Manifest.Guid | Should be '44f3fd27-d82a-43c2-a9b8-72e552484b09'
        }
        It 'No Format File' {
            $Script:Manifest.ExportedFormatFiles | Should BeNullOrEmpty
        }

        It 'Required Modules' {
            $Script:Manifest.RequiredModules | Should BeNullOrEmpty
        }
    }

    Context 'Exported Functions' {

        $ManifestFunctions = $Script:Manifest.ExportedFunctions.Keys
        $ExportedFunctions = $Script:Module.ExportedFunctions.Keys
        $ExpectedFunctions = (Get-ChildItem -Path "${env:BHModulePath}\public" -Filter *.ps1 -Recurse | Select-Object -ExpandProperty Name ) -replace '\.ps1$'
        $CommandFunctions = Get-Command -Module $Script:Module.Name -CommandType Function | Select-Object -ExpandProperty Name

        $testCase = $ExpectedFunctions | Foreach-Object {@{FunctionName = $_}}
        It "Function <FunctionName> should be in manifest" -TestCases $testCase -Skip {
            param($FunctionName)
            $FunctionName -in $ManifestFunctions | Should Be $true
        }

        It "Function <FunctionName> should be exported" -TestCases $testCase {
            param($FunctionName)
            $FunctionName -in $ExportedFunctions | Should Be $true
            $FunctionName -in $CommandFunctions | Should Be $true
        }

        It 'Number of Functions Exported compared to Manifest' -Skip {
            $CommandFunctions.Count | Should be $ManifestFunctions.Count
        }

        It 'Number of Functions Exported compared to Files' {
            $CommandFunctions.Count | Should be $ExpectedFunctions.Count
        }

        $InternalFunctions = (Get-ChildItem -Path "${env:BHModulePath}\private" -Filter *.ps1 | Select-Object -ExpandProperty Name ) -replace '\.ps1$'
        $testCase = $InternalFunctions | Foreach-Object {@{FunctionName = $_}}
        It "Internal function <FunctionName> is not directly accessible outside the module" -TestCases $testCase {
            param($FunctionName)
            { . $FunctionName } | Should Throw
        }
    }

    Context 'Exported Aliases' {
        It 'Proper Number of Aliases Exported compared to Manifest' {
            $ExportedCount = Get-Command -Module ${env:BHProjectName} -CommandType Alias | Measure-Object | Select-Object -ExpandProperty Count
            $ManifestCount = $Manifest.ExportedAliases.Count

            $ExportedCount | Should be $ManifestCount
        }

        It 'Proper Number of Aliases Exported compared to Files' {
            $AliasCount = Get-ChildItem -Path "${env:BHModulePath}\public" -Filter *.ps1 | Select-String "New-Alias" | Measure-Object | Select-Object -ExpandProperty Count
            $ManifestCount = $Manifest.ExportedAliases.Count

            $AliasCount  | Should be $ManifestCount
        }
    }
}

Describe "${env:BHProjectName} ScriptAnalyzer" -Tag 'Compliance' {
    $PSScriptAnalyzerSettings = @{
        Severity    = @('Error', 'Warning')
        ExcludeRule = @('PSUseSingularNouns', 'PSUseShouldProcessForStateChangingFunctions ')
    }
    # Test all functions with PSScriptAnalyzer
    $ScriptAnalyzerErrors = @()
    $ScriptAnalyzerErrors += Invoke-ScriptAnalyzer -Path "${env:BHModulePath}\public" @PSScriptAnalyzerSettings
    $ScriptAnalyzerErrors += Invoke-ScriptAnalyzer -Path "${env:BHModulePath}\private" @PSScriptAnalyzerSettings
    # Get a list of all internal and Exported functions
    $InternalFunctions = Get-ChildItem -Path "${env:BHModulePath}\private" -Filter *.ps1 | Select-Object -ExpandProperty Name
    $ExportedFunctions = Get-ChildItem -Path "${env:BHModulePath}\public" -Filter *.ps1 | Select-Object -ExpandProperty Name
    $AllFunctions = ($InternalFunctions + $ExportedFunctions) | Sort-Object
    $FunctionsWithErrors = $ScriptAnalyzerErrors.ScriptName | Sort-Object -Unique
    if ($ScriptAnalyzerErrors) {
        $testCase = $ScriptAnalyzerErrors | Foreach-Object {
            @{
                RuleName   = $_.RuleName
                ScriptName = $_.ScriptName
                Message    = $_.Message
                Severity   = $_.Severity
                Line       = $_.Line
            }
        }
        # Compare those with not successfull
        $FunctionsWithoutErrors = Compare-Object -ReferenceObject $AllFunctions -DifferenceObject $FunctionsWithErrors  | Select-Object -ExpandProperty InputObject
        Context 'ScriptAnalyzer Testing' {
            It "Function <ScriptName> should not use <Message> on line <Line>" -TestCases $testCase {
                param(
                    $RuleName,
                    $ScriptName,
                    $Message,
                    $Severity,
                    $Line
                )
                $ScriptName | Should BeNullOrEmpty
            }
        }
    } else {
        # Everything was perfect, let's show that as well
        $FunctionsWithoutErrors = $AllFunctions
    }

    # Show good functions in the test, the more green the better
    Context 'Successful ScriptAnalyzer Testing' {
        $testCase = $FunctionsWithoutErrors | Foreach-Object {
            @{
                ScriptName = $_
            }
        }
        It "Function <ScriptName> has no ScriptAnalyzerErrors" -TestCases $testCase {
            param(
                $ScriptName
            )
            $ScriptName | Should Not BeNullOrEmpty
        }
    }
}
