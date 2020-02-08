;This software provided under MIT license. Copyright 2019-2020, ByteCave

EnableExplicit

#CHANGEPORT = 20000
#STARTSERVER = 1
#STOPSERVER = 0
#MAXSTATUSEVENTS = 3000
#NONETWORK = "No Network"
#DEFAULTMINTIME = 2000
#DEFAULTSERVERPORT = 80
#UPDATESEARCHIMAGE = #PB_Event_FirstCustomValue + 1
#UPDATETHUMBNAILTOOLTIP = #PB_Event_FirstCustomValue + 2
#STATUSUPDATEINTERVAL = 10000
#ACTIVECLIENTTIMEOUT = 330000  ;5.5 minutes timeout
#PREFSFILENAME = "config.bis"
#BIS_TITLE = "ByteCave Image Server"
#DEFAULTCLIENTIP = "0.0.0.0"
#AUTOSEARCH = 9999

Structure sCLIENT
  List listClientImages.s()
  qTimeSinceLastRequest.q
  iClientIP.i
  strImagesPath.s
  iGadget.i
  fAskedForImage.i
  iTotalImages.i
EndStructure

Structure sTHUMBINFO
  strImage.s
  iGadget.i
  iCount.i
EndStructure

Structure sUICLIENT
  hBtnIP.i
  hTxtIP.i
  strIPClientMapKey.s
  strImageDisplayed.s
  iTotalImages.i
EndStructure

Structure MUTEX
  Thumbnail.i
  Clients.i
EndStructure

Global g_MUTEX.MUTEX
Global g_fNetworkEnabled.i
Global g_fTerminateProgram.i
Global g_iNetworkStatus.i
Global g_fNetworkInitialized.i
Global g_iImagesServed.i
Global g_iImagesQueued.i
Global g_fSearchingImages.i
Global g_iLastIP.i
Global g_fMinimized.i
Global g_iRunAtLogin.i
Global g_iMinimizeToTray.i
Global g_imgPlaceholder.i 
Global g_imgAvailable.i
Global g_iForeverImagesServed.i
Global g_strServerIP.s
Global g_strDefaultFolder.s
Global g_qMinTimeBetweenImages.q = #DEFAULTMINTIME
Global g_iPort.i = #DEFAULTSERVERPORT

Global NewList g_listDefaultImages.s()
Global NewList g_listThumbnails.sTHUMBINFO()
Global NewMap g_mapClients.sCLIENT()

Define Event
Define s_imgAppIcon.i, s_iWindowX.i, s_iWindowY.i

