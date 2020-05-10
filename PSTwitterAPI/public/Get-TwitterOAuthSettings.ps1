function Get-TwitterOAuthSettings {

    [CmdletBinding()]
    Param($Resource, $AccessToken, [switch]$Quiet)

    If ($Resource) {

        # Get the next available OAuth with available resources
        $RateLimitStatus =  $Script:OAuthCollection.RateLimitStatus |
                            Where-Object { $_.resource -eq "$Resource" } |
                            Sort-Object @{expression="remaining";Descending=$true}, @{expression="reset";Ascending=$true} |
                            Select-Object -First 1 | 
                            ForEach-Object { $_.remaining += -1;  Return $_ }
        
        Write-Verbose "resource: $($RateLimitStatus.resource), limit: $($RateLimitStatus.limit), remaining: $($RateLimitStatus.remaining), reset: $($RateLimitStatus.reset)"

        $AccessToken = $RateLimitStatus.AccessToken

        If ($RateLimitStatus.remaining -lt 0) {

            # Refresh the RateLimitStatus so we throttle an accurate value
            $OAuthSettings = $Script:OAuthCollection.Where({$_.AccessToken -eq $AccessToken}) | Select-Object -First 1
            $OAuthSettings = Set-TwitterOAuthSettings -ApiKey $OAuthSettings.ApiKey -ApiSecret $OAuthSettings.ApiSecret -AccessToken $OAuthSettings.AccessToken -AccessTokenSecret $OAuthSettings.AccessTokenSecret -PassThru -Force

            $RateLimitStatus  = $OAuthSettings.RateLimitStatus | Where-Object { $_.resource -eq "$Resource" } | 
                                ForEach-Object { $_.remaining += -1;  Return $_ }

            If ($RateLimitStatus.remaining -lt 0) {

                # Throttle... you're going way too fast cowboy!
                $SleepSeconds = $RateLimitStatus.reset - (Get-Eposh).TotalSeconds + 1
                Write-Warning "Throttling for ${SleepSeconds} seconds."
                Start-Sleep -Seconds $SleepSeconds 

            }

        }


    }


    If ($AccessToken) {
        $OAuthSettings = $Script:OAuthCollection.Where({$_.AccessToken -eq $AccessToken}) | Select-Object -First 1
    } Else {
        $OAuthSettings = $Script:OAuthCollection | Select-Object -First 1
    }


    If ($OAuthSettings) {
        Write-Verbose "Using AccessToken '$($OAuthSettings.AccessToken)'"
        $OAuthSettings = @{
            ApiKey = $OAuthSettings.ApiKey
            ApiSecret = $OAuthSettings.ApiSecret
            AccessToken = $OAuthSettings.AccessToken
            AccessTokenSecret = $OAuthSettings.AccessTokenSecret
        }
        Return $OAuthSettings
    }

    If ($Quiet.IsPresent -eq $false) {
        Throw "No OAuthSettings was found. Use 'Set-TwitterOAuthSettings' to set PSTwitterAPI ApiKey & Token."
    }

}
