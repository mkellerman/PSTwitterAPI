﻿function Get-TwitterDirectMessages_EventsList {
<#
.SYNOPSIS
    Sending and receiving events

.DESCRIPTION
    GET direct_messages/events/list
    
    Returns all Direct Message events (both sent and received) within the last 30 days. Sorted in reverse-chronological order.

.PARAMETER count (optional)
    

.PARAMETER cursor (optional)
    

.NOTES
    This helper function was generated by the information provided here:
    https://developer.twitter.com/en/docs/direct-messages/sending-and-receiving/api-reference/list-events

#>
    [CmdletBinding()]
    Param(
        [string]$count,
        [string]$cursor
    )
    Begin {

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | ForEach-Object { $Parameters.Remove($_) }

        [string]$Method      = 'GET'
        [string]$Resource    = '/direct_messages/events/list'
        [string]$ResourceUrl = 'https://api.twitter.com/1.1/direct_messages/events/list.json'

    }
    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Method $Method -ResourceUrl $ResourceUrl -Resource $Resource -Parameters $Parameters -OAuthSettings $OAuthSettings

    }
    End {

    }
}