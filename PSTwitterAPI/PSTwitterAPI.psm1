$Script:OAuthCollection = [System.Collections.ArrayList]@()

$Script:EndPointBaseUrl = 'https://api.twitter.com/1.1'
$Script:EndPointFileFormat = 'json'

$Script:CmdletBindingParameters = (Get-Command 'Get-Culture').Parameters.Keys

function Set-TwitterOAuthSettings {

    Param(
        $ApiKey,
        $ApiSecret,
        $AccessToken,
        $AccessTokenSecret,
        [switch]$PassThru,
        [switch]$Force
    )
    Begin {
    }
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
        Throw "No OAuthSettings was found. Use 'Set-OAuthSettings' to set PSTwitterAPI ApiKey & Token."
    }
    
    Return $OAuthSettings

}

function Get-OAuthParameters {

    [OutputType('System.Management.Automation.PSCustomObject')]
	 Param($ApiKey, $ApiSecret, $AccessToken, $AccessTokenSecret, $Method, $Resource, $Parameters)
     
     Process{

         Try {

            $BaseUrl = "${EndPointBaseUrl}/${Resource}.${EndPointFileFormat}"

            ## Generate a random 32-byte string. I'm using the current time (in seconds) and appending 5 chars to the end to get to 32 bytes
	        ## Base64 allows for an '=' but Twitter does not.  If this is found, replace it with some alphanumeric character
	        $OAuthNonce = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes("$([System.DateTime]::Now.Ticks.ToString())12345"))).Replace('=', 'g')
            
            ## Find the total seconds since 1/1/1970 (epoch time)
		    $OAuthTimestamp = [System.Convert]::ToInt64((Get-Eposh).TotalSeconds).ToString();
            
            ## EscapeDataString the parameters
            foreach($Param in $($Parameters.Keys)){
                $Parameters[$Param] = [System.Uri]::EscapeDataString($Parameters[$Param])
            }
            
            ## Build the enpoint url
            $EndPointUrl = "${BaseUrl}?"
            $Parameters.GetEnumerator() | Sort-Object Name | % { $EndPointUrl += "$($_.Key)=$($_.Value)&" }
            $EndPointUrl = $EndPointUrl.TrimEnd('&')

            ## Build the signature
            $SignatureBase = "$([System.Uri]::EscapeDataString("${BaseUrl}"))&"
			$SignatureParams = @{
				'oauth_consumer_key' = $ApiKey;
				'oauth_nonce' = $OAuthNonce;
				'oauth_signature_method' = 'HMAC-SHA1';
				'oauth_timestamp' = $OAuthTimestamp;
				'oauth_token' = $AccessToken;
				'oauth_version' = "1.0";
            }
	        $Parameters.Keys | ForEach-Object { $SignatureParams.Add($_ , $Parameters.Item($_)) }

			## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &
			## Remove the URL encoded & at the end and prepend the necessary 'POST&' verb to the front
			$SignatureParams.GetEnumerator() | Sort-Object Name | ForEach-Object { $SignatureBase += [System.Uri]::EscapeDataString("$($_.Key)=$($_.Value)&") }

            $SignatureBase = $SignatureBase.Substring(0,$SignatureBase.Length-3)
			$SignatureBase = $Method+'&' + $SignatureBase
			
			## Create the hashed string from the base signature
			$SignatureKey = [System.Uri]::EscapeDataString($ApiSecret) + "&" + [System.Uri]::EscapeDataString($AccessTokenSecret);
			
			$hmacsha1 = new-object System.Security.Cryptography.HMACSHA1;
			$hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($SignatureKey);
			$OAuthSignature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($SignatureBase)));
			
			## Build the authorization headers using most of the signature headers elements.  This is joining all of the 'Key=Value' elements again
			## and only URL encoding the Values this time while including non-URL encoded double quotes around each value
			$OAuthParameters = $SignatureParams
			$OAuthParameters.Add('oauth_signature', $OAuthSignature)

            $OAuthString = 'OAuth '
            $OAuthParameters.GetEnumerator() | Sort-Object Name | ForEach-Object { $OAuthString += $_.Key + '="' + [System.Uri]::EscapeDataString($_.Value) + '", ' }
            $OAuthString = $OAuthString.TrimEnd(', ')            
            Write-Verbose "Using authorization string '$TwitOAuthStringterOauthString'"			
                    
            $OAuthParameters.Add('endpoint_url', $EndPointUrl)
            $OAuthParameters.Add('endpoint_method', $Method)
            $OAuthParameters.Add('endpoint_authorization', $OAuthString)

            Return $OAuthParameters

        } Catch {
			Write-Error $_.Exception.Message
		}

    }

}

