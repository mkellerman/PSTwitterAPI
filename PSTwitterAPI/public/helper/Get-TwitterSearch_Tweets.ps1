function Get-TwitterSearch_Tweets {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET search/tweets

    .PARAMETER all
    Will handle the paging and return all.
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true, Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [system.string]
        $q,

        [Parameter(Mandatory = $false)]
        [system.string]
        $geocode,

        [Parameter(Mandatory = $false)]
        [system.string]
        $lang,

        [Parameter(Mandatory = $false)]
        [system.string]
        $locale,

        [Parameter(Mandatory = $false)]
        [system.string]
        $result_type = 'recent', #mixed/recent/popular

        [Parameter(Mandatory = $false)]
        [int]
        $count = 100,

        [Parameter(Mandatory = $false)]
        [datetime]
        $until,

        [Parameter(Mandatory = $false)]
        [int64]
        $since_id,

        [Parameter(Mandatory = $false)]
        [int64]
        $max_id,

        [Parameter(Mandatory = $false)]
        [boolean]
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended',

        [Parameter(Mandatory = $false)]
        [switch]
        $all

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "search/tweets"

        [hashtable]$Parameters    = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }
                    $Parameters.Remove('all')

        If ($all.IsPresent) { # Overide if we want to get all
            $Parameters.result_type = 'recent'
            $Parameters.count = 100
        }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.statuses }

        While (($all.IsPresent) -and ($Results)) {

            $Parameters.max_id = $Results.statuses.id | Sort-Object | Select-Object -First 1 | ForEach-Object { [int64]$_ - 1 }

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.statuses }

        }

    }

}