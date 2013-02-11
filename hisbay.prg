/*
 The MIT License (MIT)
 Copyright (c) 2013 Lorenzo Fiorini lorenzo.fiorini@gmail.com

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
 associated documentation files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge, publish, distribute,
 sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
 is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @(#)hisbay.prg
 *
 * MVC web application server
 *
 * @author      Lorenzo Fiorini
 *
 */

#include "hisbdefs.ch"
#include "hblog.ch"
#include "hbhrb.ch"
#include "error.ch"

#define TYPE_CONTROLLERS "controllers"
#define TYPE_MODELS "models"
#define TYPE_VIEWS "views"

//TOFIX
dynamic useTable

memvar _Server

memvar _Request
memvar _Response
memvar _Controller
memvar _Action

/**
 *
 * @param  cIniFile
 *
 * @return nil
 *
 */
public function main( cIniFile )

   local var oServer
   local var hIniVal
   local var nPort
   local var cDirSep := hb_osPathSeparator()

   if empty( cIniFile )
      cIniFile := "." + cDirSep + "conf" + cDirSep + "hisbay.ini"
   endif

   hIniVal := hb_iniRead( cIniFile )

   hIniVal := hIniVal[ "MAIN" ]

   init log on console() name "hisbay"

   nPort := val( gethKeyOrEmpty( hIniVal, "port" ) )

   oServer := _HttpServer():new( nPort )

   oServer:hGlobals := hIniVal

   oServer:cAppRoot := gethKeyOrDefault( hIniVal, "approot", "." + cDirSep + "app" )
   oServer:cBinRoot := gethKeyOrDefault( hIniVal, "binroot", "." + cDirSep + "bin" )
   oServer:cPubRoot := gethKeyOrDefault( hIniVal, "pubroot", "." + cDirSep + "public" )
   oServer:cCfgRoot := gethKeyOrDefault( hIniVal, "cfgroot", "." + cDirSep + "conf" )
   oServer:cLogRoot := gethKeyOrDefault( hIniVal, "logroot", "." + cDirSep + "log" )
   oServer:cIncRoot := gethKeyOrDefault( hIniVal, "incroot", "." + cDirSep + "include" )
   oServer:cLibRoot := gethKeyOrDefault( hIniVal, "libroot", "." + cDirSep + "lib" )

   oServer:cCmpRoot := gethKeyOrDefault( hIniVal, "cmproot", getenv( "HARBOUR_HOME" ) )
   oServer:cHbyRoot := gethKeyOrDefault( hIniVal, "hbyroot", getenv( "HISBAY_HOME" ) )

   oServer:cExtLibs := gethKeyOrDefault( hIniVal, "extlibs", "" )

   appendRight( @oServer:cAppRoot, cDirSep )
   appendright( @oServer:cBinRoot, cDirSep )
   appendright( @oServer:cPubRoot, cDirSep )
   appendright( @oServer:cCfgRoot, cDirSep )
   appendright( @oServer:cLogRoot, cDirSep )
   appendright( @oServer:cIncRoot, cDirSep )
   appendright( @oServer:cLibRoot, cDirSep )

   appendright( @oServer:cCmpRoot, cDirSep )
   appendright( @oServer:cHbyRoot, cDirSep )

   oServer:loadLibs()

   oServer:loadRoutes()

   log "HttpServer started on port: ", nPort, " cIniFile=", cIniFile

   oServer:Start()

   log "HttpServer stopped"

   oServer:freeLibs()

   close log

   return nil

/**
 * _HttpServer is the class that provide the basic HTTP server
 * functionality.
 *
 * @author      Lorenzo Fiorini
 *
 */
class _HttpServer

   var nPort
   var mtxModule
   var mtxSession

   var nServerSock
   var lRunning init true

   var hSessions
   var hGlobals

   var cAppRoot
   var cBinRoot
   var cPubRoot
   var cCfgRoot
   var cCmpRoot
   var cLogRoot
   var cHbyRoot
   var cIncRoot
   var cLibRoot

   var cExtLibs
   var aExtLibs init {}

   var cRouteRoot
   var aRoutes init {}

   var hModules

   method init constructor
   method start
   method stop

   method loadLibs
   method loadRoutes

   method getModule
   method checkModule
   method delModule

   method compilePrg

   method freeLibs

