<#	
	===========================================================================
	 Created on:   	1/19/2019 9:00 PM
	 Created by:   	Marc R Kellerman
     Filename:     	PSTwitterAPI.psm1
	-------------------------------------------------------------------------
	 Module Name: PSTwitterAPI
	 Description: Provides a command to call any Twitter REST API,
                  a command to access any of the Twitter Streaming APIs, 
                  and a command to upload media to Twitter.

                  Added functions to handle the RateLimitStatus 
                  Added functionality to handle Multiple APIKeys
                  Added some functions to replicate Twitter API calls

     Setup your Twitter API Keys :
         $OAuths = @{ 'ApiKey'            = 'yourapikey'; 
                      'ApiSecret'         = 'yourapisecretkey'; 
                      'AccessToken'       = 'yourapiaccesstoken'; 
                      'AccessTokenSecret' = 'yourapitokensecret' }	
         
         You can have more than one $OAuths... :)

     Original Get-OAuth code by :
         Shannon Conley & Mehmet Kaya
         https://github.com/MeshkDevs/InvokeTwitterAPIs
                  
     List of Twitter REST APIs:
     https://dev.twitter.com/rest/public

     Twitter Streamings APIs Info:
     https://dev.twitter.com/streaming/overview

     To use these commands, you must obtain a Twitter API key, API secret, 
     access token and access token secret
     https://twittercommunity.com/t/how-to-get-my-api-key/7033

     This was developed using Windows PowerShell 4.0.
                  
	===========================================================================
#>

if (!$Global:Twitter_OAuths) {

[array]$Global:Twitter_OAuths = @()
Write-Host @'

Please set your $Twitter_OAuths settings:

$Twitter_OAuths = @{ 'ApiKey'            = 'yourapikey'; 
             'ApiSecret'         = 'yourapisecretkey'; 
             'AccessToken'       = 'yourapiaccesstoken'; 
             'AccessTokenSecret' = 'yourapitokensecret' }	

'@ -ForegroundColor Yellow

}
[bool]$Global:tweet_mode_extended = $true

Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

function Get-Eposh {
    Param ([int]$Eposh) 
    Process {
        $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
        If ($Eposh) { [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($Eposh)) } 
                Else { [int]([DateTime]::UtcNow - $unixEpochStart).TotalSeconds }
    }
}

function Get-OAuth {
     <#
          .SYNOPSIS
           This function creates the authorization string needed to send a POST or GET message to the Twitter API

          .PARAMETER AuthorizationParams
           This hashtable should the following key value pairs
           HttpEndPoint - the twitter resource url [Can be found here: https://dev.twitter.com/rest/public]
           RESTVerb - Either 'GET' or 'POST' depending on the action
           Params - A hashtable containing the rest parameters (key value pairs) associated that method
           OAuthSettings - A hashtable that must contain only the following keys and their values (Generate here: https://dev.twitter.com/oauth)
                       ApiKey 
                       ApiSecret 
		               AccessToken
	                   AccessTokenSecret
          .LINK
           This function evolved from code found in Adam Betram's Get-OAuthAuthorization function in his MyTwitter module.
           The MyTwitter module can be found here: https://gallery.technet.microsoft.com/scriptcenter/Tweet-and-send-Twitter-DMs-8c2d6f0a
           Adam Betram's blogpost here: http://www.adamtheautomator.com/twitter-powershell/ provides a detailed explanation
           about how to generate an access token needed to create the authorization string 

          .EXAMPLE
            $OAuth = @{'ApiKey' = 'yourapikey'; 'ApiSecret' = 'yourapisecretkey';'AccessToken' = 'yourapiaccesstoken';'AccessTokenSecret' = 'yourapitokensecret'}	
            $Parameters = @{'q'='rumi'}
            $AuthParams = @{}
            $AuthParams.Add('HttpEndPoint', 'https://api.twitter.com/1.1/search/tweets.json')
            $AuthParams.Add('RESTVerb', 'GET')
            $AuthParams.Add('Params', $Parameters)
            $AuthParams.Add('OAuthSettings', $OAuth)
            $AuthorizationString = Get-OAuth -AuthorizationParams $AuthParams

          
     #>
    [OutputType('System.Management.Automation.PSCustomObject')]
	 Param($AuthorizationParams)
     process{
     try {

    	    ## Generate a random 32-byte string. I'm using the current time (in seconds) and appending 5 chars to the end to get to 32 bytes
	        ## Base64 allows for an '=' but Twitter does not.  If this is found, replace it with some alphanumeric character
	        $OauthNonce = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes("$([System.DateTime]::Now.Ticks.ToString())12345"))).Replace('=', 'g')
    	    ## Find the total seconds since 1/1/1970 (epoch time)
		    $EpochTimeNow = [System.DateTime]::UtcNow - [System.DateTime]::ParseExact("01/01/1970", "dd'/'MM'/'yyyy", $null)
		    $OauthTimestamp = [System.Convert]::ToInt64($EpochTimeNow.TotalSeconds).ToString();
        	## Build the signature
			$SignatureBase = "$([System.Uri]::EscapeDataString($AuthorizationParams.HttpEndPoint))&"
			$SignatureParams = @{
				'oauth_consumer_key' = $AuthorizationParams.OAuthSettings.ApiKey;
				'oauth_nonce' = $OauthNonce;
				'oauth_signature_method' = 'HMAC-SHA1';
				'oauth_timestamp' = $OauthTimestamp;
				'oauth_token' = $AuthorizationParams.OAuthSettings.AccessToken;
				'oauth_version' = '1.0';
			}
	        $AuthorizationParams.Params.Keys | % { $SignatureParams.Add($_ , [System.Net.WebUtility]::UrlEncode($AuthorizationParams.Params.Item($_)).Replace('+','%20').Replace('!','%21'))}
        
		 
			## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &
			## Remove the URL encoded & at the end and prepend the necessary 'POST&' verb to the front
			$SignatureParams.GetEnumerator() | Sort-Object name | foreach { $SignatureBase += [System.Uri]::EscapeDataString("$($_.Key)=$($_.Value)&") }

            $SignatureBase = $SignatureBase.Substring(0,$SignatureBase.Length-3)
			$SignatureBase = $AuthorizationParams.RESTVerb+'&' + $SignatureBase
			
			## Create the hashed string from the base signature
			$SignatureKey = [System.Uri]::EscapeDataString($AuthorizationParams.OAuthSettings.ApiSecret) + "&" + [System.Uri]::EscapeDataString($AuthorizationParams.OAuthSettings.AccessTokenSecret);
			
			$hmacsha1 = new-object System.Security.Cryptography.HMACSHA1;
			$hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($SignatureKey);
			$OauthSignature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($SignatureBase)));
			
			## Build the authorization headers using most of the signature headers elements.  This is joining all of the 'Key=Value' elements again
			## and only URL encoding the Values this time while including non-URL encoded double quotes around each value
			$AuthorizationParams = $SignatureParams
			$AuthorizationParams.Add('oauth_signature', $OauthSignature)
		
			
			$AuthorizationString = 'OAuth '
			$AuthorizationParams.GetEnumerator() | sort-Object name | foreach { $AuthorizationString += $_.Key + '="' + [System.Uri]::EscapeDataString($_.Value) + '", ' }
			$AuthorizationString = $AuthorizationString.TrimEnd(', ')
            Write-Verbose "Using authorization string '$AuthorizationString'"			
			$AuthorizationString

        }
        catch {
			Write-Error $_.Exception.Message
		}

     }

}

