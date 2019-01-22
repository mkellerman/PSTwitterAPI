function ConvertFrom-RateLimitStatus ($RateLimitStatus) {

    $Eposh = Get-Eposh

    $RateLimitStatus.resources.PSObject.Properties | ForEach-Object {
        $_.value | ForEach-Object {
            $_.PSObject.Properties | ForEach-Object {
                $_ | Select-Object @{ n='accesstoken'; e={ $RateLimitStatus.rate_limit_context.access_token }},
                                   @{ n='resource'; e={ $_.name }},
                                   @{ n='limit'; e={ $_.value.limit }},
                                   @{ n='remaining'; e={ $_.value.remaining }},
                                   @{ n='reset'; e={ $_.value.reset }}
            }
        }
    }

    # No idea why, but '/statuses/update' is missing from the RateLimitStatus result.
    "/statuses/update" | Select-Object @{ n='accesstoken'; e={ $RateLimitStatus.rate_limit_context.access_token }},
                                       @{ n='resource'; e={ $_ }},
                                       @{ n='limit'; e={ 15 }},
                                       @{ n='remaining'; e={ 15 }},
                                       @{ n='reset'; e={ $Eposh.TotalSeconds }}

}