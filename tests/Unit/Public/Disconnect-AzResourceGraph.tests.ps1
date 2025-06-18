BeforeAll {
    Import-Module -FullyQualifiedName "$PSScriptRoot/../../../output/module/AzResourceGraph"
}

Describe 'Disconnect-AzResourceGraph' {
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
        Context 'Successful token removal' {
            It 'Resets any token information' {
                Connect-AzResourceGraph
                Disconnect-AzResourceGraph
                $script:TokenSplat.Keys.Count | Should -be 0
                $null -eq $script:CertificatePath | Should -be $true
                $null -eq $script:Token | Should -be $true
            }
        }

    }
}