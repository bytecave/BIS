param(
    [ValidateSet('All','x64','x86')][string]$Architecture = 'All',
    [ValidateSet('All','Debug','Release')][string]$Configuration = 'All',
    [switch]$WithTests
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    [xml]$project = Get-Content -LiteralPath 'ByteLord Image Server.pbp'
    $compilers = @{
        x64 = 'C:\Program Files\PureBasic\Compilers\pbcompiler.exe'
        x86 = 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe'
    }
    foreach ($target in $project.project.section.target | Where-Object { $_.enabled -eq '1' }) {
        $mode, $arch = $target.name -split ' '
        if ($Architecture -ne 'All' -and $Architecture -ne $arch) { continue }
        if ($Configuration -ne 'All' -and $Configuration -ne $mode) { continue }
        $compiler = $compilers[$arch]
        if (-not (Test-Path -LiteralPath $compiler)) { throw "Missing $arch compiler: $compiler" }
        $banner = & $compiler /VERSION
        if ("$banner" -notmatch "Windows - $arch") { throw "Wrong compiler architecture: $banner" }
        $directory = Join-Path $PSScriptRoot "build\$arch\$mode"
        New-Item -ItemType Directory -Force $directory | Out-Null
        $flags = @()
        if ($target.options.thread -eq '1') { $flags += '/THREAD' }
        if ($target.options.xpskin -eq '1') { $flags += '/XP' }
        if ($target.options.debug -eq '1') { $flags += '/DEBUGGER' }
        if ($target.icon.enable -eq '1') { $flags += @('/ICON', $target.icon.InnerText) }
        foreach ($constant in $target.constants.constant | Where-Object { $_.enable -eq '1' }) {
            $value = $constant.value -replace '^#','' -replace '\s*=\s*','='
            # /CONSTANT accepts string contents directly, unlike project source syntax.
            if ($value -match '^([^=]+)="(.*)"$') { $value = $Matches[1] + '=' + $Matches[2] }
            $flags += @('/CONSTANT', $value)
        }
        $flags += @('/CONSTANT', "PB_Editor_BuildCount=$($target.buildcount.value)",
                    '/CONSTANT', "PB_Editor_CompileCount=$($target.compilecount.value)")
        $version = $target.versioninfo
        $description = $version.field6.value
        $internal = $version.field7.value
        $copyright = $version.field9.value
        $filename = $target.outputfile.value
        $debugFlag = if ($mode -eq 'Debug') { 1 } else { 0 }
        $resource = @"
1 VERSIONINFO
FILEVERSION $($version.field0.value)
PRODUCTVERSION $($version.field1.value)
FILEFLAGSMASK 0x3fL
FILEFLAGS $debugFlag
FILEOS 0x40004L
FILETYPE 1
FILESUBTYPE 0
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904B0"
    BEGIN
      VALUE "CompanyName", "$($version.field2.value)\0"
      VALUE "ProductName", "$($version.field3.value)\0"
      VALUE "FileVersion", "$($version.field4.value)\0"
      VALUE "ProductVersion", "$($version.field5.value)\0"
      VALUE "FileDescription", "$description\0"
      VALUE "InternalName", "$internal\0"
      VALUE "OriginalFilename", "$filename\0"
      VALUE "LegalCopyright", "$copyright\0"
      VALUE "WebSite", "$($version.field14.value)\0"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation", 0x0409, 1200
  END
END
"@
        $resourcePath = Join-Path $directory 'version.rc'
        [IO.File]::WriteAllText($resourcePath, $resource + "`r`n", [Text.Encoding]::ASCII)
        $exe = Join-Path $directory $filename
        $log = & $compiler $target.inputfile.value @flags /RESOURCE $resourcePath /OUTPUT $exe 2>&1
        $code = $LASTEXITCODE
        @("Compiler: $banner", "Flags: $($flags -join ' ')", "Exit: $code") + @($log) | Set-Content (Join-Path $directory 'build.log')
        if ($code) { throw "$arch $mode build failed: $log" }
        $pe = [IO.File]::ReadAllBytes($exe)
        $machine = [BitConverter]::ToUInt16($pe, [BitConverter]::ToInt32($pe, 0x3c) + 4)
        $expected = if ($arch -eq 'x64') { 0x8664 } else { 0x14c }
        if ($machine -ne $expected) { throw "Wrong PE machine for $exe" }
        $metadata = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
        if ($metadata.CompanyName -ne 'ByteLord' -or $metadata.InternalName -ne $internal -or
            $metadata.ProductName -ne 'ByteLord Image Server' -or $metadata.FileVersion -ne '2.1.0' -or
            $metadata.ProductVersion -ne '2.1.0' -or $metadata.OriginalFilename -ne $filename -or
            $metadata.IsDebug -ne ($mode -eq 'Debug')) {
            throw "Version resource validation failed for $exe"
        }
        $testExe = $null
        if ($WithTests) {
            $testExe = Join-Path $directory 'BIS-tests.exe'
            $log = & $compiler $target.inputfile.value @flags /CONSOLE /CONSTANT BIS_TEST=1 /OUTPUT $testExe 2>&1
            $code = $LASTEXITCODE
            @("Compiler: $banner", "Flags: $($flags -join ' ') /CONSOLE /CONSTANT BIS_TEST=1", "Exit: $code") + @($log) | Set-Content (Join-Path $directory 'test-build.log')
            if ($code) { throw "$arch $mode regression build failed: $log" }
        }
        Write-Host "$arch $mode built; PE 0x$($machine.ToString('X')); $($metadata.FileDescription)"
        [pscustomobject]@{ Architecture=$arch; Configuration=$mode; Executable=$exe; TestExecutable=$testExe }
    }
} finally { Pop-Location }
