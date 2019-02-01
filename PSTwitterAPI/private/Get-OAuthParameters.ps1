function Get-OAuthParameters {

    [OutputType('System.Management.Automation.PSCustomObject')]
    Param($ApiKey, $ApiSecret, $AccessToken, $AccessTokenSecret, $Method, $ResourceUrl, $Parameters, $Body)

    Process{

        Try {

            ## Generate a random 32-byte string. I'm using the current time (in seconds) and appending 5 chars to the end to get to 32 bytes
	        ## Base64 allows for an '=' but Twitter does not.  If this is found, replace it with some alphanumeric character
	        $OAuthNonce = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes("$([System.DateTime]::Now.Ticks.ToString())12345"))).Replace('=', 'g')

            ## Find the total seconds since 1/1/1970 (epoch time)
		    $OAuthTimestamp = [System.Convert]::ToInt64((Get-Eposh).TotalSeconds).ToString();

            ## EscapeDataString the parameters
            $EscapedParameters = @{}
            foreach($Param in $($Parameters.Keys)){
                $EscapedParameters[$Param] = "$([System.Uri]::EscapeDataString($Parameters[$Param]))".Replace("!","%21").Replace("'","%27").Replace("(","%28").Replace(")","%29").Replace("*","%2A")
            }

            ## Build the enpoint url
            $EndPointUrl = "${ResourceUrl}?"
            $EscapedParameters.GetEnumerator() | Where-Object { $_.Value -is [string] } | Sort-Object Name | ForEach-Object { $EndPointUrl += "$($_.Key)=$($_.Value)&" }
            $EndPointUrl = $EndPointUrl.TrimEnd('&')

            ## Build the signature
            $SignatureBase = "$([System.Uri]::EscapeDataString("${ResourceUrl}"))&"
			$SignatureParams = @{
				'oauth_consumer_key' = $ApiKey;
				'oauth_nonce' = $OAuthNonce;
				'oauth_signature_method' = 'HMAC-SHA1';
				'oauth_timestamp' = $OAuthTimestamp;
				'oauth_token' = $AccessToken;
				'oauth_version' = "1.0";
            }
            $EscapedParameters.Keys | ForEach-Object { $SignatureParams.Add($_ , $EscapedParameters.Item($_)) }

			## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &
			## Remove the URL encoded & at the end and prepend the necessary 'POST&' verb to the front
			$SignatureParams.GetEnumerator() | Sort-Object Name | ForEach-Object { $SignatureBase += [System.Uri]::EscapeDataString("$($_.Key)=$($_.Value)&") }

            $SignatureBase = $SignatureBase.Substring(0,$SignatureBase.Length-3)
			$SignatureBase = $Method+'&' + $SignatureBase

			## Create the hashed string from the base signature
			$SignatureKey = [System.Uri]::EscapeDataString($ApiSecret) + "&" + [System.Uri]::EscapeDataString($AccessTokenSecret);

			$hmacsha1 = New-Object System.Security.Cryptography.HMACSHA1;
			$hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($SignatureKey);
			$OAuthSignature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($SignatureBase)));

			## Build the authorization headers using most of the signature headers elements.  This is joining all of the 'Key=Value' elements again
			## and only URL encoding the Values this time while including non-URL encoded double quotes around each value
			$OAuthParameters = $SignatureParams
			$OAuthParameters.Add('oauth_signature', $OAuthSignature)

            $OAuthString = 'OAuth '
            $OAuthParameters.GetEnumerator() | Sort-Object Name | ForEach-Object { $OAuthString += $_.Key + '="' + [System.Uri]::EscapeDataString($_.Value) + '", ' }
            $OAuthString = $OAuthString.TrimEnd(', ')
            Write-Verbose "Using authorization string '$OAuthString'"

            $OAuthParameters.Add('endpoint_url', $EndPointUrl)
            $OAuthParameters.Add('endpoint_method', $Method)
            $OAuthParameters.Add('endpoint_authorization', $OAuthString)

            # If Body is required, change contenttype to json
            # Example: Send-TwitterDirectMessages_EventsNew
            If ($Body) {
                $OAuthParameters.Add('endpoint_contentType', "application/json")
                $OAuthParameters.Add('endpoint_body', "$($Body | ConvertTo-Json -Depth 99 -Compress)")
            } Else {
                $OAuthParameters.Add('endpoint_contentType', "application/x-www-form-urlencoded")
            }

            Return $OAuthParameters

        } Catch {
			Write-Error $_.Exception.Message
		}

    }

}