start 
no List items selected
255’s, If exist, always first in List
remove button disabled 

ipaddr blank And path = click above
status = start server
Or
ipaddr 255’s And disabled
status = 255s

clicked_list
If items selected = 1
ipaddr = List item
txtpath = List item
g_strpathselected = txtpath
Else
ipaddr = 0.0.0.0
lbldeffolder = multiselect
Select path button disabled 
add button disabled
txtpath = click remove To remove selected
EndIf 
If ipaddr <> 255’s
remove button enabled

clicked_remove
remove selected items except 255’s
ipaddr = blank 
txtpath = click above

ipaddr_change
If ip in List
If txtpath
addbutton = “update”
Else
addbutton disabled 

clicked_add
If ip in List 
If txtpath = List path
status = change path

clicked_setpath
folder requester init path = txtpath
txtpath = requester path on close


Structure sUISTATE
  IPMultiSelect.i
  HaveValidIP.i
  HaveImagePath.i
  HaveDefaultFolderInList.i
EndStructure
  
If Not IPMultiSelect
  UIState\HaveImagePath = Is txtpath a valid folder?
  strIP = IP address from gadget
  If strIP <> "0.0.0.0"
    Search client IP List For strIP
    UIState\IPinList = Found from search above
	
	If UIState\IPinList = #True
	  Add button text changed To update
	  If UIState\HaveImagePath = #True
	    Enable Add button
		If strIP <> 255.255.255.255
		  Enable Remove button
		EndIf
		
    If strIP is 255's
	  Add button changed To update
	  Add button enabled
	  Remove button disabled
	Else
	  If txtpath = a valid folder
	    Enable Add button
		If IP field address in clientiplist
		  Add button changed To update
		Enable remove button
		Else
		  Add button changed To add
        EndIf
      Else
        txtpath = click button above To Select folder
		disable add button
		disable remove button
      EndIf
		
		
Else
  set bigstatus To Select Default 255.255.255.255 images folder
  
  
  
  #PB_EventType_Change          = 768
  #PB_EventType_Focus           = 14000
  #PB_EventType_LostFocus       = 14001
  
  
  
UsePNGImageDecoder()
; Shows possible flags of ListIconGadget in action...
  If OpenWindow(0, 0, 0, 700, 300, "ListIconGadgets", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
    ListIconGadget(5, 10, 10, 620, 65, "Client", 55, #PB_ListIcon_GridLines|#LVS_NOCOLUMNHEADER)
    ; Here we change the ListIcon display to large icons and show an image
    If LoadImage(0, "d:\code\bis\resources\logo.png")     ; change path/filename to your own 32x32 pixel image
      SetGadgetAttribute(5, #PB_ListIcon_DisplayMode, #PB_ListIcon_Report)
      ;AddGadgetColumn(5, 1, "", 35)
      AddGadgetColumn(5, 1, "IP", 100)
      AddGadgetColumn(5, 2, "Images", 75)
      AddGadgetColumn(5, 3, "Path", 100)
      AddGadgetItem(5, 1, "  [1]  " + Chr(10) + "192.168.200.105" + Chr(10) + "12,234,567" + Chr(10) + "D:\Code", ImageID(0))
      ;AddGadgetItem(5, 2, "192.168.20.215")
      ;+ #LF$ + "1,234,567" + LF$ + "D:\CODE", ImageID(0))
      ;AddGadgetItem(5, 2, "Picture 2", ImageID(0))
    EndIf
    Repeat : Until WaitWindowEvent() = #PB_Event_CloseWindow
  EndIf
  
  Path.s = "c:\users\bytecave\mypartition\mystuff\myfolder\filename.jpg\"
Procedure abbrpath(strPath.s, sep.s,level)
  Protected iCount.i
  Protected strShortPath.s = "..." + "\"
  
  strShortPath = "...\"
  
  iCount = CountString(strPath, "\")
  
  If level < iCount - 1
   For i = level To 0 Step -1
      strShortPath = strShortPath + StringField(strPath, iCount - i, "\") + "\"
   Next
   
   Debug strShortPath
   
 EndIf
EndProcedure

abbrpath(path.s,"/",0)
abbrpath(path.s,"/",1)
abbrpath(path.s,"/",2)
abbrpath(path.s,"/",4)
abbrpath(path.s,"/",5)


    Procedure.I GetRowHeight(ListIconID.I)
      Protected Rectangle.RECT
     
      Rectangle\left = #LVIR_BOUNDS
      SendMessage_(GadgetID(ListIconID), #LVM_GETITEMRECT, 0, Rectangle)
      ProcedureReturn Rectangle\bottom - Rectangle\top - 1
    EndProcedure
    
    
    Even If we have no connected clients, still need a "default" images List. When new clients Not already in button gadget List connect, 
            THIS will be the List that is copied And shuffled.
      
; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; CursorPosition = 136
; FirstLine = 116
; Folding = -
; EnableXP