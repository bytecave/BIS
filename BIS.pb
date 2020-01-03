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
#STATUSUPDATEINTERVAL = 10000
#ACTIVECLIENTTIMEOUT = 330000  ;5.5 minutes timeout
#PREFSFILENAME = "config.bis"
#BISTITLE = "ByteCave Image Server"

Structure sLIST
  List listClient.s()
  qTimeSinceLastRequest.q
EndStructure

Structure MUTEX
  Rotate.i
  Clients.i
EndStructure

Global g_MUTEX.MUTEX
Global g_fStopNetwork.i
Global g_fTerminateProgram.i
Global g_iNetworkStatus.i
Global g_iImagesServed.i
Global g_iImagesQueued.i
Global g_fSearchingImages.i
Global g_fMinimized.i
Global g_iRunAtLogin.i
Global g_iMinimizeToTray.i
Global g_iForeverImagesServed.i
Global g_strServerIP.s
Global g_strPathFromPrefs.s
Global g_qMinTimeBetweenImages.q = #DEFAULTMINTIME
Global g_iPort.i = #DEFAULTSERVERPORT

Global NewList g_listImages.s()
Global NewList g_listRotate.s()
Global NewMap g_Lists.sLIST()

Define Event
Define s_imgAppIcon.i
Define s_iWindowX.i, s_iWindowY.i

UseGIFImageDecoder()
UseJPEGImageDecoder()