endclass

/**
 *
 * @param  nPort
 * @param  hIniVal
 *
 * @return this
 *
 */
method init( nPort ) class _HttpServer

   ::nPort := nPort

   ::mtxModule := hb_MutexCreate()
   ::mtxSession := hb_MutexCreate()

   return this

/**
 *
 * @param
 *
 * @return this
 *
 */
method start() class _HttpServer

   local var nSocket

   ::hSessions := {=>}

   ::hModules := {=>}

   ::hModules[ TYPE_CONTROLLERS ] := {=>}
   ::hModules[ TYPE_MODELS ] := {=>}
   ::hModules[ TYPE_VIEWS ] := {=>}

   hb_inetInit()

   ::nServerSock := hb_inetServer( ::nPort )

   while ::lRunning
      nSocket := hb_inetAccept( ::nServerSock )
      if nSocket != nil
         try
            hb_threadDetach( hb_threadStart( @ProcessRequest(), Self, nSocket ) )
         catch
            log "Too many concurrent connections, slow down a bit"
            hb_idlesleep(1)
            loop
         endtry
      else
         log "Error socket invalid. Server stopped", "port", ::nPort, hb_inetErrorCode( ::nServerSock ), hb_inetErrorDesc( ::nServerSock )
         ::lRunning := .F.
      endif
   endwhile

   hb_inetClose( ::nServerSock )

   hb_inetCleanup()

   return this

/**
 *
 * @param
 *
 * @return nil
 *
 */
method loadLibs() class _HttpServer

   local var aLibs := hb_atokens( ::cExtLibs, "," )
   local var cLib

   if !empty( aLibs )
      for each cLib in aLibs
         aadd( ::aExtLibs, hb_libload( cLib ) )
      endfor
   endif

   return nil

/**
 *
 * @param
 *
 * @return nil
 *
 */
method freeLibs() class _HttpServer

   ascan( ::aExtLibs, { |pLib| hb_libfree( pLib ) } )

   return nil

/**
 *
 * @param
 *
 * @return nil
 *
 */
method loadRoutes() class _HttpServer

   local var cRoutes := memoread( ::cCfgRoot + "routes" )
   local var cEol := iif( chr(13)+chr(10) $ cRoutes, chr(13)+chr(10), chr(10) )
   local var aLines := {}
   local var aTmp := {}
   local var aTmp1
   local var aTmp2
   local var cTmp

   aeval( hb_atokens( cRoutes, cEol ), { |cLine| aadd( aLines, hb_atokens( alltrim( cLine ), " " ) ) } )
   aeval( aLines, { |aLine| iif( aLine[ 1 ] != "#", aadd( aTmp, aLine ), nil ) } )

   for each aTmp1 in aTmp
      if !empty( aTmp1[ 1 ] )
         aTmp2 := {}
         for each cTmp in aTmp1
            if !empty( cTmp )
               aadd( aTmp2, cTmp )
            endif
         endfor
         if aTmp2[ 2 ] == "/"
            ::cRouteRoot := aTmp2[ 3 ]
         else
            aadd( ::aRoutes, aTmp2 )
         endif
      endif
   endfor

   return nil

/**
 *
 * @param
 *
 * @return nil
 *
 */
method stop() class _HttpServer

   ::lRunning := .F.

   return nil

/**
 *
 * @param cType
 * @param cName
 * @param oResponse
 *
 * @return nil
 *
 */
method getModule( cType, cName, oResponse ) class _HttpServer

   local var oError
   local var hChkModule := ::checkmodule( cType, cName )
   local var cHrbFile := hChkModule[ "cHrbFile" ]

   if !hChkModule[ "lUpdated" ]
      ::compilePrg( hChkModule, oResponse )
      ::delModule( cType, cName )
   endif

   if !hb_hHaskey( ::hModules[ cType ], cName )
      try with { |e| logerror( e, oResponse, cHrbFile ) }
         ::hModules[ cType ][ cName ] := { hb_hrbload( HB_HRB_BIND_OVERLOAD, cHrbFile ), cName+"():new()" }
      catch oError
         log "error getModule:", oError:description, oError:operation
         ::delModule( cType, cName )
      endtry
   endif

   return &(::hModules[ cType ][ cName ][ 2 ])

