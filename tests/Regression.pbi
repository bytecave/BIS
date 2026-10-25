; Compiled from BIS.pb with BIS_TEST=1; uses the real production procedures.
; All preferences and fixtures live under the supplied build directory.
Global g_testRoot.s = ProgramParameter(1) + "\"
Global g_testImages.s = g_testRoot + "fixtures\"
Global g_testChecks.i

Procedure Expect(condition.i, label.s)
  g_testChecks + 1
  If Not condition
    PrintN("FAIL: " + label)
    End 1
  EndIf
EndProcedure

Procedure ClickConfigControl(gadget.i)
  Protected event.i, deadline.q = ElapsedMilliseconds() + 100
  SendMessage_(GadgetID(gadget), #BM_CLICK, 0, 0)
  Repeat
    event = WaitWindowEvent(1)
    If event : ProcessWindowEvent(event) : EndIf
  Until ElapsedMilliseconds() >= deadline
EndProcedure

Procedure AboutLicenseTests()
  Protected text.s
  DisplayAboutBox(0)
  HideWindow(wndAbout, #True)
  text = GetGadgetText(edtAbout)
  Expect(Bool(GetGadgetText(txtAboutLabel) = "About " + #BIS_TITLE + " v" + #BIS_VERSION), "About displays the current product version")
  Expect(Bool(FindString(text, "BSD 3-Clause License")), "embedded README identifies the BSD license")
  Expect(Bool(FindString(text, "BSD-3-Clause")), "embedded README includes the SPDX identifier")
  Expect(Bool(GetGadgetText(btnContent) = "Display BSD 3-Clause License"), "About offers the current license")
  ClickConfigControl(btnContent)
  text = GetGadgetText(edtAbout)
  Expect(Bool(FindString(text, "# BSD 3-Clause License")), "About opens the embedded BSD license")
  Expect(Bool(FindString(text, "Copyright (c) 2019-2026 ByteLord")), "embedded license retains the copyright notice")
  Expect(Bool(FindString(text, "1. Redistributions of source code")), "embedded license includes the source redistribution clause")
  Expect(Bool(FindString(text, "2. Redistributions in binary form")), "embedded license includes the binary redistribution clause")
  Expect(Bool(FindString(text, "3. Neither the name")), "embedded license includes the non-endorsement clause")
  Expect(Bool(FindString(text, "THIS SOFTWARE IS PROVIDED")), "embedded license includes its disclaimer")
  Expect(Bool(Not FindString(text, "Permission is hereby granted, free of charge")), "embedded license excludes obsolete grant text")
  Expect(Bool(GetGadgetText(btnContent) = "Read about ByteLord Image Server"), "license view offers the README")
  ClickConfigControl(btnContent)
  Expect(Bool(FindString(GetGadgetText(edtAbout), "Version " + #BIS_VERSION)), "license can switch back to the current README")
  CloseAboutBox(0)
  Expect(Bool(wndAbout = 0), "About license test closes its dialog")
EndProcedure

Procedure FolderSelectionTests()
  Shared s_iGadget
  Protected mode.i, cycle.i, calls.i
  Protected originalDefault.s = g_strDefaultFolder
  Protected originalClient.s = g_mapClients("127.0.0.1")\strImagesPath
  g_fTestFolderRequester = #True
  s_iGadget = 0
  For cycle = 1 To 3
    For mode = #False To #True
      DisplayAboutBox(0)
      CloseAboutBox(0)
      Expect(Bool(wndAbout = 0), "closed About window cannot intercept a reused window ID")
      ClientConfigDialog(mode)
      HideWindow(wndClientConfig, #True)
      calls = g_iTestFolderCalls
      g_strTestFolderResult = g_testImages + "nested\"
      ClickConfigControl(btnImagesPath)
      Expect(Bool(g_iTestFolderCalls = calls + 1), "folder button is routed to the requester after About")
      Expect(Bool(g_iTestFolderParent = WindowID(wndClientConfig)), "folder chooser belongs to the configuration dialog")
      Expect(Bool(GetGadgetText(edtConfigImagesPath) = g_strTestFolderResult), "chosen folder appears in client/default dialog")
      Expect(Bool(Not (GetWindowLongPtr_(GadgetID(btnSetClient), #GWL_STYLE) & #WS_DISABLED)), "choosing a folder enables Set")
      calls = g_iTestFolderCalls
      g_strTestFolderResult = ""
      ClickConfigControl(btnImagesPath)
      Expect(Bool(g_iTestFolderCalls = calls + 1), "folder chooser can be reopened")
      Expect(Bool(GetGadgetText(edtConfigImagesPath) = g_testImages + "nested\"), "cancelling the chooser preserves the selected folder")
      ClickConfigControl(btnSetClient)
      Expect(Bool(wndClientConfig = 0), "Set closes and clears the client configuration window")
      If mode
        Expect(Bool(g_strDefaultFolder = g_testImages + "nested\"), "default folder selection is saved")
      Else
        Expect(Bool(g_mapClients("127.0.0.1")\strImagesPath = g_testImages + "nested\"), "client folder selection is saved")
      EndIf
    Next
  Next
  g_fTestFolderRequester = #False
  g_strDefaultFolder = originalDefault
  g_mapClients("127.0.0.1")\strImagesPath = originalClient
EndProcedure

Procedure ResetTestClients()
  StopImageServer()
  ClearMap(g_mapClients())
  ClearList(g_listDefaultImages())
  g_qMinTimeBetweenImages = 0
  g_fTerminateProgram = #False
  RefreshClientButtons()
EndProcedure

Procedure WaitForTestServer()
  Protected deadline.q = ElapsedMilliseconds() + 5000
  While g_iNetworkStatus = #SERVERSTARTING And ElapsedMilliseconds() < deadline
    Delay(1)
  Wend
  Expect(Bool(g_iNetworkStatus <> #SERVERSTARTING), "server startup is bounded")
EndProcedure

Procedure StartTestServer()
  g_iNetworkStatus = #SERVERSTARTING
  g_fNetworkEnabled = #True
  g_iServerThread = CreateThread(@ImageServerThread(), 0)
  Expect(Bool(g_iServerThread), "network worker created")
  WaitForTestServer()
EndProcedure

Procedure MakeTestImages()
  Protected img.i, i.i
  Protected Dim names.s(3)
  names(0) = g_testImages + "a.png"
  names(1) = g_testImages + "b.jpg"
  names(2) = g_testImages + "c.bmp"
  names(3) = g_testImages + "nested\unicode-" + Chr($56FE) + ".PNG"
  UsePNGImageEncoder()
  UseJPEGImageEncoder()
  For i = 0 To 3
    img = CreateImage(#PB_Any, 120 + i, 110 + i, 24, RGB(40 * i, 50, 90))
    Expect(Bool(img), "create fixture")
    Select i
      Case 1 : Expect(SaveImage(img, names(i), #PB_ImagePlugin_JPEG), "save JPEG fixture")
      Case 2 : Expect(SaveImage(img, names(i), #PB_ImagePlugin_BMP), "save BMP fixture")
      Default : Expect(SaveImage(img, names(i), #PB_ImagePlugin_PNG), "save PNG fixture")
    EndSelect
    FreeImage(img)
  Next
  img = CreateImage(#PB_Any, 2048, 1536, 24, RGB(70, 90, 110))
  Expect(Bool(img), "create large fixture")
  Expect(SaveImage(img, g_testRoot + "large.bmp", #PB_ImagePlugin_BMP), "save large fixture")
  FreeImage(img)
EndProcedure

Procedure CoreTests()
  Shared s_iGadget
  Protected i.i, j.i, file.i, previous.i, blocker.i, port.i, buttonDC.i, expectedColor.i
  Protected paintDeadline.q
  Protected image.s, key.s
  Protected *data
  Protected NewMap seen.i()
  Protected NewList images.s()
  ; Missing settings must not make an invalid Preferences call in Debug.
  LoadSettings(g_testRoot + "absent.bis")
  Expect(Bool(ImageWidth(Img_wndMain_0) <= 120 And ImageHeight(Img_wndMain_0) <= 62), "logo fits button without cropping")
  Expect(Bool(MapSize(g_mapClients()) = 0), "missing preferences are safe")
  AboutLicenseTests()
  MakeTestImages()
  g_strDefaultFolder = g_testImages
  CreateClientList(MakeIPAddress(127,0,0,1), "127.0.0.1", g_testImages, 0)
  Expect(Bool(GetNextImage("127.0.0.1") = ""), "empty queue has a finite result")
  Expect(Bool(GetNextImage("missing") = "" And MapSize(g_mapClients()) = 1), "unknown queue does not create a client")
  For i = 1 To 3
    AddElement(g_mapClients("127.0.0.1")\listClientImages())
    g_mapClients()\listClientImages() = Str(i)
  Next
  ShuffleImageList("127.0.0.1")
  For j = 1 To 20
    ClearMap(seen())
    For i = 1 To 3
      image = GetNextImage("127.0.0.1")
      Expect(Bool(image <> "" And Not FindMapElement(seen(), image)), "no repeats within a client cycle")
      seen(image) = 1
    Next
  Next
  Expect(Bool(g_mapClients("127.0.0.1")\iTotalImages = 0), "selection alone is not counted as a transmitted image")
  ; Reproduce the old exhausted-map-cursor configuration crash.
  CreateClientList(MakeIPAddress(127,0,0,2), "127.0.0.2", g_testImages, 1)
  s_iGadget = 0
  ClientConfigDialog(#False)
  HideWindow(wndClientConfig, #True)
  UpdateStatusBar()
  SetGadgetText(edtConfigImagesPath, g_testImages + "nested\")
  SetClientConfig(0)
  Expect(Bool(g_mapClients("127.0.0.1")\strImagesPath = g_testImages + "nested\"), "edit selected client after status refresh")
  Expect(Bool(g_mapClients("127.0.0.2")\strImagesPath = g_testImages), "other client path unchanged")
  FolderSelectionTests()
  ; Per-client lists and cursors are independent.
  AddElement(g_mapClients("127.0.0.2")\listClientImages())
  g_mapClients()\listClientImages() = "only-B"
  ResetList(g_mapClients()\listClientImages())
  GetNextImage("127.0.0.1")
  Expect(Bool(GetNextImage("127.0.0.2") = "only-B"), "independent client cursor")
  ResetTestClients()
  For i = 0 To #LASTCLIENT
    key = "10.0.0." + Str(i + 1)
    Expect(CreateClientList(MakeIPAddress(10,0,0,i+1), key), "allocate client slot")
  Next
  Expect(Bool(Not CreateClientList(MakeIPAddress(10,0,0,99), "10.0.0.99")), "reject fifteenth client")
  Expect(Bool(Not CreateClientList(1, "invalid", g_testImages, -1)), "reject negative slot")
  ResetTestClients()
  ; Simulate success, backpressure, zero progress, and failure after progress.
  g_fNetworkEnabled = #True
  g_fFakeSocket = #True
  For i = 0 To 5
    AddElement(g_listFakeWrites())
    Select i
      Case 0 : g_listFakeWrites() = 3
      Case 1, 4 : g_listFakeWrites() = -1
      Case 2 : g_listFakeWrites() = 0
      Case 3 : g_listFakeWrites() = 2
      Case 5 : g_listFakeWrites() = 3
    EndSelect
  Next
  ResetList(g_listFakeWrites())
  *data = Ascii("ABCDEFGH")
  Expect(SendAll(0, *data, 8), "partial writes recover")
  Expect(Bool(g_strFakeOutput = "ABCDEFGH"), "send offset never moves backward")
  ClearList(g_listFakeWrites())
  Expect(Bool(Not SendAll(0, *data, 8)), "stalled socket times out")
  g_fNetworkEnabled = #False
  Expect(Bool(Not SendAll(0, *data, 8)), "stop interrupts a send")
  FreeMemory(*data)
  g_fFakeSocket = #False
  ; Recursive discovery includes supported formats and Unicode, skips junctions.
  g_fSearchingImages = #True
  GetImagesList(g_testImages, images())
  g_fSearchingImages = #False
  Expect(Bool(ListSize(images()) = 4), "recursive fixture discovery and junction exclusion")
  ; Preferences round trip without touching the real home config or registry.
  g_qMinTimeBetweenImages = 2000
  CreateClientList(MakeIPAddress(127,0,0,1), "127.0.0.1", g_testImages, 0, 123)
  g_strDefaultFolder = g_testImages
  g_strServerIP = "127.0.0.1"
  SaveSettings(g_testRoot + "roundtrip.bis", #False)
  ResetTestClients()
  LoadSettings(g_testRoot + "roundtrip.bis")
  Expect(Bool(g_mapClients("127.0.0.1")\iTotalImages = 123), "persistent client count round trip")
  Expect(Bool(g_mapClients("127.0.0.1")\strImagesPath = g_testImages), "persistent client path round trip")
  file = CreateFile(#PB_Any, g_testRoot + "invalid.bis")
  WriteStringN(file, "Port = 99999")
  WriteStringN(file, "MinTimeBetweenImages = -1")
  WriteStringN(file, "ClientIP0 = " + Str(MakeIPAddress(127,0,0,1)))
  WriteStringN(file, "ClientIP1 = " + Str(MakeIPAddress(127,0,0,1)))
  CloseFile(file)
  ResetTestClients()
  LoadSettings(g_testRoot + "invalid.bis")
  Expect(Bool(g_iPort = #DEFAULTSERVERPORT And g_qMinTimeBetweenImages = #DEFAULTMINTIME), "invalid preference ranges use defaults")
  Expect(Bool(MapSize(g_mapClients()) = 1), "duplicate persisted IP is ignored")
  ; A close event during scanning must cancel startup.
  g_strDefaultFolder = g_testImages
  g_fSearchingImages = #True
  PostEvent(#PB_Event_CloseWindow, wndMain, 0)
  CreateImageLists()
  Expect(Bool(g_fTerminateProgram And Not g_fSearchingImages And g_iImagesQueued = 0), "close cancels discovery")
  g_fTerminateProgram = #False
  ; Replacement must update the button as well as retain a valid image object.
  HideWindow(wndMain, #False)
  For i = 1 To 30
    previous = g_rgUIClients(0)\iThumbnail
    AddElement(g_listThumbnails())
    If i % 2
      g_listThumbnails()\strImage = g_testImages + "a.png"
      expectedColor = RGB(0, 50, 90)
    Else
      g_listThumbnails()\strImage = g_testImages + "nested\unicode-" + Chr($56FE) + ".PNG"
      expectedColor = RGB(120, 50, 90)
    EndIf
    g_listThumbnails()\iGadget = 0
    g_listThumbnails()\iCount = i
    DisplayThumbnails(0)
    Expect(Bool(IsImage(g_rgUIClients(0)\iThumbnail)), "current thumbnail is valid")
    Expect(Bool(ImageWidth(g_rgUIClients(0)\iThumbnail) = 100 And ImageHeight(g_rgUIClients(0)\iThumbnail) = 100), "thumbnail is sized for the client button")
    Expect(Bool(GetGadgetAttribute(g_rgUIClients(0)\hBtnIP, #PB_Button_Image) = ImageID(g_rgUIClients(0)\iThumbnail)), "client button displays the current thumbnail")
    RefreshClientButtons()
    Expect(Bool(GetGadgetAttribute(g_rgUIClients(0)\hBtnIP, #PB_Button_Image) = ImageID(g_rgUIClients(0)\iThumbnail)), "client refresh preserves the displayed thumbnail")
    paintDeadline = ElapsedMilliseconds() + 10
    Repeat
      ProcessWindowEvent(WaitWindowEvent(1))
    Until ElapsedMilliseconds() >= paintDeadline
    buttonDC = GetDC_(GadgetID(g_rgUIClients(0)\hBtnIP))
    Expect(Bool(GetPixel_(buttonDC, 50, 50) = expectedColor), "client button paints the latest image pixels")
    ReleaseDC_(GadgetID(g_rgUIClients(0)\hBtnIP), buttonDC)
    If previous : Expect(Bool(Not IsImage(previous)), "previous thumbnail is freed") : EndIf
  Next
  HideWindow(wndMain, #True)
  previous = g_rgUIClients(0)\iThumbnail
  s_iGadget = 0
  ClientConfigDialog(#False)
  HideWindow(wndClientConfig, #True)
  RemoveClientConfig(0)
  Expect(Bool(Not IsImage(previous)), "removing client frees thumbnail")
  ResetTestClients()
  ; Failed binding, repeated start/stop, and immediate port reuse.
  g_strServerIP = "127.0.0.1"
  port = Val(ProgramParameter(2))
  g_iPort = port
  blocker = CreateNetworkServer(#PB_Any, port, #PB_Network_TCP, "127.0.0.1")
  Expect(Bool(blocker), "reserve occupied test port")
  StartTestServer()
  Expect(Bool(g_iNetworkStatus = #SERVERNOTSTARTED), "occupied port reports failure")
  StopImageServer()
  CloseNetworkServer(blocker)
  AddGadgetItem(cmbServerIP, -1, "127.0.0.1")
  SetGadgetState(cmbServerIP, CountGadgetItems(cmbServerIP) - 1)
  CreateClientList(MakeIPAddress(127,0,0,1), "127.0.0.1", g_testImages, 0)
  For i = 1 To 10
    ToggleImageServer(#STARTSERVER)
    Expect(Bool(g_fNetworkEnabled And g_iServerThread And g_iNetworkStatus = #SERVERSTARTED), "UI lifecycle starts")
    Expect(Bool(Not (GetWindowLongPtr_(GadgetID(#btn0), #GWL_STYLE) & #WS_DISABLED)), "configured client button enabled on start")
    Expect(Bool(GetWindowLongPtr_(GadgetID(#btn1), #GWL_STYLE) & #WS_DISABLED), "unassigned client button disabled while running")
    SetGadgetState(btnControl, 0)
    ToggleImageServer(#STOPSERVER)
    Expect(Bool(Not g_fNetworkEnabled And g_iServerThread = 0), "UI lifecycle joins worker")
    blocker = CreateNetworkServer(#PB_Any, port, #PB_Network_TCP, "127.0.0.1")
    Expect(Bool(blocker), "port immediately reusable after stop")
    CloseNetworkServer(blocker)
  Next
  If ProgramParameter(3) <> "" And FileSize(ProgramParameter(3)) = -2
    ClearList(images())
    g_fSearchingImages = #True
    GetImagesList(ProgramParameter(3), images())
    g_fSearchingImages = #False
    Expect(Bool(ListSize(images()) > 0), "owner image folder discovery")
    PrintN("WALLPICS supported images discovered: " + Str(ListSize(images())))
  EndIf
  PrintN("PASS: " + Str(g_testChecks) + " core checks")
EndProcedure

Procedure ServeTests()
  Protected scenario.s = ProgramParameter(3)
  Protected i.i, file.i
  Protected deadline.q = ElapsedMilliseconds() + 90000
  ; Force a millisecond boundary during auto-add to expose first-request throttling.
  g_iTestCreateDelay = 5
  LoadSettings(g_testRoot + "absent.bis")
  g_strDefaultFolder = g_testImages
  g_strServerIP = "127.0.0.1"
  g_iPort = Val(ProgramParameter(2))
  g_qMinTimeBetweenImages = 0
  Select scenario
    Case "normal", "throttle"
      g_fSearchingImages = #True
      GetImagesList(g_testImages, g_listDefaultImages())
      g_fSearchingImages = #False
      ResetList(g_listDefaultImages())
      If scenario = "throttle" : g_qMinTimeBetweenImages = 2000 : EndIf
    Case "large", "missing", "zero"
      AddElement(g_listDefaultImages())
      If scenario = "large"
        g_listDefaultImages() = g_testRoot + "large.bmp"
      Else
        g_listDefaultImages() = g_testRoot + scenario + ".jpg"
      EndIf
      ResetList(g_listDefaultImages())
    Case "full"
      For i = 0 To #LASTCLIENT
        CreateClientList(MakeIPAddress(10,0,0,i+1), "10.0.0." + Str(i+1), g_testImages, i)
      Next
    Case "empty"
      ; Deliberately empty default list exercises the old stack overflow.
  EndSelect
  StartTestServer()
  Expect(Bool(g_iNetworkStatus = #SERVERSTARTED), "loopback test server starts")
  file = CreateFile(#PB_Any, g_testRoot + scenario + ".ready")
  CloseFile(file)
  While FileSize(g_testRoot + scenario + ".stop") = -1 And ElapsedMilliseconds() < deadline
    ProcessWindowEvent(WindowEvent())
    Delay(1)
  Wend
  StopImageServer()
  ForEach g_mapClients()
    If g_mapClients()\fAskedForImage
      i = g_mapClients()\iGadget
      Expect(Bool(g_rgUIClients(i)\strIPClientMapKey = MapKey(g_mapClients())), "HTTP client owns the displayed slot")
      Expect(Bool(IsImage(g_rgUIClients(i)\iThumbnail)), "completed HTTP image has a decoded thumbnail")
      Expect(Bool(GetGadgetAttribute(g_rgUIClients(i)\hBtnIP, #PB_Button_Image) = ImageID(g_rgUIClients(i)\iThumbnail)), "completed HTTP image is attached to the client button")
      Expect(Bool(g_rgUIClients(i)\iTotalImages = g_mapClients()\iTotalImages), "thumbnail count matches completed HTTP responses")
    EndIf
  Next
  file = CreateFile(#PB_Any, g_testRoot + scenario + ".stats")
  WriteStringN(file, Str(g_iImagesServed))
  WriteStringN(file, Str(g_iForeverImagesServed))
  WriteStringN(file, Str(ListSize(g_listThumbnails())))
  CloseFile(file)
  Expect(Bool(ElapsedMilliseconds() < deadline), "server test completed before watchdog")
  PrintN("PASS: server " + scenario)
EndProcedure

OpenConsole()
XIncludeFile "FolderRequester.pbi"
Select ProgramParameter(0)
  Case "core" : CoreTests()
  Case "folder-native" : NativeFolderTests()
  Case "server" : ServeTests()
  Default : PrintN("Expected core, folder-native or server mode") : End 1
EndSelect
End 0
