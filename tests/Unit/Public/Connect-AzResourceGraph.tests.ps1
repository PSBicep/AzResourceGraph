BeforeAll {
    Import-Module -FullyQualifiedName "$PSScriptRoot/../../../output/module/AzResourceGraph"
}

Describe 'Connect-AzResourceGraph' {
    InModuleScope 'AzResourceGraph' {
        BeforeEach {
            # Mock the Get-AzToken function to avoid actual authentication
            Mock 'Get-AzToken' {
                @{
                    Token = 'dummy'
                    ExpiresOn = [System.DateTimeOffset]::Now.AddHours(1)
                    Claims = @{
                        aud = 'myApp'
                    }
                }
            }
        }
        Context 'Successful token retrieval' {
            It 'Triggers Interactive login when no parameters are provided' {
                Connect-AzResourceGraph
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $Interactive -eq $true
                }
            }

            It 'Passes on TenantId to Get-AzToken' {
                Connect-AzResourceGraph -Tenant 'myTenant'
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $TenantId -eq 'myTenant'
                }
            }

            It 'Passes on ClientSecret to Get-AzToken' {
                Connect-AzResourceGraph -Tenant 'myTenant' -ClientId 'myApp' -ClientSecret 'mySecret'
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $ClientSecret -eq 'mySecret'
                }
            }

            It 'Passes on ManagedIdentity to Get-AzToken' {
                Connect-AzResourceGraph -ManagedIdentity
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $ManagedIdentity.IsPresent -eq $true
                }
            }

            It 'Passses ClientCertificatePath to Get-AzToken as ClientCertificate' {
                Mock 'Get-Item' { New-MockObject -Type 'System.Security.Cryptography.X509Certificates.X509Certificate2' }
                $Params = @{
                    CertificatePath = 'Foo'
                    Tenant   = 'MyTenantId'
                    ClientId = 'MyClientId'
                }
                Connect-AzResourceGraph @Params
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $null -eq $ClientCertificatePath -and $ClientCertificate.GetType().FullName -eq 'System.Security.Cryptography.X509Certificates.X509Certificate2'
                }
            }

            It 'Passses ClientCertificatePath to Get-AzToken as ClientCertificatePath' {
                Mock 'Get-Item' { New-MockObject -Type 'System.IO.FileInfo' }
                $Params = @{
                    CertificatePath = 'Foo'
                    Tenant   = 'MyTenantId'
                    ClientId = 'MyClientId'
                }
                Connect-AzResourceGraph @Params
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $ClientCertificatePath -eq 'Foo' -and $null -eq $ClientCertificate
                }
            }
        }

    }
}