/**
 *
 * @param  cType
 * @param  cName
 *
 * @return hReturn
 *
*/
method checkModule( cType, cName ) class _HttpServer

   local var cHrbFile := ::cBinRoot + lower( cType ) + hb_osPathSeparator() + lower( cName ) + ".hrb"
   local var cPrgFile := ::cAppRoot + lower( cType ) + hb_osPathSeparator() + lower( cName ) + ".prg"

   local var tHrbFile
   local var tPrgFile

   local var hReturn := {=>}

   hReturn[ "cHrbFile" ] := cHrbFile
   hReturn[ "cPrgFile" ] := cPrgFile

   if file( cHrbFile ) .and. file( cPrgFile )
      hb_fgetdatetime( cHrbFile, @tHrbFile )
      hb_fgetdatetime( cPrgFile, @tPrgFile )
      hReturn[ "lUpdated" ] := tHrbFile >= tPrgFile
   else
      hReturn[ "lUpdated" ] := false
   endif

   return hReturn

/**
 *
 * @param cType
 * @param cName
 *
 * @return nil
 *
 */
method delModule( cType, cName ) class _HttpServer

   if hb_hHaskey( ::hModules[ cType ], cName )
      hb_hrbunload( ::hModules[ cType ][ cName ][ 1 ] )
      ::hModules[ cType ][ cName ][ 1 ] := nil
      ::hModules[ cType ][ cName ][ 2 ] := nil
      hb_hDel( ::hModules[ cType ], cName )
   endif

   return nil

/**
 *
 * @param  cType
 * @param  cName
 * @param  oResponse
 *
 * @return cHrbFile
 *
 */
method compilePrg( hChkModule, oResponse ) class _HttpServer

   local var oError
   local var cHrbFile := hChkModule[ "cHrbFile" ]
   local var cPrgFile := hChkModule[ "cPrgFile" ]
   local var lUpdated := hChkModule[ "lUpdated" ]
   local var cCmdStr
   local var cCmpOut := ""
   local var cCmpErr := ""
   local var lSuccess := FALSE

   if !file( cPrgFile )
      oResponse:Flush( 404, "Not found", "text/html", getGenHtmlErrMsg( "404 File: " + cPrgFile + chr( 10 ) + " not found" ) )
   elseif !file( cHrbFile ) .or. !lUpdated
      try with { |e| logerror( e, oResponse, cHrbFile ) }
         cCmdStr := "harbour -n -gh -w3 -es2 -q0 -ge1"
         cCmdStr += " -I" + ::cCmpRoot + "include"
         cCmdStr += " -I" + ::cHbyRoot
         cCmdStr += " -I" + ::cIncRoot
         cCmdStr += " " + cPrgFile
         cCmdStr += " -o" + cHrbFile
         if hb_processRun( cCmdStr,, @cCmpOut, @cCmpErr ) != 0
            oResponse:Flush( 500, "Compiler Error", "text/html", getCmpHtmlErrMsg( cCmpErr, memoread( cPrgFile ) ) )
         else
            lSuccess := true
         endif
      catch oError
         log "error compilePrg:", oError:description, oError:operation
      endtry
   endif

   return lSuccess

/**
 *
 * @param  cErrFile
 * @param  cAppFile
 *
 * @return cHtml
 *
 */
