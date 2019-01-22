function Get-TwitterStatuses_Lookup {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET statuses/lookup
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true, Position=0,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [int64[]]
        $id,

        [Parameter(Mandatory = $false)]
        [boolean]
        $include_entities,

        [Parameter(Mandatory = $false)]
        [boolean]
        $trim_user,

        [Parameter(Mandatory = $false)]
        [boolean]
        $map,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "statuses/lookup"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

        $max_count = 100
        [int64[]]$ids = @()

    }

    Process {

        $ids += $id

        While ($ids.Count -ge $max_count) {

            If ($Parameters.id) { $Parameters.id = [string](($ids[$i..($i+$max_count-1)] | ? { $_ }) -Join ',') }

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

            [int64[]]$ids = $ids | Select-Object -Skip $max_count

        }

    }

    End {

        If ($ids.Count) {

            If ($Parameters.id) { $Parameters.id = [string](($ids | ? { $_ }) -Join ',') }

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

        }

    }

}