function Get-OAuthSettings {

<#
          .SYNOPSIS
           This function checks RateLimit availability. 

          .PARAMETER Resource
           The desired twitter resource to check for availability.
           
          .PARAMETER RateLimit 
           Tells the function to wait till it is available.

#>
        [CmdletBinding()]
	    [OutputType('System.Management.Automation.PSCustomObject')]
        Param (
            [string]$Resource,
            [switch]$RateLimit
        )
    
        Begin {

            If(!$Global:Twitter_OAuths) {

                Write-Warning "`$OAuths has not been initialized..."
                if (!($ApiKey = Read-Host "ApiKey ")) { Break }
                if (!($ApiSecret = Read-Host "ApiSecret ")) { Break }
                if (!($AccessToken = Read-Host "AccessToken ")) { Break }
                if (!($AccessTokenSecret = Read-Host "AccessTokenSecret ")) { Break }

                $Global:Twitter_OAuths = @{ 'ApiKey'            = $ApiKey; 
                                    'ApiSecret'         = $ApiSecret; 
                                    'AccessToken'       = $AccessToken; 
                                    'AccessTokenSecret' = $AccessTokenSecret }	
                
            }

            if (!($Global:RateLimitStatus)) { Set-RateLimitStatus }

        }

        Process {

            $Eposh = Get-Eposh

            $ResourceLimitStatus = $Global:RateLimitStatus | Where-Object { $_.resource -eq $Resource } | 
                                                             Sort-Object @{expression="remaining";Descending=$true}, @{expression="reset";Ascending=$true} | 
                                                             Select-Object -First 1
    
            If ($ResourceLimitStatus) { 
                Write-Debug "$(Get-Date) [InvokeTwitterAPI] : $($ResourceLimitStatus.resource) (limit:$($ResourceLimitStatus.limit), remaining:$($ResourceLimitStatus.remaining), reset:$($ResourceLimitStatus.reset)) - $($ResourceLimitStatus.accesstoken)" 
            } Else { 
                Write-Warning "$(Get-Date) [InvokeTwitterAPI] : RateLimit Error : $($Resource)" 
            }

            
            if (($ResourceLimitStatus.remaining -eq 0) -or (($ResourceLimitStatus.reset - $Eposh) -lt 1)) { 
                Set-RateLimitStatus
                $ResourceLimitStatus = $Global:RateLimitStatus | Where-Object { $_.resource -eq $Resource } | 
                                                                 Sort-Object @{expression="remaining";Descending=$true},@{expression="reset";Ascending=$true} | 
                                                                 Select-Object -First 1
            }

            if ($ResourceLimitStatus.remaining -eq 0) { 

                [int]$SleepSeconds = $ResourceLimitStatus.reset - (Get-Eposh) + 1
        
                if ($SleepSeconds -gt 0) {
                    if ($RateLimit.IsPresent) {

                      Write-Warning "$(Get-Date) [InvokeTwitterAPI] : Wait $SleepSeconds..."
                      Sleep -Seconds $SleepSeconds
                      Set-RateLimitStatus
                      $ResourceLimitStatus = $Global:RateLimitStatus | Where-Object { $_.resource -eq $Resource } | 
                                                                       Sort-Object @{expression="remaining";Descending=$true},@{expression="reset";Ascending=$true} | 
                                                                       Select-Object -First 1
                    
                    } Else { Return }
                }
        
            }

            # Update the remaining counter for that resource
            $Global:RateLimitStatus | ? { $_.accesstoken -eq $ResourceLimitStatus.accesstoken } | ? { $_.resource -eq $Resource } | % { $_.remaining-- }
            
            # Return the OAuthSettings for the selected access_token
            $OAuthSettings = $Twitter_OAuths | ? { $_.accesstoken -eq $ResourceLimitStatus.accesstoken }

            Return $OAuthSettings
        }

}

