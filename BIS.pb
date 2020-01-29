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
#GETDEFAULTFOLDER = #PB_Event_FirstCustomValue + 2
#STATUSUPDATEINTERVAL = 10000
#ACTIVECLIENTTIMEOUT = 330000  ;5.5 minutes timeout
#PREFSFILENAME = "config.bis"
#BISTITLE = "ByteCave Image Server"
#DEFAULTCLIENTIP = "0.0.0.0"
#AUTOSEARCH = 9999

Structure sUISTATE
  iSelectedGadget.i
  HaveValidIP.i
  HaveImagePath.i
EndStructure
  
Structure sCLIENT
  List listClientImages.s()
  qTimeSinceLastRequest.q
  iClientIP.i
  strImagesPath.s
  iGadget.i  ;TODO:needed?
EndStructure

Structure sUICLIENT
  hBtnIP.i
  hTxtIP.i
  strIPClientMapKey.s
EndStructure

Structure MUTEX
  Rotate.i
  Clients.i
EndStructure

Global g_MUTEX.MUTEX
Global g_UIState.sUISTATE
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
Global g_iForeverImagesServed.i
Global g_strServerIP.s
Global g_strDefaultFolder.s
Global g_qMinTimeBetweenImages.q = #DEFAULTMINTIME
Global g_iPort.i = #DEFAULTSERVERPORT

Global NewList g_listImages.s()
Global NewList g_listRotate.s()
Global NewMap g_mapClients.sCLIENT()
Global Dim g_rgUIClients.sUICLIENT(13)

Define Event
Define s_imgAppIcon.i, s_imgPlaceholder, s_imgAvailable
Define s_iWindowX.i, s_iWindowY.i

