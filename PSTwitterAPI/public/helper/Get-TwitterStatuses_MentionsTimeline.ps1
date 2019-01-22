function Get-TwitterStatuses_MentionsTimeline {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET statuses/mentions_timeline
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $false)]
        [int]
        $count,

        [Parameter(Mandatory = $false)]
        [int64]
        $since_id,

        [Parameter(Mandatory = $false)]
        [int64]
        $max_id,

        [Parameter(Mandatory = $false)]
        [boolean]
        $trim_user,

        [Parameter(Mandatory = $false)]
        [boolean]
        $contributor_details,

        [Parameter(Mandatory = $false)]
        [boolean]
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {

        [string]$Method    = "GET"
        [string]$Resource  = "statuses/mentions_timeline"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings

    }

}