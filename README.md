# PSTwitterAPI

## Features

- API Helpers cmdlets to mimic the Twitter API enpoints.
- Handles loops to request more data (eg: 200 tweets per call).
- You can set multiple ApiKey/Token.
- Handles rate limit for you, and rotate through your ApiKeys.

## Installation

```powershell
Install-Module PSTwitterAPI
```

## Getting started

```powershell

Import-Module PSTwitterAPI

$OAuthSettings = @{
  ApiKey = $env:ApiKey
  ApiSecret = $env:ApiSecret
  AccessToken = $env:AccessToken
  AccessTokenSecret =$env:AccessTokenSecret
}
Set-TwitterOAuthSettings @OAuthSettings

# Use one of the API Helpers provided:
Get-TwitterUser_Lookup -screen_name 'mkellerman'

# Use TwitterAPI rest method directly:
Invoke-TwitterAPI -Resource 'statuses/update' -Parameters @{ status = 'Hello World!' }
```

## Completed API Helper endpoints

- Get-TwitterApplication_RateLimitStatus
- Get-TwitterFollowers_IDs
- Get-TwitterFriends_IDs
- Get-TwitterLists_list
- Get-TwitterLists_Subscriptions
- Get-TwitterSearch_Tweets
- Get-TwitterStatuses_HomeTimeline
- Get-TwitterStatuses_Lookup
- Get-TwitterStatuses_MentionsTimeline
- Get-TwitterStatuses_Retweeters_IDs
- Get-TwitterStatuses_RetweetsID
- Get-TwitterStatuses_RetweetsOfMe
- Get-TwitterStatuses_ShowID
- Get-TwitterStatuses_UserTimeline
- Get-TwitterUser_Lookup
- Send-TwitterStatuses_DestroyID
- Send-TwitterStatuses_RetweetID
- Send-TwitterStatuses_UnretweetID
- Send-TwitterStatuses_Update

## Resources

- https://twittercommunity.com/t/how-to-get-my-api-key/7033
- https://dev.twitter.com/rest/public

