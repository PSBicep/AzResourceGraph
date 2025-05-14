BeforeAll {
    $script:ModuleName = 'AzResourceGraph'
    Import-Module -FullyQualifiedName "$PSScriptRoot/../../../output/module/AzResourceGraph"
}

Describe 'Get-AzResourceGraphPage' {
    InModuleScope 'AzResourceGraph' {
        BeforeEach {
            Mock 'Start-Sleep' {}
            # Generic Mock for Invoke-WebRequest
            Mock 'Invoke-WebRequest' {
                $BodyObj = "$Body" | ConvertFrom-Json
                [PSCustomObject]@{
                    Content = @{
                        data = 1..($BodyObj.options.'$top' ?? 10) | Foreach-Object {[PSCustomObject]@{}}
                        totalRecords = 20
                    } | ConvertTo-Json -Compress
                    Headers = @{
                        'x-ms-user-quota-remaining'    = @(1)
                        'x-ms-user-quota-resets-after' = @('00:00:10')
                    }
                }
            }

            $Params = @{
                Uri = 'https://example.com'
                Body = @{ 'options' = @{ '$top' = 10; '$skip' = 0 } }
                Headers = @{ Authorization = 'Bearer token' }
                TotalRecords = 20
                Output = [System.Collections.ArrayList]@()
                ResultHeaders = @{
                    'x-ms-user-quota-remaining' = @(10)
                    'x-ms-user-quota-resets-after' = @('00:00:10')
                }
            }
        }
        It 'Sleeps when hitting 0 quota' {
            $Params.ResultHeaders.'x-ms-user-quota-remaining' = @(0)
            $Params.ResultHeaders.'x-ms-user-quota-resets-after' = @('00:00:10')

            $null = Get-AzResourceGraphPage @Params
            Should -Invoke 'Start-Sleep' -ParameterFilter {$Milliseconds -eq 10000} -Times 1 -Exactly
        }
        It 'Does not sleep when quota is above 0' {
            $null = Get-AzResourceGraphPage @Params
            Should -Invoke 'Start-Sleep' -ParameterFilter {$Milliseconds -eq 10000} -Times 0 -Exactly
        }
        It 'Adjusts the pagesize on last page' {
            $Params.Body.options.'$top' = 10              # We are going to get 10 records (PageSize is 10)
            $Params.Body.options.'$skip' = 11             # We already got 11 records
            $Params.TotalRecords = 20                     # There are 20 records in total

            $Result = Get-AzResourceGraphPage @Params
            Should -Invoke 'Invoke-WebRequest' -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json -AsHashtable)['options']['$top'] -eq 9 # We expect the PageSize to be adjusted to 9
            }
        }
        It 'Does not run if all records are retrieved' {
            $Params.Body.options.'$top' = 10              # PageSize is 10
            $Params.Body.options.'$skip' = 20             # We already got 20 records
            $Params.TotalRecords = 20                     # There are 20 records in total
            $Result = Get-AzResourceGraphPage @Params
            Should -Invoke 'Invoke-WebRequest' -Times 0 -Exactly # No call to the API should be made
        }

        It 'Recurses when hitting payload limit size' {
            # New Mock for when PageSize is 10 which errors on ResponsePayloadTooLarge
            Mock Invoke-WebRequest -ParameterFilter {
                ($Body | ConvertFrom-Json -AsHashtable)['options']['$top'] -eq 20
            } -MockWith {
                $ErrorMessage = @{
                    error = @{
                        details = @(
                            @{
                                code    = 'ResponsePayloadTooLarge'
                                message = 'Response payload size is 2, and has exceeded the limit of 1.' +
                                    ' Please consider querying less data at a time and make paginated call if needed.'
                            }
                        )
                    }
                } | ConvertTo-Json -Depth 100 -Compress
                $ErrorRecord = [System.Management.Automation.ErrorRecord]::New(
                    [Exception]::new(),
                    'ErrorID',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    [PSCustomObject]@{Foo = 'Bar'}
                )
                $ErrorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($ErrorMessage)
                Write-Error -ErrorRecord $ErrorRecord -ErrorAction 'Stop'
            }
            $Params.Body.options.'$top' = 20
            $Result = Get-AzResourceGraphPage @Params -Verbose

            # First invocation should get an error and calculate a new page size
            Should -Invoke 'Invoke-WebRequest' -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json -AsHashtable)['options']['$top'] -eq 20
            }
            # Will retry with page size of 7 two times
            Should -Invoke 'Invoke-WebRequest' -Times 2 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json -AsHashtable)['options']['$top'] -eq 7
            }
            # On third iteration, page size will be 6 to properly add up to 20
            Should -Invoke 'Invoke-WebRequest' -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json -AsHashtable)['options']['$top'] -eq 6
            }
        }
    }
}