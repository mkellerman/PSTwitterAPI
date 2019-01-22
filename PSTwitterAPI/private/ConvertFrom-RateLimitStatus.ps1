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