Declare AddStatusEvent(strStatusEvent.s, fSetGadgetStatus = #False, iColor.i = #Black)
Declare ProcessWindowEvent(Event)
Declare ShuffleImageList(strClientIP.s)
Declare.s GetNextImage(strClientIP.s)
Declare.i CreateClientList(iClientIP.i, strClientIP.s, strImagesPath.s = "", iGadgetPos.i = #AUTOSEARCH, iTotalImages.i = 0)

;initialize decoders before referencing in MainUI
UseGIFImageDecoder()
UseJPEGImageDecoder()

;Change #LASTCLIENT to match number of client buttons - 1
XIncludeFile "frmBIS.pbf"
#LASTCLIENT = 13
Global Dim g_rgUIClients.sUICLIENT(#LASTCLIENT)

XIncludeFile "ImageServer.pbi"
XIncludeFile "Helpers.pbi"
XIncludeFile "ClientConfig.pbi"
XIncludeFile "CrossPlatform.pbi"
XIncludeFile "MainUI.pbi"
XIncludeFile "About.pbi"

Procedure GetImagesList(strDir.s, List listImages.s())   ;Lists in PureBasic are always passed by reference
  NewList Directories.s()
  Protected strFileName.s
  Protected iDirectory.i
  
  If Right(strDir, 1) <> "\"
    strDir + "\"
  EndIf
  
  iDirectory = ExamineDirectory(#PB_Any, strDir, "*.*")
  
  If iDirectory
    While NextDirectoryEntry(iDirectory)
      ProcessWindowEvent(WindowEvent())
      
      If g_fSearchingImages
        Select DirectoryEntryType(iDirectory)
          Case #PB_DirectoryEntry_File
            
            strFileName = DirectoryEntryName(iDirectory)
            Select LCase(GetExtensionPart(strFileName))
              Case "jpg", "jpeg", "png", "gif", "bmp"
                If g_iImagesQueued % 500 = 0
                  SetGadgetColor(lblStatus, #PB_Gadget_FrontColor, #Black)
                  SetGadgetText(lblStatus, "Searching for images, please wait... [" + Str(g_iImagesQueued) + "]")
                EndIf
                
                g_iImagesQueued + 1
                AddElement(listImages())
                listImages() = strDir + strFileName
              EndSelect
            
          Case #PB_DirectoryEntry_Directory
            Select DirectoryEntryName(iDirectory)
              Case ".", ".."
                Continue
                
              Default
                AddElement(Directories())
                Directories() = strDir + DirectoryEntryName(iDirectory)
            EndSelect
        EndSelect
      Else
        Break
      EndIf
    Wend
    
    FinishDirectory(iDirectory)
    
    If g_fSearchingImages
      ForEach Directories()
        GetImagesList(Directories(), listImages())
      Next
    EndIf
    
    FreeList(Directories())
  EndIf
EndProcedure

Procedure AddStatusEvent(strStatusEvent.s, fSetGadgetStatus = #False, iColor.i = #Black)
  If CountGadgetItems(lstEvents) = #MAXSTATUSEVENTS
    RemoveGadgetItem(lstEvents, 0)
  EndIf
  
  AddGadgetItem(lstEvents, 0, strStatusEvent)
  SetGadgetItemColor(lstEvents, 0, #PB_Gadget_FrontColor, iColor, #PB_All)

  
  If fSetGadgetStatus
    SetGadgetColor(lblStatus, #PB_Gadget_FrontColor, iColor)
    SetGadgetText(lblStatus, strStatusEvent)
  EndIf
EndProcedure

Procedure GetServerIPs()
  Protected iIP.i
  Protected iIdx.i = -1
  Protected iNumIP.i
  
  ;get all IP addresses on system and add to combobox list
  If ExamineIPAddresses()
    Repeat
      iIP = NextIPAddress()
      
      If iIP
        AddGadgetItem(cmbServerIP, -1, IPString(iIP))
        iNumIP + 1
        
        ;if existing IP selected from settings, set it to current item in combo list
        If IPString(iIP) = g_strServerIP
          iIdx = iNumIP - 1
        EndIf
      EndIf
    Until iIP = 0
    
    If iNumIP = 1
      iIdx = 0
    EndIf
    
    SetGadgetState(cmbServerIP, iIdx)
    g_strServerIP = GetGadgetText(cmbServerIP)
  EndIf
EndProcedure

Procedure.i InitializeNetwork()
  Protected fRC.i = #True
  
  If Not InitNetwork()
    AddGadgetItem(cmbServerIP, -1, #NONETWORK)
    AddStatusEvent("Could not initialize network. Restart app to try again.", #True, #Red)
    
    HideGadget(cmbServerIP, #True)
    HideGadget(lblNoNetwork, #False)
    DisableGadget(edtPort, #True)
    DisableGadget(edtMinTime, #True)
    DisableGadget(btnDefaultFolder, #True)
    
    fRC = #False
  EndIf
  
  ProcedureReturn fRC
EndProcedure

Procedure ChangePort(EventType)
  Protected nPort.i
  
  If EventType = #PB_EventType_LostFocus Or EventType = #CHANGEPORT
    nPort = Val(GetGadgetText(edtPort))
    
    If nPort > 0 And nPort < 65536
      g_iPort = nPort
    Else
      AddStatusEvent("Please choose a port number between 1 And 65535.", #True, #Red)
      SetGadgetText(edtPort, Str(g_iPort))
      SetActiveGadget(edtPort)
    EndIf
  EndIf
EndProcedure

Procedure ChangeMinTime(EventType)
  Protected iMinTime.i
  
  If EventType = #PB_EventType_LostFocus
    iMinTime = Val(GetGadgetText(edtMinTime))
    
    If iMinTime >= 2000 And iMinTime <= 86400
      g_qMinTimeBetweenImages = iMinTime
    Else
      AddStatusEvent("Please choose a minimum time between 2000 And 86400 milliseconds.", #True, #Red)
      SetGadgetText(edtMinTime, Str(g_qMinTimeBetweenImages))
      SetActiveGadget(edtMinTime)
    EndIf
  EndIf
EndProcedure

Procedure ChangeServerIP(EventType)
  If EventType = #PB_EventType_Change   
    g_strServerIP = GetGadgetText(cmbServerIP)
  EndIf
EndProcedure

;Client MUTEX locked before calling this
Procedure ShuffleImageList(strClientIP.s)
  With g_mapClients(strClientIP)
    AddStatusEvent("Shuffling image list for >> " + strClientIP + " << ... Grand total displayed: " + FormatNumber(\iTotalImages, 0), #False, #Blue)
    RandomizeList(\listClientImages())
    ResetList(\listClientImages())
  EndWith

EndProcedure

;When network is running, Client MUTEX is locked before calling this
Procedure.i CreateClientList(iClientIP.i, strClientIP.s, strImagesPath.s = "", iGadgetPos.i = #AUTOSEARCH, iTotalImages.i = 0)
  Protected iIdx.i
  Protected fAvailableSlot.i = #False
   
   If strImagesPath = ""
    strImagesPath = g_strDefaultFolder
  EndIf
  
  iIdx = iGadgetPos
  
  ;if adding via client network connection, search for free gadget to display thumbnails/store client IP
  If iGadgetPos = #AUTOSEARCH
    For iIdx = 0 To #LASTCLIENT
      If g_rgUIClients(iIdx)\strIPClientMapKey = ""
        Break
      EndIf
    Next
    
    ;Last IP set = new client connected
    g_iLastIP = MakeIPAddress(Val(StringField(strClientIP, 1, ".")),
                              Val(StringField(strClientIP, 2, ".")),
                              Val(StringField(strClientIP, 3, ".")),
                              0)
  EndIf
  
  ;if we found a valid slot or one was passed in
  If iIdx <= #LASTCLIENT
    AddMapElement(g_mapClients(), strClientIP)
    
    With g_mapClients()
      \iClientIP = iClientIP
      \strImagesPath = strImagesPath
      \iGadget = iIdx
      \qTimeSinceLastRequest = ElapsedMilliseconds() - g_qMinTimeBetweenImages
      \iTotalImages = iTotalImages
    EndWith
    
    ;create list based off default path when auto-addded
    If iGadgetPos = #AUTOSEARCH
      CopyList(g_listDefaultImages(), g_mapClients()\listClientImages())
      ShuffleImageList(strClientIP)
    EndIf
    
    ;set button image list information
    With g_rgUIClients(iIdx)
      \strIPClientMapKey = strClientIP
      \iTotalImages = iTotalImages
      
      SetGadgetText(\hTxtIP, strClientIP)
      SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(g_imgPlaceholder))
      GadgetToolTip(\hBtnIP, "[Total: " + Str(iTotalImages) + "] Current: <none>")
      DisableGadget(\hBtnIP, #False)
    EndWith
      
    fAvailableSlot = #True
  EndIf
  
  ProcedureReturn fAvailableSlot
EndProcedure            

;MUTEX locked before calling this
Procedure.s GetNextImage(strClientIP.s)
  Protected strImage.s
  
  With g_mapClients()  ;g_mapClients() points to correct entry for this IP address on call -- g_mapClients(strClientIP)
    If NextElement(\listClientImages())
      strImage = \listClientImages()
      g_iImagesServed + 1
      g_iForeverImagesServed + 1
      \iTotalImages + 1
      
      LockMutex(g_MUTEX\Thumbnail)
      
      AddElement(g_listThumbnails())
      g_listThumbnails()\strImage = strImage
      g_listThumbnails()\iGadget = \iGadget
      g_listThumbnails()\iCount = \iTotalImages
      
      UnlockMutex(g_MUTEX\Thumbnail)
    Else
      ShuffleImageList(strClientIP)
      strImage = GetNextImage(strClientIP)
    EndIf
    
    ;for counting active connections, need to know if client requested at least one image
    \fAskedForImage = #True
  EndWith
  
  ProcedureReturn strImage
EndProcedure  

Procedure CreateImageLists()
  Protected NewMap mapUniqueImages.s()  ;used solely to count unique images
  Protected i.i
  
  g_iImagesQueued = 0
  
  ;get images for default folder
  ClearList(g_listDefaultImages())
  GetImagesList(g_strDefaultFolder, g_listDefaultImages())
  
  If g_iImagesQueued = 0
    AddStatusEvent("No images found in default folder. Select a different path.", #True, #Red)
  Else
    ;add to temporary map we used so we can count unique images being served
    ResetList(g_listDefaultImages())
    While NextElement(g_listDefaultImages())
      AddMapElement(mapUniqueImages(), g_listDefaultImages())
    Wend
    
    ;Get image list for each IP address in button area
    ResetMap(g_mapClients())
    
    While NextMapElement(g_mapClients())
      g_iImagesQueued = 0
      
      With g_mapClients()
        ClearList(\listClientImages())
        GetImagesList(\strImagesPath, \listClientImages())
        
        If g_iImagesQueued = 0
          AddStatusEvent("No images found for " + g_rgUIClients(\iGadget)\strIPClientMapKey + ". Select a different path.", #True, #Red)
          SetGadgetAttribute(g_rgUIClients(\iGadget)\hBtnIP, #PB_Button_Image, ImageID(g_imgPlaceholder))
          SetGadgetColor(g_rgUIClients(\iGadget)\hTxtIP, #PB_Gadget_FrontColor, #Red)
          
          Break
        Else
          ResetList(\listClientImages())
          While NextElement(\listClientImages())
            AddMapElement(mapUniqueImages(), \listClientImages())
          Wend
        EndIf
      EndWith
    Wend
  EndIf
  
  If g_iImagesQueued > 0
    g_iImagesQueued = MapSize(mapUniqueImages())
    
    ClearMap(mapUniqueImages())
    
    ;Enable buttons with valid IP
    For i = 0 To #LASTCLIENT
      If g_rgUIClients(i)\strIPClientMapKey <> ""
        DisableGadget(g_rgUIClients(i)\hBtnIP, #False)
      EndIf
    Next
  EndIf
EndProcedure

Procedure.i ReadyToStart()
  Protected fRC.i = #False
  
  If GetGadgetState(cmbServerIP) = -1
    AddStatusEvent("Please Select an IP address For the image server.", #True, #Red)
    SetActiveGadget(cmbServerIP)
  ElseIf g_strDefaultFolder = ""
    AddStatusEvent("Press Default Folder button at bottom left to set default images folder.", #True, #Red)
  Else
    fRC = #True
  EndIf
  
  If Not fRC
    SetGadgetState(btnControl, 0)
  EndIf
  
  ProcedureReturn fRC
EndProcedure

Procedure ToggleImageServer(EventType)  
  Protected fInitialized.i = #False
  Protected strStatus.s
  Protected i.i
  
  If EventType = #STARTSERVER
    SetGadgetState(btnControl, 1)
  EndIf
  
  If GetGadgetState(btnControl) = 1 ;Toggled On
    If Not ReadyToStart()
      ProcedureReturn
    EndIf
    
    SetGadgetText(edtMainImagesPath, "[Default Folder]: " + g_strDefaultFolder)
    
    ;Disable UI controls while searching
    HideGadget(btnControl, #True)
    HideGadget(imgSearching, #False)
    HideGadget(imgArrow, #True)
    DisableGadget(btnAbout, #True)
    DisableGadget(btnDefaultFolder, #True)
    DisableClientButtons(#True)
    
    g_fSearchingImages = #True
    CreateThread(@PlaySearchAnimation(), Img_wndMain_1)
    
    ;will set g_iImagesQueued to number of unique images too
    CreateImageLists()
      
    g_fSearchingImages = #False
    HideGadget(imgSearching, #True)
    HideGadget(btnControl, #False)
    
    ;if there we no image paths found that didn't contain any images
    If g_iImagesQueued
      AddStatusEvent(FormatNumber(g_iImagesQueued, 0) + " images found.", #False, #Blue)
      
      SetGadgetText(btnControl, "STOP")
      DisableGadget(edtPort, #True)
      DisableGadget(edtMinTime, #True)
      DisableGadget(cmbServerIP, #True)
      
      AddStatusEvent("Starting image server...", #True, #Blue)

      g_iNetworkStatus = #SERVERSTARTING
      g_fNetworkEnabled = #True
      CreateThread(@ImageServerThread(), 0)
      CreateThread(@DisplayThumbnails(), 0)
      
      While g_iNetworkStatus = #SERVERSTARTING
        Delay(1)
      Wend
      
      Select g_iNetworkStatus
        Case #SERVERNOTSTARTED
          AddStatusEvent("Cannot initialize server on port "+ Str(g_iPort) + ".", #True, #Red)
        Case #SERVERSTARTED
          GadgetToolTip(btnDefaultFolder, "Click to display default images folder name.")
          
          strStatus = "Connect String: http://" + g_strServerIP
          
          If g_iPort <> 80
            strStatus + ":" + Str(g_iPort)
          EndIf
          
          AddStatusEvent(strStatus, #True, #Blue)
          AddWindowTimer(wndMain, 0, #STATUSUPDATEINTERVAL)
          
          ;clear any error (no images found) red text in the button area
          For i = 0 To #LASTCLIENT
            SetGadgetColor(g_rgUIClients(i)\hTxtIP, #PB_Gadget_FrontColor, #PB_Default)
          Next
          
          fInitialized = #True
      EndSelect
    EndIf
  EndIf
  
  If Not fInitialized
    g_fNetworkEnabled = #False
    g_iImagesQueued = 0
    
    SetGadgetText(btnControl, "START")
    DisableGadget(edtPort, #False)
    DisableGadget(edtMinTime, #False)
    DisableGadget(cmbServerIP, #False)
    DisableGadget(btnAbout, #False)
    HideGadget(imgArrow, #False)
    
    SetGadgetState(btnControl, 0)
    AddStatusEvent("Image server stopped.", #False, #Blue)
    RemoveWindowTimer(wndMain, 0)
    
    DisableClientButtons(#False)
    GadgetToolTip(btnDefaultFolder, "Click to set default images folder.")
  EndIf
  
  DisableGadget(btnDefaultFolder, #False)
  UpdateStatusBar()
EndProcedure

Procedure ProcessWindowEvent(Event)
  Shared s_imgAppIcon
  Protected iGadget.i
  
  Select EventWindow()
    Case wndMain
      Select Event
        Case #PB_Event_CloseWindow
          g_fTerminateProgram = #True
        Case #UPDATESEARCHIMAGE
          SetGadgetState(imgSearching, ImageID(Img_wndMain_1))
        Case #UPDATETHUMBNAILTOOLTIP
          iGadget = EventData()
          GadgetToolTip(EventGadget(), "[Total: " + Str(g_rgUIClients(iGadget)\iTotalImages) + "] Current: " + g_rgUIClients(iGadget)\strImageDisplayed)
        Case #PB_Event_Timer
          UpdateStatusBar()
        Case #PB_Event_MinimizeWindow
          If Not g_fMinimized And g_iMinimizeToTray = #PB_Checkbox_Checked
            AddSysTrayIcon(0, WindowID(wndMain), ImageID(s_imgAppIcon))
            SysTrayIconToolTip(0, #BIS_TITLE)
            HideWindow(wndMain, #True)
              
            g_fMinimized = #True
          EndIf
                
        Case #PB_Event_RestoreWindow
          g_fMinimized = #False
              
        Case #PB_Event_SysTray
          Select EventType()
            Case #PB_EventType_LeftClick, #PB_EventType_RightClick, #PB_EventType_LeftDoubleClick, #PB_EventType_RightDoubleClick
              If g_fMinimized And g_iMinimizeToTray = #PB_Checkbox_Checked
                RemoveSysTrayIcon(0)
                HideWindow(wndMain, #False)
                SetWindowState(wndMain, #PB_Window_Normal)  
                     
                g_fMinimized = #False
              EndIf
          EndSelect
      EndSelect
      
      wndMain_Events(Event)
      
    Case wndAbout
      HandleAboutEvents(Event)
      
    Case wndClientConfig
      HandleClientConfigEvents(Event)
  EndSelect
EndProcedure

;Start Main Program
g_MUTEX\Clients = CreateMutex()
g_MUTEX\Thumbnail = CreateMutex()

If InitializeNetwork()
  g_fNetworkInitialized = #True
  
  LoadSettings()
  GetServerIPs()
EndIf
  
InitializeUI()
UpdateStatusBar(#False)

;auto-start server if old preferences were read from config file
If g_strServerIP <> "" And g_strDefaultFolder <> ""
  ToggleImageServer(#STARTSERVER)
EndIf

Repeat
  Event = WaitWindowEvent(1)
  ProcessWindowEvent(Event)
Until g_fTerminateProgram

If g_fNetworkInitialized
  ;save user preferences on exit
  SaveSettings()
EndIf
; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; CursorPosition = 475
; FirstLine = 447
; Folding = ---
; EnableXP