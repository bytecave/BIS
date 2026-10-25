ByteLord Image Server, (c) 2019-2026 ByteLord. Licensed under the BSD 3-Clause License (BSD-3-Clause).

Version 2.1.3. Windows x64 and x86, built with PureBasic 6.41.

ByteLord Image Server is an open-source mini webserver that sends a random image to your browser when a client sends any GET request. You provide a recursively processed folder containing the images to display. Those images are then shuffled and never repeated--on a per client connection basis--until all images have been displayed once. The process then repeats itself for subsequent image requests. Great for wall tablets and kiosks!

Download and extract Binaries/BIS-2.1.3.zip. It contains BIS_x64.Exe and
BIS_x86.Exe for normal use, plus BISDebug_x64.Exe and BISDebug_x86.Exe for
debugging. Run the executable matching your Windows architecture. The ZIP contains only those EXEs.

Instructions
===========================================================================
While image server networking is stopped:
> Click "Default Folder" button to add default images folder for new
  connections.
> Click on any image button to specify images folder for specified IP
  address or to remove button for that IP address.

While image server is running:
> Last displayed image displays on the surface of button associated with
  the IP address that requested the image.
> Click "Default Folder" to display name of default images folder.
> Click on any image button that is not grayed out to display grand total
  of images ever displayed for that IP address and path of the last
  displayed image.
> Hover over any image button that is not grayed out to see tooltip
  containing the information above.

Open the Connect String shown by BIS in your browser. When using a port other
than 80, include that port in the URL, for example `http://<server-ip>:8080`.

Github home: https://github.com/bytelordgames/BIS
Support: https://github.com/bytelordgames/BIS/issues

License
===========================================================================
BIS is licensed under the BSD 3-Clause License (BSD-3-Clause). Source and binary redistributions, with or without modification, are permitted subject to the copyright notice, license conditions and disclaimer in [LICENSE.md](LICENSE.md). ByteLord and contributor names may not be used to endorse derived products without prior written permission. The full license is also available from the About dialog in every executable.

Build and validation
===========================================================================
Open "ByteLord Image Server.pbp" in the corresponding PureBasic IDE, or use
PowerShell 7 from this directory:

    pwsh -NoProfile -File .\Build.ps1
    pwsh -NoProfile -File .\Validate.ps1
    pwsh -NoProfile -File .\Package.ps1

Build.ps1 builds all four x64/x86 Debug/Release targets into build/, using the
installed compilers in Program Files and Program Files (x86). It retains the
project's thread-safe runtime, Windows themes, optimizer setting, application icon, constants and
version resources, and verifies each executable's machine type and metadata.
Use -Architecture x64 or x86 and -Configuration Debug or Release for a subset.

Validate.ps1 also runs isolated core and loopback HTTP regression tests. If a
WALLPICS directory exists, it scans those images without modifying them.
Package.ps1 rebuilds all four production targets, copies the EXEs to Binaries,
and creates Binaries/BIS-2.1.3.zip containing only those four executables. It
extracts the ZIP and verifies the file hashes, architecture, version, copyright,
Debug flags and embedded logo. Release EXEs and ZIPs in Binaries are included in Git.
Temporary build output, WALLPICS, and the local handoff are excluded from Git.
See TESTING.md for the test scope and manual checks.

Requests and image discovery
===========================================================================
Each HTTP connection receives one response and then closes. Unsupported methods,
unavailable images, rate limits and full client slots return explicit HTTP error
responses. Image responses disable caching so refreshing can request a new image.
JPEG, PNG, GIF and BMP files are supported. Directory junctions and symbolic-link
directories are skipped to avoid cycles; recursion stops after 128 nested levels.
The server retains up to 14 per-IP client configurations.
