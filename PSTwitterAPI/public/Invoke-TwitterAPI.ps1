function Invoke-TwitterAPI {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$Resource,
        [Parameter(Mandatory)]
        [string]$Method,
        [Parameter(Mandatory)]
        $Parameters,
        [Parameter(Mandatory=$false)]
        $OAuthSettings
    )

    If (-Not($OAuthSettings)) {
        $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource
    }

    $OAuthParameters_Params = @{}
    $OAuthParameters_Params['ApiKey'] = $OAuthSettings.ApiKey
    $OAuthParameters_Params['ApiSecret'] = $OAuthSettings.ApiSecret
    $OAuthParameters_Params['AccessToken'] = $OAuthSettings.AccessToken
    $OAuthParameters_Params['AccessTokenSecret'] = $OAuthSettings.AccessTokenSecret
    $OAuthParameters_Params['Method'] = $Method
    $OAuthParameters_Params['Resource'] = $Resource
    $OAuthParameters_Params['Parameters'] = $Parameters
    $OAuthParameters = Get-OAuthParameters @OAuthParameters_Params

    $RestMethod_Params = @{}
    $RestMethod_Params['Uri'] = $OAuthParameters.endpoint_url
    $RestMethod_Params['Method'] = $OAuthParameters.endpoint_method
    $RestMethod_Params['Headers'] = @{ 'Authorization' = $OAuthParameters.endpoint_authorization }
    $RestMethod_Params['ContentType'] = "application/x-www-form-urlencoded"
    Invoke-RestMethod @RestMethod_Params

}