function Invoke-TwitterAPI {

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

function ConvertFrom-RateLimitStatus ($RateLimitStatus) {

    $Eposh = Get-Eposh

    $RateLimitStatus.resources.PSObject.Properties | ForEach { 
        $_.value | ForEach { 
            $_.PSObject.Properties | ForEach { 
                $_ | Select-Object @{ n='accesstoken'; e={ $RateLimitStatus.rate_limit_context.access_token }}, @{ n='resource'; e={ $_.name }}, @{ n='limit'; e={ $_.value.limit }}, @{ n='remaining'; e={ $_.value.remaining }}, @{ n='reset'; e={ $_.value.reset }} 
            } 
        } 
    } 

    "/statuses/update" | Select-Object @{ n='accesstoken'; e={ $RateLimitStatus.rate_limit_context.access_token }}, @{ n='resource'; e={ $_ }}, @{ n='limit'; e={ 15 }}, @{ n='remaining'; e={ 15 }}, @{ n='reset'; e={ $Eposh.TotalSeconds }} 

}

function Get-Eposh {
    Param ([int]$Eposh) 
    Process {
        If ($Eposh) { 
            [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($Eposh)) 
        } Else { 
            $unixEpochStart = New-Object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
            [DateTime]::UtcNow - $unixEpochStart
        }
    }
}





#region [ Mimic Public API ] ======================================

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
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {
        
        [string]$Method    = "GET"
        [string]$Resource  = "statuses/mentions_timeline"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings
                    
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
        [system.string]
        $tweet_mode = 'extended',

        [Parameter(Mandatory = $false)]
        [switch]
        $all

    )

    Begin {
        
        [string]$Method    = "GET"
        [string]$Resource  = "statuses/user_timeline"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('all')
                   

        If ($all.IsPresent) { $Parameters.count = 200 } # Overide if we want to get all

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | ForEach { $_ }

        if (($all.IsPresent) -and ($Results.id)) {
            $Parameters.max_id = [int64]($Results.id | Measure-Object -Minimum | Select-Object -Expand Minimum) -1
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
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {
        
        [string]$Method   = "GET"
        [string]$Resource = "statuses/home_timeline"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
                    
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
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {
        
        [string]$Method   = "GET"
        [string]$Resource = "statuses/home_timeline"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
                    
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
        $trim_user,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {
        
        [string]$Method   = "GET"
        [string]$Resource = "statuses/retweets/:id"

        [hashtable]$Parameters    = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
        
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
        $include_entities,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {
        
        [string]$Method   = "GET"
        [string]$Resource = "statuses/show/:id"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
        
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
        
        [string]$Method   = "POST"
        [string]$Resource = "statuses/destroy/:id"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
        
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
        
        
        [string]$Method   = "POST"
        [string]$Resource = "statuses/update"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
        
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
        
        [string]$Method   = "POST"
        [string]$Resource = "statuses/retweet/:id"
                
        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
        
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
        
        [string]$Method   = "POST"
        [string]$Resource = "statuses/unretweet/:id"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
        
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
        
        [string]$Method   = "GET"
        [string]$Resource = "retweeters/ids"

        [hashtable]$Parameters    = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('all')
                   
    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
        
        While (($all.IsPresent) -and ($Results.next_cursor)) {

            $Parameters.cursor = $Results.next_cursor
            
            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
            
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
        $map,

        [Parameter(Mandatory = $false)]
        [system.string]
        $tweet_mode = 'extended'

    )

    Begin {

        [string]$Method   = "GET"
        [string]$Resource = "statuses/lookup"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }

        $max_count = 100
        [int64[]]$ids = @()

    }

    Process {

        $ids += $id

        While ($ids.Count -ge $max_count) {

            If ($Parameters.id) { $Parameters.id = [string](($ids[$i..($i+$max_count-1)] | ? { $_ }) -Join ',') }
            
            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }
            
            [int64[]]$ids = $ids | Select-Object -Skip $max_count

        }

    }

    End {

        If ($ids.Count) {

            If ($Parameters.id) { $Parameters.id = [string](($ids | ? { $_ }) -Join ',') }

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | ForEach { $_ }

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
        [system.string]
        $tweet_mode = 'extended',

        [Parameter(Mandatory = $false)]
        [switch]
        $all

    )

    Begin {
        
        [string]$Method   = "GET"
        [string]$Resource = "search/tweets"

        [hashtable]$Parameters    = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('all')
                   
        If ($all.IsPresent) { # Overide if we want to get all
            $Parameters.result_type = 'recent'
            $Parameters.count = 100 
        }

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.statuses }
        
        While (($all.IsPresent) -and ($Results)) {

            $Parameters.max_id = $Results.statuses.id | Sort-Object | Select-Object -First 1 | ForEach-Object { [int64]$_ - 1 }
            
            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.statuses }

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
        
        [string]$Method   = "GET"
        [string]$Resource = "friends/ids"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('all')
                   

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
        
        While (($all.IsPresent) -and ($Results.next_cursor)) {

        $Parameters.cursor = $Results.next_cursor
        
        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }

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
        
        [string]$Method   = "GET"
        [string]$Resource = "followers/ids"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('all')

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
        
        While (($all.IsPresent) -and ($Results.next_cursor)) {

            $Parameters.cursor = $Results.next_cursor

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { [int64[]]$_.ids }
            
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

        [string]$Method   = "GET"
        [string]$Resource = "lists/list"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('all')

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_ }
        
        While (($all.IsPresent) -and ($Results.next_cursor)) {

        $Parameters.cursor = $Results.next_cursor

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_ }
        
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

        [string]$Method   = "GET"
        [string]$Resource = "lists/subscriptions"

        [hashtable]$Parameters = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('all')

    }

    Process {

        If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_.lists }
        
        While (($all.IsPresent) -and ($Results.next_cursor)) {

            $Parameters.cursor = $Results.next_cursor

            If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource }
            Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | % { $_ }
            
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
        
        $Method   = "GET"
        $Resource = "application/rate_limit_status"
        
        [hashtable]$Parameters    = $PSBoundParameters
                   $CmdletBindingParameters | % { $Parameters.Remove($_) }
                   $Parameters.Remove('OAuthSettings')

    }

    Process {

        If (-Not $OAuthSettings) { If (-Not $OAuthSettings) { $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource } }
        Invoke-TwitterAPI -Resource $Resource -Method $Method -Parameters $Parameters -OAuthSettings $OAuthSettings

    }

}
    
# function GET help/configuration
# function GET help/languages
# function GET help/privacy
# function GET help/tos
# function GET trends/closest
# function POST users/report_spam

#endregion ==================================================
    