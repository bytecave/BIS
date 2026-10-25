;This software provided under the BSD 3-Clause License. Copyright 2019-2026, ByteLord

#RECEIVEBUFFER = 4096
#MAXHEADERSIZE = 16384
#MAXCONNECTIONS = 64
#REQUESTTIMEOUT = 5000
#SENDTIMEOUT = 2000
#SENDCHUNKSIZE = 65536
#SERVERIDSTRING = "Server: " + #BIS_TITLE + " " + #BIS_VERSION

Enumeration
  #SERVERSTARTING = 5000
  #SERVERSTARTED
  #SERVERNOTSTARTED
  #SERVERMEMORY
EndEnumeration

Structure sREQUEST
  headers.s
  started.q
EndStructure

; Tests can inject partial writes; production always calls the real network API.
Procedure.i WriteSocket(hSocket.i, *buffer, length.i)
  CompilerIf Defined(BIS_TEST, #PB_Constant)
    If g_fFakeSocket
      If NextElement(g_listFakeWrites())
        If g_listFakeWrites() > 0
          g_strFakeOutput + PeekS(*buffer, g_listFakeWrites(), #PB_Ascii)
        EndIf
        ProcedureReturn g_listFakeWrites()
      EndIf
      ProcedureReturn -1
    EndIf
  CompilerEndIf
  ProcedureReturn SendNetworkData(hSocket, *buffer, length)
EndProcedure

Procedure.i SendAll(hSocket.i, *buffer, length.i)
  Protected offset.i, sent.i, chunk.i
  Protected lastProgress.q = ElapsedMilliseconds()
  While offset < length And g_fNetworkEnabled
    chunk = length - offset
    If chunk > #SENDCHUNKSIZE : chunk = #SENDCHUNKSIZE : EndIf
    sent = WriteSocket(hSocket, *buffer + offset, chunk)
    If sent > 0 And sent <= chunk
      offset + sent
      lastProgress = ElapsedMilliseconds()
    Else
      If ElapsedMilliseconds() - lastProgress >= #SENDTIMEOUT
        ProcedureReturn #False
      EndIf
      Delay(1)
    EndIf
  Wend
  ProcedureReturn Bool(offset = length)
EndProcedure

Procedure.i SendTextResponse(hSocket.i, status.s, body.s, extraHeaders.s = "")
  Protected response.s
  Protected *data
  Protected result.i
  response = "HTTP/1.1 " + status + #CRLF$ + #SERVERIDSTRING + #CRLF$ +
             "Connection: close" + #CRLF$ + "Cache-Control: no-store" + #CRLF$ +
             "Content-Type: text/plain; charset=utf-8" + #CRLF$ +
             "Content-Length: " + Str(StringByteLength(body, #PB_UTF8)) + #CRLF$ +
             extraHeaders + #CRLF$ + body
  *data = UTF8(response)
  If *data
    result = SendAll(hSocket, *data, StringByteLength(response, #PB_UTF8))
    FreeMemory(*data)
  EndIf
  ProcedureReturn result
EndProcedure

Procedure.i SendImage(hSocket.i, strImageToSend.s, strClientIP.s)
  Protected file.i, *buffer, *header
  Protected remaining.q, length.q
  Protected chunk.i, bytes.i, result.i
  Protected contentType.s, header.s
  file = ReadFile(#PB_Any, strImageToSend, #PB_File_SharedRead)
  If Not file
    SendTextResponse(hSocket, "404 Not Found", "Image unavailable.")
    ProcedureReturn #False
  EndIf
  length = Lof(file)
  If length <= 0
    CloseFile(file)
    SendTextResponse(hSocket, "404 Not Found", "Image unavailable.")
    ProcedureReturn #False
  EndIf
  *buffer = AllocateMemory(#SENDCHUNKSIZE, #PB_Memory_NoClear)
  If Not *buffer
    CloseFile(file)
    SendTextResponse(hSocket, "503 Service Unavailable", "Image buffer unavailable.")
    ProcedureReturn #False
  EndIf
  Select LCase(GetExtensionPart(strImageToSend))
    Case "jpg", "jpeg" : contentType = "image/jpeg"
    Case "png" : contentType = "image/png"
    Case "gif" : contentType = "image/gif"
    Case "bmp" : contentType = "image/bmp"
    Default : contentType = "application/octet-stream"
  EndSelect
  header = "HTTP/1.1 200 OK" + #CRLF$ + #SERVERIDSTRING + #CRLF$ +
           "Content-Length: " + Str(length) + #CRLF$ +
           "Content-Type: " + contentType + #CRLF$ +
           "Connection: close" + #CRLF$ + "Cache-Control: no-store" + #CRLF$ + #CRLF$
  *header = UTF8(header)
  If *header
    result = SendAll(hSocket, *header, StringByteLength(header, #PB_UTF8))
    FreeMemory(*header)
    remaining = length
    While result And remaining > 0
      chunk = #SENDCHUNKSIZE
      If remaining < chunk : chunk = remaining : EndIf
      bytes = ReadData(file, *buffer, chunk)
      If bytes <> chunk
        result = #False
      Else
        result = SendAll(hSocket, *buffer, bytes)
        remaining - bytes
      EndIf
    Wend
  EndIf
  FreeMemory(*buffer)
  CloseFile(file)
  ProcedureReturn result
EndProcedure

Procedure HandleHTTPRequest(hSocket.i, request.s)
  Protected line.s = StringField(request, 1, #CRLF$)
  Protected method.s = StringField(line, 1, " ")
  Protected version.s = StringField(line, 3, " ")
  Protected strImage.s, strClientIP.s
  Protected now.q = ElapsedMilliseconds()
  Protected wait.q
  Protected accepted.i = #True
  If CountString(line, " ") <> 2 Or StringField(line, 2, " ") = "" Or
     (version <> "HTTP/1.0" And version <> "HTTP/1.1")
    SendTextResponse(hSocket, "400 Bad Request", "Invalid HTTP request line.")
    ProcedureReturn
  EndIf
  If method <> "GET"
    SendTextResponse(hSocket, "405 Method Not Allowed", "Use GET to request an image.", "Allow: GET" + #CRLF$)
    ProcedureReturn
  EndIf
  strClientIP = IPString(GetClientIP(hSocket))
  LockMutex(g_MUTEX\Clients)
  If Not FindMapElement(g_mapClients(), strClientIP)
    accepted = CreateClientList(GetClientIP(hSocket), strClientIP)
  EndIf
  If accepted
    FindMapElement(g_mapClients(), strClientIP)
    ; Creation initializes the timestamp; measure after it to admit the first GET.
    now = ElapsedMilliseconds()
    wait = g_qMinTimeBetweenImages - (now - g_mapClients()\qTimeSinceLastRequest)
    If wait <= 0
      g_mapClients()\qTimeSinceLastRequest = now
      strImage = GetNextImage(strClientIP)
    EndIf
  EndIf
  UnlockMutex(g_MUTEX\Clients)
  If Not accepted
    SendTextResponse(hSocket, "503 Service Unavailable", "All client slots are in use.")
  ElseIf wait > 0
    SendTextResponse(hSocket, "429 Too Many Requests", "Please wait before requesting another image.",
                     "Retry-After: " + Str((wait + 999) / 1000) + #CRLF$)
  ElseIf strImage = ""
    SendTextResponse(hSocket, "404 Not Found", "No images available.")
  ElseIf SendImage(hSocket, strImage, strClientIP)
    LockMutex(g_MUTEX\Clients)
    If FindMapElement(g_mapClients(), strClientIP)
      g_iImagesServed + 1
      g_iForeverImagesServed + 1
      g_mapClients()\iTotalImages + 1
      g_mapClients()\fAskedForImage = #True
      LockMutex(g_MUTEX\Thumbnail)
      ; Keep only the latest pending image for each slot.
      ForEach g_listThumbnails()
        If g_listThumbnails()\iGadget = g_mapClients()\iGadget
          DeleteElement(g_listThumbnails())
          Break
        EndIf
      Next
      AddElement(g_listThumbnails())
      g_listThumbnails()\strImage = strImage
      g_listThumbnails()\iGadget = g_mapClients()\iGadget
      g_listThumbnails()\iCount = g_mapClients()\iTotalImages
      UnlockMutex(g_MUTEX\Thumbnail)
      PostEvent(#UPDATETHUMBNAILTOOLTIP, wndMain, 0)
    EndIf
    UnlockMutex(g_MUTEX\Clients)
  EndIf
EndProcedure

Procedure ImageServerThread(Parameter)
  Protected *buffer
  Protected socket.i, event.i, server.i, received.i
  Protected key.s, request.s
  Protected lastSweep.q
  Protected NewMap requests.sREQUEST()
  *buffer = AllocateMemory(#RECEIVEBUFFER)
  If Not *buffer
    g_iNetworkStatus = #SERVERMEMORY
    ProcedureReturn
  EndIf
  server = CreateNetworkServer(#PB_Any, g_iPort, #PB_Network_TCP | #PB_Network_IPv4, g_strServerIP)
  If Not server
    FreeMemory(*buffer)
    g_iNetworkStatus = #SERVERNOTSTARTED
    ProcedureReturn
  EndIf
  g_iNetworkStatus = #SERVERSTARTED
  While g_fNetworkEnabled
    event = NetworkServerEvent(server)
    If event
      socket = EventClient()
      key = Str(socket)
      Select event
        Case #PB_NetworkEvent_Connect
          If MapSize(requests()) >= #MAXCONNECTIONS
            SendTextResponse(socket, "503 Service Unavailable", "Too many open connections.")
            CloseNetworkConnection(socket)
          Else
            AddMapElement(requests(), key)
            requests()\started = ElapsedMilliseconds()
          EndIf
        Case #PB_NetworkEvent_Data
          If FindMapElement(requests(), key)
            received = ReceiveNetworkData(socket, *buffer, #RECEIVEBUFFER)
            If received > 0
              requests()\headers + PeekS(*buffer, received, #PB_Ascii)
              If Len(requests()\headers) > #MAXHEADERSIZE
                SendTextResponse(socket, "431 Request Header Fields Too Large", "Request headers too large.")
                CloseNetworkConnection(socket)
                DeleteMapElement(requests())
              ElseIf FindString(requests()\headers, #CRLF$ + #CRLF$)
                request = requests()\headers
                HandleHTTPRequest(socket, request)
                CloseNetworkConnection(socket)
                DeleteMapElement(requests())
              EndIf
            ElseIf received < 0
              CloseNetworkConnection(socket)
              DeleteMapElement(requests())
            EndIf
          EndIf
        Case #PB_NetworkEvent_Disconnect
          ; PureBasic already closes disconnected clients.
          DeleteMapElement(requests(), key)
      EndSelect
    Else
      Delay(1)
    EndIf
    If ElapsedMilliseconds() - lastSweep >= 100
      ForEach requests()
        If ElapsedMilliseconds() - requests()\started >= #REQUESTTIMEOUT
          SendTextResponse(Val(MapKey(requests())), "408 Request Timeout", "Request headers timed out.")
          CloseNetworkConnection(Val(MapKey(requests())))
          DeleteMapElement(requests())
        EndIf
      Next
      lastSweep = ElapsedMilliseconds()
    EndIf
  Wend
  CloseNetworkServer(server)
  FreeMemory(*buffer)
EndProcedure
