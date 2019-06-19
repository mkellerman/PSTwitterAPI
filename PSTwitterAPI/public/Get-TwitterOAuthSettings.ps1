function Get-TwitterOAuthSettings {

    [CmdletBinding()]
    Param($Resource, $AccessToken)

    #Check for pipeline flag file
    $flagPath = "$(${function:Get-TwitterOAuthSettings}.module.modulebase)/private/flag.cli.xml"
    $AZDO = Test-Path -Path $flagPath -ErrorAction SilentlyContinue

    If ($Resource) {
        if($AZDO){
            #Changing default behaviour to cope with Azure DevOps build agent variable scoping
            #API creds will now be stored in clixml file instead of script variable
            $OAuthSettings = Import-CliXML -Path "$(${function:Set-TwitterOAuthSettings}.module.modulebase)/private/Oauthfile.cli.xml"
            $AccessToken = $OAuthSettings.RateLimitStatus
        }
        else{
            $AccessToken = $Script:OAuthCollection.RateLimitStatus
        }

        $AccessToken = $AccessToken | Where-Object { $_.resource -eq "/$Resource" } |
            Sort-Object @{expression="remaining";Descending=$true}, @{expression="reset";Ascending=$true} |
            Select-Object -First 1 -Expand AccessToken
    }

    If ($AccessToken) {
        if($AZDO){
            $OAuthSettings = $OAuthSettings.Where({$_.AccessToken -eq $AccessToken}) | Select-Object -First 1
        }
        else{
            $OAuthSettings = $Script:OAuthCollection.Where({$_.AccessToken -eq $AccessToken}) | Select-Object -First 1
        }

    } Else {
        if($AZDO){
            $OAuthSettings = $OAuthSettings | Get-Random
        }
        else{
            $OAuthSettings = $Script:OAuthCollection | Get-Random
        }
    }

    If ($OAuthSettings) {
        Write-Verbose "Using AccessToken '$($OAuthSettings.AccessToken)'"
        $OAuthSettings = @{
            ApiKey = $OAuthSettings.ApiKey
            ApiSecret = $OAuthSettings.ApiSecret
            AccessToken = $OAuthSettings.AccessToken
            AccessTokenSecret = $OAuthSettings.AccessTokenSecret
        }
    } Else {
        $OAuthSettings = $null

        $message =  "No OAuthSettings was found. Use 'Set-TwitterOAuthSettings' to set PSTwitterAPI ApiKey & Token."
        if($AZDO){
            Write-Verbose $message
        }
        else{
            Throw $message
        }
    }

    Return $OAuthSettings

}