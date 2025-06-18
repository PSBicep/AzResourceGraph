<#
.SYNOPSIS
Disconnects the current PowerShell session from Azure Resource Graph and clears cached access token in memory.

.DESCRIPTION
Disconnect-AzResourceGraph removes any stored session information and resets sessions configuration.

.EXAMPLE
# 1. Disconnect and clear session information
Disconnect-AzResourceGraph

#>
function Disconnect-AzResourceGraph {
    [CmdletBinding()]
    param ()

    $script:TokenSplat = @{}
    $script:TokenSource = 'Global'
    $script:Token = $null
    $script:CertificatePath = $null
}