static function getCmpHtmlErrMsg( cErrText, cAppText )

   local var cEol := iif( chr(13)+chr(10) $ cAppText, chr(13)+chr(10), chr(10) )
   local var aAppFile := hb_aTokens( cAppText, cEol )
   local var aErrFile := hb_aTokens( cErrText, cEol )
   local var aErrLine
   local var cErrLine
   local var nErrLine
   local var cErrMesg
   local var nIni
   local var nEnd
   local var nLen
   local var cLine
   local var nLine
   local var aTemp := {}
   local var cHtml := ""

   textcstream into cHtml
      <!DOCTYPE html>
         <html>
         <head>
         <style>
         table,th,td {
            border-collapse:collapse;
            border:1px solid black;
         }
         td {
            background-color:DarkGray;
            color:black;
         }
         </style>
         </head>

         <body>
   endtext

   for each cLine in aErrFile
      if !empty( cLine )
         aadd( aTemp, cLine )
      endif
   endfor

   aErrFile := aTemp

   for each cErrLine in aErrFile

      aErrLine := hb_aTokens( cErrLine, ":" )

      if len( aErrLine ) > 2
         nErrLine := val( aErrLine[ 2 ] )
         cErrMesg := aErrLine[ 3 ]
      else
         nErrLine := 0
         cErrMesg := ""
      endif

      nLen := len( aAppFile )

      //TOFIX in case of non assigned f.e. you get the error at the last line while
      // the real line error in the function name as 'nnn:FUNCNAME'
      // hisbay.prg:1215: warning W0003  Variable 'CLINE' declared but not used in function '1166:GETGENHTMLERRMSG'
      if ( nErrLine >= 6 ) .and. ( nErrLine <= ( nLen - 6 ) ) .and. ( nLen > 20 )
         nIni := nErrLine - 5
         nEnd := nErrLine + 5
      else
         nIni := 1
         nEnd := nLen
      endif

      cHtml += '<table><th>Line</th><th>' + cErrLine + '</th>'

      for nLine := nIni to nEnd
         cHtml += "<tr><td>" + hb_ntos( nLine ) + "</td>"
         cLine := tip_htmlspecialchars( aAppFile[ nLine ] )
         cLine := strtran( cLine, " ", "&nbsp;" )
         if nLine == nErrline
            cHtml += '<td><font size=+1 style="color:white;background-color:red">' + cLine + " &lt;--- " + cErrMesg + "</font></td>"
         else
            cHtml += '<td>' + cLine + '</td>'
         endif
         cHtml += "</tr>"
      endfor

      cHtml += "</table>"

   endfor

   textcstream into cHtml
      </body>
      </html>
   endtext

   return cHtml

/**
 * _HttpRequest is the class to parse and manage the HTTP request
 *
 * @author      Lorenzo Fiorini
 *
 */
class _HttpRequest

   var nRequestSock
   var cRequest
   var cHeader
   var cReqMethod
   var cReqUri
   var cHttpVer
   var hHeaders init {=>}
   var hCookies init {=>}
   var hGets init {=>}
   var hPosts init {=>}
   var hFields init {=>}
   var hVars init {=>}
   var hSession init {=>}
   var HTTP_RAW_POST_DATA init ""
   var QUERY_STRING init ""
   var cSID
   var cHost

   method init constructor

endclass

/**
 *
 * @param  nRequestSock
 *
 * @return Self
 *
 */
