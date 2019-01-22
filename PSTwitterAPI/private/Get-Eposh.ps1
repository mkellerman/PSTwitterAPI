function Get-Eposh {

    [CmdletBinding()]
    Param (
        [int]$Eposh
    )

    Process {

        If ($Eposh) {
            [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($Eposh))
        } Else {
            $unixEpochStart = New-Object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
            [DateTime]::UtcNow - $unixEpochStart
        }

    }

}