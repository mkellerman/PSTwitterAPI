function Send-TwitterStatuses_RetweetID {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET statuses/retweet/:id
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
        [string]$Resource = "statuses/retweet/:id"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

    }

}