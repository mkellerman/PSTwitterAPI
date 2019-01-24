# $ApiResources = Get-Content ".\twitter_api.json" | ConvertFrom-Json
# $ValidResources = $ApiResources | Where-Object { $_.ReferenceProperties.ResourceUrl -Match '.json$' }

ForEach ($ApiResource in $ValidResources) {

$Verb = If ($ApiResource.Method -eq 'GET') { 'Get' } Else { 'Send' }
$ResourceName = (Get-Culture).TextInfo.ToTitleCase($ApiResource.Resource.Replace("/"," ")).Trim() -Split " "
$FunctionName = "${Verb}-Twitter" + $ResourceName[0] + "_" + ($ResourceName[1..9] -Join "")
$FunctionParameters = "Param([string]`$$($ApiResource.ReferenceProperties.Parameters.Name -Join ", [string]`$"))"

@"
function ${FunctionName} {

    [CmdletBinding()]
    ${functionParameters}
    Begin {

        [string]`$Method   = "$($ApiResource.Method)"
        [string]`$Resource = "$($ApiResource.Resource)"

        [hashtable]`$Parameters = `$PSBoundParameters
                   `$CmdletBindingParameters | % { `$Parameters.Remove(`$_) }

    }
    Process {

        If (-Not `$OAuthSettings) { `$OAuthSettings = Get-TwitterOAuthSettings -Resource `$Resource }
        Invoke-TwitterAPI -Resource `$Resource -Method `$Method -Parameters `$Parameters -OAuthSettings `$OAuthSettings

    }
    End {

    }
}
"@ | Set-Content ".\APIHelper\helper\${FunctionName}.ps1"

}
