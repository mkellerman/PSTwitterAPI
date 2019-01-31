function Get-TwitterOAuthSettings {

    [CmdletBinding()]
    Param($Resource, $AccessToken)

    If ($Resource) {

        $AccessToken = $Script:OAuthCollection.RateLimitStatus |
                       Where-Object { $_.resource -eq "/$Resource" } |
                       Sort-Object @{expression="remaining";Descending=$true}, @{expression="reset";Ascending=$true} |
                       Select-Object -First 1 -Expand AccessToken

    }

    If ($AccessToken) {

        $OAuthSettings = $Script:OAuthCollection.Where({$_.AccessToken -eq $AccessToken}) | Select-Object -First 1

    } Else {

        $OAuthSettings = $Script:OAuthCollection | Get-Random

    }

    If ($OAuthSettings) {
        $OAuthSettings = @{
            ApiKey = $OAuthSettings.ApiKey
            ApiSecret = $OAuthSettings.ApiSecret
            AccessToken = $OAuthSettings.AccessToken
            AccessTokenSecret = $OAuthSettings.AccessTokenSecret
        }
    } Else {
        $OAuthSettings = $null
        Throw "No OAuthSettings was found. Use 'Set-TwitterOAuthSettings' to set PSTwitterAPI ApiKey & Token."
    }

    Write-Verbose "Using AccessToken '$($OAuthSettings.AccessToken)'"
    Return $OAuthSettings

}