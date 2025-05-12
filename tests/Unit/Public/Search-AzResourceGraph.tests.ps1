BeforeAll {
    Import-Module -FullyQualifiedName "$PSScriptRoot/../../../output/module/AzResourceGraph" -Force
}

Describe 'Search-AzResourceGraph' {
    BeforeAll {
        Mock 'Assert-AzureConnection' { return } -ModuleName 'AzResourceGraph'
        Mock 'Get-Content' { return 'Resources | take 1' } -ModuleName 'AzResourceGraph'
        Mock 'Get-AzResourceGraphPage' {
            $Body.options.'$skip' = $Body.options.'$skip' + $Body.options.'$top'
            return @{
                Uri = 'https://example.com'
                Body = $Body
                Headers = @{ Authorization = 'Bearer token' }
                TotalRecords = 20
                Output = [System.Collections.ArrayList]@(
                    1..($Body.options.'$top' -lt 20 ? $Body.options.'$top' : 20) | Foreach-Object {
                        [PSCustomObject]@{}
                    }
                )
                ResultHeaders = @{
                    'x-ms-user-quota-remaining' = @(10)
                    'x-ms-user-quota-resets-after' = @('00:00:10')
                }
            }
        } -ModuleName 'AzResourceGraph'
    }

    It 'Searches using a query string' {
        $null = Search-AzResourceGraph -Query 'Resources | take 20' -PageSize 10
        Should -Invoke 'Get-AzResourceGraphPage' -Times 2 -Exactly  -ModuleName 'AzResourceGraph'
    }

    It 'Searches using a query from file' {
        $null = Search-AzResourceGraph -QueryPath '~/foo.kql' -PageSize 10
        Should -Invoke 'Get-AzResourceGraphPage' -Times 2 -Exactly  -ModuleName 'AzResourceGraph'
    }

    It 'Throws when using both SubscriptionId and ManagementGroup parameters' {
        {$null = Search-AzResourceGraph -Query 'Resources | take 20' -SubscriptionId 'id' -ManagementGroup 'id'} |
        Should -Throw
    }

    It 'Passes SubscriptionId to Get-AzResourceGraphPage' {
        $null = Search-AzResourceGraph -QueryPath '~/foo.kql' -PageSize 10 -SubscriptionId 'mySub'
        Should -Invoke 'Get-AzResourceGraphPage' -Times 2 -Exactly  -ModuleName 'AzResourceGraph' -ParameterFilter {
            $Body.subscriptions -contains 'mySub'
        }
    }

    It 'Passes ManagementGroup to Get-AzResourceGraphPage' {
        $null = Search-AzResourceGraph -QueryPath '~/foo.kql' -PageSize 10 -ManagementGroup 'myMG'
        Should -Invoke 'Get-AzResourceGraphPage' -Times 2 -Exactly  -ModuleName 'AzResourceGraph' -ParameterFilter {
            $Body.managementGroups -contains 'myMG'
        }
    }
}