method init( nRequestSock ) class _HttpRequest

   local var aTemp
   local var cTemp
   local var nLength
   local var nResult
   local var cCrLf := hb_inetCRLF()
   local var nH

   ::nRequestSock := nRequestSock

   ::cRequest := hb_inetRecvLine( nRequestSock, @nResult )

   if nResult == 0

      /* connection closed */
      return nil

   elseif nResult < 0

      /* error */
      log "_HttpRequest nResult=", nResult, hb_inetErrorCode( nRequestSock ), hb_inetErrorDesc( nRequestSock )
      return nil

   else

      aTemp := hb_aTokens( ::cRequest, " " )

      ::cReqMethod := aTemp[ 1 ]
      ::cReqUri    := aTemp[ 2 ]
      ::cHttpVer   := aTemp[ 3 ]

      aTemp := hb_aTokens( ::cReqUri, "?" )

      if len( aTemp ) > 1
         ::cReqUri := aTemp[ 1 ]
         ::QUERY_STRING := aTemp[ 2 ]
         ::hGets := GetSepFields( aTemp[ 2 ], "&", "=" )
      else
         ::hGets := {=>}
      endif

      ::hFields := {=>}

      ::hFields := hb_hMerge( ::hFields, ::hGets )

      ::cHeader := hb_inetRecvEndBlock( nRequestSock, cCrLf + cCrLf, @nLength )

      if nLength > 0

         ::hHeaders := GetSepHeaders( ::cHeader, cCrLf, ":" )

         if hb_hPos( ::hHeaders, 'Cookie' ) != 0
            ::hCookies := GetSepFields( ::hHeaders[ 'Cookie' ], ";", "=" )
         else
            ::hCookies := {=>}
         endif

         ::cSID := nil

         if ( nH := hb_hPos( ::hGets, "SESSIONID" ) ) != 0
            ::cSID := hb_hValueAt( ::hGets, nH )
         elseif ( nH := hb_hPos( ::hPosts, "SESSIONID" ) ) != 0
            ::cSID := hb_hValueAt( ::hPosts, nH )
         elseif ( nH := hb_hPos( ::hCookies, "SESSIONID" ) ) != 0
            ::cSID := hb_hValueAt( ::hCookies, nH )
         endif

         if empty( ::cSID )
            ::cSID := tip_generateSID()
            ::hSession := {=>}
         endif

         ::hCookies[ "SESSIONID" ] := ::cSID

         ::hFields := hb_hMerge( ::hFields, ::hHeaders )

         ::hFields := hb_hMerge( ::hFields, ::hCookies )

         ::HTTP_RAW_POST_DATA := ""
         ::hPosts := {=>}

         nLength := val( gethKeyOrEmpty( ::hHeaders, "Content-Length" ) )

         if nLength > 0
            cTemp := Space( nLength )
            nLength := hb_inetRecvAll( nRequestSock, @cTemp, nLength )
            if nLength < 0
               log "_HttpRequest Content-Length < 0"
               return nil
            else
               cTemp := left( cTemp, nLength )
            endif
            ::HTTP_RAW_POST_DATA := cTemp
            if gethKeyOrEmpty( ::hHeaders, "Content-Type" ) = "application/x-www-form-urlencoded"
               ::hPosts := GetSepFields( cTemp, "&", "=" )
               ::hFields := hb_hMerge( ::hFields, ::hPosts )
            endif
         endif

      endif

   endif

   return Self

/**
 * _HttpResponse is the class to create and manage the HTTP response
 *
 * @author      Lorenzo Fiorini
 *
 */
class _HttpResponse

   var oServer
   var nRequestSock
   var hHeaders init {=>}
   var hCookies init {=>}
   var cBuffer init ""
   var lCompress init .F.
   var cHost

   method init
   method setHeader
   method write
   method redirect
   method flush

endclass

/**
 *
 * @param  nRequestSock
 * @param  oServer
 *
 * @return Self
 *
 */
method init( nRequestSock ) class _HttpResponse

   ::nRequestSock := nRequestSock

   ::cBuffer := ""

   ::hHeaders := { "Server" => "_HttpServer", ;
                   "Content-Type" => "text/html; charset=UTF-8", ;
                   "Content-Length" => 0 }

   return Self

/**
 *
 * @param  cField
 * @param  cValue
 *
 * @return nil
 *
 */
method setheader( cField, cValue ) class _HttpResponse

   ::hHeader[ cField ] := cValue

   return nil

/**
 *
 * @param  cData
 *
 * @return nil
 *
 */
method write( cData ) class _HttpResponse

   ::cBuffer += cData

   return nil

/**
 *
 * @param  cUrl
 *
 * @return nil
 *
 */
method redirect( cUrl ) class _HttpResponse

   local var cCrLf := hb_inetCRLF()

   hb_inetSendAll( ::nRequestSock, "HTTP/1.1 302 Found" + cCrLf + "Location: " + cUrl + cCrLf + cCrLf )

   return nil

/**
 *
 * @param  nStatus
 * @param  cReason
 * @param  cMimeType
 * @param  cData
 *
 * @return nil
 *
 */
