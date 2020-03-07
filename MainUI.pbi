;This software provided under MIT license. Copyright 2019-2020, ByteCave

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
      If ElapsedMilliseconds() - g_mapClients()\qTimeSinceLastRequest < #ACTIVECLIENTTIMEOUT And g_mapClients()\fAskedForImage
        iActiveConnections + 1
      EndIf
    Wend
    
    UnlockMutex(g_MUTEX\Clients)
  EndIf
  
  StatusBarText(idStatusBar, 2, Str(iActiveConnections) + " active connections")
  StatusBarText(idStatusBar, 4, FormatNumber(g_iImagesServed, 0) + " images this session")
  StatusBarText(idStatusBar, 6, FormatNumber(g_qForeverImagesServed, 0) + " images all time")
  
  StatusBarText(idStatusBar, 8, "Serving " + FormatNumber(g_iImagesQueued, 0) + " images", #PB_StatusBar_BorderLess)
EndProcedure

Procedure UpdateThumbnail(iGadget.i)
  Protected img.i
  
  With g_rgUIClients(iGadget)
    GadgetToolTip(\hBtnIP, "[Total: " + Str(\iTotalImages) + "] Current: " + \strImageDisplayed)
    
    ;Free the previous image that was displayed so as not to leak memory
    If IsImage(\iPreviousImage)
      FreeImage(\iPreviousImage)
    EndIf
    
    img = LoadImage(#PB_Any, \strImageDisplayed)
    
    If IsImage(img)
      ResizeImage(img, 100, 100, #PB_Image_Raw)
      SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(img))
      
      ;Can't FreeImage after setting image into gadget, as only the handle to the image is stored, not a copy of the image
      \iPreviousImage = img
    EndIf
  EndWith
EndProcedure

Procedure DisplayThumbnails(Parameter)
  Protected iGadget.i, iCount.i
  Protected strImage.s
  
  Repeat
    Delay(1)
     
    LockMutex(g_MUTEX\Thumbnail)
   
    If FirstElement(g_listThumbnails())
      ;get image and client gadget UI slot from queue 
      With g_listThumbnails()
        strImage = \strImage
        iGadget = \iGadget
        iCount = \iCount
      EndWith
     
      DeleteElement(g_listThumbnails())
      UnlockMutex(g_MUTEX\Thumbnail)
      
      ;Update button gadget data for this IP address
      g_rgUIClients(iGadget)\strImageDisplayed = strImage
      g_rgUIClients(iGadget)\iTotalImages = iCount
      
      If Not g_fMinimized
        ;PureBasic doesn't like it when we update UI in a thread, so post event to main window
        PostEvent(#UPDATETHUMBNAIL, wndMain, 0, 0, iGadget)
      EndIf
    Else
      UnlockMutex(g_MUTEX\Thumbnail)
    EndIf
    
  ;drain queue and display all thumbnails asked even after network is stopped  
  Until Not g_fNetworkEnabled And ListSize(g_listThumbnails()) = 0
   
  ClearList(g_listThumbnails())
EndProcedure

Procedure InitializeUI()
  Protected i.i
  Shared s_iWindowX, s_iWindowY
  
  HideGadget(imgSearching, #True)
  HideGadget(lblNoNetwork, #True)
  
  ;reposition window to last position from settings, if any
  ResizeWindow(wndMain, s_iWindowX, s_iWindowY, #PB_Ignore, #PB_Ignore)
  HideWindow(wndMain, #False)
  
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
  FreeImage(Img_wndMain_1)
  FreeImage(Img_wndMain_2)
  FreeImage(Img_wndMain_3)
EndIf

;Replace the images with those embedded in the executable
Img_wndMain_0 = CatchImage(#PB_Any, ?LOGO)
Img_wndMain_1 = CatchImage(#PB_Any, ?Searching)
Img_wndMain_2 = CatchImage(#PB_Any, ?DefaultFolder)
Img_wndMain_3 = CatchImage(#PB_Any, ?AboutArrow)

s_imgAppIcon = CatchImage(#PB_Any, ?AppIcon)
g_imgPlaceholder = CatchImage(#PB_Any, ?Placeholder)
g_imgAvailable = CatchImage(#PB_Any, ?Available)

OpenwndMain()
HideWindow(wndMain, #True)
; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 116
; FirstLine = 91
; Folding = -
; EnableXP