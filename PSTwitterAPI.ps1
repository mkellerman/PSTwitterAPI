$ErrorActionPreference = 'Stop'

$EndPointBaseUrl = 'https://api.twitter.com/1.1'
$EndPointFileFormat = 'json'

function Add-TwitterOauthSettings {

    Param(
        $ApiKey,
        $ApiSecret,
        $AccessToken,
        $AccessTokenSecret,
        [switch]$PassThru,
        [switch]$Force
    )
    Begin {
        If (-Not(Test-Path Variable:Global:TwitterOAuth)) {
            $Global:____TwitterOAuthSettings = [System.Collections.ArrayList]@()
        }
    }
    Process {

        If ($OAuthSettings = Get-OAuthSettings -AccessToken $AccessToken -ErrorAction SilentlyContinue) {
            If ($Force) {
                [void]$Global:____TwitterOAuthSettings.Remove($OAuthSettings)
            } Else {
                Throw "OAuthSettings with AccessToken '${AccessToken}' already exists."
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

        [void]$Global:____TwitterOAuthSettings.Add($OAuthSettings)

        If ($PassThru) { $OAuthSettings }

    }

}


function Get-TwitterOauthSettings {

    [CmdletBinding()]  
    Param($EndPoint, $AccessToken)

    If ($EndPoint) {
    
        $AccessToken = $Global:____TwitterOAuthSettings.RateLimitStatus | 
                        Where-Object { $_.resource -eq $EndPoint } | 
                        Sort-Object @{expression="remaining";Descending=$true}, @{expression="reset";Ascending=$true} | 
                        Select-Object -First 1 -Expand AccessToken
    
                    }

    If ($AccessToken) {

        $TwitterOAuthSettings = $Global:____TwitterOAuthSettings.Where({$_.AccessToken -eq $AccessToken}) | Select-Object -First 1
    
    } Else {
    
        $TwitterOAuthSettings = $Global:____TwitterOAuthSettings | Get-Random
    
    }
    
    $OAuthSettings = @{
        ApiKey = $TwitterOAuthSettings.ApiKey
        ApiSecret = $TwitterOAuthSettings.ApiSecret
        AccessToken = $TwitterOAuthSettings.AccessToken
        AccessTokenSecret = $TwitterOAuthSettings.AccessTokenSecret
    }
    Return $OAuthSettings

}

function ConvertFrom-RateLimitStatus ($RateLimitStatus) {

    $Eposh = Get-Eposh

    $RateLimitStatus.resources.PSObject.Properties | ForEach { 
        $_.value | ForEach { 
            $_.PSObject.Properties | ForEach { 
                $_ | Select-Object @{ n='accesstoken'; e={ $RateLimitStatus.rate_limit_context.access_token }}, @{ n='resource'; e={ $_.name }}, @{ n='limit'; e={ $_.value.limit }}, @{ n='remaining'; e={ $_.value.remaining }}, @{ n='reset'; e={ $_.value.reset }} 
            } 
        } 
    } 

    "/statuses/update" | Select-Object @{ n='accesstoken'; e={ $RateLimitStatus.rate_limit_context.access_token }}, @{ n='resource'; e={ $_ }}, @{ n='limit'; e={ 15 }}, @{ n='remaining'; e={ 15 }}, @{ n='reset'; e={ $Eposh }} 

}

function Get-Eposh {
    Param ([int]$Eposh) 
    Process {
        $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
        If ($Eposh) { [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($Eposh)) } 
                Else { [int]([DateTime]::UtcNow - $unixEpochStart).TotalSeconds }
    }
}


function Get-TwitterOauthParameters {

    [OutputType('System.Management.Automation.PSCustomObject')]
	 Param($ApiKey, $ApiSecret, $AccessToken, $AccessTokenSecret, $Verb, $EndPoint, $Parameters)
     
     Process{

         Try {

    	    ## Generate a random 32-byte string. I'm using the current time (in seconds) and appending 5 chars to the end to get to 32 bytes
	        ## Base64 allows for an '=' but Twitter does not.  If this is found, replace it with some alphanumeric character
	        $OauthNonce = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes("$([System.DateTime]::Now.Ticks.ToString())12345"))).Replace('=', 'g')
    	    ## Find the total seconds since 1/1/1970 (epoch time)
		    $EpochTimeNow = [System.DateTime]::UtcNow - [System.DateTime]::ParseExact("01/01/1970", "dd'/'MM'/'yyyy", $null)
		    $OauthTimestamp = [System.Convert]::ToInt64($EpochTimeNow.TotalSeconds).ToString();
            
            ## URLEncode the parameters
            foreach($Param in $($Parameters.Keys)){
                $Parameters[$Param] = [System.Net.WebUtility]::UrlEncode($Parameters[$Param]).Replace('+','%20').Replace('!','%21') 
            }

            ## Build the enpoint url
            $EndPointUrl = "${EndPointBaseUrl}${EndPoint}.${EndPointFileFormat}?"
            $Parameters.GetEnumerator() | Sort-Object Name | % { $EndPointUrl += "$($_.Key)=$([System.Net.WebUtility]::UrlEncode($_.Value).Replace('+','%20').Replace('!','%21') )&" }
            $EndPointUrl = $EndPointUrl.TrimEnd('&')

            ## Build the signature
            $SignatureBase = "$([System.Uri]::EscapeDataString("${EndPointBaseUrl}${EndPoint}.${EndPointFileFormat}"))&"
			$SignatureParams = @{
				'oauth_consumer_key' = $ApiKey;
				'oauth_nonce' = $OauthNonce;
				'oauth_signature_method' = 'HMAC-SHA1';
				'oauth_timestamp' = $OauthTimestamp;
				'oauth_token' = $AccessToken;
				'oauth_version' = '1.0';
            }
	        $Parameters.Keys | ForEach-Object { $SignatureParams.Add($_ , $Parameters.Item($_)) }

			## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &
			## Remove the URL encoded & at the end and prepend the necessary 'POST&' verb to the front
			$SignatureParams.GetEnumerator() | Sort-Object Name | ForEach-Object { $SignatureBase += [System.Uri]::EscapeDataString("$($_.Key)=$($_.Value)&") }

            $SignatureBase = $SignatureBase.Substring(0,$SignatureBase.Length-3)
			$SignatureBase = $Verb+'&' + $SignatureBase
			
			## Create the hashed string from the base signature
			$SignatureKey = [System.Uri]::EscapeDataString($ApiSecret) + "&" + [System.Uri]::EscapeDataString($AccessTokenSecret);
			
			$hmacsha1 = new-object System.Security.Cryptography.HMACSHA1;
			$hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($SignatureKey);
			$OauthSignature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($SignatureBase)));
			
			## Build the authorization headers using most of the signature headers elements.  This is joining all of the 'Key=Value' elements again
			## and only URL encoding the Values this time while including non-URL encoded double quotes around each value
			$AuthorizationParams = $SignatureParams
			$AuthorizationParams.Add('oauth_signature', $OauthSignature)
            $AuthorizationParams.Add('endpoint_method', $Verb)
            $AuthorizationParams.Add('endpoint_url', $EndPointUrl)

            Write-Verbose "Using authorization params '$AuthorizationParams'"			
            Return $AuthorizationParams

        } Catch {
			Write-Error $_.Exception.Message
		}

    }

}

