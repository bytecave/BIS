;This software provided under the BSD 3-Clause License. Copyright 2019-2026, ByteLord

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
  AboutArrow:
    IncludeBinary "resources\aboutarrow.png"  
EndDataSection

; Called only by the main window timer during discovery.
Procedure PlaySearchAnimation(*hGIF)
  Protected frame.i = GetImageFrame(*hGIF) + 1
  If frame >= ImageFrameCount(*hGIF) : frame = 0 : EndIf
  SetImageFrame(*hGIF, frame)
  SetGadgetState(imgSearching, ImageID(*hGIF))
EndProcedure
Procedure UpdateStatusBar(fUpdateConnections.i = #True)
  Static idStatusBar.i = 0
  Protected iActiveConnections.i
  Protected idQueueIcon.i
  Protected session.i, allTime.i
  
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
  
  LockMutex(g_MUTEX\Clients)
  If fUpdateConnections
    ResetMap(g_mapClients())
    
    While NextMapElement(g_mapClients())
      If ElapsedMilliseconds() - g_mapClients()\qTimeSinceLastRequest < #ACTIVECLIENTTIMEOUT And g_mapClients()\fAskedForImage
        iActiveConnections + 1
      EndIf
    Wend
    
  EndIf
  session = g_iImagesServed
  allTime = g_iForeverImagesServed
  UnlockMutex(g_MUTEX\Clients)
  
  StatusBarText(idStatusBar, 2, Str(iActiveConnections) + " active connections")
  StatusBarText(idStatusBar, 4, FormatNumber(session, 0) + " images this session")
  StatusBarText(idStatusBar, 6, FormatNumber(allTime, 0) + " images all time")
  
  StatusBarText(idStatusBar, 8, "Serving " + FormatNumber(g_iImagesQueued, 0) + " images", #PB_StatusBar_BorderLess)
EndProcedure

Procedure RefreshClientButtons()
  Protected i.i, key.s
  LockMutex(g_MUTEX\Clients)
  For i = 0 To #LASTCLIENT
    key = ""
    ForEach g_mapClients()
      If g_mapClients()\iGadget = i
        key = MapKey(g_mapClients())
        Break
      EndIf
    Next
    With g_rgUIClients(i)
      If \strIPClientMapKey <> key
        SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(g_imgPlaceholder))
        If IsImage(\iThumbnail) : FreeImage(\iThumbnail) : EndIf
        \iThumbnail = 0
        \strImageDisplayed = ""
        \iTotalImages = 0
      EndIf
      \strIPClientMapKey = key
      SetGadgetText(\hTxtIP, key)
      If key = ""
        SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(g_imgAvailable))
        GadgetToolTip(\hBtnIP, "Click to add image folder for specific IP address.")
      Else
        \iTotalImages = g_mapClients(key)\iTotalImages
        If \strImageDisplayed = ""
          SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(g_imgPlaceholder))
        EndIf
        GadgetToolTip(\hBtnIP, "[Total: " + Str(\iTotalImages) + "] Current: " + \strImageDisplayed)
      EndIf
      DisableGadget(\hBtnIP, Bool(g_fNetworkEnabled And key = ""))
    EndWith
  Next
  UnlockMutex(g_MUTEX\Clients)
EndProcedure

; Main-thread consumer. Only one owned thumbnail is retained per slot.
Procedure DisplayThumbnails(Parameter)
  Protected img.i, previous.i, iGadget.i, iCount.i
  Protected strImage.s
  Repeat
    LockMutex(g_MUTEX\Thumbnail)
    If Not FirstElement(g_listThumbnails())
      UnlockMutex(g_MUTEX\Thumbnail)
      Break
    EndIf
    strImage = g_listThumbnails()\strImage
    iGadget = g_listThumbnails()\iGadget
    iCount = g_listThumbnails()\iCount
    DeleteElement(g_listThumbnails())
    UnlockMutex(g_MUTEX\Thumbnail)
    If iGadget >= 0 And iGadget <= #LASTCLIENT
      With g_rgUIClients(iGadget)
        \strImageDisplayed = strImage
        \iTotalImages = iCount
        img = LoadImage(#PB_Any, strImage)
        If img
          ResizeImage(img, 100, 100, #PB_Image_Raw)
          SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(img))
        Else
          SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(g_imgPlaceholder))
        EndIf
        previous = \iThumbnail
        \iThumbnail = img
        If IsImage(previous) : FreeImage(previous) : EndIf
        GadgetToolTip(\hBtnIP, "[Total: " + Str(iCount) + "] Current: " + strImage)
      EndWith
    EndIf
  ForEver