Declare AddStatusEvent(strStatusEvent.s, fSetGadgetStatus = #False, iColor.i = #Black)
Declare ProcessWindowEvent(Event)
Declare.s GetNextImage(strClientIP.s)
Declare ShuffleImageList(strClientIP.s)
Declare CreateClientList(strClientIP.s)
Declare ClearClientList()

XIncludeFile "frmBIS.pbf"
XIncludeFile "ImageServer.pbi"
XIncludeFile "About.pbi"
XIncludeFile "Helpers.pbi"

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
  Placeholder:
    IncludeBinary "resources\placeholder.png"
EndDataSection

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

Procedure GetImagesPath(EventType)
  Protected strImagesPath.s
  
  If g_strPathFromPrefs = ""
    strImagesPath = PathRequester("Select images folder", ".\")
  Else
    strImagesPath = g_strPathFromPrefs
    g_strPathFromPrefs = ""
  EndIf
  
  If strImagesPath <> ""
    If GetGadgetText(edtImagesPath) <> strImagesPath
      AddStatusEvent("Changed image path: " + strImagesPath)
    EndIf
    
    SetGadgetText(edtImagesPath, strImagesPath)
    SetGadgetColor(edtImagesPath, #PB_Gadget_FrontColor, $000000)
    DisableGadget(btnControl, 0)
    
  EndIf
 EndProcedure
 
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
  Protected qIP.q
  Protected iIdx.i = -1
  Protected iNumIP
  
  If InitNetwork()
    ExamineIPAddresses()
    
    If ExamineIPAddresses()
      Repeat
        qIP = NextIPAddress()
        
        If qIP
          AddGadgetItem(cmbServerIP, -1, IPString(qIP))
          iNumIP + 1
          
          If IPString(qIP) = g_strServerIP
            iIdx = iNumIP - 1
          EndIf
        EndIf
      Until qIP = 0
      
      If iNumIP = 1
        iIdx = 0
      EndIf
      
      SetGadgetState(cmbServerIP, iIdx)
      g_strServerIP = GetGadgetText(cmbServerIP)
    EndIf
  Else
    AddGadgetItem(cmbServerIP, -1, #NONETWORK)
    AddStatusEvent("Could not initialize network. Restart app to try again.", #True, #Red)
    
    HideGadget(cmbServerIP, 1)
    HideGadget(lblNoNetwork, 0)
    DisableGadget(btnImagesPath, 1)
    DisableGadget(edtImagesPath, 1)
    DisableGadget(edtPort, 1)
    DisableGadget(edtMinTime, 1)
  EndIf
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
  
  RandomizeList(g_Lists(strClientIP)\listClient())
  ResetList(g_Lists(strClientIP)\listClient())
EndProcedure

;MUTEX locked before calling this
Procedure CreateClientList(strClientIP.s)
  AddMapElement(g_Lists(), strClientIP)
  g_Lists()\qTimeSinceLastRequest = ElapsedMilliseconds() - g_qMinTimeBetweenImages

  CopyList(g_listImages(), g_Lists()\listClient())
  ShuffleImageList(strClientIP)
EndProcedure            

Procedure UpdateStatusBar()
  Static idStatusBar.i = 0
  Protected iActiveConnections.i
  Protected idQueueIcon.i
  
  If idStatusBar = 0
    idStatusBar = CreateStatusBar(#PB_Any, WindowID(wndMain))
    
    AddStatusBarField(20)  ;blank space
    AddStatusBarField(24)  ;connections icon
    AddStatusBarField(167) ;connections text
    AddStatusBarField(24)  ;session images icon
    AddStatusBarField(185) ;session images text
    AddStatusBarField(24)  ;all-time images icon
    AddStatusBarField(185) ;session images text
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
  
  LockMutex(g_MUTEX\Clients)
  ResetMap(g_Lists())
  
  While NextMapElement(g_Lists())
    If ElapsedMilliseconds() - g_Lists()\qTimeSinceLastRequest < #ACTIVECLIENTTIMEOUT
      iActiveConnections + 1
    EndIf
  Wend
  
  UnlockMutex(g_MUTEX\Clients)
  
  StatusBarText(idStatusBar, 2, Str(iActiveConnections) + " active connections")
  StatusBarText(idStatusBar, 4, FormatNumber(g_iImagesServed, 0) + " images this session")
  StatusBarText(idStatusBar, 6, FormatNumber(g_iForeverImagesServed, 0) + " images all time")
  
  StatusBarText(idStatusBar, 8, "Serving " + FormatNumber(g_iImagesQueued, 0) + " images", #PB_StatusBar_BorderLess)
EndProcedure

Procedure ClearClientList()
  LockMutex(g_MUTEX\Clients)
  
  ResetMap(g_Lists())
  While NextMapElement(g_Lists())
    ClearList(g_Lists()\listClient())
  Wend
  ClearMap(g_Lists())
  
  UnlockMutex(g_MUTEX\Clients)
EndProcedure

Procedure RotateImages(Parameter)
  Static Dim idImage.i(2)
  Dim img.i(2)
  Static iPass.i = 0
  Static Count.i = 0
  Static fInit.i = #False
  
  If Not g_fMinimized
    If Not fInit
      idImage(0) = imgLast_1
      idImage(1) = imgLast_2
      idImage(2) = imgLast_3
    EndIf
    
    Repeat
      Delay(1)
      
      LockMutex(g_MUTEX\Rotate)
      
      If FirstElement(g_listRotate())
        If IsImage(img(iPass))
          FreeImage(img(iPass))
        EndIf
        
        img(iPass) = LoadImage(#PB_Any, g_listRotate())
        DeleteElement(g_listRotate(), 1)
        UnlockMutex(g_MUTEX\Rotate)
        
        If IsImage(img(iPass))
          ResizeImage(img(iPass), 110, 110, #PB_Image_Raw)
          SetGadgetState(idImage(iPass), ImageID(img(iPass)))
          
          iPass + 1
          If iPass = 3
            iPass = 0
          EndIf
        EndIf
      Else
        UnlockMutex(g_MUTEX\Rotate)
      EndIf
    Until g_fStopNetwork = #True And ListSize(g_listRotate()) = 0
  Else
    Delay(1)
  EndIf
  
  ClearList(g_listRotate())
EndProcedure

;MUTEX locked before calling this
Procedure.s GetNextImage(strClientIP.s)
  Protected strImage.s
  Protected img.i
  
  If NextElement(g_Lists(strClientIP)\listClient())
    strImage = g_Lists(strClientIP)\listClient()
    g_iImagesServed + 1
    g_iForeverImagesServed + 1
    
    LockMutex(g_MUTEX\Rotate)
    
    AddElement(g_listRotate())
    g_listRotate() = strImage
    
    UnlockMutex(g_MUTEX\Rotate)
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
    GetImagesList(GetGadgetText(edtImagesPath))
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
      g_fStopNetwork = #False
      CreateThread(@ImageServerThread(), 0)
      CreateThread(@RotateImages(), 0)
      
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
    g_fStopNetwork = #True
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

Procedure ProcessWindowEvent(Event)
  Shared s_imgAppIcon
  
  Select EventWindow()
    Case wndMain
      Select Event
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
        Default
          wndMain_Events(Event)
      EndSelect
    Case wndAbout
      HandleAboutEvents(Event)
  EndSelect
EndProcedure

g_MUTEX\Clients = CreateMutex()
g_MUTEX\Rotate = CreateMutex()

;PB Form Designer attempts to load images from disk, which only works at development time
;So free these at run time, and fall through to CatchImage statements below that work at dev and run time
If IsImage(Img_wndMain_0)
  FreeImage(Img_wndMain_0)
  FreeImage(Img_wndMain_1)
  FreeImage(Img_wndMain_2)
EndIf

;Replace the images with those embedded in the executable
Img_wndMain_0 = CatchImage(#PB_Any, ?LOGO)
Img_wndMain_1 = CatchImage(#PB_Any, ?Searching)
Img_wndMain_2 = CatchImage(#PB_Any, ?Placeholder)

s_imgAppIcon = CatchImage(#PB_Any, ?AppIcon)

LoadSettings()

OpenwndMain(s_iWindowX, s_iWindowY)
HideGadget(imgSearching, 1)
HideGadget(lblNoNetwork, 1)

UpdateStatusBar()
GetServerIPs()

SetGadgetText(edtMinTime, Str(g_qMinTimeBetweenImages))
SetGadgetText(edtPort, Str(g_iPort))
ChangePort(#CHANGEPORT)

;auto-start server if old preferences were read from config file
If g_strServerIP <> "" And GetGadgetText(edtImagesPath) <> ""
  ToggleImageServer(#STARTSERVER)
EndIf

Repeat
  Event = WaitWindowEvent(1)
  ProcessWindowEvent(Event)
Until g_fTerminateProgram

SaveSettings()
; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 550
; FirstLine = 521
; Folding = ---
; EnableXP