function Get-TwitterOauthString ($OauthParameters) {

    $TwitterOauthString = 'OAuth '
    $OauthParameters.GetEnumerator() | Where-Object { $_.Name -notMatch "endpoint_" } | Sort-Object Name | 
                                       ForEach-Object { $TwitterOauthString += $_.Key + '="' + [System.Uri]::EscapeDataString($_.Value) + '", ' }
    $TwitterOauthString = $TwitterOauthString.TrimEnd(', ')
    
    Write-Verbose "Using authorization string '$TwitterOauthString'"			
    Return $TwitterOauthString
            
}

function Invoke-TwitterRestMethod {

    Param(
        [Parameter(Mandatory)]
        [string]$EndPoint,
        [Parameter(Mandatory)]
        [string]$Verb,
        [Parameter(Mandatory)]
        $Parameters,
        [Parameter(Mandatory=$false)]
        $OAuthSettings
    )

    If (-Not($OAuthSettings)) {
        $OAuthSettings = Get-TwitterOauthSettings -EndPoint $EndPoint
    }
    
    $OAuthParameters_Params = @{}
    $OAuthParameters_Params['ApiKey'] = $OAuthSettings.ApiKey
    $OAuthParameters_Params['ApiSecret'] = $OAuthSettings.ApiSecret
    $OAuthParameters_Params['AccessToken'] = $OAuthSettings.AccessToken
    $OAuthParameters_Params['AccessTokenSecret'] = $OAuthSettings.AccessTokenSecret
    $OAuthParameters_Params['Verb'] = $Verb
    $OAuthParameters_Params['EndPoint'] = $EndPoint
    $OAuthParameters_Params['Parameters'] = $Parameters
    $OAuthParameters = Get-OAuthParameters @OAuthParameters_Params

    $OAuthString = Get-OAuthString -OAuthParameters $OAuthParameters

    $RestMethod_Params = @{}
    $RestMethod_Params['Uri'] = $OAuthParameters.endpoint_url
    $RestMethod_Params['Method'] = $OAuthParameters.endpoint_method
    $RestMethod_Params['Headers'] = @{ 'Authorization' = $OAuthString }
    $RestMethod_Params['ContentType'] = "application/x-www-form-urlencoded"
    Invoke-RestMethod @RestMethod_Params

}