function Set-RateLimitStatus {
<#
          .SYNOPSIS
           This function gets the Rate Limit Status from Twitter and set's the Global:RateLimitStatus variable.
           
#>
        [CmdletBinding()]
	    [OutputType('System.Management.Automation.PSCustomObject')]
        Param ()

        Process {

            [array]$Global:RateLimitStatus = @()
            ForEach ($OAuthSettings in $Twitter_OAuths) {

                $ApplicationRateLimitStatus = Get-TwitterApplication_RateLimitStatus -OAuthSettings $OAuthSettings
                $ApplicationRateLimitStatus.resources.PSObject.Properties | ForEach { 
                    $_.value | ForEach { 
                        $_.PSObject.Properties | ForEach { 
                            $Global:RateLimitStatus += $_ | Select-Object @{ n='accesstoken'; e={ $ApplicationRateLimitStatus.rate_limit_context.access_token }}, @{ n='resource'; e={ $_.name }}, @{ n='limit'; e={ $_.value.limit }}, @{ n='remaining'; e={ $_.value.remaining }}, @{ n='reset'; e={ $_.value.reset }} 
                        } 
                    } 
                } 

                $Eposh = Get-Eposh
                $Global:RateLimitStatus += "/statuses/update" | Select-Object @{ n='accesstoken'; e={ $ApplicationRateLimitStatus.rate_limit_context.access_token }}, @{ n='resource'; e={ $_ }}, @{ n='limit'; e={ 15 }}, @{ n='remaining'; e={ 15 }}, @{ n='reset'; e={ $Eposh }} 

            }

        }

}

