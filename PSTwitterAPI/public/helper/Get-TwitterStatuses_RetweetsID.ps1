function Get-TwitterStatuses_RetweetsID {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET statuses/retweets/:id
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]
    param (

        [Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [int64]
        $id,

        [Parameter(Mandatory = $false)]
        [int]
        $count,

        [Parameter(Mandatory = $false)]
        [switch]
        $trim_user,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "statuses/retweets/:id"

        [hashtable]$Parameters    = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

    }

}
