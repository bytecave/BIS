Procedure RunAtLogin(iRunAtLogin.i)
  Protected ihKey.i, iRC.i = #False
  Protected strPath.s, cTerminatorSize.c = '!'
  Protected strRegPath.s = "Software\Microsoft\Windows\CurrentVersion\Run"
  
  If iRunAtLogin = #PB_Checkbox_Checked
    strPath = Space(32767)   ;Windows 10 can allow 32,767 characters in pathname
    
    If GetModuleFileName_(0, strPath, 32767)
      strPath = Chr(34) + Trim(strPath) + Chr(34)
      
      RegCreateKeyEx_(#HKEY_CURRENT_USER, @strRegPath, 0, 0, 0, #KEY_WRITE, 0, @ihKey, 0)
      RegSetValueEx_(ihKey, @"BIS", 0, #REG_SZ, @strPath, StringByteLength(strPath) + SizeOf(cTerminatorSize))
    EndIf
  Else
    RegOpenKey_(#HKEY_CURRENT_USER, @strRegPath, @ihKey)
    RegDeleteValue_(ihKey, @"BIS")
  EndIf
  
  If ihKey > 0
    RegCloseKey_(ihKey)
  EndIf
EndProcedure

 Procedure LoadSettings()
  Shared s_iWindowX, s_iWindowY
  Protected strPrefs.s
  Protected strImagesPath.s
  Protected i.i, iIP.i
  
  strPrefs = GetHomeDirectory() + #PREFSFILENAME
  OpenPreferences(strPrefs)
  
  g_qMinTimeBetweenImages = ReadPreferenceInteger("MinTimeBetweenImages", g_qMinTimeBetweenImages)
  g_iMinimizeToTray = ReadPreferenceInteger("MinimizeToTray", #False)
  g_iRunAtLogin = ReadPreferenceInteger("RunAtLogin", #PB_Checkbox_Unchecked)
  g_iPort = ReadPreferenceInteger("Port", g_iPort)
  g_iForeverImagesServed = ReadPreferenceInteger("ForeverImagesServed", g_iForeverImagesServed)
  g_strServerIP = ReadPreferenceString("ServerIP", g_strServerIP)

  s_iWindowX = ReadPreferenceInteger("WindowX", #PB_Ignore)
  s_iWindowY = ReadPreferenceInteger("WIndowY", #PB_Ignore)
  
  g_strDefaultFolder = ReadPreferenceString("DefaultFolder", "")  
  If Not FileSize(g_strDefaultFolder) = -2   ;if it's a valid directory
    g_strDefaultFolder = ""
  EndIf
  
  For i = 0 To 13
    iIP = ReadPreferenceInteger("ClientIP" + Str(i), 0)
    
    If iIP
      With g_rgUIClients(i)
        \strIPClientMapKey = IPString(iIP)
        
        SetGadgetText(\hTxtIP, IPString(iIP))
        SetGadgetAttribute(\hBtnIP, #PB_Button_Image, g_imgPlaceholder)
        DisableGadget(\hBtnIP, 0)
      EndWith
      
      strImagesPath = ReadPreferenceString("ImagePath" + Str(i), "")
      If Not FileSize(strImagesPath) = -2  ;if it's a valid directory
        strImagesPath = g_strDefaultFolder
      EndIf
      
      CreateClientList(iIP, IPString(iIP), strImagesPath)
    Else
      Break
    EndIf
  Next
  
  ClosePreferences()
EndProcedure

Procedure SaveSettings()
  Protected strPrefs.s
  Protected i.i
  
  strPrefs = GetHomeDirectory() + #PREFSFILENAME
  
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
    
    ResetMap(g_mapClients())
    
    While NextMapElement(g_mapClients())
      WritePreferenceInteger("ClientIP" + Str(i), g_mapClients()\iClientIP)
      WritePreferenceString("ImagePath" + Str(i), g_mapClients()\strImagesPath)
      
      i + 1
    Wend

    ClosePreferences()   
    
    RunAtLogin(g_iRunAtLogin)
  EndIf
EndProcedure


; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 100
; FirstLine = 55
; Folding = -
; EnableXP