function Send-TwitterStatuses_UnretweetID {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for POST statuses/unretweet/:id
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true, Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [int64]
        $id,

        [Parameter(Mandatory = $false)]
        [switch]
        $trim_user

    )

    Begin {

        [string]$Method   = "POST"
        [string]$Resource = "statuses/unretweet/:id"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

    }

}
