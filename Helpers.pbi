;This software provided under MIT license. Copyright 2019-2020, ByteCave

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

Procedure DisableClientButtons(fDisable)
  Protected i.i
  
  For i = 0 To #LASTCLIENT
    DisableGadget(g_rgUIClients(i)\hBtnIP, fDisable)
  Next
EndProcedure

Procedure LoadSettings()
  Shared s_iWindowX, s_iWindowY
  Protected strPrefs.s
  Protected strImagesPath.s
  Protected i.i, iIP.i, iTotalImages.i
  
  strPrefs = GetHomeDirectory() + #PREFSFILENAME
  OpenPreferences(strPrefs)
  
  g_qMinTimeBetweenImages = ReadPreferenceInteger("MinTimeBetweenImages", g_qMinTimeBetweenImages)
  g_iMinimizeToTray = ReadPreferenceInteger("MinimizeToTray", #False)
  g_iRunAtLogin = ReadPreferenceInteger("RunAtLogin", #PB_Checkbox_Unchecked)
  g_iPort = ReadPreferenceInteger("Port", g_iPort)
  g_qForeverImagesServed = ReadPreferenceQuad("ForeverImagesServed", g_qForeverImagesServed)
  g_strServerIP = ReadPreferenceString("ServerIP", g_strServerIP)

  s_iWindowX = ReadPreferenceInteger("WindowX", #PB_Ignore)
  s_iWindowY = ReadPreferenceInteger("WIndowY", #PB_Ignore)
  
  g_strDefaultFolder = ReadPreferenceString("DefaultFolder", "")  
  If Not FileSize(g_strDefaultFolder) = -2   ;if it's a valid directory
    g_strDefaultFolder = ""
  EndIf
  
  ;map UI image button and IP text label handles to arrays
  For i = #btn0 To #btn0 + #LASTCLIENT
    g_rgUIClients(i - #btn0)\hBtnIP = i
  Next
  
  For i = #txt0 To #txt0 + #LASTCLIENT
    g_rgUIClients(i - #txt0)\hTxtIP = i
  Next

  For i = 0 To #LASTCLIENT
    iIP = ReadPreferenceInteger("ClientIP" + Str(i), 0)
    
    If iIP
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

Procedure SaveSettings()
  Protected strPrefs.s, strImagesPath.s
  Protected i.i, iIP.i, iTotalImages.i
  
  strPrefs = GetHomeDirectory() + #PREFSFILENAME
  
  If CreatePreferences(strPrefs)
    WritePreferenceInteger("MinTimeBetweenImages", g_qMinTimeBetweenImages)
    WritePreferenceInteger("MinimizeToTray", g_iMinimizeToTray)
    WritePreferenceInteger("RunAtLogin", g_iRunAtLogin)
    WritePreferenceInteger("Port", g_iPort)
    WritePreferenceQuad("ForeverImagesServed", g_qForeverImagesServed)
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
    
    RunAtLogin(g_iRunAtLogin)
  EndIf
EndProcedure
; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; CursorPosition = 2
; Folding = -
; EnableXP