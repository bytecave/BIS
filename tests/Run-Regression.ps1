param([Parameter(Mandatory)]$Build, [string]$ImageFolder = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$run = Join-Path $repo ("build\tests\{0}-{1}-{2}" -f $Build.Architecture,$Build.Configuration,[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$run\fixtures\nested" | Out-Null
# A cycle must be skipped, without traversing it or deleting any user files.
New-Item -ItemType Junction -Path "$run\fixtures\cycle" -Target "$run\fixtures" | Out-Null
New-Item -ItemType Directory -Force "$run\launch\resources" | Out-Null
# Launch with only a loose logo present; all other UI assets must come from the EXE.
Copy-Item -LiteralPath "$repo\resources\logo.png" -Destination "$run\launch\resources\logo.png"
[IO.File]::WriteAllText("$run\fixtures\ignore.txt", 'unsupported extension')
[IO.File]::WriteAllBytes("$run\zero.jpg", [byte[]]::new(0))
$script:checks = 0
function Check($Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Free-Port {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
    return $port
}
function Start-TestProcess([string[]]$Arguments, [string]$Log) {
    # Windows filenames cannot contain quotes. Quote each argument to retain spaces.
    $quoted = ($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $working = if ($Arguments[0] -eq 'core') { "$run\launch" } else { $repo }
    return Start-Process -FilePath $Build.TestExecutable -ArgumentList $quoted -WorkingDirectory $working `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run\$Log.log" -RedirectStandardError "$run\$Log.err"
}
function Wait-TestProcess($Process, [int]$Timeout, [string]$Log) {
    if (-not $Process.WaitForExit($Timeout)) {
        Stop-Process -Id $Process.Id
        throw "Test process timed out: $Log"
    }
    $lines = Get-Content "$run\$Log.log" -Raw
    if ($Process.ExitCode -ne 0) { throw "$Log exit $($Process.ExitCode): $lines" }
    Write-Host $lines.Trim()
}
function Connect-Test([int]$Port, [string]$SourceIP = '') {
    $client = [Net.Sockets.TcpClient]::new([Net.Sockets.AddressFamily]::InterNetwork)
    $client.NoDelay = $true
    if ($SourceIP) { $client.Client.Bind([Net.IPEndPoint]::new([Net.IPAddress]::Parse($SourceIP), 0)) }
    if (-not $client.ConnectAsync('127.0.0.1', $Port).Wait(3000)) {
        $client.Dispose()
        throw "Loopback connect timeout on port $Port"
    }
    $client.GetStream().ReadTimeout = 8000
    return $client
}
function Read-Response($Client) {
    $stream = $Client.GetStream()
    $memory = [IO.MemoryStream]::new()
    try {
        $buffer = [byte[]]::new(81920)
        while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) { $memory.Write($buffer, 0, $count) }
        $data = $memory.ToArray()
    } finally { $memory.Dispose() }
    $prefix = [Text.Encoding]::ASCII.GetString($data, 0, [Math]::Min($data.Length, 32768))
    $separator = $prefix.IndexOf("`r`n`r`n")
    Check ($separator -ge 0) 'complete HTTP response headers'
    $lines = $prefix.Substring(0, $separator) -split "`r`n"
    $headers = @{}
    foreach ($line in $lines | Select-Object -Skip 1) {
        $parts = $line -split ':', 2
        $headers[$parts[0].ToLowerInvariant()] = $parts[1].Trim()
    }
    $bodyLength = $data.Length - $separator - 4
    Check ($bodyLength -eq [long]$headers['content-length']) 'exact Content-Length with no trailing NUL'
    Check ($headers['connection'] -eq 'close') 'response declares connection close'
    Check ($headers['cache-control'] -eq 'no-store') 'random responses bypass browser cache'
    Check ($headers['server'] -eq 'ByteLord Image Server 2.1.0') "server identity and version: $($headers['server'])"
    $body = [byte[]]::new($bodyLength)
    [Array]::Copy($data, $separator + 4, $body, 0, $bodyLength)
    return [pscustomobject]@{Status=[int]($lines[0] -split ' ')[1]; Headers=$headers; Body=$body}
}
function Request([int]$Port, [string[]]$Fragments = @("GET / HTTP/1.1`r`nHost: localhost`r`n`r`n"),
                 [string]$SourceIP = '', [int]$ReadDelay = 0) {
    $client = Connect-Test $Port $SourceIP
    try {
        foreach ($fragment in $Fragments) {
            $bytes = [Text.Encoding]::ASCII.GetBytes($fragment)
            $client.GetStream().Write($bytes, 0, $bytes.Length)
            if ($Fragments.Count -gt 1) { Start-Sleep -Milliseconds 50 }
        }
        if ($ReadDelay) { Start-Sleep -Milliseconds $ReadDelay }
        return Read-Response $client
    } finally { $client.Dispose() }
}
function Hash-Bytes([byte[]]$Bytes) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function With-Server([string]$Scenario, [scriptblock]$Test, [int]$ExpectedImages) {
    $port = Free-Port
    $process = Start-TestProcess @('server', $run, "$port", $Scenario) $Scenario
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    try {
        while (-not (Test-Path "$run\$Scenario.ready")) {
            if ($process.HasExited) { throw "Server failed: $(Get-Content "$run\$Scenario.log" -Raw)" }
            if ([DateTime]::UtcNow -gt $deadline) { throw "No ready marker: $Scenario" }
            Start-Sleep -Milliseconds 20
        }
        & $Test $port
    } finally {
        [IO.File]::WriteAllText("$run\$Scenario.stop", 'stop')
        Wait-TestProcess $process 8000 $Scenario
    }
    $stats = @(Get-Content "$run\$Scenario.stats")
    Check ([int]$stats[0] -eq $ExpectedImages) "$Scenario counts only completed image responses"
    Check ([int]$stats[1] -eq $ExpectedImages) "$Scenario lifetime count matches"
    Check ([int]$stats[2] -eq 0) "$Scenario thumbnail queue drained at shutdown"
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
    try { $probe.Start(); Check $true "$Scenario releases listening port" } finally { $probe.Stop() }
}
$core = Start-TestProcess @('core', $run, "$(Free-Port)", $ImageFolder) 'core'
Wait-TestProcess $core 45000 'core'
$hashes = @{}
foreach ($file in Get-ChildItem "$run\fixtures" -File -Recurse -Attributes !ReparsePoint | Where-Object { $_.Extension -in '.png','.jpg','.bmp' }) {
    $hashes[(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash] = $file.Extension.ToLowerInvariant()
}
Check ($hashes.Count -eq 4) 'four distinct small fixture images'
With-Server 'normal' {
    param($port)
    foreach ($source in @('', '')) {
        $seen = @{}
        for ($i = 0; $i -lt 4; $i++) {
            $response = Request $port -SourceIP $source
            Check ($response.Status -eq 200) 'GET returns image'
            $hash = Hash-Bytes $response.Body
            Check ($hashes.ContainsKey($hash) -and -not $seen.ContainsKey($hash)) 'byte-exact, nonrepeating client cycle'
            $seen[$hash] = $true
            if ($hashes[$hash] -eq '.jpg') { Check ($response.Headers['content-type'] -eq 'image/jpeg') 'JPEG MIME type' }
        }
    }
    $r = Request $port -Fragments @('G', "ET /anything?random=1 HTTP/1.1`r`nHost: localhost`r`n", "`r`n")
    Check ($r.Status -eq 200) 'GET split across three TCP fragments'
    $r = Request $port -Fragments @("GET / HTTP/1.1`r`nHost: localhost`r`n`r`nGET /next HTTP/1.1`r`nHost: localhost`r`n`r`n")
    Check ($r.Status -eq 200) 'one response per connection even with pipelined bytes'
    foreach ($method in @('GETTING','POST','HEAD')) {
        $r = Request $port -Fragments @("$method / HTTP/1.1`r`nHost: localhost`r`n`r`n")
        Check ($r.Status -eq 405 -and $r.Headers['allow'] -eq 'GET') "reject $method"
    }
    $r = Request $port -Fragments @("GET /`r`n`r`n")
    Check ($r.Status -eq 400) 'malformed request line'
    $r = Request $port -Fragments @("GET / HTTP/1.1`r`nX-Large: " + ('a' * 17000) + "`r`n`r`n")
    Check ($r.Status -eq 431) 'oversized headers are bounded'
    $client = Connect-Test $port
    try {
        $client.GetStream().WriteByte(71)
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $r = Read-Response $client
        Check ($r.Status -eq 408) 'incomplete request expires with a finite timeout response'
        Check ($clock.ElapsedMilliseconds -ge 4500 -and $clock.ElapsedMilliseconds -lt 7500) 'incomplete request deadline'
    } finally { $client.Dispose() }
    $clients = [Collections.Generic.List[Net.Sockets.TcpClient]]::new()
    try {
        for ($i=0; $i -lt 64; $i++) { $clients.Add((Connect-Test $port)) }
        Start-Sleep -Milliseconds 150
        $overflow = Connect-Test $port
        try { $r = Read-Response $overflow } finally { $overflow.Dispose() }
        Check ($r.Status -eq 503) 'connection cap prevents unbounded pending headers'
    } finally { foreach ($c in $clients) { $c.Dispose() } }
    Start-Sleep -Milliseconds 100
    for ($i=0; $i -lt 20; $i++) { $c = Connect-Test $port; $c.Dispose() }
    $r = Request $port
    Check ($r.Status -eq 200) 'server survives disconnects and header errors'
} 11
With-Server 'throttle' {
    param($port)
    $r = Request $port; Check ($r.Status -eq 200) 'first throttled request succeeds'
    $r = Request $port; Check ($r.Status -eq 429 -and [int]$r.Headers['retry-after'] -ge 1) 'explicit rate-limit response'
    Start-Sleep -Milliseconds 2100
    $r = Request $port; Check ($r.Status -eq 200) 'request succeeds after throttle interval'
} 2
$largeHash = (Get-FileHash "$run\large.bmp" -Algorithm SHA256).Hash
$script:pendingClient = $null
try {
    With-Server 'large' {
        param($port)
        $r = Request $port -ReadDelay 350
        Check ($r.Status -eq 200 -and (Hash-Bytes $r.Body) -eq $largeHash) "9 MiB transfer is byte-exact with delayed reader: status $($r.Status), bytes $($r.Body.Length), hash $(Hash-Bytes $r.Body), expected $largeHash"
        $client = Connect-Test $port
        $client.Client.LingerState = [Net.Sockets.LingerOption]::new($true,0)
        $bytes = [Text.Encoding]::ASCII.GetBytes("GET / HTTP/1.1`r`nHost: localhost`r`n`r`n")
        $client.GetStream().Write($bytes,0,$bytes.Length)
        Start-Sleep -Milliseconds 20
        $client.Dispose()
        $r = Request $port
        Check ($r.Status -eq 200 -and (Hash-Bytes $r.Body) -eq $largeHash) 'server recovers after peer aborts a partial image'
        $script:pendingClient = Connect-Test $port
        $script:pendingClient.GetStream().Write($bytes,0,$bytes.Length)
        Start-Sleep -Milliseconds 100
        # With-Server now stops while the last peer is not reading its response.
    } 2
} finally { if ($script:pendingClient) { $script:pendingClient.Dispose() } }
foreach ($scenario in @('empty','missing','zero')) {
    With-Server $scenario {
        param($port)
        $r = Request $port
        Check ($r.Status -eq 404) "unavailable image is an explicit finite 404: status $($r.Status)"
        Check ([Text.Encoding]::UTF8.GetString($r.Body) -notmatch [regex]::Escape($run)) 'error does not disclose a local path'
    } 0
}
With-Server 'full' {
    param($port)
    $r = Request $port
    Check ($r.Status -eq 503) 'fifteenth client gets a finite 503'
} 0
$summary = "PASS: $($Build.Architecture) $($Build.Configuration), $script:checks HTTP/integration checks; logs $run"
$summary | Set-Content "$run\result.txt"
Write-Host $summary
