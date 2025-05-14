BeforeAll {
    Import-Module -FullyQualifiedName "$PSScriptRoot/../../../output/module/AzResourceGraph"
}

Describe 'Test-AzureToken' {
    InModuleScope 'AzResourceGraph' {
        It 'Rejects an empty token' {
            Test-AzureToken -Token $null | Should -Be $false
        }

        It 'Rejects a token expiring before -MinValid minutes' {
            $Token = [PSCustomObject]@{
                ExpiresOn = [System.DateTimeOffset]::Now.AddMinutes(9)
                Claims = @{
                    aud = 'myResource'
                }
            }
            Test-AzureToken -Token $Token -MinValid 10 -Resource 'myResource' | Should -Be $false
        }

        It 'Rejects a token with wrong audience' {
            $Token = [PSCustomObject]@{
                ExpiresOn = [System.DateTimeOffset]::Now.AddMinutes(15)
                Claims = @{
                    aud = 'wrongAudience'
                }
            }
            Test-AzureToken -Token $Token -MinValid 10 -Resource 'myResource' | Should -Be $false
        }

        It 'Accepts a token valid longer than -MinValid' {
            $Token = [PSCustomObject]@{
                ExpiresOn = [System.DateTimeOffset]::Now.AddMinutes(15)
                Claims = @{
                    aud = 'myResource'
                }
            }
            Test-AzureToken -Token $Token -MinValid 10 -Resource 'myResource' | Should -Be $true
        }
    }
}