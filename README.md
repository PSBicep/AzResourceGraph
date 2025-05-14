[![Release]][PSGallery] [![Downloads]][PSGallery]
# AzResourceGraph

Minimal module for searching Azure Resource Graph for resources in your Azure subscriptions using a query string or a path to a file containing the query.

## Installation

```powershell
Install-Module AzResourceGraph -Scope CurrentUser
```

## Usage

```powershell
Import-Module AzResourceGraph
Connect-AzResourceGraph
Search-AzResourceGraph -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines' | project name, location, resourceGroup"
```

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