function Get-TwitterApplication_RateLimitStatus {
    <#
              .SYNOPSIS
               Mimics Twitter API parameters for GET application/rate_limit_status
    #>
    [CmdletBinding()]  
    param (

        [Parameter(Mandatory = $false)]
        [system.string]
        $resources,

        [hashtable]
        $OAuthSettings

    )

    Begin {
        
        $Verb    = "GET"
        $EndPoint = "/application/rate_limit_status"
        
        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('OAuthSettings')
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-OAuthSettings -EndPoint $EndPoint }
        Invoke-TwitterRestMethod -EndPoint $EndPoint -Verb $Verb -Parameters $Parameters -OAuthSettings $OAuthSettings

    }

}

#Add-TwitterOauthSettings -ApiKey 'WjQpjNLrDtv9suRHrFFC8BAzt' -ApiSecret 'NpPbkhzfh1Q2SitEdJz1Rsb3fsejYXjvDGrIOLLYoyVJkVZwIH' -AccessToken '2840793927-NHWRTuRtSlH5NxeXAn1y5aGhOiBsKFMxkfDUPkO' -AccessTokenSecret 'zs41fFB7WIdEBQRjPPs93mCPEUqJQIipQgmLdmfM7yDrH' -Force
#Add-TwitterOauthSettings -ApiKey 'S13ockNsRbPL8qtZrKvC8cTRF' -ApiSecret '3CeVLOZ2xBbX9bBLsWMIKx86H5BceALyegFTDz6B7eX6WbF1vK' -AccessToken '2840793927-MF264l29r51BFpDTxseZblS3G5w2QwXcYKpAdjL' -AccessTokenSecret 'EXCWPHzM3E3X5kH6vXDpdVeRofaxuYMLA5xDbIMIkbRr8' -Force
#Add-TwitterOauthSettings -ApiKey 'wfGbYD5FuF2JBOyFlg2UZI0iv' -ApiSecret 'SVNY6ipzhnR3TMpEXNFh3AkQ8nc906i9snM5kPimNl7pEE5mBK' -AccessToken '2840793927-dRuGtppEVVY5HTr1dA9LfymH3GSSOnQ8E8PKvYD' -AccessTokenSecret 'WRPP7GxgrxXWUp6MaohhIMDigSssMa8t8l5UfLFaWron9' -Force
#Add-TwitterOauthSettings -ApiKey 'LgQIcfUE13rTfSyaDQWmg4rVV' -ApiSecret '6bk3UOllBIiPRP3msXPnhWOUtmJy9bmQW5KIruV6pcYuowLBpm' -AccessToken '2840793927-zQsyQDl1IvC8SABb0WT5HMI2KSEbggkAqrYnxOi' -AccessTokenSecret 'FEyMy5dHhDmrzHb4vDUEjE9q62O1bKYhydY1l4j7CRBrS' -Force
#Add-TwitterOauthSettings -ApiKey 'g3RrecmY4VjXR2WCHsVlImJff' -ApiSecret 'f6A72rBvhIWYC77Y66sm4SRR4mulL1sKa2f20Ec7V137VDEjbY' -AccessToken '2840793927-u8XtAvaLfOh93WqOKqHm9nQPMzWyEyYAY8q9yX4' -AccessTokenSecret '4cfBzbZoblQCC8ZCqsHcx5O8ZF2lS5lIlAtSn7kHfGb9G' -Force

$Verb    = "GET"
$EndPoint = "/application/rate_limit_status"
$Parameters = @{ q = 'twitter' }

Invoke-TwitterRestMethod -EndPoint $EndPoint -Verb $Verb -Parameters $Parameters

