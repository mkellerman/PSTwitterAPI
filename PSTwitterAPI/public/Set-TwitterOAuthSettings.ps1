function Set-TwitterOAuthSettings {

    [CmdletBinding()]
    Param(
        $ApiKey,
        $ApiSecret,
        $AccessToken,
        $AccessTokenSecret,
        [switch]$PassThru,
        [switch]$Force
    )
    Process {

        If ($OAuthSettings = Get-TwitterOAuthSettings -AccessToken $AccessToken -ErrorAction SilentlyContinue) {
            If ($Force) {
                [void]$Script:OAuthCollection.Remove($OAuthSettings)
            } Else {
                Write-Warning "OAuthSettings with AccessToken '${AccessToken}' already exists."
            }
        }

        $OAuthSettings = @{
            ApiKey = $ApiKey
            ApiSecret = $ApiSecret
            AccessToken = $AccessToken
            AccessTokenSecret = $AccessTokenSecret
        }

        $RateLimitStatus = Get-TwitterApplication_RateLimitStatus -OAuthSettings $OAuthSettings
        $OAuthSettings['RateLimitStatus'] = ConvertFrom-RateLimitStatus -RateLimitStatus $RateLimitStatus

        [void]$Script:OAuthCollection.Add($OAuthSettings)
        If ($PassThru) { $OAuthSettings }

    }

}