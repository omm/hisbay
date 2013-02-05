/*
 The MIT License (MIT)
 Copyright (c) 2012 Lorenzo Fiorini lorenzo.fiorini@gmail.com

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

#ifdef HARSUPPORT

/**
 *
 * @param  cHarFile
 *
 * @return nil
 *
 */
function harLoad( cHarFile )

   local var cZipName, dDate, cTime, nInternalAttr, nExternalAttr, nMethod, nSize, nCompressedSize
   local var cFile

   hSHarBag := {=>}

   pSHar := hb_UnzipOpen( cHarFile )

   hb_UnzipFileFirst( pSHar )

   while .t.

      HB_UnzipFileInfo( pSHar, @cZipName, @dDate, @cTime, @nInternalAttr, @nExternalAttr, @nMethod, @nSize, @nCompressedSize )

      hSHarBag[ cZipName ] := { "pos" => HB_UNZIPFILEPOS( pSHar ), "size" => nSize }

      if hb_UnzipFileNext( pSHar ) != 0
         exit
      endif

   endwhile

   return nil

/**
 *
 * @param
 *
 * @return nil
 *
 */
function harUnLoad()

   hb_UnzipClose( pSHar )

   return nil

/**
 *
 * @param  cFile
 *
 * @return cBuffer
 *
 */
function harRead( cFile )

   local hFile := gethKeyOrEmpty( hSHarBag, cFile )
   local cBuffer

   if !empty( hFile )
      hb_UnzipFileGoto( pSHar, hFile[ "pos" ] )
      hb_UnzipFileOpen( pSHar )
      cBuffer := space( hFile[ "size" ] )
      hb_UnzipFileRead( pSHar, @cBuffer )
      hb_UnzipFileClose( pSHar )
   endif

   return cBuffer

/* a possible use of har file */

elseif cExt == ".hrb"
cRunFile := harRead( "out/" + cName + cExt )
begin sequence with { |e| LogError( e, oResponse, cName + cExt ) }
   if !EMPTY( pHRB := HB_HRBLOAD( cHarFile ) )
      xResult := HRBMAIN()
      if HB_ISCHARACTER( xResult )
         oResponse:Flush( 200, "OK",, xResult )
      endif
   endif
   always
   if !EMPTY( pHRB )
      HB_HRBUNLOAD( pHRB )
   endif
endwhile
else
cHarFile := harRead( "res/" + cPath + cName + cExt )
if empty( cHarFile )
   oResponse:Flush( 404, "Not found", "text/html", "404 File: " + cPath + cName + cExt + " not found" )
elseif cExt $ ".html|.xml|.css"
   oResponse:Flush( 200, "OK", "text/" + substr( cExt, 2 ), cHarFile )
elseif cExt $ ".png|.jpg|.gif|.ico"
   oResponse:Flush( 200, "OK", "image/" + substr( cExt, 2 ), cHarFile )
elseif cExt $ ".swf"
   oResponse:Flush( 200, "OK", "application/x-shockwave-flash", cHarFile )
elseif cExt $ ".pdf"
   oResponse:Flush( 200, "OK", "application/pdf", cHarFile )
else
   oResponse:Flush( 406, "Not Acceptable", "text/html", "406 Command: " + cName + " File: " + cFile + " not acceptable" )
endif
endif

#endif