EndProcedure

Procedure StopImageServer()
  g_fNetworkEnabled = #False
  If g_iServerThread
    WaitThread(g_iServerThread)
    g_iServerThread = 0
  EndIf
  RefreshClientButtons()
  DisplayThumbnails(0)
EndProcedure
Procedure InitializeUI()
  Protected i.i
  Shared s_iWindowX, s_iWindowY
  
  HideGadget(imgSearching, #True)
  HideGadget(lblNoNetwork, #True)
  
  ;reposition window to last position from settings, if any
  ResizeWindow(wndMain, s_iWindowX, s_iWindowY, #PB_Ignore, #PB_Ignore)
  HideWindow(wndMain, #False)
  SetWindowTitle(wndMain, #BIS_TITLE)
  
  ;Fix up gadget positions as these start in a position visible in Form Designer, but not the correct UI position
  ResizeGadget(lblNoNetwork, GadgetX(cmbServerIP), GadgetY(cmbServerIP), #PB_Ignore, #PB_Ignore)
  
  ;PureBasic Form Designer creates ListIconGadget with header row. Remove it and set the width long enough to display a long file name
  RemoveListHeaders()
  SetGadgetItemAttribute(lstEvents, 0, #PB_ListIcon_ColumnWidth, 2048) 
  
  If g_strDefaultFolder = ""
    SetGadgetText(edtMainImagesPath, "Press Default Folder button at bottom left to set default images folder.")
    AddStatusEvent("Press Default Folder button at bottom left to set default images folder.", #False, #Red)
  Else
    SetGadgetText(edtMainImagesPath, "[Default Folder]: " + g_strDefaultFolder)
  EndIf
  
  SetGadgetText(edtMinTime, Str(g_qMinTimeBetweenImages))
  SetGadgetText(edtPort, Str(g_iPort))
  ChangePort(#CHANGEPORT)
EndProcedure

;PB Form Designer attempts to load images from disk, which only works at development time
;So free these at run time, and fall through to CatchImage statements below that work at both dev and run time
If IsImage(Img_wndMain_0)
  FreeImage(Img_wndMain_0)
EndIf
If IsImage(Img_wndMain_1)
  FreeImage(Img_wndMain_1)
EndIf
If IsImage(Img_wndMain_2)
  FreeImage(Img_wndMain_2)
EndIf
If IsImage(Img_wndMain_3)
  FreeImage(Img_wndMain_3)
EndIf

;Replace the images with those embedded in the executable
Img_wndMain_0 = CatchImage(#PB_Any, ?LOGO)
Img_wndMain_1 = CatchImage(#PB_Any, ?Searching)
Img_wndMain_2 = CatchImage(#PB_Any, ?DefaultFolder)
Img_wndMain_3 = CatchImage(#PB_Any, ?AboutArrow)

; Fit the embedded logo to the button's interior while preserving its aspect ratio.
Define logoScale.d = 1.0
Define logoWidth.i, logoHeight.i
If ImageWidth(Img_wndMain_0) > 120 : logoScale = 120.0 / ImageWidth(Img_wndMain_0) : EndIf
If ImageHeight(Img_wndMain_0) * logoScale > 62 : logoScale = 62.0 / ImageHeight(Img_wndMain_0) : EndIf
If logoScale < 1.0
  logoWidth = Int(ImageWidth(Img_wndMain_0) * logoScale)
  logoHeight = Int(ImageHeight(Img_wndMain_0) * logoScale)
  If logoWidth < 1 : logoWidth = 1 : EndIf
  If logoHeight < 1 : logoHeight = 1 : EndIf
  ResizeImage(Img_wndMain_0, logoWidth, logoHeight, #PB_Image_Smooth)
EndIf

s_imgAppIcon = CatchImage(#PB_Any, ?AppIcon)
g_imgPlaceholder = CatchImage(#PB_Any, ?Placeholder)
g_imgAvailable = CatchImage(#PB_Any, ?Available)

OpenwndMain()
HideWindow(wndMain, #True)
; IDE Options = PureBasic 6.41 (Windows - x86)
; CursorPosition = 8
; Folding = --
; EnableXP