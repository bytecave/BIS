param([switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($PSScriptRoot)

function Verify-Package([string]$Archive, [string]$ExtractTo, $Builds, [string[]]$ExpectedEntries, [string]$Version) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $entries = @($zip.Entries.FullName)
        if ($entries.Count -ne $ExpectedEntries.Count -or
            @(Compare-Object $entries $ExpectedEntries).Count -ne 0 -or
            @($entries | Select-Object -Unique).Count -ne $entries.Count) {
            throw "Unexpected release archive contents: $($entries -join ', ')"
        }
    } finally { $zip.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($Archive, $ExtractTo)
    $logo = [Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $repo 'resources\logo.png')))
    foreach ($build in $Builds) {
        $name = Split-Path $build.Executable -Leaf
        $extracted = Join-Path $ExtractTo $name
        if ((Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $build.Executable -Algorithm SHA256).Hash) {
            throw "Packaged executable differs from its fresh build: $name"
        }
        $bytes = [IO.File]::ReadAllBytes($extracted)
        $machine = [BitConverter]::ToUInt16($bytes, [BitConverter]::ToInt32($bytes, 0x3c) + 4)
        $expectedMachine = if ($build.Architecture -eq 'x64') { 0x8664 } else { 0x14c }
        $metadata = [Diagnostics.FileVersionInfo]::GetVersionInfo($extracted)
        if ($machine -ne $expectedMachine -or $metadata.FileVersion -ne $Version -or
            $metadata.ProductVersion -ne $Version -or $metadata.CompanyName -ne 'ByteLord' -or
            $metadata.ProductName -ne 'ByteLord Image Server' -or
            $metadata.LegalCopyright -ne '(c) 2019-2026 ByteLord' -or
            $metadata.IsDebug -ne ($build.Configuration -eq 'Debug')) {
            throw "Packaged executable metadata does not match its target: $name"
        }
        if (-not [Text.Encoding]::Unicode.GetString($bytes).Contains('ByteLord Image Server') -or
            -not [Text.Encoding]::ASCII.GetString($bytes).Contains('2019-2026 ByteLord') -or
            -not [Convert]::ToHexString($bytes).Contains($logo)) {
            throw "Packaged executable is missing its title, copyright text or embedded logo: $name"
        }
    }
}

# Every package starts from fresh production builds of all four project targets.
$builds = @(& (Join-Path $repo 'Build.ps1'))
$targets = @($builds | ForEach-Object { "$($_.Architecture) $($_.Configuration)" })
$expectedTargets = @('x86 Debug', 'x86 Release', 'x64 Debug', 'x64 Release')
if ($targets.Count -ne 4 -or @(Compare-Object $targets $expectedTargets).Count -ne 0) {
    throw 'A release package requires all four x64/x86 Debug/Release targets'
}
$versions = @($builds | ForEach-Object { [Diagnostics.FileVersionInfo]::GetVersionInfo($_.Executable).FileVersion } | Select-Object -Unique)
if ($versions.Count -ne 1 -or $versions[0] -notmatch '^\d+\.\d+\.\d+$') { throw 'Inconsistent release versions' }
$version = $versions[0]
$work = Join-Path $repo ('build\packages\' + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $work 'payload'
New-Item -ItemType Directory -Force $stage | Out-Null
foreach ($build in $builds) { Copy-Item -LiteralPath $build.Executable -Destination $stage }
$expectedEntries = @($builds | ForEach-Object { Split-Path $_.Executable -Leaf })
$prepared = Join-Path $work "BIS-$version.zip"
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $prepared, [IO.Compression.CompressionLevel]::Optimal, $false)
Verify-Package $prepared (Join-Path $work 'verified') $builds $expectedEntries $version
$archive = $prepared
if (-not $PrepareOnly) {
    $destination = Join-Path $repo 'Binaries'
    New-Item -ItemType Directory -Force $destination | Out-Null
    $archive = Join-Path $destination "BIS-$version.zip"
    Copy-Item -LiteralPath $prepared -Destination $archive -Force
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $prepared -Algorithm SHA256).Hash) {
        throw 'Published local archive differs from the verified package'
    }
    foreach ($build in $builds) {
        $file = Join-Path $destination (Split-Path $build.Executable -Leaf)
        Copy-Item -LiteralPath $build.Executable -Destination $file -Force
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $build.Executable -Algorithm SHA256).Hash) {
            throw "Published executable differs from its fresh build: $file"
        }
    }
}
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
[pscustomobject]@{Archive=$archive;Version=$version;SHA256=$archiveHash;Entries=$expectedEntries;VerificationDirectory=(Join-Path $work 'verified')}
