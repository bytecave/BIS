﻿;This software provided under MIT license. Copyright 2019-2020, ByteCave

#CONFIGESCPRESSED = 1000

DataSection
  SelectFolder:
    IncludeBinary "resources\selectfolder.png"
EndDataSection

XIncludeFile "frmClientConfig.pbf"

Define s_fSettingDefault.i, s_fExistingClientOnEntry.i, s_iGadget.i, s_iLastIP.i

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

Procedure ClientConfigDialog(fGetDefaultFolder.i)
  Shared s_fSettingDefault.i, s_fExistingClientOnEntry.i, s_iGadget.i, s_iLastIP.i
  
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
      SetGadgetState(ipClientAddress, s_iLastIP)
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
  Shared s_iGadget.i, s_iLastIP.i
  
  If Not EventGadget() = btnDefaultFolder
    If s_iLastIP = 0
      s_iLastIP = MakeIPAddress(Val(StringField(g_strServerIP, 1, ".")),
                                Val(StringField(g_strServerIP, 2, ".")),
                                Val(StringField(g_strServerIP, 3, ".")),
                                0)
    EndIf
    
    s_iGadget = EventGadget() - #btn0
    g_UIState\iSelectedGadget = s_iGadget
    
    If g_fNetworkEnabled
      LockMutex(g_MUTEX\Clients)
      SetGadgetText(edtMainImagesPath, g_mapClients(g_rgUIClients(s_iGadget)\strIPClientMapKey)\strImagesPath)
      UnlockMutex(g_MUTEX\Clients)
    Else
      ClientConfigDialog(#False)
    EndIf
  Else
    If g_fNetworkEnabled
      SetGadgetText(edtMainImagesPath, g_strDefaultFolder)
    Else
      ClientConfigDialog(#True)
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
  Shared s_fSettingDefault.i, s_fExistingClientOnEntry.i, s_iGadget.i, s_iLastIP.i
  Protected i.i
  Protected strIP.s, strImagesPath.s
  
  If s_fSettingDefault
    g_strDefaultFolder = GetGadgetText(edtConfigImagesPath)
    SetGadgetText(edtMainImagesPath, g_strDefaultFolder)
    
    For i = 0 To 13
      DisableGadget(g_rgUIClients(i)\hBtnIP, 0)
    Next
  Else
    strIP = GetGadgetText(ipClientAddress)
    strImagesPath = GetGadgetText(edtConfigImagesPath)
    
    If s_fExistingClientOnEntry
      g_mapClients()\strImagesPath = strImagesPath
    Else
      If FindMapElement(g_mapClients(), strIP)
        MessageRequester("Duplicate Client IP", "Client entry already exists for IP address " + strIP + ". Please change IP address and try again.", #PB_MessageRequester_Ok | #PB_MessageRequester_Warning)
      Else
        ;Last IP set = last client entered in dialog
        s_iLastIP = MakeIPAddress(Val(StringField(strIP, 1, ".")),
                                  Val(StringField(strIP, 2, ".")),
                                  Val(StringField(strIP, 3, ".")),
                                  0)

        CreateClientList(GetGadgetState(ipClientAddress), strIP, strImagesPath, s_iGadget)
      EndIf
    EndIf
  EndIf
  
  CloseClientConfig()
EndProcedure

Procedure RemoveClientConfig(EventType)
  Shared s_iGadget.i, s_imgAvailable
  
  With g_rgUIClients(s_iGadget)
    FindMapElement(g_mapClients(), \strIPClientMapKey)
    ClearList(g_mapClients()\listClientImages())
    DeleteMapElement(g_mapClients())
    
    \strIPClientMapKey = ""
    SetGadgetText(\hTxtIP, "")
    SetGadgetAttribute(\hBtnIP, #PB_Button_Image, ImageID(s_imgAvailable))
  EndWith
  
  CloseClientConfig()
    
  ;remove IP address from client array rgUIClients 
  ;change image on fgUIClients button gadget to available
  ;remove client from client list (disconnectclient?)
  ;FindMapElement in g_mapClients
  ;free listClientImages from g_mapClients entry
  ;DeleteMapElement(listClientImages)
  ;Close config dialog
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
; CursorPosition = 69
; FirstLine = 41
; Folding = --
; EnableXP