;This software provided under MIT license. Copyright 2019-2020, ByteCave

#CONFIGESCPRESSED = 1000

DataSection
  SelectFolder:
    IncludeBinary "resources\selectfolder.png"
EndDataSection

XIncludeFile "frmClientConfig.pbf"

Define s_fSettingDefault.i, s_fExistingClientOnEntry.i

Procedure GetImagesPath(EventType)
  Protected strImagesPath.s
  
  strImagesPath = GetGadgetText(edtConfigImagesPath)
  
  If strImagesPath = ""
    strImagesPath = g_strDefaultFolder
  EndIf
  
  strImagesPath = PathRequester("Select images folder", strImagesPath)
  
  If strImagesPath <> ""
    SetGadgetText(edtConfigImagesPath, strImagesPath)
    DisableGadget(btnSetClient, 0)
  EndIf
EndProcedure

Procedure ClientConfigDialog(iGadget.i, fGetDefaultFolder.i)
  Shared s_fSettingDefault.i, s_fExistingClientOnEntry.i
  
  ;Shared variable value is saved between calls so need to reset each time dialog is displayed
  s_fSettingDefault = #False
  s_fExistingClientOnEntry = #False
  
  DisableWindow(wndMain, #True)
  OpenwndClientConfig()
  
  AddKeyboardShortcut(wndClientConfig, #PB_Shortcut_Escape, #CONFIGESCPRESSED)
  
  ;Fix up gadget positions as these start in a position visible in Form Designer, but not the correct UI position
  ResizeGadget(lblDefaultFolder, GadgetX(ipClientAddress), GadgetY(ipClientAddress), #PB_Ignore, #PB_Ignore)
  
  If fGetDefaultFolder
    s_fSettingDefault = #True
    
    HideGadget(ipClientAddress, 1)
    HideGadget(btnRemoveClient, 1)
    HideGadget(lblDefaultFolder, 0)
    
    SetGadgetText(edtConfigImagesPath, g_strDefaultFolder)
  Else
    HideGadget(lblDefaultFolder, 1)
    
    SetGadgetText(edtConfigImagesPath, g_mapClients(g_rgUIClients(iGadget)\strIPClientMapKey)\strImagesPath)
    SetGadgetState(ipClientAddress, g_mapClients(g_rgUIClients(iGadget)\strIPClientMapKey)\iClientIP)
  EndIf
  
  ;new client being added or default folder not yet set
  If GetGadgetText(edtConfigImagesPath) = ""
    DisableGadget(btnSetClient, 1)
    DisableGadget(btnRemoveClient, 1)
  ElseIf Not fGetDefaultFolder   ;existing client on entry to dialog
    s_fExistingClientOnEntry = #True
    DisableGadget(ipClientAddress, 1)
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

Procedure CloseClientConfig()
  RemoveKeyboardShortcut(wndClientConfig, #PB_Shortcut_Escape)
  
  ;TODO:Are these auto-reset every time the Client Config window is open? Maybe we don't have to do the stuff below...
;   HideGadget(lblDefaultFolder, 1)
;   HideGadget(ipClientAddress, 0)
;   HideGadget(btnRemoveClient, 0)
;   
;   DisableGadget(ipClientAddress, 0)
;   DisableGadget(btnRemoveClient, 0)
;   DisableGadget(btnSetClient, 0)
  DisableWindow(wndMain, #False)
  CloseWindow(wndClientConfig)
EndProcedure

    ;TODO:Do we need to LockMutex or is rotate thread guaranteed stopped here
Procedure SetClientConfig(EventType)
  Shared s_fSettingDefault.i, s_fExistingClientOnEntry.i
  Protected fExisting.i
  Protected strIP.s
  
  If s_fSettingDefault
    g_strDefaultFolder = GetGadgetText(edtConfigImagesPath)
    SetGadgetText(edtMainImagesPath, g_strDefaultFolder)
  Else
    strIP = GetGadgetText(ipClientAddress)
    fExisting = FindMapElement(g_mapClients(), strIP)
    
    If s_fExistingClientOnEntry
      g_mapClients()\strImagesPath = GetGadgetText(edtConfigImagesPath)
    Else
      If fExisting
        MessageRequester("Duplicate Client IP", "Client entry already exists for IP address " + strIP + ". Please change IP address and try again.", #PB_MessageRequester_Ok | #PB_MessageRequester_Warning)
      Else
        ;got a brand new IP address, should set it in "GADGET" position
        ;do this with call to CreateClientList, passing in images path and IP address
        ;this will require iGadget from the ClientConfig() call to be a shared variable so it's available here
        ;Networking code will call the same CreateClientList() function when it gets a new connection
        ;CreateClientList() needs to work the same here as it does there, including adding to the gadget list
        ;when user clicked a button to get here, we KNOW which gadget they used, so it's easy
        ;when network client tries to auto-create one, it needs to create entry in g_mapClients but ALSO
        ;  needs to create an entry in the gadget list. It will do this by searching for a free gadget space.
        ;  it doesn't need to search the existing client gadget list because if an IP existed it would have
        ;  been found in the network code and we wouldn't be trying to create a new client (CreateClientList())
        
        ;REMEMBER: CTRL-B sets "block coment," and ALT-B removes the block comments.
        Debug "NEW IP Address"
      EndIf
    EndIf
  EndIf
  
  CloseClientConfig()
EndProcedure

Procedure RemoveClientConfig(EventType)
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
; CursorPosition = 139
; FirstLine = 91
; Folding = --
; EnableXP