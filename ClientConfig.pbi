;This software provided under MIT license. Copyright 2019-2020, ByteCave

#CONFIGESCPRESSED = 1000

DataSection
  SelectFolder:
    IncludeBinary "resources\selectfolder.png"
EndDataSection

XIncludeFile "frmClientConfig.pbf"

Procedure GetImagesPath(EventType)
  Protected strImagesPath.s
  
  strImagesPath = GetGadgetText(edtConfigImagesPath)
  
  If strImagesPath = ""
    strImagesPath = g_strDefaultFolder
  EndIf
  
  strImagesPath = PathRequester("Select images folder", strImagesPath)
  
  If strImagesPath <> ""
    SetGadgetText(edtConfigImagesPath, strImagesPath)
  EndIf
EndProcedure

Procedure ClientConfigDialog(iGadget.i, fGetDefaultFolder.i)
  DisableWindow(wndMain, #True)
  OpenwndClientConfig()
  
  AddKeyboardShortcut(wndClientConfig, #PB_Shortcut_Escape, #CONFIGESCPRESSED)
  
  ;Fix up gadget positions as these start in a position visible in Form Designer, but not the correct UI position
  ResizeGadget(lblDefaultFolder, GadgetX(ipClientAddress), GadgetY(ipClientAddress), #PB_Ignore, #PB_Ignore)
  
  If fGetDefaultFolder
    HideGadget(ipClientAddress, 1)
    HideGadget(btnRemoveClient, 1)
    HideGadget(lblDefaultFolder, 0)
    
    SetGadgetText(edtConfigImagesPath, g_strDefaultFolder)
  Else
    HideGadget(lblDefaultFolder, 1)
    
    SetGadgetText(edtConfigImagesPath, g_mapClients(g_rgUIClients(iGadget)\strIPClientMapKey)\strImagesPath)
    SetGadgetState(ipClientAddress, g_mapClients(g_rgUIClients(iGadget)\strIPClientMapKey)\iClientIP)
  EndIf
EndProcedure

;can't click UI client button while server is running and no client ip/images path are set
Procedure ClientConfig(EventType)
  Protected iGadget.i
  
  If Not EventGadget() = btnDefaultFolder
    iGadget = EventGadget() - #btn0
    g_UIState\iSelectedGadget = iGadget
    
    If g_fNetworkEnabled
      LockMutex(g_MUTEX\Clients)
      SetGadgetText(edtMainImagesPath, g_mapClients(g_rgUIClients(iGadget)\strIPClientMapKey)\strImagesPath)
      UnlockMutex(g_MUTEX\Clients)
    Else
      ClientConfigDialog(iGadget, #False)
    EndIf
  Else
    If g_fNetworkEnabled
      SetGadgetText(edtMainImagesPath, g_strDefaultFolder)
    Else
      ClientConfigDialog(0, #True)
    EndIf
  EndIf
EndProcedure

Procedure SetClientConfig(EventType)
EndProcedure

Procedure RemoveClientConfig(EventType)
EndProcedure

Procedure CloseClientConfig()
  RemoveKeyboardShortcut(wndClientConfig, #PB_Shortcut_Escape)
  
  HideGadget(ipClientAddress, 0)
  HideGadget(btnRemoveClient, 0)
  HideGadget(lblDefaultFolder, 1)
  
  DisableWindow(wndMain, #False)
  CloseWindow(wndClientConfig)
EndProcedure

;PB Form Designer attempts to load image from disk, which only works at development time
;So free this at run time, and fall through to CatchImage statement below that work at both dev and run time
If IsImage(Img_wndClientConfig_0)
  FreeImage(Img_wndClientConfig_0)
EndIf

;Replace the image with the one embedded in the executable
Img_wndClientConfig_0 = CatchImage(#PB_Any, ?SelectFolder)

Procedure HandleClientConfigEvents(Event)
  If EventMenu() = #CONFIGESCPRESSED
    CloseClientConfig()
  Else
    Select Event
      Case #PB_Event_CloseWindow
        CloseClientConfig()
      Default
        wndClientConfig_Events(Event)
    EndSelect
  EndIf
EndProcedure

; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 106
; FirstLine = 61
; Folding = --
; EnableXP