<#
.SYNOPSIS
Connects the current PowerShell session to Azure Resource Graph and caches an access token in memory.

.DESCRIPTION
Connect-AzResourceGraph authenticates to Entra ID using one of four flows:
  • Interactive user sign-in (default)
  • Service principal with client secret
  • Service principal with certificate
  • Managed Identity (system- or user-assigned)

The obtained token is stored in module scope and automatically reused until it expires.
All subsequent AzResourceGraph cmdlets rely on this cached token; therefore, call this
function once at the beginning of your session or script.

.PARAMETER Tenant
EntraID tenant ID (GUID) or tenant domain name.

.PARAMETER ClientId
Application (service principal) client ID.
Defaults to the public Azure PowerShell client ID
`1950a258-227b-4e31-a9cf-717495945fc2` for interactive sign-in.

.PARAMETER CertificatePath
Path to a PFX or CER file, or a certificate thumbprint in the local
certificate store, used for certificate-based service-principal auth.

.PARAMETER ClientSecret
Client secret string associated with the service principal.

.PARAMETER ManagedIdentity
Switch indicating that the command should acquire a token using the
Azure Managed Identity assigned to the current VM / App Service / container.

.PARAMETER ManagementEndpoint
Endpoint used for management. This is used for the Audience claim when authenticating to Azure.
For global Azure, this should be left as the default of 'https://management.azure.com'.
For Azure China, use 'https://management.chinacloudapi.cn' and for US Government Cloud use 'https://management.usgovcloudapi.net'.

.EXAMPLE
# 1. Interactive sign-in (prompts user)
Connect-AzResourceGraph

.EXAMPLE
# 2. Managed Identity inside an Azure resource
Connect-AzResourceGraph -ManagedIdentity

.EXAMPLE
# 3. Service principal with client secret
Connect-AzResourceGraph -Tenant 'contoso.onmicrosoft.com' `
                         -ClientId '00000000-0000-0000-0000-000000000000' `
                         -ClientSecret (Get-Content '.\sp-secret.txt' -Raw)

.EXAMPLE
# 4. Service principal with certificate
Connect-AzResourceGraph -Tenant '72f988bf-86f1-41af-91ab-2d7cd011db47' `
                         -ClientId  '00000000-0000-0000-0000-000000000000' `
                         -CertificatePath '.\sp-cert.pfx'

#>
function Connect-AzResourceGraph {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSAvoidDefaultValueForMandatoryParameter",
        "ClientId",
        Justification = "Client Id is only mandatory for certain auth flows."
    )]
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(Mandatory, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [ValidateNotNullOrEmpty()]
        [string]$Tenant,

        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(Mandatory, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [ValidateNotNullOrEmpty()]
        [string]$ClientId = '1950a258-227b-4e31-a9cf-717495945fc2', # Default Azure PowerShell ClientId

        [Parameter(Mandatory, ParameterSetName = 'Certificate')]
        [string]$CertificatePath,

        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [string]$ClientSecret,

        [Parameter(Mandatory, ParameterSetName = 'ManagedIdentity')]
        [switch]$ManagedIdentity,

        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Certificate')]
        [Parameter(ParameterSetName = 'ClientSecret')]
        $ManagementEndpoint = 'https://management.azure.com'
    )

    # Set up module-scoped variables for getting tokens
    $script:TokenSplat = @{}
    $script:CertificatePath = $null

    $script:TokenSplat['Resource'] = $ManagementEndpoint
    $script:TokenSplat['ClientId'] = $ClientId
    if ($PSBoundParameters.ContainsKey('Tenant')) {
        $script:TokenSplat['TenantId'] = $Tenant
    }
    if ($PSBoundParameters.ContainsKey('CertificatePath')) {
        $script:CertificatePath = $CertificatePath
        $Certificate = Get-Item $CertificatePath

        if ($Certificate -is [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
            $script:TokenSplat['ClientCertificate'] = Get-Item $CertificatePath
        }
        else {
            $script:TokenSplat['ClientCertificatePath'] = $CertificatePath
        }
    }
    if ($PSBoundParameters.ContainsKey('ClientSecret')) {
        $script:TokenSplat['ClientSecret'] = $ClientSecret
    }
    if ($PSCmdlet.ParameterSetName -eq 'Interactive') {
        $script:TokenSplat['Interactive'] = $true
        $script:TokenSplat['TokenCache'] = 'AzResourceGraph'
    }
    if ($ManagedIdentity.IsPresent) {
        $script:TokenSplat['ManagedIdentity'] = $true
    }

    $script:Token = Get-AzToken @script:TokenSplat
    # Save the source of the token to module scope for AssertAzureConnection to know how to refresh it
    $script:TokenSource = 'Module'
    if ($script:TokenSplat['Interactive'] -eq $true) {
        $script:TokenSplat['UserName'] = $script:Token.Identity
    }
}