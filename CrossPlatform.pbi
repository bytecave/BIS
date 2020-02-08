Procedure RemoveListHeaders()
CompilerSelect #PB_Compiler_OS
  CompilerCase #PB_OS_Linux
    gtk_tree_view_set_headers_visible_(GadgetID(lstEvents), #False)
  CompilerCase #PB_OS_Windows
	 SetWindowLongPtr_(GadgetID(lstEvents), #GWL_STYLE, GetWindowLongPtr_(GadgetID(lstEvents), #GWL_STYLE) | #LVS_NOCOLUMNHEADER)
CompilerEndSelect
EndProcedure

; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; CursorPosition = 7
; Folding = -
; EnableXP