param(
    [ValidateSet('All','x64','x86')][string]$Architecture = 'All',
    [ValidateSet('All','Debug','Release')][string]$Configuration = 'All',
    [switch]$BuildOnly,
    [string]$ImageFolder = (Join-Path $PSScriptRoot 'WALLPICS')
)
$ErrorActionPreference = 'Stop'
$builds = @(& "$PSScriptRoot\Build.ps1" -Architecture $Architecture -Configuration $Configuration -WithTests:(-not $BuildOnly))
if (-not $BuildOnly) {
    foreach ($build in $builds) {
        & "$PSScriptRoot\tests\Run-Regression.ps1" -Build $build -ImageFolder $ImageFolder
    }
}
$builds | Format-Table Architecture,Configuration,Executable
