
function Get-TwitterStatuses_ShowID {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET statuses/show/:id
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true, Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [int64]
        $id,

        [Parameter(Mandatory = $false)]
        [switch]
        $trim_user,

        [Parameter(Mandatory = $false)]
        [switch]
        $include_my_retweet,

        [Parameter(Mandatory = $false)]
        [switch]
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "statuses/show/:id"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

    }

}