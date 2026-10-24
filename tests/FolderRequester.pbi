; Opens and cancels only folder dialogs owned by this isolated test process.
Global g_iNativeFolderFound.i, g_iNativeFolderOwner.i

Procedure DismissOwnedFolder(expectedOwner.i)
  Protected deadline.q = ElapsedMilliseconds() + 5000
  Protected window.i, processID.i
  Repeat
    window = 0
    Repeat
      window = FindWindowEx_(0, window, @"#32770", 0)
      If window
        GetWindowThreadProcessId_(window, @processID)
        If processID = GetCurrentProcessId_() And IsWindowVisible_(window)
          g_iNativeFolderFound = #True
          g_iNativeFolderOwner = Bool(GetWindow_(window, #GW_OWNER) = expectedOwner)
          PostMessage_(window, #WM_CLOSE, 0, 0)
          ProcedureReturn
        EndIf
      EndIf
    Until window = 0
    Delay(5)
  Until ElapsedMilliseconds() >= deadline
EndProcedure

Procedure NativeFolderTests()
  Shared s_iGadget
  Protected mode.i, worker.i, event.i, deadline.q
  LoadSettings(g_testRoot + "absent.bis")
  g_strDefaultFolder = g_testImages
  CreateClientList(MakeIPAddress(127,0,0,1), "127.0.0.1", g_testImages, 0)
  s_iGadget = 0
  For mode = #False To #True
    DisplayAboutBox(0)
    CloseAboutBox(0)
    ClientConfigDialog(mode)
    HideWindow(wndClientConfig, #True)
    g_iNativeFolderFound = #False
    g_iNativeFolderOwner = #False
    worker = CreateThread(@DismissOwnedFolder(), WindowID(wndClientConfig))
    Expect(Bool(worker), "create native requester watchdog")
    SendMessage_(GadgetID(btnImagesPath), #BM_CLICK, 0, 0)
    deadline = ElapsedMilliseconds() + 5500
    Repeat
      event = WaitWindowEvent(1)
      If event : ProcessWindowEvent(event) : EndIf
    Until g_iNativeFolderFound Or ElapsedMilliseconds() >= deadline
    WaitThread(worker)
    Expect(g_iNativeFolderFound, "real Windows folder chooser opens after About for client/default settings")
    Expect(g_iNativeFolderOwner, "real folder chooser is owned by the active configuration dialog")
    Expect(Bool(GetGadgetText(edtConfigImagesPath) = g_testImages), "cancelling real chooser preserves the folder")
    CloseClientConfig()
  Next
  PrintN("PASS: " + Str(g_testChecks) + " native folder requester checks")
EndProcedure