method flush( nStatus, cReason, cMimeType, cData ) class _HttpResponse

   local var cCrLf := hb_inetCRLF()
   local var cHeader
   local var cBuffer := ::cBuffer
   local var cBufType

   if empty( nStatus )
      nStatus := 200
   endif

   if empty( cReason )
      cReason := "OK"
   endif

   cHeader := "HTTP/1.1 " + alltrim( str( nStatus ) ) + " " + cReason + cCrLf

   if !empty( cMimeType )
      ::hHeaders[ "Content-Type" ] := cMimeType
   endif

   if !empty( cData )
      cBuffer += cData
   endif

   cBufType := ::hHeaders[ "Content-Type" ]

   ::hHeaders[ "Cache-Control" ] := "no-cache"

   if ::lCompress .and. ( nStatus == 200 ) .and. !( "image" $ cBufType )

      cBuffer := HB_ZCOMPRESS( cBuffer )

      ::hHeaders[ "Content-Encoding" ] := "deflate"

   endif

   ::hHeaders[ "Content-Length" ] := hb_ntos( Len( cBuffer ) )

   hb_hEval( ::hHeaders, { |k,v| cHeader += alltrim( k ) + ":" + alltrim( v ) + cCrLf } )

   hb_hEval( ::hCookies, { |k,v| cHeader += 'Set-Cookie: ' + k + '=' + v + ';' + cCrLf } )

   hb_inetSendAll( ::nRequestSock, cHeader + cCrLf + cBuffer )

   ::cBuffer := ""

   ::lCompress := .F.

   return nil

/**
 *
 * @param  oServer
 * @param  nSocket
 *
 * @return
 *
 */
static function processRequest( oServer, nSocket )

   local var oError
   local var oRequest
   local var oResponse
   local var aHostVars

   local var cController
   local var cAction
   local var cPubFile

   if ( oRequest := _HttpRequest():new( nSocket, oServer ) ) == nil
      return -1 // oRequest is invalid, stop here
   endif

   oResponse := _HttpResponse():new( nSocket, oServer )

   if empty( gethKeyOrEmpty( oRequest:hHeaders, "Host" ) )
      oResponse:Flush( 400, "Bad Request", "text/plain" )
      return -2 // oRequest is invalid, stop here
   endif

   if hb_mutexLock( oServer:mtxSession )
      oRequest:hSession := gethKeyOrDefault( oServer:hSessions, oRequest:cSID, {=>} )
      hb_mutexUnLock( oServer:mtxSession )
   endif

   aHostVars := hb_aTokens( oRequest:hHeaders[ "Host" ], ":" )

   oRequest:hVars[ 'HostName' ] := aHostVars[ 1 ]
   oRequest:hVars[ 'HostPort' ] := aHostVars[ 2 ]

   oRequest:hVars[ 'BinRoot' ] := oServer:cBinRoot
   oRequest:hVars[ 'PubRoot' ] := oServer:cPubRoot

   oResponse:hCookies := oRequest:hCookies
   oResponse:cHost := oRequest:hHeaders[ "Host" ]
   oResponse:lCompress := ( "deflate" $ gethKeyOrEmpty( oRequest:hHeaders, "Accept-Encoding" ) )

   processRoutes( oServer, oRequest, oResponse, @cController, @cAction, @cPubFile )

   if !empty( cController ) .and. !empty( cAction )
      try with { |e| logerror( e, oResponse, "Controller: " + cController + " Action: " + cAction ) }
         public var _Server, _Request, _Response, _Controller, _Action
         _Server := oServer
         _Request := oRequest
         _Response := oResponse
         _Controller := oServer:getModule( TYPE_CONTROLLERS, cController, oResponse )
         _Action := cAction
         &("_Controller:" + cAction + "()")
         _Controller := nil
      catch oError
         log "error processRequest:", oError:description, oError:operation
         oServer:delModule( TYPE_CONTROLLERS, cController )
      endtry
   elseif !empty( cPubFile )
      if !file( cPubFile )
         oResponse:Flush( 404, "Not found", "text/html", getGenHtmlErrMsg( "404 File: " + cPubFile + chr( 10 ) + " not found" ) )
      else
         oResponse:Flush( 200, "OK", tip_filemimetype( cPubFile ), memoread( cPubFile ) )
      endif
   endif

   if hb_mutexLock( oServer:mtxSession )
      oServer:hSessions[ oRequest:cSID ] := oRequest:hSession
      hb_mutexUnLock( oServer:mtxSession )
   endif

   hb_inetClose( nSocket )

   return 0

/**
 *
 * @param  oRequest
 * @param  cController
 * @param  cAction
 *
 * @return
 *
 */
