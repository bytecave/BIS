;This software provided under MIT license. Copyright 2019-2020, ByteCave

#CONFIGESCPRESSED = 1000

DataSection
  SelectFolder:
    IncludeBinary "resources\selectfolder.png"
EndDataSection

XIncludeFile "frmClientConfig.pbf"

Define s_fSettingDefault.i, s_fExistingClientOnEntry.i, s_iGadget.i

Procedure GetImagesPath(EventType)
  Protected strImagesPath.s
  
  strImagesPath = GetGadgetText(edtConfigImagesPath)
  
  If strImagesPath = ""
    strImagesPath = g_strDefaultFolder
  EndIf
  
  strImagesPath = PathRequester("Select images folder", strImagesPath)
  
  ;if valid images path, enable Set button, even if IP address is still 0.0.0.0
  If strImagesPath <> ""
    SetGadgetText(edtConfigImagesPath, strImagesPath)
    DisableGadget(btnSetClient, 0)
  EndIf
EndProcedure

Procedure ClientConfigDialog(fGetDefaultFolder.i)
  Shared s_fSettingDefault.i, s_fExistingClientOnEntry.i, s_iGadget.i
  
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
    
    If g_rgUIClients(s_iGadget)\strIPClientMapKey <> ""
      SetGadgetText(edtConfigImagesPath, g_mapClients(g_rgUIClients(s_iGadget)\strIPClientMapKey)\strImagesPath)
      SetGadgetState(ipClientAddress, g_mapClients(g_rgUIClients(s_iGadget)\strIPClientMapKey)\iClientIP)
    Else
      SetGadgetState(ipClientAddress, g_iLastIP)
    EndIf
  EndIf
  
  ;new client being added or default folder not yet set
  If GetGadgetText(edtConfigImagesPath) = ""
    DisableGadget(btnSetClient, 1)
    DisableGadget(btnRemoveClient, 1)
    
    SetActiveGadget(ipClientAddress)
  ElseIf Not fGetDefaultFolder   ;existing client on entry to dialog
    s_fExistingClientOnEntry = #True
    DisableGadget(ipClientAddress, 1)
  EndIf
EndProcedure

;can't click UI client button while server is running and no client ip/images path are set
Procedure ClientConfig(EventType)
  Shared s_iGadget.i
  Protected strIP.s
  
  If Not EventGadget() = btnDefaultFolder
    If g_iLastIP = 0
      g_iLastIP = MakeIPAddress(Val(StringField(g_strServerIP, 1, ".")),
                                Val(StringField(g_strServerIP, 2, ".")),
                                Val(StringField(g_strServerIP, 3, ".")),
                                0)
    EndIf
    
    s_iGadget = EventGadget() - #btn0
    g_UIState\iSelectedGadget = s_iGadget
    
    If g_fNetworkEnabled
      strIP = g_rgUIClients(s_iGadget)\strIPClientMapKey
      
      LockMutex(g_MUTEX\Clients)
      SetGadgetText(edtMainImagesPath, "[" + strIP + "]: " + g_mapClients(strIP)\strImagesPath)
      UnlockMutex(g_MUTEX\Clients)
    Else
      ClientConfigDialog(#False)
    EndIf
  Else
    If g_fNetworkEnabled
      SetGadgetText(edtMainImagesPath, "[Default Folder]: " + g_strDefaultFolder)
    Else
      ClientConfigDialog(#True)
    EndIf
  EndIf
EndProcedure

Procedure CloseClientConfig()
  RemoveKeyboardShortcut(wndClientConfig, #PB_Shortcut_Escape)
  
  DisableWindow(wndMain, #False)
  CloseWindow(wndClientConfig)
EndProcedure

Procedure SetClientConfig(EventType)
  Shared s_fSettingDefault.i, s_fExistingClientOnEntry.i, s_iGadget.i
  Protected i.i, fRC.i = #True
  Protected strIP.s, strImagesPath.s
  
  If s_fSettingDefault
    g_strDefaultFolder = GetGadgetText(edtConfigImagesPath)
    SetGadgetText(edtMainImagesPath, "[" + "Default Folder]: " + g_strDefaultFolder)
    
    DisableClientButtons(#False)
  Else
    strIP = GetGadgetText(ipClientAddress)
    strImagesPath = GetGadgetText(edtConfigImagesPath)
    
    If s_fExistingClientOnEntry
      g_mapClients()\strImagesPath = strImagesPath
    Else
      If FindMapElement(g_mapClients(), strIP)
        MessageRequester("Duplicate Client IP", "Client entry already exists for IP address " + strIP + ". Please change IP address and try again.", #PB_MessageRequester_Ok | #PB_MessageRequester_Warning)
        SetActiveGadget(ipClientAddress)
        
        fRC = #False
      Else
        ;New IP address so let's set it as Last IP set = last client entered in dialog
        g_iLastIP = MakeIPAddress(Val(StringField(strIP, 1, ".")),
                                  Val(StringField(strIP, 2, ".")),
                                  Val(StringField(strIP, 3, ".")),
                                  0)

        CreateClientList(GetGadgetState(ipClientAddress), strIP, strImagesPath, s_iGadget)
      EndIf
    EndIf
  EndIf
  
  If fRC
    SetGadgetColor(g_rgUIClients(s_iGadget)\hTxtIP, #PB_Gadget_FrontColor, #PB_Default)
    
    If s_fSettingDefault
      SetGadgetText(edtMainImagesPath, "[" + "Default Folder]: " + g_strDefaultFolder)
    Else
      SetGadgetText(edtMainImagesPath, "[" + strIP + "]: " + strImagesPath)
    EndIf
    
    CloseClientConfig()
  EndIf
EndProcedure

Procedure RemoveClientConfig(EventType)
  Shared s_iGadget.i
  
  With g_rgUIClients(s_iGadget)
    FindMapElement(g_mapClients(), \strIPClientMapKey)
    ClearList(g_mapClients()\listClientImages())
    DeleteMapElement(g_mapClients())
    
    \strIPClientMapKey = ""
    SetGadgetText(\hTxtIP, "")
    SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(g_imgAvailable))
  EndWith
  
  CloseClientConfig()
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

; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; CursorPosition = 36
; FirstLine = 31
; Folding = --
; EnableXP