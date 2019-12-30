;This software provided under MIT license. Copyright 2019-2020, ByteCave

#ABOUTESCPRESSED = 1000

;Shared variable in procedures that reference it
Define fAbout.i

DataSection
  miniLOGO:
    IncludeBinary "resources\minilogo.png"
  StartAbout:
    IncludeBinary "README.MD"
  EndAbout:
  StartLicense:
    IncludeBinary "LICENSE.MD"
  EndLicense:
EndDataSection

XIncludeFile "frmAbout.pbf"

;PB Form Designer attempts to load images from disk, which only works at development time
;So free these at run time, and fall through to CatchImage statements below that work at dev and run time
If IsImage(Img_wndAbout_0)
  FreeImage(Img_wndAbout_0)
EndIf

;Replace the images with those embedded in the executable
Img_wndAbout_0 = CatchImage(#PB_Any, ?miniLOGO)

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
  
  fAbout = #True
  
  DisplayContent(0)
EndProcedure

;When fAbout is true, About info is displayed, otherwise license info is displayed
Procedure DisplayContent(EventType)
  Shared fAbout
  
  If fAbout
    SetGadgetText(edtAbout, PeekS(?StartAbout, ?EndAbout - ?StartAbout, #PB_Ascii))
    SetGadgetText(btnContent, "Display ByteCave (c) 2020, MIT License")
    
    fAbout = #False
  Else
    SetGadgetText(edtAbout, PeekS(?StartLicense, ?EndLicense - ?StartLicense, #PB_Ascii))
    SetGadgetText(btnContent, "Read about ByteCave Image Server")
    
    fAbout = #True
  EndIf
EndProcedure

Procedure CloseAboutBox(EventType)
  DisableWindow(wndMain, #False)
  CloseWindow(wndAbout)
EndProcedure
; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; CursorPosition = 14
; FirstLine = 7
; Folding = -
; EnableXP