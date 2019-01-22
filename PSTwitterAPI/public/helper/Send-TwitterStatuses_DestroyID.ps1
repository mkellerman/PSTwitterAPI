

function Send-TwitterStatuses_DestroyID {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for POST statuses/destroy/:id

    .DESCRIPTION
    Destroys the status specified by the required ID parameter. The authenticating user must be the author of the specified status. Returns the destroyed status if successful.

    .LINK
    https://dev.twitter.com/rest/reference/post/statuses/destroy/%3Aid
#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true, Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [int64]
        $id,

        [Parameter(Mandatory = $false)]
        [switch]
        $trim_user

    )

    Begin {

        [string]$Method   = "POST"
        [string]$Resource = "statuses/destroy/:id"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

    }

}
