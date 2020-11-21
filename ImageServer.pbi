;This software provided under MIT license. Copyright 2019-2020, ByteCave

#RECEIVEBUFFER = 4096
#RETRYCOUNT = 100
#SERVERIDSTRING = "Server: " + #BIS_TITLE + " " + #BIS_VERSION

Enumeration
  #SERVERSTARTING = 5000
  #SERVERSTARTED
  #SERVERNOTSTARTED
  #SERVERMEMORY
EndEnumeration

Procedure GetImageData(strPath.s)
  Protected hFile.i
  Protected *pImageData
  Protected iFileLen.i
  
  hFile = ReadFile(#PB_Any, strPath, #PB_File_SharedRead)
  If hFile
    iFileLen = Lof(hFile)
    
    If iFileLen > 0
      *pImageData = AllocateMemory(iFileLen, #PB_Memory_NoClear)
      ReadData(hFile, *pImageData, iFileLen)
    EndIf
    
    CloseFile(hFile)
  EndIf
    
  ProcedureReturn *pImageData
EndProcedure

Procedure SendImage(hSocket.i, strImageToSend.s, strClientIP.s)
  Protected strHeader.s, strContentType.s
  Protected *pSendBuffer, *pImageData, *pData
  Protected iPacketSize.i, iSentBytes.i, iRetries.i
  Protected iImageLength.i
  
  *pImageData = GetImageData(strImageToSend)
  
  If *pImageData
    strContentType = "image/" + LCase(GetExtensionPart(strImageToSend))
  Else
    strContentType = "text/html"
    *pImageData = UTF8("<html><p>Unable to transmit image: " + strImageToSend + "</p></html>")
  EndIf
  
  iImageLength = MemorySize(*pImageData)

  strHeader= "HTTP/1.1 200 OK" + #CRLF$ +
             #SERVERIDSTRING + #CRLF$ +
             "Content-Length: " + Str(iImageLength) + #CRLF$ +
             "Content-Type: " + strContentType + #CRLF$ + 
             #CRLF$
  
  iPacketSize = StringByteLength(strHeader, #PB_UTF8) + iImageLength
  *pSendBuffer = AllocateMemory(iPacketSize, #PB_Memory_NoClear)
  *pData = *pSendBuffer + PokeS(*pSendBuffer, strHeader, -1, #PB_UTF8)
  
  CopyMemory(*pImageData, *pData, iImageLength)
  FreeMemory(*pImageData)
  
  Repeat
    iSentBytes + SendNetworkData(hSocket, *pSendBuffer + iSentBytes, iPacketSize - iSentBytes)
    iRetries + 1
  Until iSentBytes >= iPacketSize Or iSentBytes = -1 Or iRetries = #RETRYCOUNT
  
  FreeMemory(*pSendBuffer)
EndProcedure
  
Procedure HandleHTTPRequest(hSocket, *pReceivedData)
  Protected *send
  Protected strImageToSend.s, strClientIP.s
  Protected qElapsedTime.q
  Protected fRC.i = #True
  Protected iIPAddress.i
  
  ;only care about GET requests
  If PeekS(*pReceivedData, 3, #PB_UTF8) = "GET"
    qElapsedTime = ElapsedMilliseconds()
    
    iIPAddress = GetClientIP(hSocket)
    strClientIP = IPString(iIPAddress)
    
    LockMutex(g_MUTEX\Clients)
    If Not FindMapElement(g_mapClients(), strClientIP)
      fRC = CreateClientList(iIPAddress, strClientIP)  ;returns true if UI gadget slot exists
    EndIf
    
    ;If there's no UI gadget slot available for a new connection, we ignore the request
    If fRC
      ;After successful call to CreateClientList(), g_mapClients() points to the Map entry for this IP address
      
      If qElapsedTime - g_mapClients()\qTimeSinceLastRequest >= g_qMinTimeBetweenImages
        g_mapClients()\qTimeSinceLastRequest = qElapsedTime
        
        strImageToSend = GetNextImage(strClientIP)
        
        UnlockMutex(g_MUTEX\Clients)
        
        SendImage(hSocket, strImageToSend, strClientIP)
      Else
        UnlockMutex(g_MUTEX\Clients)
      EndIf
    Else
      ;Behavior is undefined if we attempt to unlock an already-unlocked mutex. Hence the multiple UnlockMutex() calls.
      UnlockMutex(g_MUTEX\Clients)
    EndIf
  EndIf
EndProcedure

Procedure ImageServerThread(Parameter)
  Protected *pReceivedData
  Protected hSocket.i
  Protected iNetworkEvent.i
  Protected iServerID.i
  
  iServerID = CreateNetworkServer(#PB_Any, g_iPort, #PB_Network_TCP, g_strServerIP)
  
  If iServerID = 0
    g_iNetworkStatus = #SERVERNOTSTARTED
  Else
    *pReceivedData = AllocateMemory(#RECEIVEBUFFER)
    g_iNetworkStatus = #SERVERSTARTED
  
    Repeat
      iNetworkEvent = NetworkServerEvent()
      hSocket = EventClient()
      
      If hSocket And iNetworkEvent = #PB_NetworkEvent_Data
          ReceiveNetworkData(hSocket, *pReceivedData, #RECEIVEBUFFER)
          HandleHTTPRequest(hSocket, *pReceivedData)
      EndIf
        
      Delay(1)
    Until Not g_fNetworkEnabled
    
    FreeMemory(*pReceivedData)
      
    CloseNetworkServer(iServerID)
  EndIf
EndProcedure
; IDE Options = PureBasic 5.71 beta 1 LTS (Windows - x64)
; Folding = -
; EnableXP
; CurrentDirectory = binaries\
; Compiler = PureBasic 5.71 LTS (Windows - x64)