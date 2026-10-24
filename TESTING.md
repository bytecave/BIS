# BIS 2.1.1 validation

Run from the repository root in PowerShell 7:

```powershell
pwsh -NoProfile -File .\Validate.ps1
```

The script builds x64 Debug, x64 Release, x86 Debug and x86 Release with the
installed PureBasic compilers. It derives flags, icons, version resources and
constants from `ByteLord Image Server.pbp`, and checks the resulting PE machine,
file/product version, company, internal name and Debug flag. Production executables
are in `build/<architecture>/<configuration>/`. `BIS-tests.exe` is a separate test
executable compiled from the same sources and settings, with a test entry point.
Do not distribute the test executable.

`-BuildOnly` skips runtime tests. `-Architecture` and `-Configuration` select a
subset. `-ImageFolder 'C:\path\to\images'` changes the optional read-only discovery
test; the default is local `WALLPICS` if it exists.

## Release archive

```powershell
pwsh -NoProfile -File .\Package.ps1
```

This rebuilds all four production targets and creates `Binaries/BIS-2.1.1.zip`.
The ZIP contains only `BIS_x64.Exe`, `BIS_x86.Exe`, `BISDebug_x64.Exe`,
and `BISDebug_x86.Exe`. The same four executables are copied directly into Binaries.
Packaging extracts the archive into an isolated build directory, compares every
executable to the fresh build, checks PE architecture, version, copyright and
Debug flags, verifies the embedded title/logo, and compares file hashes.
It excludes documentation, checksum files, the regression executable, local
preferences, photos, handoff and review report. Use `-PrepareOnly` to verify a package under build/packages without
copying it into Binaries.

## Automated scope

Each target gets a unique directory under `build/tests/` with logs, generated
fixtures, isolated preferences and result.txt. The tests never load or save the
real home-directory config, call startup-registration code, adjust the firewall,
or use another computer. Each server binds only to 127.0.0.1 on an ephemeral port.
Test processes are hidden, have timeouts and are stopped at the end. The test
fixture contains a self-referencing junction to verify that scanning skips it.
Core processes launch from a directory containing only a loose logo, exercising
embedded-resource fallback and safe cleanup when other loose images are absent.
Debug logs for that fixture contain expected "specified file does not exist"
warnings from the generated forms' initial disk loads, before embedded fallback.

Core tests cover empty and missing image lists; independent client cursors;
no-repeat cycles; editing a selected client after a status refresh; slot limits;
partial, failed and stalled sends; recursive Unicode/extension discovery;
missing, invalid and duplicate preferences; settings round trips; cancellation
on close; thumbnail replacement/removal; occupied ports; ten start/stop cycles;
configured/unassigned button state; and immediate port reuse.
Folder-selection regressions open and close About, then click Select folder,
cancel, reopen and save in both default-folder and client settings across repeated
dialog lifecycles. A native smoke test also opens and cancels the real Windows
folder chooser for both modes on every target, verifying its owner and the
preserved path. It closes only dialogs belonging to the isolated test process.

Raw TCP tests cover two complete no-repeat cycles, byte-exact image responses,
JPEG MIME, three-part fragmented GET, pipelined bytes, unsupported methods,
malformed requests, oversized headers, header deadlines, a pending-connection
cap, rapid disconnects, throttling/retry, a 9 MiB transfer with a delayed reader,
an aborted partial transfer, stop during blocked transmission, missing/empty
files, empty queues, full per-IP slots, exact Content-Length, no trailing NUL,
connection closure, non-caching responses, and completed-transfer counters.

The original baseline can be reproduced separately:

```powershell
pwsh -NoProfile -File .\tests\Establish-Baseline.ps1
```

That script exports the pinned historical revision to build/baseline, reproduces
four compiler failures, and uses a minimal compatibility shim to reproduce the
original stack overflow, selected-client access violation and fragmented GET
timeout. It does not overwrite current source or resources.

## Manual checks

1. Run `build/x64/Release/BIS_x64.Exe`. Check the ByteLord logo, title, About text,
   version 2.1.1, copyright 2019-2026, and layout at your usual display scale.
   Check the x86 Release UI as well, including a higher DPI display if available.
2. Set the default folder to WALLPICS, select the intended local address and a
   free port, then start. Refresh the displayed HTTP URL in your usual browser.
   Check thumbnails, tooltips, totals, animation, image formats and throttle
   behavior. A request within the minimum interval should return HTTP 429.
3. Stop, add or edit an IP-specific folder, restart, and confirm that a client at
   that IP uses its own folder. Use two actual client IPs to verify independent
   sequences over your normal network. Automated Windows loopback tests use one
   source IP; core tests separately verify client-state independence.
4. Stop/restart repeatedly while refreshing, close while serving, and close
   during a long scan. Reopen and check saved folders, positions and totals.
5. Enable minimize-to-tray, minimize, request images, then restore from the tray.
   Verify the current thumbnail and counts, and repeat with the setting disabled.
6. If desired, enable Run at user login, exit normally and verify the quoted BIS
   path under HKCU/Software/Microsoft/Windows/CurrentVersion/Run; confirm login
   starts the intended executable. Disable the setting and exit to remove it.
   Automated tests intentionally do not change this registry setting.

LAN access and firewall behavior require testing on your chosen interface. Files
larger than 2 GiB, long-running/high-concurrency load, unavailable network shares,
and operating-system out-of-memory conditions have not been exercised. File
lengths are 64-bit and streaming uses a bounded 64 KiB buffer. One worker handles
HTTP transfers serially; an unresponsive receiving client can delay other requests
until the two-second no-progress timeout. Filesystem reads on a stalled network
share can still delay shutdown.
