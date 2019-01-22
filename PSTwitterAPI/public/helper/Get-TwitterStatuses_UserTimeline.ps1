function Get-TwitterStatuses_UserTimeline {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET statuses/user_timeline

    .PARAMETER all
    Will handle the paging and return all.
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]
    param (

        [Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [Alias("id")]
        [int64]
        $user_id,

        [Parameter(Mandatory = $true,ParameterSetName="RequestByName", Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [system.string]
        $screen_name,

        [Parameter(Mandatory = $false)]
        [int64]
        $since_id,

        [Parameter(Mandatory = $false)]
        [int]
        $count,

        [Parameter(Mandatory = $false)]
        [int64]
        $max_id,

        [Parameter(Mandatory = $false)]
        [boolean]
        $trim_user,

        [Parameter(Mandatory = $false)]
        [boolean]
        $exclude_replies,

        [Parameter(Mandatory = $false)]
        [boolean]
        $contributor_details,

        [Parameter(Mandatory = $false)]
        [boolean]
        $include_rts,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended',

        [Parameter(Mandatory = $false)]
        [switch]
        $all

    )

    Begin {

        [string]$Method    = "GET"
        [string]$Resource  = "statuses/user_timeline"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }
                    $Parameters.Remove('all')


        If ($all.IsPresent) { $Parameters.count = 200 } # Overide if we want to get all

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | ForEach { $_ }

        if (($all.IsPresent) -and ($Results.id)) {
            $Parameters.max_id = [int64]($Results.id | Measure-Object -Minimum | Select-Object -Expand Minimum) -1
            Get-TwitterStatuses_UserTimeline @Parameters -all
        }

    }

}