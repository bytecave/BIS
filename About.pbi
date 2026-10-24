;This software provided under MIT license. Copyright 2019-2026, ByteLord

#ABOUTESCPRESSED = 1000

;Shared variable in procedures that reference it
Define fAbout.i

DataSection
  StartAbout:
    IncludeBinary "README.MD"
  EndAbout:
  StartLicense:
    IncludeBinary "LICENSE.MD"
  EndLicense:
EndDataSection

XIncludeFile "frmAbout.pbf"

Procedure HandleAboutEvents(Event)
  If Event = #PB_Event_Menu And EventMenu() = #ABOUTESCPRESSED
    CloseAboutBox(Event)
  Else
    Select Event
      Case #PB_Event_CloseWindow
        CloseAboutBox(Event)
      Default
        wndAbout_Events(Event)
    EndSelect
  EndIf
EndProcedure
    
Procedure DisplayAboutBox(EventType)
  Shared fAbout
  
  DisableWindow(wndMain, #True)
  OpenwndAbout()
  
  AddKeyboardShortcut(wndAbout, #PB_Shortcut_Escape, #ABOUTESCPRESSED)
  
  SetGadgetText(txtAboutLabel, "About " + #BIS_TITLE + " v" + #BIS_VERSION)
  SetGadgetState(chkTray, g_iMinimizeToTray)
  SetGadgetState(chkStartup, g_iRunAtLogin)
  
  fAbout = #True
  
  DisplayContent(0)
EndProcedure

;When fAbout is true, About info is displayed, otherwise license info is displayed
Procedure DisplayContent(EventType)
  Shared fAbout
  
  If fAbout
    SetGadgetText(edtAbout, PeekS(?StartAbout, ?EndAbout - ?StartAbout, #PB_Ascii))
    SetGadgetText(btnContent, "Display ByteLord (c) 2019-2026, MIT License")
    
    fAbout = #False
  Else
    SetGadgetText(edtAbout, PeekS(?StartLicense, ?EndLicense - ?StartLicense, #PB_Ascii))
    SetGadgetText(btnContent, "Read about ByteLord Image Server")
    
    fAbout = #True
  EndIf
EndProcedure

Procedure CloseAboutBox(EventType)
  RemoveKeyboardShortcut(wndAbout, #PB_Shortcut_Escape)

  DisableWindow(wndMain, #False)
  CloseWindow(wndAbout)
  wndAbout = 0
EndProcedure

Procedure SetMinToTray(EventType)
  g_fMinimized = #False
  g_iMinimizeToTray = GetGadgetState(chkTray)
EndProcedure

Procedure SetRunAtLogin(EventType)
  g_iRunAtLogin = GetGadgetState(chkStartup)
EndProcedure

; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 39
; FirstLine = 20
; Folding = --
; EnableXP
