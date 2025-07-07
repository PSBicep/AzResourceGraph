[![Release]][PSGallery] [![Downloads]][PSGallery]
# AzResourceGraph

Minimal module for searching Azure Resource Graph for resources in your Azure subscriptions using a query string or a path to a file containing the query.

## Installation

```powershell
Install-Module AzResourceGraph -Scope CurrentUser
```

## Usage

Use `Connect-AzResourceGraph` to connect to Azure Resource Graph, and then use `Search-AzResourceGraph` to search for resources.

```powershell
Import-Module AzResourceGraph
Connect-AzResourceGraph
Search-AzResourceGraph -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines' | project name, location, resourceGroup"
```

If running `Search-AzResourceGraph` without running `Connect-AzResourceGraph` first, the module will automatically try to connect to Azure Resource Graph using the current Azure context from the Az module or Azure CLI. Use the parameter `-Verbose` to see the connection details.

## What is the difference between `Search-AzResourceGraph` and `Search-AzGraph`?

`Search-AzResourceGraph` is small and has built-in support for paging and throttling. It is designed to be easy to use and to provide a simple interface for searching Azure Resource Graph.
`Search-AzResourceGraph` also supports reading queries from a file, which can be useful for complex queries or when you want to keep your queries organized.

It works without any dependency on the Az module, which makes it suitable for use in, for example, specialized containers where AzResourceGraph and AzAuth together use only 15 MB of disk space,
compared to Az.ResourceGraph which together with Az.Accounts uses 31 MB.

The official module Az.ResourceGraph contains a cmdlet called `Search-AzGraph` which works great for many scenarios.
There are however some scenarios where it requires the user to write a lot of logic around the command.

When you want to page through results, you need to write a loop that handles the paging logic, which can be cumbersome.  
Here is an example of how to do that with `Search-AzGraph`:

```powershell
$PageSize = 100
$Query = 'PolicyResources | where type =~ "microsoft.authorization/policyassignments" or 
            type =~ "microsoft.authorization/policydefinitions" or 
            type =~ "microsoft.authorization/policyexemptions" or 
            type =~ "microsoft.authorization/policysetdefinitions"'
$Result = Search-AzGraph -Query $Query -First $PageSize
do {
    $NextPage = Search-AzGraph -Query $Query -First $PageSize -SkipToken $Result.SkipToken -Skip $Result.Data.Count
    if ($NextPage.Data.Count -gt 0) {
        $Result.Data.AddRange($NextPage.Data)
    }
    Write-Verbose "Found $($NextPage.Data.Count) more results, total: $($Result.Data.Count)" -Verbose
} while ($NextPage.Data.Count -eq $PageSize)
```

This approach often works, but there is a risk that one page will return a result larger than the allowed maximum payload size of 16777216 bytes, 
which will cause the command to fail, forcing the user to try again with a smaller page size. Using the default page size of 100 usually works but results
in slow performance for large datasets, as it requires many requests to get all the data.

The dreaded error message you might see is:

```plaintext
"Response payload size is 16802910, and has exceeded the limit of 16777216. Please consider querying less data at a time and make paginated call if needed."
```

`Search-AzResourceGraph` is designed to handle paging and throttling automatically, so you don't have to worry about it. When hitting the maximum payload size, it will automatically retry with a smaller page size until it succeeds. This makes it easier to work with large datasets and reduces the amount of code you need to write.

The same request as above can be done with `Search-AzResourceGraph` writing much less code:

```powershell
$Query = 'PolicyResources | where type =~ "microsoft.authorization/policyassignments" or 
            type =~ "microsoft.authorization/policydefinitions" or 
            type =~ "microsoft.authorization/policyexemptions" or 
            type =~ "microsoft.authorization/policysetdefinitions"'
$Result = Search-AzResourceGraph -Query $Query -Verbose
```

`Search-AzResourceGraph` also handles throttling automatically and gracefully, it will sleep for a short time when receiving a HTTP 429 Too Many Requests response.

## Bug report and feature requests

If you find a bug or have an idea for a new feature create an issue in the repo. Please have a look and see if a similar issue is already created before submitting.

## Contribution

If you like the module and want to contribute you are very much welcome to do so. Please read our [Contribution Guide](CONTRIBUTING.md) before you start! ❤

## Maintainers

This project is currently maintained by the following coders:

- [SimonWahlin](https://github.com/SimonWahlin)
- [PalmEmanuel](https://github.com/PalmEmanuel)

<!-- References -->
[Release]: https://img.shields.io/github/v/release/PSBicep/AzResourceGraph?style=for-the-badge&sort=semver
[Downloads]: https://img.shields.io/powershellgallery/dt/AzResourceGraph?style=for-the-badge&labelColor=24c3a0&color=blue&cacheSeconds=3600
[PSGallery]: https://www.powershellgallery.com/packages/AzResourceGraph/