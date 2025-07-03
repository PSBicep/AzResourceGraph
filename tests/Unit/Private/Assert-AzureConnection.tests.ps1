BeforeAll {
    $script:ModuleName = 'AzResourceGraph'
    Import-Module -FullyQualifiedName "$PSScriptRoot/../../../output/module/AzResourceGraph"
}

Describe 'Assert-AzureConnection' {
    InModuleScope 'AzResourceGraph' {
        Context 'when valid token exists' {
            BeforeEach {
                Mock 'Test-AzureToken' { return $true }
                Mock 'Get-AzToken' {}
            }
            It 'does not call Get-AzToken' {
                Assert-AzureConnection -TokenSplat @{}
                Should -Invoke 'Test-AzureToken' -Times 1 -Exactly
                Should -Invoke 'Get-AzToken' -Times 0 -Exactly
            }
        }

        Context 'when Token invalid and TokenSource not Module' {
            BeforeEach {
                $script:Token = $null
                $script:TokenSource = 'Other'
                Mock Test-AzureToken { return $false }
            }
            It 'Calls Get-AzToken and sets script:Token on success' {
                # Returning inbound parameters allows for easy validation of parameter usage
                Mock 'Get-AzToken' { 'ValidToken' }
                Assert-AzureConnection -TokenSplat @{ClientId = 'Foo'} -Resource 'Bar'
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $ClientId -eq 'Foo' -and $Resource -eq 'Bar'
                }
                $script:Token | Should -Be 'ValidToken'
            }
            It 'Throws error when Get-AzToken fails' {
                Mock 'Get-AzToken' { throw 'fail' }
                { Assert-AzureConnection -TokenSplat @{} } | Should -Throw
            }
        }

        Context 'when Token invalid and TokenSource is Module' {
            BeforeEach {
                $script:Token = $null
                $script:TokenSource = 'Module'
                Mock Test-AzureToken { return $false }
            }
            It 'Refreshes token without interactive parameters' {
                Mock 'Get-AzToken' { return 'Refreshed' }
                Assert-AzureConnection -TokenSplat @{Interactive=$true;ClientId='X'}
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $null -eq $Interactive
                }
                $script:Token | Should -Be 'Refreshed'
            }

            It 'Passes ClientCertificatePath to Get-AzToken as ClientCertificatePath' {
                Mock 'Get-AzToken' { return 'RefreshedWithCertificate' }
                Mock 'Get-Item' { 'PathAsString' }
                Assert-AzureConnection -TokenSplat @{
                    ClientCertificatePath = 'Foo'
                    TenantId = 'MyTenantId'
                    ClientId = 'MyClientId'
                }
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $ClientCertificatePath -eq 'Foo' -and $null -eq $ClientCertificate
                }
                $script:Token | Should -Be 'RefreshedWithCertificate'
            }

            It 'Passes ClientCertificatePath to Get-AzToken as ClientCertificate' {
                Mock 'Get-AzToken' { return 'RefreshedWithCertificate' }
                Mock 'Get-Item' { New-MockObject -Type 'System.Security.Cryptography.X509Certificates.X509Certificate2' }
                Assert-AzureConnection -TokenSplat @{
                    ClientCertificatePath = 'Foo'
                    TenantId = 'MyTenantId'
                    ClientId = 'MyClientId'
                }
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $null -eq $ClientCertificatePath -and $ClientCertificate.GetType().FullName -eq 'System.Security.Cryptography.X509Certificates.X509Certificate2'
                }
                $script:Token | Should -Be 'RefreshedWithCertificate'
            }

            It 'Passes ClientCertificatePath to Get-AzToken as ClientCertificatePath' {
                Mock 'Get-AzToken' { return 'RefreshedWithCertificate' }
                Mock 'Get-Item' { New-MockObject -Type 'System.IO.FileInfo' }
                Assert-AzureConnection -TokenSplat @{
                    ClientCertificatePath = 'Foo'
                    TenantId = 'MyTenantId'
                    ClientId = 'MyClientId'
                }
                Should -Invoke 'Get-AzToken' -Times 1 -Exactly -ParameterFilter {
                    $ClientCertificatePath -eq 'Foo' -and $null -eq $ClientCertificate
                }
                $script:Token | Should -Be 'RefreshedWithCertificate'
            }
            It 'Throws error when Get-AzToken fails' {
                Mock 'Get-AzToken' { throw 'fail' }
                Mock 'Get-Item' { New-MockObject -Type 'System.IO.FileInfo' }
                {
                    Assert-AzureConnection -TokenSplat @{
                        ClientCertificatePath = 'Foo'
                        TenantId = 'MyTenantId'
                        ClientId = 'MyClientId'
                    }
                } | Should -Throw
            }
        }
    }
}