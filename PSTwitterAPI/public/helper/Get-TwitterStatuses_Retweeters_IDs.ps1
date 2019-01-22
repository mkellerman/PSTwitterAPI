function Get-TwitterStatuses_Retweeters_IDs {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET statuses/retweeters/ids

    .PARAMETER all
    Will handle the paging and return all.
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true, Position=0,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [int64]
        $id,

        [Parameter(Mandatory = $false)]
        [int64]
        $cursor,

        [Parameter(Mandatory = $false)]
        [boolean]
        $stringify_ids,

        [Parameter(Mandatory = $false)]
        [switch]
        $all

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "retweeters/ids"

        [hashtable]$Parameters    = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }
                    $Parameters.Remove('all')

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }

        While (($all.IsPresent) -and ($Results.next_cursor)) {

            $Parameters.cursor = $Results.next_cursor

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }

        }

    }

}