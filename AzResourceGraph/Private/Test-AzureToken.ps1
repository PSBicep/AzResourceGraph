<#
.SYNOPSIS
Validates an Azure access token for audience and remaining lifetime.

.DESCRIPTION
Test-AzureToken checks whether the supplied Microsoft EntraID access
token is still valid for a specified resource and for at least a minimum
number of minutes. The function is used internally by AzResourceGraph to decide when to acquire
or refresh tokens.

.PARAMETER Token
The access token object returned by Get-AzToken.
May be $null; the function returns $false in that case.

.PARAMETER Resource
The audience (aud claim) the token must match.
Defaults to https://management.azure.com.

.PARAMETER MinValid
The minimum amount of time, in minutes, that the token must remain valid.
Default is 15 minutes.

.OUTPUTS
Boolean. Returns $true when the token is valid, otherwise $false.

.EXAMPLE
$token = Get-AzToken -ResourceUrl 'https://management.azure.com'
Test-AzureToken -Token $token                  # -> $true

.EXAMPLE
# Fails if token expires in less than 60 minutes
Test-AzureToken -Token $tok -MinValid 60       # -> $false
#>

function Test-AzureToken {
    param (
        [Parameter(Mandatory)]
        [AllowNull()]
        $Token,

        [Parameter()]
        $Resource = 'https://management.azure.com',

        [Parameter()]
        $MinValid = 15
    )
    return (
        $null -ne $Token -and
        $Token.ExpiresOn.UtcDateTime -ge [System.DateTimeOffset]::Now.AddMinutes($MinValid).UtcDateTime -and
        $Resource -eq $Token.Claims['aud']
    )
}