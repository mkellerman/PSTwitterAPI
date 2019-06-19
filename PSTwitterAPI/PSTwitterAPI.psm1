param (
    #Specify: -ArgumentList $true on Import-Module to alter behaviour an AzureDevOps pipeline.
    [parameter(Position=0,Mandatory=$false)][bool]$AZDO
)

if(-not($AZDO)){
    $Script:OAuthCollection = [System.Collections.ArrayList]@()
}
else{
    if(-not(Test-Path -path "$PSScriptRoot\private\flag.cli.xml" -ErrorAction SilentlyContinue)){

        Write-Verbose "You have specified 'true' as a module load -Argumentlist parameter. This switch is designed for use in an AzureDevOps pipeline. The parameter causes API credentials to be stored in a file."
        Write-Verbose "Ensure that the 'Remove-Module PSTwitterAPI' command is used inside the pipeline to remove this file from the build agent system."
        
        'Azure DevOps pipeline fix' | Export-CliXML -Path "$PSScriptRoot/private/flag.cli.xml"

        $thisModule = $MyInvocation.MyCommand.ScriptBlock.Module
        $thisModule.OnRemove = {
            Get-Item -Path "$(${function:Set-TwitterOAuthSettings}.module.modulebase)/private/flag.cli.xml" | Remove-Item -Verbose  -ErrorAction SilentlyContinue
            Get-Item -Path "$(${function:Set-TwitterOAuthSettings}.module.modulebase)/private/Oauthfile.cli.xml" | Remove-Item -Verbose -ErrorAction SilentlyContinue
        }
    }
}

$Script:EndPointBaseUrl = 'https://api.twitter.com/1.1'
$Script:EndPointFileFormat = 'json'

$Script:CmdletBindingParameters = @('Verbose','Debug','ErrorAction','WarningAction','InformationAction','ErrorVariable','WarningVariable','InformationVariable','OutVariable','OutBuffer','PipelineVariable')

#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files.
Foreach ($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $Public.Basename