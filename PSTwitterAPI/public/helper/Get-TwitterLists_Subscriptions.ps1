function Get-TwitterLists_Subscriptions {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET lists/list
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [Alias("id")]
        [int64]
        $user_id,

        [Parameter(Mandatory = $true,ParameterSetName="RequestByName", Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [system.string]
        $screen_name,

        [Parameter(Mandatory = $false)]
        [int]
        $count,

        [Parameter(Mandatory = $false)]
        [boolean]
        $reverse

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "lists/subscriptions"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }
                    $Parameters.Remove('all')

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.lists }

        While (($all.IsPresent) -and ($Results.next_cursor)) {

            $Parameters.cursor = $Results.next_cursor

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_ }

        }

    }

}
