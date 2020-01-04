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
        
        ;first item added to list becomes the default images folder
        If CountGadgetItems(lstClientFolders) = 0
          strIP = "255.255.255.255"
          
          ;SetGadgetText(edtImagesPath, strPath)
        EndIf
        
        AddGadgetItem(lstClientFolders, -1, strIP + #LF$ + strPath)
      EndIf
    EndIf
    
    iCount + 1
  ForEver
    
  ;g_strPathFromPrefs = ReadPreferenceString("ImagesPath", "")
  
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
    
    ;WritePreferenceString("ImagesPath", GetGadgetText(edtImagesPath))

    ClosePreferences()   
    
    RunAtLogin(g_iRunAtLogin)
  EndIf
EndProcedure
; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 109
; FirstLine = 62
; Folding = -
; EnableXP