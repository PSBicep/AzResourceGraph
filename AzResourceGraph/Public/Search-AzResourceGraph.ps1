<#
.SYNOPSIS
Runs an Azure Resource Graph query and outputs the results to the pipeline.

.DESCRIPTION
Search-AzResourceGraph executes a Kusto Query Language (KQL) statement
against Azure Resource Graph.
You can supply the query as a string or as the path to a text file.
The command supports querying:
  • One or more subscriptions
  • One or more management groups
  • The currently connected tenant (by omitting both SubscriptionId and ManagementGroup)

Results are paged transparently until the full data set is returned.
Authentication is provided by a cached token populated through Connect-AzResourceGraph.

.PARAMETER QueryPath
Path to a file containing the KQL query.
Specify either ‑QueryPath or ‑Query, not both.

.PARAMETER Query
KQL query string.
Specify either ‑Query or ‑QueryPath, not both.

.PARAMETER SubscriptionId
One or more Azure subscription IDs (GUID) to scope the query.
Cannot be used together with ‑ManagementGroup.

.PARAMETER ManagementGroup
One or more Azure Management Group IDs (e.g. “contoso-mg”) to scope the query.
Cannot be used together with ‑SubscriptionId.

.PARAMETER AuthorizationScopeFilter
Controls how authorization scope is interpreted when evaluating the query.
Valid values: AtScopeAboveAndBelow, AtScopeAndAbove, AtScopeAndBelow, AtScopeExact.
Default is AtScopeAndBelow.

.PARAMETER AllowPartialScopes
Allow partial scopes in the query. Only applicable for tenant and management group level queries to decide whether to allow partial scopes for result in case the number of subscriptions exceed allowed limits.

.PARAMETER PageSize
Number of rows to request per page (1-1000).
The function continues paging until all rows are retrieved.

.PARAMETER Token
Use to call Azure Resource Graph with a specified access token. Using this parameter will override any sign-in made with Connect-AzResourceGraph for a single command.

.EXAMPLE
# Execute a query stored in a file against two subscriptions
Search-AzResourceGraph -QueryPath '.\vm-details.kql' `
                          -SubscriptionId '11111111-1111-1111-1111-111111111111',
                                          '22222222-2222-2222-2222-222222222222'

.EXAMPLE
# Inline query against a management group
Search-AzResourceGraph -Query 'Resources | where type =~ "Microsoft.Compute/virtualMachines"' `
                          -ManagementGroup 'contoso-mg'

.EXAMPLE
# Tenant-wide query allowing partial scopes
Search-AzResourceGraph -Query 'ResourceContainers | summarize count()' `
                          -AllowPartialScopes

#>
function Search-AzResourceGraph {
    [CmdletBinding(DefaultParameterSetName = 'String')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string]$QueryPath,

        [Parameter(Mandatory, ParameterSetName = 'String')]
        [ValidateNotNullOrEmpty()]
        [string]$Query,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'String')]
        [string[]]$SubscriptionId,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'String')]
        [string[]]$ManagementGroup,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'String')]
        [ValidateSet('AtScopeAboveAndBelow', 'AtScopeAndAbove', 'AtScopeAndBelow', 'AtScopeExact')]
        [string]$AuthorizationScopeFilter = 'AtScopeAndBelow',

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'String')]
        [switch]$AllowPartialScopes,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'String')]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 1000,

        [Parameter(ParameterSetName = 'Path', DontShow)]
        [Parameter(ParameterSetName = 'String', DontShow)]
        [string]$Token
    )

    # Ensure only one of SubscriptionId or ManagementGroup is provided
    if ($PSBoundParameters.ContainsKey('SubscriptionId') -and $PSBoundParameters.ContainsKey('ManagementGroup')) {
        throw 'KQL Query can only be run against either a Subscription or a Management Group, not both.'
    }

    if (-not $PSBoundParameters.ContainsKey('Token')) {
        Assert-AzureConnection -TokenSplat $script:TokenSplat
        $Token = $script:Token.Token
    }

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $Query = Get-Content $QueryPath -Raw
    }

    $Uri = 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01'
    $Body = @{
        query   = $Query
        options = @{
            resultFormat             = 'objectArray'
            authorizationScopeFilter = $AuthorizationScopeFilter
            allowPartialScopes       = $AllowPartialScopes.IsPresent
            '$top'                   = $PageSize
            '$skip'                  = 0
        }
    }

    if ($PSBoundParameters.ContainsKey('SubscriptionId')) { $Body['subscriptions'] = @($SubscriptionId) }
    if ($PSBoundParameters.ContainsKey('ManagementGroup')) { $Body['managementGroups'] = @($ManagementGroup) }

    $Headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type'  = 'application/json'
    }

    $PageParams = @{
        Uri = $Uri
        Body = $Body
        Headers = $Headers
        TotalRecords = 0
        ResultHeaders = @{}
        Output = [System.Collections.ArrayList]::new()
    }

    while ($PageParams['TotalRecords'] -eq 0 -or $PageParams['TotalRecords'] -gt $PageParams['Body']['options']['$skip']) {
        $PageParams = Get-AzResourceGraphPage @PageParams

        Write-Verbose "Outputting $($PageParams.Output.Count) records."
        if ($PageParams.TotalRecords -eq 0) {return}
        Write-Output $PageParams.Output
        $PageParams.Output.Clear()
    }
}

