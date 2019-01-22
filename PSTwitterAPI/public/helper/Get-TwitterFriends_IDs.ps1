function Get-TwitterFriends_IDs {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET friends/ids

    .PARAMETER all
    Will handle the paging and return all.
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]
    param (

        [Parameter(Mandatory = $true,
                    ParameterSetName="RequestById", Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [Alias("id")]
        [int64]
        $user_id,

        [Parameter(Mandatory = $true,
                    ParameterSetName="RequestByName", Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [system.string]
        $screen_name,

        [Parameter(Mandatory = $false)]
        [int64]
        $cursor,

        [Parameter(Mandatory = $false)]
        [boolean]
        $stringify_ids,

        [Parameter(Mandatory = $false)]
        [int]
        $count,

        [Parameter(Mandatory = $false)]
        [switch]
        $all

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "friends/ids"

        [hashtable]$Parameters = $PSBoundParameters
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