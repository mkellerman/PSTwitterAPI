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

    begin{
        $flagPath = "$(${function:Get-TwitterOAuthSettings}.module.modulebase)/private/flag.cli.xml"
        $AZDO = Test-Path -Path $flagPath -ErrorAction SilentlyContinue
    }

    Process {

        If ($OAuthSettings = Get-TwitterOAuthSettings -AccessToken $AccessToken -ErrorAction SilentlyContinue) {
            If ($Force) {
                if(-not($AZDO)){
                    [void]$Script:OAuthCollection.Remove($OAuthSettings)
                }
                else{
                    Write-Verbose "Force param supplied but no OAuth settings were found. Skipping removal due to AZDO condition."
                }
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

        $RateLimitStatus = Get-TwitterApplication_RateLimitStatus
        If ($RateLimitStatus.rate_limit_context.access_token -ne $AccessToken) { Throw 'RateLimitStatus was returned for the wrong AccessToken.'}
        
        $OAuthSettings['RateLimitStatus'] = ConvertFrom-RateLimitStatus -RateLimitStatus $RateLimitStatus

        if($AZDO){
            #Workaround for Azure DevOps
            #Changing default behaviour to cope with build agent variable scoping
            #API creds will now be stored in clixml file instead of script variable
            $OAuthSettings | Export-CliXML -Path "$(${function:Set-TwitterOAuthSettings}.module.modulebase)\private\Oauthfile.cli.xml"
        }
        else{
            [void]$Script:OAuthCollection.Add($OAuthSettings)
        }

        If ($PassThru) { $OAuthSettings }

    }

}