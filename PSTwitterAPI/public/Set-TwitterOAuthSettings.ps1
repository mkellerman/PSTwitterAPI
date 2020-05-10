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

        If ($OAuthSettings = Get-TwitterOAuthSettings -AccessToken $AccessToken -Quiet) {
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
        If ($RateLimitStatus.rate_limit_context.access_token -ne $AccessToken) { Throw 'RateLimitStatus was returned for the wrong AccessToken.'}
        
        $OAuthSettings['RateLimitStatus'] = ConvertFrom-RateLimitStatus -RateLimitStatus $RateLimitStatus

        [void]$Script:OAuthCollection.Add($OAuthSettings)

        If ($PassThru) { $OAuthSettings }

    }

}