$ErrorActionPreference = 'Stop'

function Get-APIHelperResources {

    $baseUrl = 'https://developer.twitter.com/en/docs/api-reference-index'
    Write-Warning $baseUrl
    Enter-SeUrl -Driver $Driver -Url $baseUrl

    $eApiReferencesIndex = $Driver.FindElementByCssSelector('div[class$="-api-references-index"]')
    $ApiResources = $eApiReferencesIndex.FindElementsByCssSelector('a[class$="_link"]').Where({($_.Text -match "GET ") -or ($_.Text -match "POST ")}) |
                    Select-Object @{n="Method"; e={($_.Text -Split " ")[0]}}, @{n="Resource"; e={"/" + ($_.Text -Split " ")[1]}}, @{n="ReferenceUrl"; e={$_.GetAttribute('href')}}

    # Add Missing References from Index page
    $ApiResources += [PSCustomObject]@{ Method = 'GET'; Resource = "/application/rate_limit_status"; ReferenceUrl = 'https://developer.twitter.com/en/docs/developer-utilities/rate-limit-status/api-reference/get-application-rate_limit_status' }
    $ApiResources += [PSCustomObject]@{ Method = 'GET'; Resource = "/search/tweets"; ReferenceUrl = 'https://developer.twitter.com/en/docs/tweets/search/api-reference/get-search-tweets' }
    $ApiResources += [PSCustomObject]@{ Method = 'DELETE'; Resource = "/custom_profiles/destroy"; ReferenceUrl = 'https://developer.twitter.com/en/docs/direct-messages/custom-profiles/api-reference/delete-profile' }
    $ApiResources += [PSCustomObject]@{ Method = 'GET'; Resource = "/help/configuration"; ReferenceUrl = 'https://developer.twitter.com/en/docs/developer-utilities/configuration/api-reference/get-help-configuration' }
    $ApiResources += [PSCustomObject]@{ Method = 'GET'; Resource = "/help/languages"; ReferenceUrl = 'https://developer.twitter.com/en/docs/developer-utilities/supported-languages/api-reference/get-help-languages' }
    $ApiResources += [PSCustomObject]@{ Method = 'GET'; Resource = "/help/privacy"; ReferenceUrl = 'https://developer.twitter.com/en/docs/developer-utilities/privacy-policy/api-reference/get-help-privacy' }
    $ApiResources += [PSCustomObject]@{ Method = 'GET'; Resource = "/help/tos"; ReferenceUrl = 'https://developer.twitter.com/en/docs/developer-utilities/terms-of-service/api-reference/get-help-tos' }

}

function Get-APIHelperFunction ($ApiResource) {

    
    Write-Warning $ApiResource.ReferenceUrl
    Enter-SeUrl -Driver $Driver -Url $ApiResource.ReferenceUrl

    $eResourceReference = $Driver.FindElementByCssSelector('div[class="c01-rich-text-editor"]').FindElementByTagName("div").FindElementsByXPath("*")

    $eResource = @{}
    $Parameter = "Description"
    $eResource[$Parameter] = @()

    ForEach($eReference in $eResourceReference) {

        Switch ($eReference.Text) {
            "Resource URL" { $Parameter = "ResourceUrl"; $SkipLine = $True }
            "Resource Information" { $Parameter = "ResourceInformation"; $SkipLine = $True }
            "Resource Infromation" { $Parameter = "ResourceInformation"; $SkipLine = $True }
            "Parameters" { $Parameter = "Parameters"; $SkipLine = $True }
            "Example Request" { $parameter = "ExampleRequest"; $SkipLine = $True }
            "Example Response" { $parameter = "ExampleResponse"; $SkipLine = $True }
            Default { $SkipLine = $False }
        }
        If ($SkipLine) { $eResource[$Parameter] = @(); Continue }
        $eResource[$Parameter] += $eReference

    }

    $Result = @{}
    $Result['fDescription'] = $Driver.FindElementByTagName("h1").Text
    ForEach($Key in $eResource.Keys) {
        Switch ($Key) {
            'Parameters' {

                $Parameters = @()
                $eParameters = $eResource[$Key].FindElementsByTagName('tr')
                ForEach($eParameter in $eParameters) {

                    $ParameterColumns = $eParameter.FindElementsByTagName('td').Text
                    If (-Not($ParameterColumns)) { Continue }
                    If ($ParameterColumns[0] -eq 'Name') { Continue }

                    $Parameters += [PSCustomObject]@{
                        Name = $ParameterColumns[0]
                        Required = $ParameterColumns[1]
                        Description = $ParameterColumns[2]
                        DefaultValue = $ParameterColumns[3]
                        Example = $ParameterColumns[4]
                    }

                }
                $Result[$Key] = $Parameters
            }
            Default {
                $Result[$Key] = ( $eResource[$Key].Text | ? { $_ } ) -Join "`r`n`r`n"
            }
        }
    }

    $ApiResource | Add-Member -MemberType NoteProperty -Name ReferenceProperties -Value ([PSCustomObject]$Result) -Force

}

Import-Module Selenium
$Driver = Start-SeChrome

$ApiResources = Get-APIHelperResources

ForEach($ApiResource in $ApiResources) {

    $ApiResource = Get-APIHelperFunction -ApiResource $ApiResource

}

$ApiResources | ConvertTo-Json -Depth 5 | Set-Content ".\twitter_api.json"