function Get-TwitterUser_Lookup {
<#
    .SYNOPSIS
    Mimics Twitter API parameters for GET user/lookup
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]
    param (

        [Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [Alias("id")]
        [int64[]]
        $user_id,

        [Parameter(Mandatory = $true,ParameterSetName="RequestByName", Position=0,
                    ValueFromPipelineByPropertyName=$true)]
        [system.string[]]
        $screen_name,

        [Parameter(Mandatory = $false)]
        [boolean]
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "users/lookup"

        [hashtable]$Parameters = $PSBoundParameters
                    $CmdletBindingParameters | % { $Parameters.Remove($_) }

        $max_count = 100
        [int64[]]$user_ids = @()
        [system.string[]]$screen_names = @()

    }

    Process {

        $user_ids += $user_id
        $screen_names += $screen_name

        [int]$NCount = $user_ids.count + $screen_names.count

        While ($NCount -ge $max_count) {

            If ($Parameters.user_id)     { $Parameters.user_id     = [string](($user_ids[$i..($i+$max_count-1)] | ? { $_ }) -Join ',') }
            If ($Parameters.screen_name) { $Parameters.screen_name = [string](($screen_names[$i..($i+$max_count-1)] | ? { $_ }) -Join ',') }

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

            [int64[]]$user_ids = $user_ids | Select-Object -Skip $max_count
            [system.string[]]$screen_names = $screen_names | Select-Object -Skip $max_count

            [int]$NCount = $user_ids.count + $screen_names.count

        }

    }

    End {

        If ($NCount) {

            If ($Parameters.user_id)     { $Parameters.user_id     = [string](($user_ids | ? { $_ }) -Join ',') }
            If ($Parameters.screen_name) { $Parameters.screen_name = [string](($screen_names | ? { $_ }) -Join ',') }

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

        }

    }

}
