﻿function Get-TwitterSearch_Tweets {
    <#
    .SYNOPSIS
        Search Tweets
    
    .DESCRIPTION
        Standard search API
        
        Returns a collection of relevant Tweets matching a specified query.
        
        Please note that Twitter's search service and, by extension, the Search API is not meant to be an exhaustive source of Tweets. Not all Tweets will be indexed or made available via the search interface.
        
        To learn how to use Twitter Search effectively, please see the Standard search operators page for a list of available filter operators. Also, see the Working with Timelines page to learn best practices for navigating results by since_id and max_id.
    
    .PARAMETER q
        A UTF-8, URL-encoded search query of 500 characters maximum, including operators. Queries may additionally be limited by complexity.
    
    .PARAMETER geocode
        Returns tweets by users located within a given radius of the given latitude/longitude. The location is preferentially taking from the Geotagging API, but will fall back to their Twitter profile. The parameter value is specified by " latitude,longitude,radius ", where radius units must be specified as either " mi " (miles) or " km " (kilometers). Note that you cannot use the near operator via the API to geocode arbitrary locations; however you can use this geocode parameter to search near geocodes directly. A maximum of 1,000 distinct "sub-regions" will be considered when using the radius modifier.
    
    .PARAMETER lang
        Restricts tweets to the given language, given by an ISO 639-1 code. Language detection is best-effort.
    
    .PARAMETER locale
        Specify the language of the query you are sending (only ja is currently effective). This is intended for language-specific consumers and the default should work in the majority of cases.
    
    .PARAMETER result_type
        Optional. Specifies what type of search results you would prefer to receive. The current default is "mixed." Valid values include:
            * mixed : Include both popular and real time results in the response.
            * recent : return only the most recent results in the response
            * popular : return only the most popular results in the response.
    
    .PARAMETER count
        The number of tweets to return per page, up to a maximum of 100. Defaults to 15. This was formerly the "rpp" parameter in the old Search API.
    
    .PARAMETER until
        Returns tweets created before the given date. Date should be formatted as YYYY-MM-DD. Keep in mind that the search index has a 7-day limit. In other words, no tweets will be found for a date older than one week.
    
    .PARAMETER since_id
        Returns results with an ID greater than (that is, more recent than) the specified ID. There are limits to the number of Tweets which can be accessed through the API. If the limit of Tweets has occured since the since_id, the since_id will be forced to the oldest ID available.
    
    .PARAMETER max_id
        Returns results with an ID less than (that is, older than) or equal to the specified ID.
    
    .PARAMETER include_entities
        The entities node will not be included when set to false.
    
    .PARAMETER tweet_mode
        Valid request values are compat and extended, which give compatibility mode and extended mode, respectively for Tweets that contain over 140 characters

    .NOTES
        This helper function was generated by the information provided here:
        https://developer.twitter.com/en/docs/tweets/search/api-reference/get-search-tweets
    
    #>
        [CmdletBinding()]
        Param(
            [string]$q,
            [string]$geocode,
            [string]$lang,
            [string]$locale,
            [string]$result_type,
            [string]$count = 15,
            [string]$until,
            [string]$since_id,
            [string]$max_id,
            [string]$include_entities,
            [string]$tweet_mode
        )
        Begin {
    
            [hashtable]$Parameters = $PSBoundParameters
                       $CmdletBindingParameters | ForEach-Object { $Parameters.Remove($_) }
    
            [string]$Method      = 'GET'
            [string]$Resource    = '/search/tweets'
            [string]$ResourceUrl = 'https://api.twitter.com/1.1/search/tweets.json'
    
        }
        Process {
    
            # Find & Replace any ResourceUrl parameters.
            $UrlParameters = [regex]::Matches($ResourceUrl, '(?<!\w):\w+')
            ForEach ($UrlParameter in $UrlParameters) {
                $UrlParameterValue = $Parameters["$($UrlParameter.Value.TrimStart(":"))"]
                $ResourceUrl = $ResourceUrl -Replace $UrlParameter.Value, $UrlParameterValue
            }
    
            Do {
    
                $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource
                Invoke-TwitterAPI -Method $Method -ResourceUrl $ResourceUrl -Parameters $Parameters -OAuthSettings $OAuthSettings | Tee-Object -Variable Results | Select-Object -Expand statuses
                
                $Parameters['max_id'] = $Results.search_metadata.max_id
                $Parameters['count'] = ([int]($Parameters['count'])) - ([int]($Results.statuses.Count))
                If ($Parameters['count'] -le 0) { Return }
    
            } While ($Results.search_metadata.next_results)
    
        }
        End {
    
        }
    }
    