Declare AddStatusEvent(strStatusEvent.s, fSetGadgetStatus = #False, iColor.i = #Black)
Declare ProcessWindowEvent(Event)
Declare.s GetNextImage(strClientIP.s)
Declare ShuffleImageList(strClientIP.s)
Declare.i CreateClientList(iClientIP.i, strClientIP.s, strImagesPath.s = "", iGadgetPos.i = #AUTOSEARCH)
;Declare ClearClientList()

;initialize decoders before referencing in About.pbi and main program code
UseGIFImageDecoder()
UseJPEGImageDecoder()

DataSection
  Connections:
    IncludeBinary "resources\connections.ico"
  NumImages:
    IncludeBinary "resources\images.ico"
  NumForeverImages:
    IncludeBinary "resources\foreverimages.ico"
  QueuedImages:
    IncludeBinary "resources\imagesqueued.ico"
  AppIcon:
    IncludeBinary "bis.ico"
  LOGO:
    IncludeBinary "resources\logo.png"
  Searching:
    IncludeBinary "resources\searching.gif"
  DefaultFolder:
    IncludeBinary "resources\defaultfolder.png"
  Placeholder:
    IncludeBinary "resources\placeholder.png"
  Available:
    IncludeBinary "resources\available.png"
EndDataSection

XIncludeFile "frmBIS.pbf"
XIncludeFile "ImageServer.pbi"
XIncludeFile "About.pbi"
XIncludeFile "ClientConfig.pbi"
XIncludeFile "Helpers.pbi"

Procedure PlaySearchAnimation(*hGIF)
  Protected iFrameCount.i, iFrame.i
  
  iFrameCount = ImageFrameCount(*hGIF)

  Repeat
    
    For iFrame = 0 To iFrameCount - 1
      If g_fSearchingImages
        SetImageFrame(*hGIF, iFrame)
        
        PostEvent(#UPDATESEARCHIMAGE, wndMain, #PB_Any)
        
        Delay(GetImageFrameDelay(*hGIF))
      EndIf
    Next
  Until g_fSearchingImages = #False
EndProcedure

; Procedure OLD_GetImagesPath(EventType)
;   Protected strImagesPath.s, strCurrentPath.s
;   
;   If EventType = #GETDEFAULTFOLDER
;     strCurrentPath = g_strDefaultFolder
;     SetGadgetText(txtImagesPath, g_strDefaultFolder)
;   EndIf
;   
;   strCurrentPath = GetGadgetText(txtImagesPath)
;   strImagesPath = strCurrentPath
;   
;   If strImagesPath = ""
;     strImagesPath = g_strDefaultFolder
;   EndIf
;   
;   strImagesPath = PathRequester("Select images folder", strImagesPath)
;   
;   If strImagesPath <> ""
;     If strCurrentPath <> strImagesPath
;       AddStatusEvent("Changed image path: " + strImagesPath)
;     EndIf
;     
;     SetGadgetText(txtImagesPath, strImagesPath)
;     SetGadgetColor(txtImagesPath, #PB_Gadget_FrontColor, $000000)
;   EndIf
;   
;   If EventType = #GETDEFAULTFOLDER
;     g_strDefaultFolder = strImagesPath
;   Else
;     FindMapElement(g_mapClients( kkk
;   EndIf
;   
;   ProcedureReturn strCurrentPath
; EndProcedure

Procedure GetImagesList(strDir.s)
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
                AddElement(g_listImages())
                g_listImages() = strDir + strFileName
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
        GetImagesList(Directories())
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
  
  If fSetGadgetStatus
    SetGadgetColor(lblStatus, #PB_Gadget_FrontColor, iColor)
    SetGadgetText(lblStatus, strStatusEvent)
  EndIf
EndProcedure

Procedure GetServerIPs()
  Protected iIP.i
  Protected iIdx.i = -1
  Protected iNumIP.i
  
  If ExamineIPAddresses()
    Repeat
      iIP = NextIPAddress()
      
      If iIP
        AddGadgetItem(cmbServerIP, -1, IPString(iIP))
        iNumIP + 1
        
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
    
    HideGadget(cmbServerIP, 1)
    HideGadget(lblNoNetwork, 0)
    DisableGadget(edtPort, 1)
    DisableGadget(edtMinTime, 1)
    DisableGadget(btnDefaultFolder, 1)
    
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

;MUTEX locked before calling this
Procedure ShuffleImageList(strClientIP.s)
  AddStatusEvent("Shuffling image list for >> " + strClientIP + "<< ...")
  
  RandomizeList(g_mapClients(strClientIP)\listClientImages())
  ResetList(g_mapClients(strClientIP)\listClientImages())
EndProcedure

;MUTEX locked before calling this
Procedure.i CreateClientList(iClientIP.i, strClientIP.s, strImagesPath.s = "", iGadgetPos.i = #AUTOSEARCH)
  Protected iIdx.i
  Protected fAvailableSlot.i = #False
  Shared s_imgPlaceholder.i
   
   If strImagesPath = ""
    strImagesPath = g_strDefaultFolder
  EndIf
  
  iIdx = iGadgetPos
  
  If iGadgetPos = #AUTOSEARCH
    For iIdx = 0 To 13
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
  
  If iIdx < 14
    AddMapElement(g_mapClients(), strClientIP)
    g_mapClients()\iClientIP = iClientIP
    g_mapClients()\strImagesPath = strImagesPath
    g_mapClients()\iGadget = iGadgetPos
    g_mapClients()\qTimeSinceLastRequest = ElapsedMilliseconds() - g_qMinTimeBetweenImages
    
    If iGadgetPos = #AUTOSEARCH
      CopyList(g_listImages(), g_mapClients()\listClientImages())
      ShuffleImageList(strClientIP)
    EndIf
    
    ;set button image list information
    With g_rgUIClients(iIdx)
      \strIPClientMapKey = strClientIP
      SetGadgetText(\hTxtIP, strClientIP)
      SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(s_imgPlaceholder))
    EndWith
      
    fAvailableSlot = #True
  EndIf
  
  ProcedureReturn fAvailableSlot
EndProcedure            

Procedure UpdateStatusBar(fUpdateConnections.i = #True)
  Static idStatusBar.i = 0
  Protected iActiveConnections.i
  Protected idQueueIcon.i
  
  If idStatusBar = 0
    idStatusBar = CreateStatusBar(#PB_Any, WindowID(wndMain))
    
    AddStatusBarField(20)  ;blank space
    AddStatusBarField(24)  ;connections icon
    AddStatusBarField(135) ;connections text
    AddStatusBarField(24)  ;session images icon
    AddStatusBarField(200) ;session images text
    AddStatusBarField(24)  ;all-time images icon
    AddStatusBarField(200) ;session images text
    AddStatusBarField(24)  ;queued images icon
    AddStatusBarField(135) ;images queued for serving
    
    StatusBarText(idStatusBar, 0, "", #PB_StatusBar_BorderLess)
    
    CatchImage(1000, ?Connections)
    StatusBarImage(idStatusBar, 1, ImageID(1000), #PB_StatusBar_BorderLess)
    
    CatchImage(1001, ?NumImages)
    StatusBarImage(idStatusBar, 3, ImageID(1001), #PB_StatusBar_BorderLess)
    
    CatchImage(1002, ?NumForeverImages)
    StatusBarImage(idStatusBar, 5, ImageID(1002), #PB_StatusBar_BorderLess)
    
    CatchImage(1003, ?QueuedImages)
    StatusBarImage(idStatusBar, 7, ImageID(1003), #PB_StatusBar_BorderLess)
  EndIf
  
  If fUpdateConnections
    LockMutex(g_MUTEX\Clients)
    ResetMap(g_mapClients())
    
    While NextMapElement(g_mapClients())
      If ElapsedMilliseconds() - g_mapClients()\qTimeSinceLastRequest < #ACTIVECLIENTTIMEOUT
        iActiveConnections + 1
      EndIf
    Wend
    
    UnlockMutex(g_MUTEX\Clients)
  EndIf
  
  StatusBarText(idStatusBar, 2, Str(iActiveConnections) + " active connections")
  StatusBarText(idStatusBar, 4, FormatNumber(g_iImagesServed, 0) + " images this session")
  StatusBarText(idStatusBar, 6, FormatNumber(g_iForeverImagesServed, 0) + " images all time")
  
  StatusBarText(idStatusBar, 8, "Serving " + FormatNumber(g_iImagesQueued, 0) + " images", #PB_StatusBar_BorderLess)
EndProcedure

; Procedure ClearClientList()
;   LockMutex(g_MUTEX\Clients)
;   
;   ResetMap(g_mapClients())
;   While NextMapElement(g_mapClients())
;     ClearList(g_mapClients()\listClientImages())
;   Wend
;   ClearMap(g_mapClients())
;   
;   UnlockMutex(g_MUTEX\Clients)
; EndProcedure

; Procedure DisplayThumbnails(Parameter)
;   Static Dim idImage.i(2)
;   Dim img.i(2)
;   Static iPass.i = 0
;   Static Count.i = 0
;   Static fInit.i = #False
;   
;   If Not g_fMinimized
;     If Not fInit
;       idImage(0) = imgLast_1
;       idImage(1) = imgLast_2
;       idImage(2) = imgLast_3
;     EndIf
;     
;     Repeat
;       Delay(1)
;       
;       LockMutex(g_MUTEX\Rotate)
;       
;       If FirstElement(g_listRotate())
;         If IsImage(img(iPass))
;           FreeImage(img(iPass))
;         EndIf
;         
;         img(iPass) = LoadImage(#PB_Any, g_listRotate())
;         DeleteElement(g_listRotate(), 1)
;         UnlockMutex(g_MUTEX\Rotate)
;         
;         If IsImage(img(iPass))
;           ResizeImage(img(iPass), 110, 110, #PB_Image_Raw)
;           SetGadgetState(idImage(iPass), ImageID(img(iPass)))
;           
;           iPass + 1
;           If iPass = 3
;             iPass = 0
;           EndIf
;         EndIf
;       Else
;         UnlockMutex(g_MUTEX\Rotate)
;       EndIf
;     Until Not g_fNetworkEnabled And ListSize(g_listRotate()) = 0
;   Else
;     Delay(1)
;   EndIf
;   
;   ClearList(g_listRotate())
; EndProcedure

;MUTEX locked before calling this
Procedure.s GetNextImage(strClientIP.s)
  Protected strImage.s
  Protected img.i
  
  If NextElement(g_mapClients(strClientIP)\listClientImages())
    strImage = g_mapClients(strClientIP)\listClientImages()
    g_iImagesServed + 1
    g_iForeverImagesServed + 1
    
    ;we don't rotate images when app is minimized
    If Not g_fMinimized
      LockMutex(g_MUTEX\Rotate)
      
      AddElement(g_listRotate())
      g_listRotate() = strImage
      
      UnlockMutex(g_MUTEX\Rotate)
    EndIf
  Else
    ShuffleImageList(strClientIP)
    strImage = GetNextImage(strClientIP)
  EndIf
    
  ProcedureReturn strImage
EndProcedure  
    
Procedure ToggleImageServer(EventType)  
  Protected fInitialized.i = #False
  Protected strStatus.s
  
  If EventType = #STARTSERVER
    SetGadgetState(btnControl, 1)
  EndIf
  
  If GetGadgetState(btnControl) = 1 ;Toggled On
    If GetGadgetState(cmbServerIP) = -1
      AddStatusEvent("Please Select an IP address For the image server.", #True, #Red)
      SetGadgetState(btnControl, 0)
      SetActiveGadget(cmbServerIP)
      
      ProcedureReturn
    EndIf
    
    HideGadget(btnControl, 1)
    HideGadget(imgSearching, 0)
    g_fSearchingImages = #True
    
    CreateThread(@PlaySearchAnimation(), Img_wndMain_1)
    
    ClearList(g_listImages())
    g_iImagesQueued = 0
    GetImagesList(GetGadgetText(edtMainImagesPath))
    g_fSearchingImages = #False
    
    HideGadget(imgSearching, 1)
    HideGadget(btnControl, 0)
    
    If g_iImagesQueued = 0
      AddStatusEvent("No images found. Select a different path.", #True, #Red)
      
    Else      
      AddStatusEvent(Str(g_iImagesQueued) + " images found.")
      
      SetGadgetText(btnControl, "STOP")
      DisableGadget(btnImagesPath, 1)
      DisableGadget(edtPort, 1)
      DisableGadget(edtMinTime, 1)
      DisableGadget(cmbServerIP, 1)
      
      AddStatusEvent("Starting image server...", #True)

      g_iNetworkStatus = #SERVERSTARTING
      g_fNetworkEnabled = #True
      CreateThread(@ImageServerThread(), 0)
      ;CreateThread(@DisplayThumbnails(), 0)
      
      While g_iNetworkStatus = #SERVERSTARTING
        Delay(1)
      Wend
      
      Select g_iNetworkStatus
        Case #SERVERNOTSTARTED
          AddStatusEvent("Cannot initialize server on port "+ Str(g_iPort) + ".", #True, #Red)
        Case #SERVERSTARTED
          SetGadgetColor(lblStatus, #PB_Gadget_FrontColor, #Black)
          strStatus = "Connect String: http://" + g_strServerIP
          
          If g_iPort <> 80
            strStatus + ":" + Str(g_iPort)
          EndIf
          
          AddStatusEvent(strStatus, #True)
          AddWindowTimer(wndMain, 0, #STATUSUPDATEINTERVAL)
          DisableGadget(btnAbout, #True)
          
          fInitialized = #True
      EndSelect
    EndIf
  EndIf
  
  If Not fInitialized
    g_fNetworkEnabled = #False
    g_iImagesQueued = 0
    
    SetGadgetText(btnControl, "START")
    DisableGadget(btnImagesPath, 0)
    DisableGadget(edtPort, 0)
    DisableGadget(edtMinTime, 0)
    DisableGadget(cmbServerIP, 0)
    DisableGadget(btnAbout, #False)
    
    SetGadgetState(btnControl, 0)
    AddStatusEvent("Image server stopped.")
    RemoveWindowTimer(wndMain, 0)
  EndIf
  
  UpdateStatusBar()
EndProcedure

Procedure InitializeUI()
  Protected i.i
  Shared s_iWindowX, s_iWindowY
  
  HideGadget(imgSearching, 1)
  HideGadget(lblNoNetwork, 1)
  ;HideGadget(ipClientAddress, 1)
  
  ResizeWindow(wndMain, s_iWindowX, s_iWindowY, #PB_Ignore, #PB_Ignore)
  HideWindow(wndMain, 0)
  
  ;Fix up gadget positions as these start in a position visible in Form Designer, but not the correct UI position
  ResizeGadget(lblNoNetwork, GadgetX(cmbServerIP), GadgetY(cmbServerIP), #PB_Ignore, #PB_Ignore)
  
  If g_strDefaultFolder = "" And g_fNetworkInitialized
    SetGadgetText(edtMainImagesPath, "Press Default Folder button at bottom left to set default images folder.")
  Else
    SetGadgetText(edtMainImagesPath, g_strDefaultFolder)
  EndIf
  
  SetGadgetText(edtMinTime, Str(g_qMinTimeBetweenImages))
  SetGadgetText(edtPort, Str(g_iPort))
  ChangePort(#CHANGEPORT)
EndProcedure

Procedure SetUIState()
  Protected i.i
  
  If g_strDefaultFolder = ""
    HideGadget(ipClientAddress, 1)
    HideGadget(lblDefaultFolder, 0)
    DisableGadget(btnDefaultFolder, 1)
  Else
    HideGadget(ipClientAddress, 0)
    HideGadget(lblDefaultFolder, 1)
    DisableGadget(btnDefaultFolder, 0)
  EndIf
EndProcedure
  
Procedure ProcessClientListEvents(EventType)
  Protected iSelected.i, i.i, iCount.i, iRow.i
  Protected strIP.s
  
  Select EventType()
;       Case #PB_EventType_LeftClick, #PB_EventType_Change
;         iCount = CountGadgetItems(lstClientFolders)
;         
;         For i = 0 To iCount - 1
;           If GetGadgetItemState(lstClientFolders, i) = #PB_ListIcon_Selected
;             iSelected + 1
;             iRow = i
;           EndIf
;         Next
;         
;         If iSelected = 1
;           strIP = GetGadgetItemText(lstClientFolders, iRow, 0)
;           
;           SetGadgetState(ipClientAddress, MakeIPAddress(Val(StringField(strIP, 1, ".")),
;                                                         Val(StringField(strIP, 2, ".")),
;                                                         Val(StringField(strIP, 3, ".")),
;                                                         Val(StringField(strIP, 4, "."))))
;           SetGadgetText(txtImagesPath, GetGadgetItemText(lstClientFolders, iRow, 1))
;           ;do we need something like this? g_strPathFromPrefs = txtpath
;           
;           HideGadget(lblDefaultFolder, 1)
;           DisableGadget(btnAddFolder, 0)
;           SetGadgetText(btnAddFolder, "Update")
;           
;           ;g_UIState\HaveFolder = #True
;           g_UIState\HaveValidIP = #True
;         Else
;           ;SetGadgetState(ipClientAddress, MakeIPAddress(0, 0, 0, 0))
;           ;SetGadgetText(lblDefaultFolder, "Multiselect")
;           ;HideGadget(lblDefaultFolder, 0)
;           ;DisableGadget(btnImagesPath, 1)
;           ;DisableGadget(btnAddFolder, 1)
;           ;SetGadgetText(txtImagesPath, "Click Remove to remove selected.")
;           
;           g_UIState\IPMultiSelect = #True
;           ;g_UIState\HaveFolder = #False
;           g_UIState\HaveValidIP = #False
;           
;           SetUIState()
;         EndIf
;         
;         If GetGadgetText(ipClientAddress) <> #DEFAULTCLIENTIP
;           DisableGadget(btnRemoveFolder, 0)
;         EndIf
     EndSelect
EndProcedure

Procedure ProcessWindowEvent(Event)
  Shared s_imgAppIcon
  
  Select EventWindow()
    Case wndMain
      Select Event
    Case #PB_Event_Gadget
      Select EventGadget()
        ;Case lstClientFolders
        ;  ProcessClientListEvents(EventType())
      EndSelect
      
    Case #PB_Event_CloseWindow
          g_fTerminateProgram = #True
        Case #UPDATESEARCHIMAGE
          SetGadgetState(imgSearching, ImageID(Img_wndMain_1))
        Case #PB_Event_Timer
          UpdateStatusBar()
        Case #PB_Event_MinimizeWindow
          If Not g_fMinimized And g_iMinimizeToTray = #PB_Checkbox_Checked
            AddSysTrayIcon(0, WindowID(wndMain), ImageID(s_imgAppIcon))
            SysTrayIconToolTip(0, #BISTITLE)
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
g_MUTEX\Rotate = CreateMutex()

;PB Form Designer attempts to load images from disk, which only works at development time
;So free these at run time, and fall through to CatchImage statements below that work at both dev and run time
If IsImage(Img_wndMain_0)
  FreeImage(Img_wndMain_0)
  FreeImage(Img_wndMain_1)
  FreeImage(Img_wndMain_2)
EndIf

;Replace the images with those embedded in the executable
Img_wndMain_0 = CatchImage(#PB_Any, ?LOGO)
Img_wndMain_1 = CatchImage(#PB_Any, ?Searching)
Img_wndMain_2 = CatchImage(#PB_Any, ?DefaultFolder)

s_imgAppIcon = CatchImage(#PB_Any, ?AppIcon)
s_imgPlaceholder = CatchImage(#PB_Any, ?Placeholder)
s_imgAvailable = CatchImage(#PB_Any, ?Available)

OpenwndMain()
HideWindow(wndMain, 1)

If InitializeNetwork()
  g_fNetworkInitialized = #True
  
  LoadSettings()
  GetServerIPs()
EndIf
  
InitializeUI()
UpdateStatusBar(#False)

;auto-start server if old preferences were read from config file
;If g_strServerIP <> "" And GetGadgetText(txtImagesPath) <> ""
;  ToggleImageServer(#STARTSERVER)
;EndIf

Repeat
  Event = WaitWindowEvent(1)
  ProcessWindowEvent(Event)
Until g_fTerminateProgram

If g_fNetworkInitialized
  ;save user preferences on exit
  SaveSettings()
EndIf
; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 517
; FirstLine = 757
; Folding = ---
; EnableXP