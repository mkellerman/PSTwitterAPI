function Send-TwitterStatuses_Update {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for POST statuses/update

    .DESCRIPTION
    Updates the authenticating user’s current status, also known as Tweeting.

    For each update attempt, the update text is compared with the authenticating user’s recent Tweets. Any attempt that would result in duplication will be blocked, resulting in a 403 error. Therefore, a user cannot submit the same status twice in a row.

    While not rate limited by the API a user is limited in the number of Tweets they can create at a time. If the number of updates posted by the user reaches the current allowed limit this method will return an HTTP 403 error.

    .LINK
    https://dev.twitter.com/rest/reference/post/statuses/destroy/%3Aid
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true, Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [string]
        $status,

        [Parameter(Mandatory = $false)]
        [int64]
        $in_reply_to_status_id,

        [Parameter(Mandatory = $false)]
        [switch]
        $possibly_sensitive,

        [Parameter(Mandatory = $false)]
        [double]
        $lat,

        [Parameter(Mandatory = $false)]
        [double]
        $long,

        [Parameter(Mandatory = $false)]
        [string]
        $place_id,

        [Parameter(Mandatory = $false)]
        [switch]
        $display_coordinates,

        [Parameter(Mandatory = $false)]
        [switch]
        $trim_user,

        [Parameter(Mandatory = $false)]
        [int64[]]
        $media_ids

    )

    Begin {


        [string]$Method   = "POST"
        [string]$Resource = "statuses/update"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

    }

}