function Invoke-TwitterMediaUpload{

<#
          .SYNOPSIS
           This function uploads a media file to twitter and returns the media file id. 

          .PARAMETER ResourceURL
           The desired twitter media upload resource url For API 1.1 https://upload.twitter.com/1.1/media/upload.json [REST APIs can be found here: https://dev.twitter.com/rest/public]
           
          .PARAMETER MediaFilePath 
          Local path of media

          .PARAMETER OAuthSettings 
           A hashtable that must contain only the following keys and their values (Generate here: https://dev.twitter.com/oauth)
                       ApiKey 
                       ApiSecret 
		               AccessToken
	                   AccessTokenSecret
          .LINK
          This function evolved from the following blog post https://devcentral.f5.com/articles/introducing-poshtwitpic-ndash-use-powershell-to-post-your-images-to-twitter-via-twitpic
#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)][System.IO.FileInfo] $MediaFilePath,
        [parameter(Mandatory)] [System.URI] $ResourceURL,
        [Parameter(Mandatory)]$OAuthSettings
    )

    process{
  
     try{
           $Parameters = @{}
           $AuthParams = @{}
           $AuthParams.Add('HttpEndPoint', $ResourceURL)
           $AuthParams.Add('RESTVerb', "POST")
           $AuthParams.Add('Params', $Parameters)
           $AuthParams.Add('OAuthSettings', $o)
           $AuthorizationString = Get-OAuth -AuthorizationParams $AuthParams
           $boundary = [System.Guid]::NewGuid().ToString();
           $header = "--{0}" -f $boundary;
           $footer = "--{0}--" -f $boundary;
           [System.Text.StringBuilder]$contents = New-Object System.Text.StringBuilder
           [void]$contents.AppendLine($header);
           $bytes = [System.IO.File]::ReadAllBytes($MediaFilePath)
           $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
           $filedata = $enc.GetString($bytes)
           $contentTypeMap = @{
                    ".jpg"  = "image/jpeg";
                    ".jpeg" = "image/jpeg";
                    ".gif"  = "image/gif";
                    ".png"  = "image/png";
                 }
           $fileContentType = $contentTypeMap[$MediaFilePath.Extension.ToLower()]
           $fileHeader = "Content-Disposition: file; name=""{0}""; filename=""{1}""" -f "media", $file.Name  
           [void]$contents.AppendLine($fileHeader)
           [void]$contents.AppendLine("Content-Type: {0}" -f $fileContentType)
           [void]$contents.AppendLine()
           [void]$contents.AppendLine($fileData)
           [void]$contents.AppendLine($footer)
           $z =  $contents.ToString()
           $response = Invoke-RestMethod -Uri $ResourceURL -Body $z -Method Post -Headers @{ 'Authorization' = $AuthorizationString } -ContentType "multipart/form-data; boundary=`"$boundary`""
           $response.media_id
    }
    catch [System.Net.WebException] {
        Write-Error( "FAILED to reach '$URL': $_" )
        $_
        throw $_
    }
    }
}

function Invoke-TwitterRestMethod{
<#
          .SYNOPSIS
           This function sends a POST or GET message to the Twitter API and returns the JSON response. 

          .PARAMETER ResourceURL
           The desired twitter resource url [REST APIs can be found here: https://dev.twitter.com/rest/public]
           
          .PARAMETER RestVerb
           Either 'GET' or 'POST' depending on the resource URL

           .PARAMETER  Parameters
           A hashtable containing the rest parameters (key value pairs) associated that resource url. Pass empty hash if no paramters needed.

           .PARAMETER OAuthSettings 
           A hashtable that must contain only the following keys and their values (Generate here: https://dev.twitter.com/oauth)
                       ApiKey 
                       ApiSecret 
		               AccessToken
	                   AccessTokenSecret

           .EXAMPLE
            $OAuth = @{'ApiKey' = 'yourapikey'; 'ApiSecret' = 'yourapisecretkey';'AccessToken' = 'yourapiaccesstoken';'AccessTokenSecret' = 'yourapitokensecret'}
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/mentions_timeline.json' -RestVerb 'GET' -Parameters @{} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/user_timeline.json' -RestVerb 'GET' -Parameters @{'count' = '1'} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/home_timeline.json' -RestVerb 'GET' -Parameters @{'count' = '1'} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/retweets_of_me.json' -RestVerb 'GET' -Parameters @{} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/search/tweets.json' -RestVerb 'GET' -Parameters @{'q'='powershell';'count' = '1'}} -OAuthSettings $OAuth
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/account/settings.json' -RestVerb 'POST' -Parameters @{'lang'='tr'} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/retweets/509457288717819904.json' -RestVerb 'GET' -Parameters @{} -OAuthSettings $OAuth
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/show.json' -RestVerb 'GET' -Parameters @{'id'='123'} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/destroy/240854986559455234.json' -RestVerb 'GET' -Parameters @{} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/update.json' -RestVerb 'POST' -Parameters @{'status'='@FollowBot'} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/direct_messages.json' -RestVerb 'GET' -Parameters @{} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/direct_messages/destroy.json' -RestVerb 'POST' -Parameters @{'id' = '559298305029844992'} -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/direct_messages/new.json' -RestVerb 'POST' -Parameters @{'text' = 'hello, there'; 'screen_name' = 'ruminaterumi' } -OAuthSettings $OAuth 
            $mediaId = Invoke-TwitterMEdiaUpload -MediaFilePath 'C:\Books\pic.png' -ResourceURL 'https://upload.twitter.com/1.1/media/upload.json' -OAuthSettings $OAuth 
            Invoke-TwitterRestMethod -ResourceURL 'https://api.twitter.com/1.1/statuses/update.json' -RestVerb 'POST' -Parameters @{'status'='FollowBot'; 'media_ids' = $mediaId } -OAuthSettings $OAuth 

     #>
         [CmdletBinding()]
	     [OutputType('System.Management.Automation.PSCustomObject')]
         Param(
                [Parameter(Mandatory)]
                [string]$ResourceURL,
                [Parameter(Mandatory)]
                [string]$RestVerb,
                [Parameter(Mandatory)]
                $Parameters,
                [Parameter(Mandatory)]
                $OAuthSettings

                )

          begin { $progressPreference = 'silentlyContinue' }
          process{

            $Parameters.Remove('Verbose') | Out-Null
            
              try{

                    $AuthParams = @{}
                    $AuthParams.Add('HttpEndPoint', $ResourceURL)
                    $AuthParams.Add('RESTVerb', $RestVerb)
                    $AuthParams.Add('Params', $Parameters)
                    $AuthParams.Add('OAuthSettings', $OAuthSettings)
                    $AuthorizationString = Get-OAuth -AuthorizationParams $AuthParams                 
                    $HTTPEndpoint= $ResourceURL
                    if($Parameters.Count -gt 0)
                    {
                        $HTTPEndpoint = $HTTPEndpoint + '?'
                        $Parameters.Keys | % { $HTTPEndpoint = $HTTPEndpoint + $_  +'='+ [System.Net.WebUtility]::UrlEncode($Parameters.Item($_)).Replace('+','%20').Replace('!','%21') + '&'}
                        $HTTPEndpoint = $HTTPEndpoint.Substring(0,$HTTPEndpoint.Length-1)
  
                    }
                    Invoke-RestMethod -URI $HTTPEndpoint -Method $RestVerb -Headers @{ 'Authorization' = $AuthorizationString } -ContentType "application/x-www-form-urlencoded"
                  }
                  catch{ 
                  
                    If ($_.Exception.Response.StatusCode.value__ -ne 404) { Write-Error $_.Exception.Message }

                  }
            }
}

function Invoke-ReadFromTwitterStream{
<#
          .SYNOPSIS
           This function can be used to download info from the Twitter Streaming APIs and record the json ouptut in a text file. 

          .PARAMETER ResourceURL
           The desired twitter resource url [Streaming APIs can be found here: https://dev.twitter.com/streaming/overview]
           
          .PARAMETER RestVerb
           Either 'GET' or 'POST' depending on the resource URL

           .PARAMETER  Parameters
           A hashtable containing the rest parameters (key value pairs) associated that resource url. Pass empty hash if no paramters needed.

           .PARAMETER OAuthSettings 
           A hashtable that must contain only the following keys and their values (Generate here: https://dev.twitter.com/oauth)
                       ApiKey 
                       ApiSecret 
		               AccessToken
	                   AccessTokenSecret

           .PARAMETER  MinsToCollectStream
           The number of minutes you want to attempt to stream content. Use -1 to run infinte loop. 

           .PARAMETER  OutFilePath
           The location of the out file text. Will create file if dne yet.

           .EXAMPLE 
            $OAuth = @{'ApiKey' = 'yourapikey'; 'ApiSecret' = 'yourapisecretkey';'AccessToken' = 'yourapiaccesstoken';'AccessTokenSecret' = 'yourapitokensecret'}
            Invoke-ReadFromTwitterStream -OAuthSettings $o -OutFilePath 'C:\books\foo.txt' -ResourceURL 'https://stream.twitter.com/1.1/statuses/filter.json' -RestVerb 'POST' -Parameters @{'track' = 'foo'} -MinsToCollectStream 1

           .LINK
           This function evolved from the following blog posts http://thoai-nguyen.blogspot.com.tr/2012/03/consume-twitter-stream-oauth-net.html, https://code.google.com/p/pstwitterstream/
#>
           [CmdletBinding()]
           Param(
                [Parameter(Mandatory)]
                $OAuthSettings,
                [Parameter(Mandatory)] 
                [String] $OutFilePath,
                [Parameter(Mandatory)] 
                [string]$ResourceURL,
                [Parameter(Mandatory)] 
                [string]$RestVerb,
                [Parameter(Mandatory)] 
                $Parameters,
                [Parameter(Mandatory)] 
                $MinsToCollectStream
                )

                process{
                $Ti = Get-Date  
                while($true)
                {
                  $NewD = Get-Date
                  if(($MinsToCollectStream -ne -1) -and (($NewD-$Ti).Minutes -gt $MinsToCollectStream))
                  { return "Finished"}
     
                  try
                  {
                    $AuthParams = @{}
                    $AuthParams.Add('HttpEndPoint', $ResourceURL)
                    $AuthParams.Add('RESTVerb', $RestVerb)
                    $AuthParams.Add('Params', $Parameters)
                    $AuthParams.Add('OAuthSettings', $OAuthSettings)
                    $AuthorizationString = Get-OAuth -AuthorizationParams $AuthParams

                    [System.Net.HttpWebRequest]$Request = [System.Net.WebRequest]::Create($ResourceURL)
                    $Request.Timeout = [System.Threading.Timeout]::Infinite
                    $Request.Method = $RestVerb
                    $Request.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip, [System.Net.DecompressionMethods]::Deflate 
                    $Request.Headers.Add('Authorization', $AuthorizationString)
                    $Request.Headers.Add('Accept-Encoding', 'deflate,gzip')
                    $filter = $Null
                    if($Parameters.Count -gt 0)
                    {
                        $Parameters.Keys | % { $filter = $filter + $_  +'='+ [System.Net.WebUtility]::UrlEncode($Parameters.Item($_)).Replace('+','%20').Replace('!','%21') + '&'}
                        $filter = $filter.Substring(0, $filter.Length-1)
                        $POSTData = [System.Text.Encoding]::UTF8.GetBytes($filter)
                        $Request.ContentType = "application/x-www-form-urlencoded"
                        $Request.ContentLength = $POSTData.Length
                        $RequestStream = $Request.GetRequestStream()
                        $RequestStream.Write($POSTData, 0, $POSTData.Length)
                        $RequestStream.Close()
                    }
                 
                    $Response =  [System.Net.HttpWebResponse]$Request.GetResponse()
                    [System.IO.StreamReader]$ResponseStream = $Response.GetResponseStream()
                    
                    while ($true) 
                    {
                            $NewDt = Get-Date
                            if(($MinsToCollectStream -ne -1) -and (($NewDt-$Ti).Minutes -gt $MinsToCollectStream))
                            { return "Finished"}

                            $Line = $ResponseStream.ReadLine()
                            if($Line -eq '') 
                            { continue }
                            Add-Content $OutFilePath $Line
                            $PowerShellRepresentation = $Line | ConvertFrom-Json
                            $PowerShellRepresentation
                            If ($ResponseStream.EndOfStream) { Throw "Stream closed." }                  
                    }
                 }
                 catch{
                    Write-Error $_.Exception.Message
                }
                }
              }
}

Function Convert-TwitterDateTime {
    
    [CmdletBinding()]  
    Param( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)] [object[]]$InputObjects,
        [Parameter(Mandatory=$False,ValueFromPipeline=$false)] [string[]]$Properties = "created_at"
    )
    Process {

        ForEach ($InputObject in $InputObjects) { 
          ForEach ($Property in $Properties) {
            if ($InputObject."$Property") { 
              Try {  
                $InputObject."$Property" = [datetime]::ParseExact($InputObject."$Property",'ddd MMM dd HH:mm:ss +0000 yyyy',$null) 
              } Catch { }
            }
          }
            $InputObject
        }

    }

}


#region [ Public API ] ======================================

function Get-TwitterStatuses_MentionsTimeline {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/mentions_timeline
#>

    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[int64]
		$since_id,

		[Parameter(Mandatory = $false)]
		[int64]
		$max_id,

		[Parameter(Mandatory = $false)]
		[boolean]
		$trim_user,

		[Parameter(Mandatory = $false)]
		[boolean]
		$contributor_details,

		[Parameter(Mandatory = $false)]
		[boolean]
		$include_entities

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/mentions_timeline.json"
        [string]$Resource     = "/statuses/mentions_timeline"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings
                  
    }

}

function Get-TwitterStatuses_UserTimeline {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/user_timeline

          .PARAMETER all
           Will handle the paging and return all.
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]  
	param (

		[Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[Alias("id")]
        [int64]
		$user_id,

		[Parameter(Mandatory = $true,ParameterSetName="RequestByName", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[system.string]
		$screen_name,

		[Parameter(Mandatory = $false)]
		[int64]
		$since_id,

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[int64]
		$max_id,

		[Parameter(Mandatory = $false)]
		[boolean]
		$trim_user,

		[Parameter(Mandatory = $false)]
		[boolean]
		$exclude_replies,

		[Parameter(Mandatory = $false)]
		[boolean]
		$contributor_details,

		[Parameter(Mandatory = $false)]
		[boolean]
		$include_rts,

		[Parameter(Mandatory = $false)]
		[switch]
		$all

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/user_timeline.json"
        [string]$Resource    = "/statuses/user_timeline"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('all')
                   $Parameters.tweet_mode = 'extended'

                   'Verbose','Debug','ErrorAction','WarningAction','InformationAction','ErrorVariable','WarningVariable','InformationVariable','OutVariable','OutBuffer','PipelineVariable' | % { $Parameters.Remove($_) }

        If ($all.IsPresent) { $Parameters.count = 200 } # Overide if we want to get all

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | ForEach { $_ }

      if (($all.IsPresent) -and ($Results.id)) {
        $Parameters.max_id = [int64]($Results.id | Measure-Object -Minimum | Select-Object -Expand Minimum) -1
        $Parameters.Remove('tweet_mode')
        Get-TwitterStatuses_UserTimeline @Parameters -all
      }
            
    }

}

function Get-TwitterStatuses_HomeTimeline {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/home_timeline
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[int64]
		$since_id,

		[Parameter(Mandatory = $false)]
		[int64]
		$max_id,

		[Parameter(Mandatory = $false)]
		[boolean]
		$trim_user,

		[Parameter(Mandatory = $false)]
		[boolean]
		$exclude_replies,

		[Parameter(Mandatory = $false)]
		[boolean]
		$contributor_details,

		[Parameter(Mandatory = $false)]
		[boolean]
		$include_entities

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/home_timeline.json"
        [string]$Resource     = "/statuses/home_timeline"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
                  
    }

}

function Get-TwitterStatuses_RetweetsOfMe {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/retweets_of_me
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[int64]
		$since_id,

		[Parameter(Mandatory = $false)]
		[int64]
		$max_id,

		[Parameter(Mandatory = $false)]
		[boolean]
		$trim_user,

		[Parameter(Mandatory = $false)]
		[boolean]
		$exclude_replies,

		[Parameter(Mandatory = $false)]
		[boolean]
		$contributor_details,

		[Parameter(Mandatory = $false)]
		[boolean]
		$include_entities

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/home_timeline.json"
        [string]$Resource     = "/statuses/home_timeline"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
                  
    }

}

function Get-TwitterStatuses_RetweetsID {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/retweets/:id
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]  
	param (

		[Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[int64]
		$id,

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[switch]
		$trim_user

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/retweets/:id.json" -Replace ":id", "$id"
        [string]$Resource    = "/statuses/retweets/:id"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
      
    }

}

function Get-TwitterStatuses_ShowID {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/show/:id
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true, Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[int64]
		$id,

		[Parameter(Mandatory = $false)]
		[switch]
		$trim_user,

		[Parameter(Mandatory = $false)]
		[switch]
		$include_my_retweet,

		[Parameter(Mandatory = $false)]
		[switch]
		$include_entities

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/show.json"
        [string]$Resource    = "/statuses/show/:id"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
      
    }

}

function Send-TwitterStatuses_DestroyID {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for POST statuses/destroy/:id

          .DESCRIPTION
          Destroys the status specified by the required ID parameter. The authenticating user must be the author of the specified status. Returns the destroyed status if successful.

          .LINK
          https://dev.twitter.com/rest/reference/post/statuses/destroy/%3Aid
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true, Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[int64]
		$id,

		[Parameter(Mandatory = $false)]
		[switch]
		$trim_user

    )

    Begin {
        
        [string]$RestVerb    = "POST"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/destroy/:id.json" -Replace ":id", "$id"
        [string]$Resource     = "/statuses/destroy/:id"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
      
    }

}

function Send-TwitterStatuses_Update {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for POST statuses/update

          .DESCRIPTION
          Updates the authenticating user’s current status, also known as Tweeting.

          For each update attempt, the update text is compared with the authenticating user’s recent Tweets. Any attempt that would result in duplication will be blocked, resulting in a 403 error. Therefore, a user cannot submit the same status twice in a row.

          While not rate limited by the API a user is limited in the number of Tweets they can create at a time. If the number of updates posted by the user reaches the current allowed limit this method will return an HTTP 403 error.

          .LINK
          https://dev.twitter.com/rest/reference/post/statuses/destroy/%3Aid
#>
    [CmdletBinding()]  
    param (

		[Parameter(Mandatory = $true, Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[string]
		$status,

		[Parameter(Mandatory = $false)]
		[int64]
		$in_reply_to_status_id,

		[Parameter(Mandatory = $false)]
		[switch]
		$possibly_sensitive,

		[Parameter(Mandatory = $false)]
		[double]
		$lat,

		[Parameter(Mandatory = $false)]
		[double]
		$long,

		[Parameter(Mandatory = $false)]
		[string]
		$place_id,

		[Parameter(Mandatory = $false)]
		[switch]
		$display_coordinates,

		[Parameter(Mandatory = $false)]
		[switch]
		$trim_user,

		[Parameter(Mandatory = $false)]
		[int64[]]
		$media_ids

    )

    Begin {
        
        
        [string]$RestVerb    = "POST"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/update.json"
        [string]$Resource     = "/statuses/update"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
      
    }

}

function Send-TwitterStatuses_RetweetID {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/retweet/:id
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true, Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[int64]
		$id,

		[Parameter(Mandatory = $false)]
		[switch]
		$trim_user

    )

    Begin {
        
        [string]$RestVerb    = "POST"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/retweet/:id.json" -Replace ":id", "$id"
        [string]$Resource     = "/statuses/retweet/:id"
               
        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
      
    }

}

function Send-TwitterStatuses_UnretweetID {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for POST statuses/unretweet/:id
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true, Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[int64]
		$id,

		[Parameter(Mandatory = $false)]
		[switch]
		$trim_user

    )

    Begin {
        
        [string]$RestVerb    = "POST"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/unretweet/:id.json" -Replace ":id", "$id"
        [string]$Resource    = "/statuses/unretweet/:id"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
      
    }

}

# function POST statuses/update_with_media
# function GET statuses/oembed

function Get-TwitterStatuses_Retweeters_IDs {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/retweeters/ids

          .PARAMETER all
           Will handle the paging and return all.
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true, Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
		[int64]
		$id,

		[Parameter(Mandatory = $false)]
		[int64]
		$cursor,

		[Parameter(Mandatory = $false)]
		[boolean]
		$stringify_ids,

		[Parameter(Mandatory = $false)]
		[switch]
		$all

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/retweeters/ids.json"
        [string]$Resource    = "/retweeters/ids"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('all')
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
      
      While (($all.IsPresent) -and ($Results.next_cursor)) {

        $Parameters.cursor = $Results.next_cursor
        
        [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
      
      }

    }

}

function Get-TwitterStatuses_Lookup {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET statuses/lookup
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true, Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
		[int64[]]
		$id,

		[Parameter(Mandatory = $false)]
		[boolean]
		$include_entities,

		[Parameter(Mandatory = $false)]
		[boolean]
		$trim_user,

		[Parameter(Mandatory = $false)]
		[boolean]
		$map

    )

    Begin {

        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/statuses/lookup.json"
        [string]$Resource    = "/statuses/lookup"

        [hashtable]$Parameters = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

        $max_count = 100
        [int64[]]$ids = @()

    }

    Process {

        $ids += $id

        While ($ids.Count -ge $max_count) {

            If ($Parameters.id) { $Parameters.id = [string](($ids[$i..($i+$max_count-1)] | ? { $_ }) -Join ',') }
            
            [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
            Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
            
            [int64[]]$ids = $ids | Select-Object -Skip $max_count

        }

    }

    End {

        If ($ids.Count) {

            If ($Parameters.id) { $Parameters.id = [string](($ids | ? { $_ }) -Join ',') }

            [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
            Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

        }

    }

}

# function POST media/upload
# function POST media/upload chunked
# function GET direct_messages/sent
# function GET direct_messages/show

function Get-TwitterWebSearch_Tweets {

    [CmdletBinding()]  
    param (

        [Parameter(Mandatory = $true, Position=0,
                   ValueFromPipelineByPropertyName=$true)]
        [system.string]
        $q,

        [Parameter(Mandatory = $false)]
        [int]
        $count = 200,

		[Parameter(Mandatory = $false)]
		[int64]
		$since_id = 0,

		[Parameter(Mandatory = $false)]
		[switch]
		$full,

		[Parameter(Mandatory = $false)]
		[switch]
		$all

    )

    Begin {
        
        [string]$ResourceURL = "https://www.twitter.com"
        [string]$next_cursor = "/search?src=sprv&q=" + [System.Web.HttpUtility]::UrlEncode($q)
        
        #Top        = https://twitter.com/search?vertical=default&src=typd&q=
        #Latest     = https://twitter.com/search?f=tweets&vertical=default&src=typd&q=
        #Photos     = https://twitter.com/search?f=images&vertical=default&src=typd&q=
        #Videos     = https://twitter.com/search?f=videos&vertical=default&src=typd&q=
        #News       = https://twitter.com/search?f=news&vertical=default&src=typd&q=
        #Broadcasts = https://twitter.com/search?f=broadcasts&vertical=default&src=typd&q=

        if ($all.IsPresent) { $Count = [int]::MaxValue }

        $TweetResults = New-Object System.Collections.ArrayList

    }

    Process {

        While (($next_cursor) -and ($Count -gt $TweetResults.Count)) {
        
            $search_url = "${ResourceURL}${next_cursor}"
            $content_html = Invoke-WebRequest -Uri $search_url -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer) -UseBasicParsing
            #$content_html.Content | Set-Content .\content.html

            $next_cursor = $content_html.links | Where-Object { $_.href -match 'next_cursor' } | Select-Object -Expand href
            $content_tweet = $content_html.links | Where-Object name -match 'tweet_'
        
            ForEach ($tweet in $content_tweet) { 
                $null, $null, $rel_date, $null = $tweet.outerHTML -Split ">" -Split "<"
                $null, $screen_name, $null, [int64]$status_id, $null = $tweet.href -Split "/" -Split "\?" 
                [void]$TweetResults.Add([PSCustomObject]@{ rel_date = $rel_date; user = @{screen_name = $screen_name}; id = $status_id })
            } 
        
            If ($TweetResults.id -contains $since_id) {
                $next_cursor = $null
            }
        }

        If ($Full) {
            $Ids = $TweetResults | Where-Object  { $_.id -gt $since_id } | Select-Object -First $Count -ExpandProperty Id -Unique
            Get-TwitterStatuses_Lookup -id $Ids
        } Else {
            $TweetResults | Where-Object  { $_.id -gt $since_id } | Select-Object * -First $Count -Unique
        }

    }
}

function Get-TwitterSearch_Tweets {
    <#
              .SYNOPSIS
               Mimics Twitter API parameters for GET search/tweets
    
              .PARAMETER all
               Will handle the paging and return all.
    #>
    [CmdletBinding()]  
    param (

        [Parameter(Mandatory = $true, Position=0,
                   ValueFromPipelineByPropertyName=$true)]
        [system.string]
        $q,

        [Parameter(Mandatory = $false)]
        [system.string]
        $geocode,

        [Parameter(Mandatory = $false)]
        [system.string]
        $lang,

        [Parameter(Mandatory = $false)]
        [system.string]
        $locale,

        [Parameter(Mandatory = $false)]
        [system.string]
        $result_type = 'recent', #mixed/recent/popular

        [Parameter(Mandatory = $false)]
        [int]
        $count = 100,

        [Parameter(Mandatory = $false)]
        [datetime]
        $until,

        [Parameter(Mandatory = $false)]
        [int64]
        $since_id,

        [Parameter(Mandatory = $false)]
        [int64]
        $max_id,

		[Parameter(Mandatory = $false)]
		[boolean]
		$include_entities,

		[Parameter(Mandatory = $false)]
		[switch]
		$all

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/search/tweets.json"
        [string]$Resource    = "/search/tweets"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'
                   $Parameters.Remove('all')

        If ($all.IsPresent) { 
            # Overide if we want to get all
            $Parameters.result_type = 'recent'
            $Parameters.count = 100 
        }

    }

    Process {

        [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.statuses }
        
        While (($all.IsPresent) -and ($Results)) {

        $Parameters.max_id = $Results.statuses.id | Sort-Object | Select-Object -First 1 | ForEach-Object { [int64]$_ - 1 }
        
        [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.statuses }

        Break

        }

    }

}

# function GET direct_messages
# function POST direct_messages/destroy
# function POST direct_messages/new
# function GET friendships/no_retweets/ids

function Get-TwitterFriends_IDs {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET friends/ids

          .PARAMETER all
           Will handle the paging and return all.
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]  
	param (

		[Parameter(Mandatory = $true,
                   ParameterSetName="RequestById", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[Alias("id")]
        [int64]
		$user_id,

		[Parameter(Mandatory = $true,
                   ParameterSetName="RequestByName", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[system.string]
		$screen_name,

		[Parameter(Mandatory = $false)]
		[int64]
		$cursor,

		[Parameter(Mandatory = $false)]
		[boolean]
		$stringify_ids,

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[switch]
		$all

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/friends/ids.json"
        [string]$Resource    = "/friends/ids"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('all')
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
      
      While (($all.IsPresent) -and ($Results.next_cursor)) {

        $Parameters.cursor = $Results.next_cursor
        
        [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }

      }

    }

}

function Get-TwitterFollowers_IDs {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET followers/ids

          .PARAMETER all
           Will handle the paging and return all.
#>
    [CmdletBinding(DefaultParameterSetName="RequestById")]  
	param (

		[Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[Alias("id")]
        [int64]
		$user_id,

		[Parameter(Mandatory = $true,ParameterSetName="RequestByName", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[system.string]
		$screen_name,

		[Parameter(Mandatory = $false)]
		[int64]
		$cursor,

		[Parameter(Mandatory = $false)]
		[boolean]
		$stringify_ids,

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[switch]
		$all

    )

    Begin {
        
        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/followers/ids.json"
        [string]$Resource    = "/followers/ids"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('all')
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
      
      While (($all.IsPresent) -and ($Results.next_cursor)) {

        $Parameters.cursor = $Results.next_cursor

        [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
        
      }

    }

}

# function GET friendships/incoming
# function GET friendships/outgoing
# function POST friendships/create
# function POST friendships/destroy
# function POST friendships/update
# function GET friendships/show
# function GET friends/list
# function GET followers/list
# function GET friendships/lookup
# function GET account/settings
# function GET account/verify_credentials
# function POST account/settings
# function POST account/update_delivery_device
# function POST account/update_profile
# function POST account/update_profile_background_image
# function POST account/update_profile_image
# function GET blocks/list
# function GET blocks/ids
# function POST blocks/create
# function POST blocks/destroy

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
		$include_entities

    )

    Begin {

        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/users/lookup.json"
        [string]$Resource    = "/users/lookup"

        [hashtable]$Parameters = $PSBoundParameters
                   $Parameters.tweet_mode = 'extended'

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

            [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
            Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
            
            [int64[]]$user_ids = $user_ids | Select-Object -Skip $max_count
            [system.string[]]$screen_names = $screen_names | Select-Object -Skip $max_count

            [int]$NCount = $user_ids.count + $screen_names.count

        }

    }

    End {

        If ($NCount) {

            If ($Parameters.user_id)     { $Parameters.user_id     = [string](($user_ids | ? { $_ }) -Join ',') }
            If ($Parameters.screen_name) { $Parameters.screen_name = [string](($screen_names | ? { $_ }) -Join ',') }

            [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
            Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

        }

    }

}

# function GET users/show
# function GET users/search
# function POST account/remove_profile_banner
# function POST account/update_profile_banner
# function GET users/profile_banner
# function POST mutes/users/create
# function POST mutes/users/destroy
# function GET mutes/users/ids
# function GET mutes/users/list
# function GET users/suggestions/:slug
# function GET users/suggestions
# function GET users/suggestions/:slug/members
# function GET favorites/list
# function POST favorites/destroy
# function POST favorites/create

function Get-TwitterLists_list {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET lists/list
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
		[Alias("id")]
        [int64]
		$user_id,

		[Parameter(Mandatory = $true,ParameterSetName="RequestByName", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[system.string]
		$screen_name,

		[Parameter(Mandatory = $false)]
		[boolean]
		$reverse

    )

    Begin {

        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/lists/list.json"
        [string]$Resource    = "/lists/list"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('all')
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_ }
      
      While (($all.IsPresent) -and ($Results.next_cursor)) {

        $Parameters.cursor = $Results.next_cursor

        [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_ }
        
      }

    }

}

# function GET lists/statuses
# function POST lists/members/destroy
# function GET lists/memberships
# function GET lists/subscribers

function Get-TwitterLists_subscriptions {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET lists/list
#>
    [CmdletBinding()]  
	param (

		[Parameter(Mandatory = $true,ParameterSetName="RequestById", Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
		[Alias("id")]
        [int64]
		$user_id,

		[Parameter(Mandatory = $true,ParameterSetName="RequestByName", Position=0,
                   ValueFromPipelineByPropertyName=$true)]
		[system.string]
		$screen_name,

		[Parameter(Mandatory = $false)]
		[int]
		$count,

		[Parameter(Mandatory = $false)]
		[boolean]
		$reverse

    )

    Begin {

        [string]$RestVerb    = "GET"
        [string]$ResourceURL = "https://api.twitter.com/1.1/lists/subscriptions.json"
        [string]$Resource    = "/lists/subscriptions"

        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('all')
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

      [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
      Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.lists }
      
      While (($all.IsPresent) -and ($Results.next_cursor)) {

        $Parameters.cursor = $Results.next_cursor

        [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_ }
        
      }

    }

}

# function POST lists/subscribers/create
# function GET lists/subscribers/show
# function POST lists/subscribers/destroy
# function POST lists/members/create_all
# function GET lists/members/show
# function GET lists/members
# function POST lists/members/create
# function POST lists/destroy
# function POST lists/update
# function POST lists/create
# function GET lists/show
# function GET lists/subscriptions
# function POST lists/members/destroy_all
# function GET lists/ownerships
# function GET saved_searches/list
# function GET saved_searches/show/:id
# function POST saved_searches/create
# function POST saved_searches/destroy/:id
# function GET geo/id/:place_id
# function GET geo/reverse_geocode
# function GET geo/search
# function POST geo/place
# function GET trends/place
# function GET trends/available

function Get-TwitterApplication_RateLimitStatus {
<#
          .SYNOPSIS
           Mimics Twitter API parameters for GET application/rate_limit_status

          .PARAMETER force
           skips the checking of the RateLimit.. because we are asking to get the RateLimit (which could be empty).
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
        
        $RestVerb    = "GET"
        $ResourceURL = "https://api.twitter.com/1.1/application/rate_limit_status.json"
        
        [hashtable]$Parameters    = $PSBoundParameters
                   $Parameters.Remove('OAuthSettings')
                   $Parameters.tweet_mode = 'extended'

    }

    Process {

        If (-Not $OAuthSettings) { [hashtable]$OAuthSettings = Get-OAuthSettings -Resource $Resource -RateLimit }
        Invoke-TwitterRestMethod -ResourceURL $ResourceURL -RestVerb $RestVerb -Parameters $Parameters -OAuthSettings $OAuthSettings

    }

}

# function GET help/configuration
# function GET help/languages
# function GET help/privacy
# function GET help/tos
# function GET trends/closest
# function POST users/report_spam

#endregion ==================================================

