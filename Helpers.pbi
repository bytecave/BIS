;This software provided under MIT license. Copyright 2019-2026, ByteLord

Procedure.i RunAtLogin(iRunAtLogin.i)
  Protected key.i, result.i, path.s
  Protected registryPath.s = "Software\Microsoft\Windows\CurrentVersion\Run"
  If iRunAtLogin = #PB_Checkbox_Checked
    path = Chr(34) + ProgramFilename() + Chr(34)
    result = RegCreateKeyEx_(#HKEY_CURRENT_USER, @registryPath, 0, 0, 0, #KEY_SET_VALUE, 0, @key, 0)
    If result = #ERROR_SUCCESS
      result = RegSetValueEx_(key, @"BIS", 0, #REG_SZ, @path, StringByteLength(path, #PB_Unicode) + 2)
      RegCloseKey_(key)
    EndIf
  Else
    result = RegOpenKeyEx_(#HKEY_CURRENT_USER, @registryPath, 0, #KEY_SET_VALUE, @key)
    If result = #ERROR_SUCCESS
      result = RegDeleteValue_(key, @"BIS")
      RegCloseKey_(key)
    EndIf
  EndIf
  ProcedureReturn Bool(result = #ERROR_SUCCESS Or result = #ERROR_FILE_NOT_FOUND)
EndProcedure
Procedure DisableClientButtons(fDisable)
  Protected i.i
  
  For i = 0 To #LASTCLIENT
    DisableGadget(g_rgUIClients(i)\hBtnIP, fDisable)
  Next
EndProcedure

Procedure LoadSettings(strPrefs.s = "")
  Shared s_iWindowX, s_iWindowY
  Protected strImagesPath.s
  Protected i.i, iIP.i, iTotalImages.i
  
  If strPrefs = "" : strPrefs = GetHomeDirectory() + #PREFSFILENAME : EndIf
  For i = 0 To #LASTCLIENT
    g_rgUIClients(i)\hBtnIP = #btn0 + i
    g_rgUIClients(i)\hTxtIP = #txt0 + i
  Next
  If Not OpenPreferences(strPrefs)
    RefreshClientButtons()
    ProcedureReturn
  EndIf
  
  g_qMinTimeBetweenImages = ReadPreferenceInteger("MinTimeBetweenImages", g_qMinTimeBetweenImages)
  g_iMinimizeToTray = ReadPreferenceInteger("MinimizeToTray", #False)
  g_iRunAtLogin = ReadPreferenceInteger("RunAtLogin", #PB_Checkbox_Unchecked)
  g_iPort = ReadPreferenceInteger("Port", g_iPort)
  If g_iPort < 1 Or g_iPort > 65535 : g_iPort = #DEFAULTSERVERPORT : EndIf
  If g_qMinTimeBetweenImages < 2000 Or g_qMinTimeBetweenImages > 86400
    g_qMinTimeBetweenImages = #DEFAULTMINTIME
  EndIf
  g_iForeverImagesServed = ReadPreferenceInteger("ForeverImagesServed", g_iForeverImagesServed)
  g_strServerIP = ReadPreferenceString("ServerIP", g_strServerIP)

  s_iWindowX = ReadPreferenceInteger("WindowX", #PB_Ignore)
  s_iWindowY = ReadPreferenceInteger("WIndowY", #PB_Ignore)
  
  g_strDefaultFolder = ReadPreferenceString("DefaultFolder", "")  
  If Not FileSize(g_strDefaultFolder) = -2   ;if it's a valid directory
    g_strDefaultFolder = ""
  EndIf
  
  For i = 0 To #LASTCLIENT
    iIP = ReadPreferenceInteger("ClientIP" + Str(i), 0)
    
    If iIP And Not FindMapElement(g_mapClients(), IPString(iIP))
      strImagesPath = ReadPreferenceString("ImagesPath" + Str(i), "")
      If Not FileSize(strImagesPath) = -2  ;if it's a valid directory
        strImagesPath = g_strDefaultFolder
      EndIf
      
      iTotalImages = ReadPreferenceInteger("TotalImages" + Str(i), 0)
      
      CreateClientList(iIP, IPString(iIP), strImagesPath, i, iTotalImages)
    Else
      SetGadgetAttribute(g_rgUIClients(i)\hBtnIP, #PB_Button_Image, ImageID(g_imgAvailable))
      GadgetToolTip(g_rgUIClients(i)\hBtnIP, "Click to add image folder for specific IP address.")
    EndIf
  Next
  
  DisableClientButtons(#False)
  ClosePreferences()
EndProcedure

Procedure SaveSettings(strPrefs.s = "", applyLogin.i = #True)
  Protected strImagesPath.s
  Protected i.i, iIP.i, iTotalImages.i
  
  If strPrefs = "" : strPrefs = GetHomeDirectory() + #PREFSFILENAME : EndIf
  
  If CreatePreferences(strPrefs)
    WritePreferenceInteger("MinTimeBetweenImages", g_qMinTimeBetweenImages)
    WritePreferenceInteger("MinimizeToTray", g_iMinimizeToTray)
    WritePreferenceInteger("RunAtLogin", g_iRunAtLogin)
    WritePreferenceInteger("Port", g_iPort)
    WritePreferenceInteger("ForeverImagesServed", g_iForeverImagesServed)
    WritePreferenceString("ServerIP", g_strServerIP)
    WritePreferenceString("DefaultFolder", g_strDefaultFolder)
    
    WritePreferenceInteger("WindowX", WindowX(wndMain, #PB_Window_FrameCoordinate))
    WritePreferenceInteger("WindowY", WindowY(wndMain, #PB_Window_FrameCoordinate))
    
    For i = 0 To #LASTCLIENT
      If g_rgUIClients(i)\strIPClientMapKey <> ""
        With g_mapClients(g_rgUIClients(i)\strIPClientMapKey)
          iIP = \iClientIP
          strImagesPath = \strImagesPath
          iTotalImages = \iTotalImages
        EndWith
      Else
          iIP = 0
          strImagesPath = ""
          iTotalImages = 0
        EndIf
      
      WritePreferenceInteger("ClientIP" + Str(i), iIP)
      WritePreferenceString("ImagesPath" + Str(i), strImagesPath)
      WritePreferenceInteger("TotalImages" + Str(i), iTotalImages)
    Next
    
    ClosePreferences()   
    
    If applyLogin And Not RunAtLogin(g_iRunAtLogin)
      AddStatusEvent("Could not update Run at user login setting.", #False, #Red)
    EndIf
  EndIf
EndProcedure
; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; CursorPosition = 2
; Folding = -
; EnableXP
