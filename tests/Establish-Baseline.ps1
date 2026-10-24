param([string]$Revision = '4b8a98965f2270249022386e01283a864f598941')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo
$output = Join-Path $repo 'build\baseline'
$snapshot = Join-Path $output 'source'
New-Item -ItemType Directory -Force $snapshot | Out-Null
$files = @(git ls-tree -r --name-only $Revision | Where-Object { $_ -notmatch '^Binaries' })
foreach ($file in $files) {
    $destination = Join-Path $snapshot $file
    New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
    # Git writes binary blobs directly; no text-pipeline conversion of resources.
    $process = [Diagnostics.ProcessStartInfo]::new('git')
    $process.ArgumentList.Add('show')
    $process.ArgumentList.Add("${Revision}:$file")
    $process.RedirectStandardOutput = $true
    $process.UseShellExecute = $false
    $child = [Diagnostics.Process]::Start($process)
    $stream = [IO.File]::Create($destination)
    try { $child.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose() }
    $child.WaitForExit()
    if ($child.ExitCode) { throw "git show failed: $file" }
}
$compilers = @{
    x64 = 'C:\Program Files\PureBasic\Compilers\pbcompiler.exe'
    x86 = 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe'
}
$flags = @('/THREAD','/XP','/CONSTANT','BIS_VERSION=2',
    '/CONSTANT','PB_Editor_BuildCount=11','/CONSTANT','PB_Editor_CompileCount=202')
foreach ($arch in @('x64','x86')) {
    foreach ($mode in @('Debug','Release')) {
        $modeFlags = @(); if ($mode -eq 'Debug') { $modeFlags += '/DEBUGGER' }
        $log = & $compilers[$arch] "$snapshot\BIS.pb" /CHECK @flags @modeFlags 2>&1
        $code = $LASTEXITCODE
        $log | Set-Content "$output\$arch-$mode-project-check.log"
        Write-Output "Original $arch $mode check: exit $code; $log"
        if ($code -ne 1 -or "$log" -notmatch 'InitNetwork') { throw 'Baseline changed: inspect compiler output' }
    }
}
$source = [IO.File]::ReadAllText("$snapshot\BIS.pb")
$source = $source.Substring(0, $source.IndexOf(';Start Main Program'))
# Only the removed network initializer is shimmed; runtime procedures are unchanged.
$source = $source.Replace('InitNetwork()', '1')
$source += [IO.File]::ReadAllText("$PSScriptRoot\BaselineHarness.pbi")
[IO.File]::WriteAllText("$snapshot\Baseline.pb", $source)
& $compilers.x64 "$snapshot\Baseline.pb" @flags /CONSOLE /OUTPUT "$output\baseline.exe"
if ($LASTEXITCODE) { throw 'Baseline harness compile failed' }
foreach ($case in @('empty','cursor')) {
    $p = Start-Process "$output\baseline.exe" -ArgumentList $case -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput "$output\$case.log" -RedirectStandardError "$output\$case.err"
    if (-not $p.WaitForExit(5000)) { Stop-Process -Id $p.Id; throw "$case timed out" }
    Write-Output "$case exit=$($p.ExitCode)"
    Get-Content "$output\$case.log"
    if ($p.ExitCode -eq 0) { throw "Expected historical failure did not occur: $case" }
}
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
$p = Start-Process "$output\baseline.exe" -ArgumentList @('server', "$port") -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Milliseconds 300
    $c = [Net.Sockets.TcpClient]::new('127.0.0.1', $port)
    try {
        $s = $c.GetStream(); $s.ReadTimeout = 1000
        $s.WriteByte(71) # G arrives in its own TCP fragment.
        Start-Sleep -Milliseconds 100
        $tail = [Text.Encoding]::ASCII.GetBytes("ET / HTTP/1.1`r`nHost: localhost`r`n`r`n")
        $s.Write($tail, 0, $tail.Length)
        $buffer = [byte[]]::new(65536)
        try { $n = $s.Read($buffer, 0, $buffer.Length); throw "Unexpected response: $n bytes" }
        catch [IO.IOException] { Write-Output 'Fragmented GET: response timeout (confirmed defect)' }
    } finally { $c.Dispose() }
} finally {
    if (-not $p.HasExited) { Stop-Process -Id $p.Id }
}
