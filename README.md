[![PSGallery Version](https://img.shields.io/powershellgallery/v/PSTwitterAPI.svg?style=for-the-badge&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/PSTwitterAPI/)
![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/PSTwitterAPI.svg?style=for-the-badge&label=Downloads)

![Azure Pipeline](https://img.shields.io/azure-devops/build/mkellerman/PSTwitterAPI/7.svg?style=for-the-badge&label=Azure%20Pipeline)

# PSTwitterAPI

## Features

- API Helpers cmdlets to mimic +120 Twitter API enpoints.
- You can set multiple ApiKey/Token.
- Handles rate limit for you, and rotate through your ApiKeys.
- [WIP] Handles loops to request more data (eg: 200 tweets per call). 

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
 - Get-TwitterAccount_Settings
 - Get-TwitterAccount_VerifyCredentials
 - Get-TwitterApplication_RateLimitStatus
 - Get-TwitterBlocks_Ids
 - Get-TwitterBlocks_List
 - Get-TwitterCollections_Entries
 - Get-TwitterCollections_List
 - Get-TwitterCollections_Show
 - Get-TwitterCustomProfiles__Id
 - Get-TwitterCustomProfiles_List
 - Get-TwitterDirectMessages_EventsList
 - Get-TwitterDirectMessages_EventsShow
 - Get-TwitterDirectMessages_WelcomeMessagesList
 - Get-TwitterDirectMessages_WelcomeMessagesRulesList
 - Get-TwitterDirectMessages_WelcomeMessagesRulesShow
 - Get-TwitterDirectMessages_WelcomeMessagesShow
 - Get-TwitterFavorites_List
 - Get-TwitterFollowers_Ids
 - Get-TwitterFollowers_List
 - Get-TwitterFriends_Ids
 - Get-TwitterFriends_List
 - Get-TwitterFriendships_Incoming
 - Get-TwitterFriendships_Lookup
 - Get-TwitterFriendships_NoRetweetsIds
 - Get-TwitterFriendships_Outgoing
 - Get-TwitterFriendships_Show
 - Get-TwitterGeo_Id_PlaceId
 - Get-TwitterGeo_ReverseGeocode
 - Get-TwitterGeo_Search
 - Get-TwitterHelp_Configuration
 - Get-TwitterHelp_Languages
 - Get-TwitterHelp_Privacy
 - Get-TwitterHelp_Tos
 - Get-TwitterLists_List
 - Get-TwitterLists_Members
 - Get-TwitterLists_Memberships
 - Get-TwitterLists_MembersShow
 - Get-TwitterLists_Ownerships
 - Get-TwitterLists_Show
 - Get-TwitterLists_Statuses
 - Get-TwitterLists_Subscribers
 - Get-TwitterLists_SubscribersShow
 - Get-TwitterLists_Subscriptions
 - Get-TwitterMutes_UsersIds
 - Get-TwitterMutes_UsersList
 - Get-TwitterOauth_Authenticate
 - Get-TwitterOauth_Authorize
 - Get-TwitterSavedSearches_List
 - Get-TwitterSavedSearches_Show_Id
 - Get-TwitterSearch_Tweets
 - Get-TwitterStatuses_HomeTimeline
 - Get-TwitterStatuses_Lookup
 - Get-TwitterStatuses_MentionsTimeline
 - Get-TwitterStatuses_RetweetersIds
 - Get-TwitterStatuses_Retweets_Id
 - Get-TwitterStatuses_RetweetsOfMe
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
 - Get-TwitterUsers_Suggestions_SlugMembers
 - Remove-TwitterCustomProfiles_Destroy
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
 - Send-TwitterCollections_EntriesAdd
 - Send-TwitterCollections_EntriesCurate
 - Send-TwitterCollections_EntriesMove
 - Send-TwitterCollections_EntriesRemove
 - Send-TwitterCollections_Update
 - Send-TwitterCustomProfiles_New.Json
 - Send-TwitterDirectMessages_EventsNew
 - Send-TwitterDirectMessages_IndicateTyping
 - Send-TwitterDirectMessages_MarkRead
 - Send-TwitterDirectMessages_WelcomeMessagesNew
 - Send-TwitterDirectMessages_WelcomeMessagesRulesNew
 - Send-TwitterFavorites_Create
 - Send-TwitterFavorites_Destroy
 - Send-TwitterFriendships_Create
 - Send-TwitterFriendships_Destroy
 - Send-TwitterFriendships_Update
 - Send-TwitterLists_Create
 - Send-TwitterLists_Destroy
 - Send-TwitterLists_MembersCreate
 - Send-TwitterLists_MembersCreateAll
 - Send-TwitterLists_MembersDestroy
 - Send-TwitterLists_MembersDestroyAll
 - Send-TwitterLists_SubscribersCreate
 - Send-TwitterLists_SubscribersDestroy
 - Send-TwitterLists_Update
 - Send-TwitterMedia_MetadataCreate
 - Send-TwitterMedia_SubtitlesCreate
 - Send-TwitterMedia_SubtitlesDelete
 - Send-TwitterMedia_Upload
 - Send-TwitterMutes_UsersCreate
 - Send-TwitterMutes_UsersDestroy
 - Send-TwitterOauth_AccessToken
 - Send-TwitterOauth_InvalidateToken
 - Send-TwitterOauth_RequestToken
 - Send-TwitterOauth2_InvalidateToken
 - Send-TwitterOauth2_Token
 - Send-TwitterSavedSearches_Create
 - Send-TwitterSavedSearches_Destroy_Id
 - Send-TwitterStatuses_Destroy_Id
 - Send-TwitterStatuses_Filter
 - Send-TwitterStatuses_Retweet_Id
 - Send-TwitterStatuses_Unretweet_Id
 - Send-TwitterStatuses_Update
 - Send-TwitterStatuses_UpdateWithMedia
 - Send-TwitterUsers_ReportSpam

## Resources

- https://twittercommunity.com/t/how-to-get-my-api-key/7033
- https://dev.twitter.com/rest/public

