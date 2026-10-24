; Runs only against the historical source exported by Establish-Baseline.ps1.
; No user preferences, login registration, firewall changes, or non-loopback binding.
OpenConsole()
g_MUTEX\Clients = CreateMutex()
g_MUTEX\Thumbnail = CreateMutex()
For Event = 0 To #LASTCLIENT
  g_rgUIClients(Event)\hBtnIP = #btn0 + Event
  g_rgUIClients(Event)\hTxtIP = #txt0 + Event
Next
g_strDefaultFolder = "C:\BIS-baseline"
Select ProgramParameter()
  Case "empty"
    CreateClientList(MakeIPAddress(127,0,0,1), "127.0.0.1", g_strDefaultFolder, 0)
    PrintN("Calling GetNextImage on an empty list")
    PrintN("Result=" + GetNextImage("127.0.0.1"))
  Case "cursor"
    CreateClientList(MakeIPAddress(127,0,0,1), "127.0.0.1", "C:\A", 0)
    CreateClientList(MakeIPAddress(127,0,0,2), "127.0.0.2", "C:\B", 1)
    s_iGadget = 0
    ClientConfigDialog(#False)
    ; A normal status refresh exhausts the shared map cursor.
    UpdateStatusBar()
    SetGadgetText(edtConfigImagesPath, "C:\Changed")
    SetClientConfig(0)
    PrintN("A=" + g_mapClients("127.0.0.1")\strImagesPath)
    PrintN("B=" + g_mapClients("127.0.0.2")\strImagesPath)
  Case "server"
    g_strServerIP = "127.0.0.1"
    g_iPort = Val(ProgramParameter())
    g_qMinTimeBetweenImages = 0
    CreateClientList(MakeIPAddress(127,0,0,1), "127.0.0.1", g_strDefaultFolder, 0)
    AddElement(g_mapClients()\listClientImages())
    g_mapClients()\listClientImages() = GetCurrentDirectory() + "resources\logo.png"
    ResetList(g_mapClients()\listClientImages())
    g_fNetworkEnabled = #True
    Define baselineWorker = CreateThread(@ImageServerThread(), 0)
    Define baselineDeadline.q = ElapsedMilliseconds() + 15000
    Repeat
      Delay(10)
    Until ElapsedMilliseconds() > baselineDeadline
    g_fNetworkEnabled = #False
    WaitThread(baselineWorker)
EndSelect
End
