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
Get-TwitterUsers_Lookup -screen_name 'mkellerman'

```

## Completed API Helper endpoints [To be tested]
- Get-TwitterApplication_RateLimitStatus
- Get-TwitterAccount_Settings
- Get-TwitterAccount_VerifyCredentials
- Get-TwitterBlocks_Ids
- Get-TwitterBlocks_List
- Get-TwitterCollections_Entries
- Get-TwitterCollections_List
- Get-TwitterCollections_Show
- Get-TwitterEvent
- Get-TwitterEvents
- Get-TwitterFavorites_List
- Get-TwitterFollowers_Ids
- Get-TwitterFollowers_List
- Get-TwitterFriendships_Incoming
- Get-TwitterFriendships_Lookup
- Get-TwitterFriendships_NoRetweets_Ids
- Get-TwitterFriendships_Show
- Get-TwitterFriends_Ids
- Get-TwitterFriends_List
- Get-TwitterGeo_Id_PlaceId
- Get-TwitterGeo_ReverseGeocode
- Get-TwitterGeo_Search
- Get-TwitterLists_List
- Get-TwitterLists_Members
- Get-TwitterLists_Memberships
- Get-TwitterLists_Members_Show
- Get-TwitterLists_Ownerships
- Get-TwitterLists_Show
- Get-TwitterLists_Statuses
- Get-TwitterLists_Subscribers
- Get-TwitterLists_Subscribers_Show
- Get-TwitterLists_Subscriptions
- Get-TwitterMutes_Users_Ids
- Get-TwitterMutes_Users_List
- Get-TwitterSavedSearches_List
- Get-TwitterSavedSearches_Show_Id
- Get-TwitterStatuses_HomeTimeline
- Get-TwitterStatuses_Lookup
- Get-TwitterStatuses_MentionsTimeline
- Get-TwitterStatuses_Retweeters_Ids
- Get-TwitterStatuses_RetweetsOfMe
- Get-TwitterStatuses_Retweets_Id
- Get-TwitterStatuses_Sample
- Get-TwitterStatuses_Show_Id
- Get-TwitterStatuses_UserTimeline
- Get-TwitterTrends_Available
- Get-TwitterTrends_Closest
- Get-TwitterTrends_Place
- Get-TwitterUsers_Lookup
- Get-TwitterUsers_ProfileBanner
- Get-TwitterUsers_Search
- Get-TwitterUsers_Show
- Get-TwitterUsers_Suggestions_Slug_Members
- Get-TwitterWelcome_Message
- Get-TwitterWelcome_Messages
- Get-TwitterWelcome_Message_Rule
- Get-TwitterWelcome_Message_Rules
- Send-TwitterAccount_RemoveProfileBanner
- Send-TwitterAccount_Settings
- Send-TwitterAccount_UpdateProfile
- Send-TwitterAccount_UpdateProfileBackgroundImage
- Send-TwitterAccount_UpdateProfileBanner
- Send-TwitterAccount_UpdateProfileImage
- Send-TwitterBlocks_Create
- Send-TwitterBlocks_Destroy
- Send-TwitterCollections_Create
- Send-TwitterCollections_Destroy
- Send-TwitterCollections_Entries_Add
- Send-TwitterCollections_Entries_Curate
- Send-TwitterCollections_Entries_Move
- Send-TwitterCollections_Entries_Remove
- Send-TwitterCollections_Update
- Send-TwitterEvent
- Send-TwitterFavorites_Create
- Send-TwitterFavorites_Destroy
- Send-TwitterFriendships_Create
- Send-TwitterFriendships_Destroy
- Send-TwitterFriendships_Update
- Send-TwitterLists_Create
- Send-TwitterLists_Destroy
- Send-TwitterLists_Members_Create
- Send-TwitterLists_Members_CreateAll
- Send-TwitterLists_Members_Destroy
- Send-TwitterLists_Members_DestroyAll
- Send-TwitterLists_Subscribers_Create
- Send-TwitterLists_Subscribers_Destroy
- Send-TwitterLists_Update
- Send-TwitterMedia_Metadata_Create
- Send-TwitterMedia_Subtitles_Create
- Send-TwitterMedia_Subtitles_Delete
- Send-TwitterMedia_Upload
- Send-TwitterMedia_Upload_Append
- Send-TwitterMedia_Upload_Init
- Send-TwitterMutes_Users_Create
- Send-TwitterMutes_Users_Destroy
- Send-TwitterRead_Receipt
- Send-TwitterSavedSearches_Create
- Send-TwitterSavedSearches_Destroy_Id
- Send-TwitterStatuses_Destroy_Id
- Send-TwitterStatuses_Filter
- Send-TwitterStatuses_Retweet_Id
- Send-TwitterStatuses_Unretweet_Id
- Send-TwitterStatuses_Update
- Send-TwitterStatuses_UpdateWithMedia
- Send-TwitterTyping_Indicator
- Send-TwitterUsers_ReportSpam
- Send-TwitterWelcome_Message
- Send-TwitterWelcome_Message_Rule

## Resources

- https://twittercommunity.com/t/how-to-get-my-api-key/7033
- https://dev.twitter.com/rest/public