static function processRoutes( oServer, oRequest, oResponse, cController, cAction, cDocFile )

   local var cReqMethod
   local var cReqUri
   local var cPath
   local var cName
   local var cExt
   local var cDrive
   local var nRoute
   local var cMatch
   local var cTarget

   HB_SYMBOL_UNUSED( oResponse )

   cReqMethod := alltrim( oRequest:cReqMethod )
   cReqUri := alltrim( oRequest:cReqUri )

   hb_fnamesplit( cReqUri, @cPath, @cName, @cExt, @cDrive )

   if !empty( cPath ) .and. ( left( cPath, 1 ) == "/" )
      cPath := substr( cPath, 2 )
   endif

   cExt := lower( cExt )

   //log "cReqMethod=", cReqMethod, "cReqUri=", cReqUri, "cPath=", cPath, "cName=", cName, "cExt=", cExt, "oServer:cPubRoot", oServer:cPubRoot

   if cReqUri == "/"
      cTarget := oServer:cRouteRoot
   else
      if ( nRoute := ascan( oServer:aRoutes, { |a| cReqMethod == a[1] .and. cReqUri = a[2] } ) ) > 0
         cMatch := oServer:aRoutes[ nRoute ][ 2 ]
         cTarget := oServer:aRoutes[ nRoute ][ 3 ]
      elseif ( nRoute := ascan( oServer:aRoutes, { |a| "*" == a[1] } ) ) > 0
         cMatch := oServer:aRoutes[ nRoute ][ 2 ]
         cTarget := oServer:aRoutes[ nRoute ][ 3 ]
      endif
   endif

   //log "cTarget=", cTarget, "cPath", cPath, "cName", cName

   if cTarget == "404"
      //TOFIX
      cController := ""
      cAction := ""
      cDocFile := oServer:cPubRoot + "favicon.ico"
   elseif cTarget == "staticDir:public"
      cController := ""
      cAction := ""
      cDocFile := oServer:cPubRoot + strtran( cPath, substr( cMatch, 2 ), "" ) + cName + cExt
      cDocfile := strtran( cDocFile, "/", hb_osPathSeparator() )
   elseif cTarget == "{controller}:{action}"
      if !empty( cPath ) .and. !empty( cName )
         cController := lower( substr( cPath, 1, len( cPath ) - 1 ) )
         cAction := lower( cName )
         cDocFile := ""
      elseif empty( cPath ) .and. !empty( cName )
         cController := lower( cName )
         cAction := "index"
         cDocFile := ""
      elseif empty( cName) .and. !empty( cPath )
         cController := lower( substr( cPath, 1, len( cPath ) - 1 ) )
         cAction := "index"
         cDocFile := ""
      else
         cController := lower( cName )
         cAction := "index"
      endif
   elseif !empty( cTarget )
      cController := lower( left( cTarget, at( ":", cTarget ) - 1 ) )
      cAction := lower( substr( cTarget, at( ":", cTarget ) + 1 ) )
      cDocFile := ""
   endif

   if empty( cDocFile ) .and. empty( cController )
      oResponse:Flush( 500, "Error", "text/html", getGenHtmlErrMsg( "conf/routes problem: target " + cTarget + chr( 10 ) + "invalid for Http Method: " + cReqMethod + " and Request-URI: " + cReqUri ) )
   endif

   //log "cController", cController, "cAction", cAction, "cDocFile", cDocFile

   return nil

/**
 *
 * @param  e
 * @param  oResponse
 * @param  cCommand
 *
 * @return ( 0 )
 *
 */
public function logerror( e, oResponse, cCommand )

   local var cErrStr := ""

   if ( e:genCode == EG_ZERODIV )

      return 0

   endif

   if ( e:genCode == EG_OPEN .and. e:osCode == 32 .and. e:canDefault )

      neterr( true )

      return false

   endif

   if ( e:genCode == EG_APPENDLOCK .and. e:canDefault )

      neterr( true  )

      return false

   endif

   if ( e:genCode == EG_NOALIAS )
//TOFIX
      if !useTable( e:operation )

         break( e )

      endif

      return true

   endif

   if !empty( cCommand )

      cErrStr += cCommand + " error "

   endif

   if true // needed to avoid unreacheable code message at break

      oResponse:Flush( 500, "Error", "text/html", getGenHtmlErrMsg( cErrStr + chr( 10 ) + ErrorMessage( e ) ) )

      break( e )

   endif

   return false

