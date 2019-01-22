# PSTwitterAPI

## Installation
```powershell
Install-Module PSTwitterAPI
```

## Features

## Getting started
```powershell
Invoke-TwitterAPI
Set-TwitterOAuthSettings
Get-TwitterOAuthSettings
```

## Completed API Helper endpoints:

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

## Missing API Helpter endpoints:

- POST statuses/update_with_media
- GET statuses/oembed
- POST media/upload
- POST media/upload chunked
- GET direct_messages/sent
- GET direct_messages/show
- GET direct_messages
- POST direct_messages/destroy
- POST direct_messages/new
- GET friendships/no_retweets/ids
- GET friendships/incoming
- GET friendships/outgoing
- POST friendships/create
- POST friendships/destroy
- POST friendships/update
- GET friendships/show
- GET friends/list
- GET followers/list
- GET friendships/lookup
- GET account/settings
- GET account/verify_credentials
- POST account/settings
- POST account/update_delivery_device
- POST account/update_profile
- POST account/update_profile_background_image
- POST account/update_profile_image
- GET blocks/list
- GET blocks/ids
- POST blocks/create
- POST blocks/destroy
- GET users/show
- GET users/search
- POST account/remove_profile_banner
- POST account/update_profile_banner
- GET users/profile_banner
- POST mutes/users/create
- POST mutes/users/destroy
- GET mutes/users/ids
- GET mutes/users/list
- GET users/suggestions/:slug
- GET users/suggestions
- GET users/suggestions/:slug/members
- GET favorites/list
- POST favorites/destroy
- POST favorites/create
- GET lists/statuses
- POST lists/members/destroy
- GET lists/memberships
- GET lists/subscribers
- POST lists/subscribers/create
- GET lists/subscribers/show
- POST lists/subscribers/destroy
- POST lists/members/create_all
- GET lists/members/show
- GET lists/members
- POST lists/members/create
- POST lists/destroy
- POST lists/update
- POST lists/create
- GET lists/show
- GET lists/subscriptions
- POST lists/members/destroy_all
- GET lists/ownerships
- GET saved_searches/list
- GET saved_searches/show/:id
- POST saved_searches/create
- POST saved_searches/destroy/:id
- GET geo/id/:place_id
- GET geo/reverse_geocode
- GET geo/search
- POST geo/place
- GET trends/place
- GET trends/available
- GET help/configuration
- GET help/languages
- GET help/privacy
- GET help/tos
- GET trends/closest
- POST users/report_spam