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
  Protected strIP.s, strPath.s
  Protected iCount.i
  Protected fFoundDefault.i = #False
  
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
  
  Repeat
    strIP = ReadPreferenceString("ClientIP" + Str(iCount), "END")
    
    If strIP = "END"
      Break
    Else
      strPath = ReadPreferenceString("ImagePath" + Str(iCount), "")
      
      If FileSize(strPath) = -2  ;if it's a valid directory
        If strIP = #DEFAULTCLIENTIP
          fFoundDefault = #True
          ;SetGadgetText(txtImagesPath, strPath)
        EndIf
;          SetGadgetState(ipClientAddress, MakeIPAddress(Val(StringField(strIP, 1, ".")),
;                                                        Val(StringField(strIP, 2, ".")),
;                                                        Val(StringField(strIP, 3, ".")),
;                                                        Val(StringField(strIP, 4, "."))))
       
        AddGadgetItem(lstClientFolders, -1, strIP + #LF$ + strPath)
      EndIf
    EndIf
    
    iCount + 1
  ForEver
  
  If Not fFoundDefault
    SetGadgetState(ipClientAddress, MakeIPAddress(255, 255, 255, 255))  ;#DEFAULTCLIENTIP
    DisableGadget(ipClientAddress, 1)
  Else
    HideGadget(lblDefaultFolder, 1)
  EndIf
  
  ClosePreferences()
EndProcedure

;Set initial path to path from settings file, if it's a valid path
;If FileSize(g_strPathFromPrefs) = -2   ;if it's a valid directory
;  GetImagesPath(0)
;EndIf


Procedure SaveSettings()
  Protected strPrefs.s, strIP.s, strPath.s
  Protected iCount.i
  
  strPrefs = GetHomeDirectory() + #PREFSFILENAME
  
  If CreatePreferences(strPrefs)
    WritePreferenceInteger("MinTimeBetweenImages", g_qMinTimeBetweenImages)
    WritePreferenceInteger("MinimizeToTray", g_iMinimizeToTray)
    WritePreferenceInteger("RunAtLogin", g_iRunAtLogin)
    WritePreferenceInteger("Port", g_iPort)
    WritePreferenceInteger("ForeverImagesServed", g_iForeverImagesServed)
    WritePreferenceString("ServerIP", g_strServerIP)
    
    WritePreferenceInteger("WindowX", WindowX(wndMain, #PB_Window_FrameCoordinate))
    WritePreferenceInteger("WindowY", WindowY(wndMain, #PB_Window_FrameCoordinate))
    
    iCount = CountGadgetItems(lstClientFolders)
    While iCount
      iCount - 1
      
      strIP = GetGadgetItemText(lstClientFolders, iCount , 0)  ;ip address
      strPath = GetGadgetItemText(lstClientFolders, iCount, 1) ;image folder
      
      WritePreferenceString("ClientIP" + Str(iCount), strIP)
      WritePreferenceString("ImagePath" + Str(iCount), strPath)
    Wend

    ClosePreferences()   
    
    RunAtLogin(g_iRunAtLogin)
  EndIf
EndProcedure

Procedure ColorClientIPList()
  Protected i.i, iItems.i
  Dim rgRowColor.q(1)
  
  rgRowColor(0) = RGB(230, 250, 255)  ;blueish
  rgRowColor(1) = RGB(240, 240, 240)  ;grayish
  
  iItems = CountGadgetItems(lstClientFolders)
  
  For i = 0 To iItems
    SetGadgetItemColor(lstClientFolders, i, #PB_Gadget_BackColor, rgRowColor(i % 2), #PB_All)
  Next
EndProcedure

; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; CursorPosition = 56
; FirstLine = 38
; Folding = -
; EnableXP