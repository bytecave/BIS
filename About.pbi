;This software provided under MIT license. Copyright 2019-2020, ByteCave

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
  If EventMenu() = #ABOUTESCPRESSED
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
  
  SetGadgetText(txtAboutLabel, "About ByteCave Image Server v" + Str(#BIS_VERSION) + "." + Str(#PB_Editor_BuildCount) + "-" + Str(#PB_Editor_CompileCount))
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
    SetGadgetText(btnContent, "Display ByteCave (c) 2019-2020, MIT License")
    
    fAbout = #False
  Else
    SetGadgetText(edtAbout, PeekS(?StartLicense, ?EndLicense - ?StartLicense, #PB_Ascii))
    SetGadgetText(btnContent, "Read about ByteCave Image Server")
    
    fAbout = #True
  EndIf
EndProcedure

Procedure CloseAboutBox(EventType)
  RemoveKeyboardShortcut(wndAbout, #PB_Shortcut_Escape)

  DisableWindow(wndMain, #False)
  CloseWindow(wndAbout)
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