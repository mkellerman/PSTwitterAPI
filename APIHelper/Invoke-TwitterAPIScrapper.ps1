Import-Module Selenium

$ErrorActionPreference = 'Stop'

$baseUrl = 'https://developer.twitter.com/en/docs/api-reference-index'
$Driver = Start-SeChrome

Write-Warning $baseUrl
Enter-SeUrl -Driver $Driver -Url $baseUrl

$eApiReferencesIndex = $Driver.FindElementByCssSelector('div[class$="-api-references-index"]')
$ApiResources = $eApiReferencesIndex.FindElementsByCssSelector('a[class$="_link"]').Where({($_.Text -match "GET ") -or ($_.Text -match "POST ")}) |
                Select-Object @{n="Method"; e={($_.Text -Split " ")[0]}}, @{n="Resource"; e={"/" + ($_.Text -Split " ")[1]}}, @{n="ReferenceUrl"; e={$_.GetAttribute('href')}}

ForEach($ApiResource in $ApiResources) {

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

$ApiResources | ConvertTo-Json -Compress -Depth 5 | Set-Content ".\twitter_api.json"