/**
 *
 * @param  e
 *
 * @return cMessage
 *
 */
static function errormessage( e )

   local var cMessage
   local var i

   cMessage := iif( e:severity > ES_WARNING, "Error ", "Warning " )

   if ( valtype( e:subsystem ) == "C" )

      cMessage += e:subsystem()

   else

      cMessage += "???"

   endif

   if ( valtype( e:subCode ) == "N" )

      cMessage += "/" + hb_ntos( e:subCode )

   else

      cMessage += "/???"

   endif

   if ( valtype( e:description ) == "C" )

      cMessage += ( " " + e:description )

   endif

   if ( !empty( e:filename ) )

      cMessage += ( ":" + e:filename )

   elseif ( !empty( e:operation ) )

      cMessage += ( ":" + e:operation )

   endif

   i := 3

   while !empty( procname( i ) )

      cMessage += chr( 10 ) + alltrim( procname( i ) ) + "(" + hb_ntos( procline( i ) ) + ")"

      i ++

   endwhile

   return cMessage

/**
 *
 * @param  cErrText
 *
 * @return cHtml
 *
 */
static function getGenHtmlErrMsg( cErrText )

   local var aErrFile := hb_aTokens( cErrText, chr( 10 ) )
   local var aErrLine
   local var nLine
   local var cHtml := ""

   textcstream into cHtml
      <!DOCTYPE html>
         <html>
         <head>
         <style>
         table,th,td {
            border-collapse:collapse;
            border:1px solid black;
         }
         td {
            background-color:DarkGray;
            color:black;
         }
         </style>
         </head>

         <body>
   endtext

   if len( aErrFile ) > 1
      aErrLine := hb_aTokens( aErrFile[ 2 ], ":" )

      if aErrLine[ 1 ] == "Error BASE/1004 Message not found"
         aErrFile := { "Class: " + aErrLine[ 2 ] + " message: " + aErrLine[ 3 ], ;
                       "class or message undefined or not found" }
      endif
   endif

   cHtml += "<table><th>" + aErrFile[ 1 ] + "</th>"

   for nLine := 2 to len( aErrFile )

      cHtml += "<tr><td>" + tip_htmlspecialchars( aErrFile[ nLine ] ) + "</td></tr>"

   endfor

   cHtml += "</table>"

   textcstream into cHtml
      </body>
      </html>
   endtext

   return cHtml

/**
 *
 * @param  cTemp
 * @param  cSep
 * @param  cPairSep
 *
 * @return hData
 *
 */
static function getSepHeaders( cTemp, cSep, cPairSep )

   local var hData := {=>}
   local var aTemp := hb_aTokens( cTemp, cSep )
   local var nLen := len( aTemp )
   local var nPos
   local var nCount

   if nLen > 0
      for nCount := 1 TO nLen
         nPos := at( cPairSep, aTemp[ nCount ] )
         if nPos > 1
            hData[ alltrim( tip_urlDecode( Left( aTemp[ nCount ], nPos - 1 ) ) ) ] := alltrim( tip_urlDecode( SubStr( aTemp[ nCount ], nPos + 1 ) ) )
         endif
      next
   endif

   return hData

/**
 *
 * @param  cTemp
 * @param  cSep
 * @param  cPairSep
 *
 * @return hData
 *
 */
static function getSepFields( cTemp, cSep, cPairSep )

   local var hData := {=>}
   local var aTemp := hb_aTokens( cTemp, cSep )
   local var nLen := len( aTemp )
   local var aVar
   local var nCount

   if nLen > 0
      for nCount := 1 TO nLen
         aVar := hb_aTokens( aTemp[ nCount ], cPairSep )
         if Len( aVar ) == 2
            hData[ alltrim( tip_urlDecode( aVar[ 1 ] ) ) ] := tip_urlDecode( aVar[ 2 ] )
         endif
      next
   endif

   return hData

static function appendRight( cString, cAdd )

   if right( cString, 1 ) != cAdd
      cString += cAdd
   endif

   return nil

#include "mvc.prg"
#include "htmldoc.prg"
//TOFIX use only if you know how to use it
//#include "hdbcpg.prg"
